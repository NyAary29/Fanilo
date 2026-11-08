"""RENY : grossesse, calendrier CPN configuré, visites et rappels. Données fictives."""

import logging
from datetime import timedelta
from pathlib import Path

import pytest
import yaml
from sqlalchemy import select

from app.core.config import DEFAULT_ANC_SCHEDULE_PATH
from app.db.types import utcnow
from app.modules.reny import cli
from app.modules.reny.models import Pregnancy, Reminder, ReminderStatus
from app.modules.reny.schedule import ScheduleUnavailableError, load_schedule

CONSENT = {"method": "oral", "information_version": "demo-0.1"}


@pytest.fixture
def settings(settings):
    """Le calendrier de démonstration est autorisé dans ces tests (sauf mention)."""
    return settings.model_copy(update={"allow_demo_content": True})


def _beneficiary(client, world, who="ac_a", channel="sms"):
    resp = client.post(
        "/beneficiaries", json={"preferred_channel": channel}, headers=world.headers(who)
    )
    return resp.json()["id"]


def _consent(client, world, bid, scope, who="ac_a"):
    resp = client.post(
        f"/beneficiaries/{bid}/consents",
        json=CONSENT | {"scope": scope},
        headers=world.headers(who),
    )
    assert resp.status_code == 201
    return resp.json()["id"]


def _pregnancy(client, world, bid, lmp_days_ago=30, who="ac_a"):
    lmp = (utcnow().date() - timedelta(days=lmp_days_ago)).isoformat()
    return client.post(
        f"/beneficiaries/{bid}/pregnancies", json={"lmp_date": lmp}, headers=world.headers(who)
    )


def _visits(client, world, pid, who="ac_a"):
    return client.get(f"/pregnancies/{pid}/anc-visits", headers=world.headers(who)).json()["items"]


def _reminders(db, status=None):
    db.expire_all()
    stmt = select(Reminder)
    if status:
        stmt = stmt.where(Reminder.status == status)
    return list(db.scalars(stmt))


# --- Grossesse et consentement ------------------------------------------------


def test_pregnancy_refused_without_reny_consent(client, world, db):
    bid = _beneficiary(client, world)
    resp = _pregnancy(client, world, bid)
    assert resp.status_code == 422
    assert "Consentement RENY" in resp.json()["detail"]
    assert db.scalar(select(Pregnancy)) is None


def test_pregnancy_refused_after_reny_withdrawal(client, world):
    bid = _beneficiary(client, world)
    cid = _consent(client, world, bid, "reny")
    client.post(f"/consents/{cid}/withdraw", headers=world.headers("ac_a"))
    assert _pregnancy(client, world, bid).status_code == 422


def test_pregnancy_generates_anc_calendar_from_config(client, world):
    bid = _beneficiary(client, world)
    _consent(client, world, bid, "reny")
    resp = _pregnancy(client, world, bid, lmp_days_ago=30)
    assert resp.status_code == 201, resp.text
    pregnancy = resp.json()
    assert pregnancy["status"] == "active" and pregnancy["version"] == 1
    visits = _visits(client, world, pregnancy["id"])
    schedule = load_schedule(DEFAULT_ANC_SCHEDULE_PATH, allow_demo=True)
    assert len(visits) == len(schedule.visits)
    lmp = utcnow().date() - timedelta(days=30)
    first = schedule.visits[0]
    assert (
        visits[0]["scheduled_date"] == (lmp + timedelta(weeks=first.gestational_week)).isoformat()
    )
    assert all(v["status"] == "planned" for v in visits)


def test_past_visits_are_not_generated(client, world):
    bid = _beneficiary(client, world)
    _consent(client, world, bid, "reny")
    pid = _pregnancy(client, world, bid, lmp_days_ago=22 * 7).json()["id"]
    sequences = [v["sequence"] for v in _visits(client, world, pid)]
    assert sequences and sequences[0] > 1


def test_single_active_pregnancy(client, world):
    bid = _beneficiary(client, world)
    _consent(client, world, bid, "reny")
    assert _pregnancy(client, world, bid).status_code == 201
    assert _pregnancy(client, world, bid).status_code == 409


def test_pregnancy_isolation_and_roles(client, world):
    bid = _beneficiary(client, world)
    _consent(client, world, bid, "reny")
    pid = _pregnancy(client, world, bid).json()["id"]
    assert client.get(f"/pregnancies/{pid}", headers=world.headers("ac_b")).status_code == 404
    assert (
        client.get(f"/pregnancies/{pid}/anc-visits", headers=world.headers("ac_b")).status_code
        == 404
    )
    lmp = utcnow().date().isoformat()
    admin = client.post(
        f"/beneficiaries/{bid}/pregnancies", json={"lmp_date": lmp}, headers=world.headers("admin")
    )
    assert admin.status_code == 403


def test_pregnancy_patch_version_and_closing(client, world, db):
    bid = _beneficiary(client, world)
    _consent(client, world, bid, "reny")
    _consent(client, world, bid, "reminders")
    pid = _pregnancy(client, world, bid).json()["id"]
    headers = world.headers("ac_a")
    stale = client.patch(
        f"/pregnancies/{pid}", json={"version": 9, "status": "ended"}, headers=headers
    )
    assert stale.status_code == 409
    ok = client.patch(
        f"/pregnancies/{pid}", json={"version": 1, "status": "delivered"}, headers=headers
    )
    assert ok.status_code == 200 and ok.json()["status"] == "delivered"
    assert {v["status"] for v in _visits(client, world, pid)} == {"cancelled"}
    assert _reminders(db, ReminderStatus.SCHEDULED) == []
    listed = client.get(
        f"/beneficiaries/{bid}/pregnancies?status=delivered", headers=headers
    ).json()
    assert listed["total"] == 1


# --- Politique du calendrier --------------------------------------------------


def test_demo_schedule_refused_when_demo_not_allowed(client, world, app, settings, db):
    bid = _beneficiary(client, world)
    _consent(client, world, bid, "reny")
    strict = settings.model_copy(update={"allow_demo_content": False})
    from app.core.config import get_settings

    app.dependency_overrides[get_settings] = lambda: strict
    resp = _pregnancy(client, world, bid)
    assert resp.status_code == 422
    assert "non validé cliniquement" in resp.json()["detail"]
    assert db.scalar(select(Pregnancy)) is None


def _write_schedule(tmp_path: Path, **overrides) -> Path:
    data = yaml.safe_load(DEFAULT_ANC_SCHEDULE_PATH.read_text(encoding="utf-8"))
    data.update(overrides)
    path = tmp_path / "anc_schedule.yaml"
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    return path


def test_demo_file_is_marked_demo():
    raw = DEFAULT_ANC_SCHEDULE_PATH.read_text(encoding="utf-8")
    assert "DÉMONSTRATION — NON VALIDÉ CLINIQUEMENT" in raw
    assert load_schedule(DEFAULT_ANC_SCHEDULE_PATH, allow_demo=True).is_demo
    with pytest.raises(ScheduleUnavailableError, match="non validé"):
        load_schedule(DEFAULT_ANC_SCHEDULE_PATH, allow_demo=False)


def test_validated_schedule_loads_without_demo(tmp_path):
    path = _write_schedule(
        tmp_path, status="validated", validated_by="Responsable fictif", validated_at="2026-11-01"
    )
    assert not load_schedule(path, allow_demo=False).is_demo


@pytest.mark.parametrize(
    "overrides",
    [
        {"status": "validated"},  # sans validated_by / validated_at
        {"unknown_field": 1},
        {
            "visits": [
                {"sequence": 1, "gestational_week": 20},
                {"sequence": 2, "gestational_week": 10},
            ]
        },
    ],
)
def test_invalid_schedules_rejected(tmp_path, overrides):
    with pytest.raises(ScheduleUnavailableError):
        load_schedule(_write_schedule(tmp_path, **overrides), allow_demo=True)


def test_retired_schedule_always_refused(tmp_path):
    with pytest.raises(ScheduleUnavailableError, match="retiré"):
        load_schedule(_write_schedule(tmp_path, status="retired"), allow_demo=True)


def test_missing_schedule_refused(tmp_path):
    with pytest.raises(ScheduleUnavailableError):
        load_schedule(tmp_path / "absent.yaml", allow_demo=True)


# --- Visites CPN --------------------------------------------------------------


def _setup_visits(client, world, lmp_days_ago=30, reminders=True, channel="sms"):
    bid = _beneficiary(client, world, channel=channel)
    _consent(client, world, bid, "reny")
    if reminders:
        _consent(client, world, bid, "reminders")
    pid = _pregnancy(client, world, bid, lmp_days_ago=lmp_days_ago).json()["id"]
    return bid, pid, _visits(client, world, pid)


def test_mark_visit_done_and_stale_version(client, world, db):
    _, _, visits = _setup_visits(client, world)
    visit = visits[0]
    headers = world.headers("ac_a")
    resp = client.patch(
        f"/anc-visits/{visit['id']}", json={"status": "done", "version": 1}, headers=headers
    )
    assert resp.status_code == 200
    assert resp.json()["done_date"] == utcnow().date().isoformat()
    assert resp.json()["version"] == 2
    stale = client.patch(
        f"/anc-visits/{visit['id']}", json={"status": "missed", "version": 1}, headers=headers
    )
    assert stale.status_code == 409
    cancelled = [r for r in _reminders(db) if str(r.anc_visit_id) == visit["id"]]
    assert cancelled and all(r.status is ReminderStatus.CANCELLED for r in cancelled)


def test_reschedule_visit_moves_reminder(client, world, db):
    _, _, visits = _setup_visits(client, world)
    visit = visits[1]
    new_date = (utcnow().date() + timedelta(days=60)).isoformat()
    resp = client.patch(
        f"/anc-visits/{visit['id']}",
        json={"scheduled_date": new_date},
        headers=world.headers("ac_a"),
    )
    assert resp.status_code == 200 and resp.json()["status"] == "planned"
    reminder = next(
        r for r in _reminders(db, ReminderStatus.SCHEDULED) if str(r.anc_visit_id) == visit["id"]
    )
    assert reminder.scheduled_at.date() == utcnow().date() + timedelta(days=58)


def test_visit_done_date_in_future_rejected(client, world):
    _, _, visits = _setup_visits(client, world)
    future = (utcnow().date() + timedelta(days=3)).isoformat()
    resp = client.patch(
        f"/anc-visits/{visits[0]['id']}",
        json={"status": "done", "done_date": future},
        headers=world.headers("ac_a"),
    )
    assert resp.status_code == 422


def test_upcoming_visits_respect_site_scope(client, world):
    # Première visite dans 3 jours.
    schedule = load_schedule(DEFAULT_ANC_SCHEDULE_PATH, allow_demo=True)
    lmp_days_ago = schedule.visits[0].gestational_week * 7 - 3
    _, _, visits = _setup_visits(client, world, lmp_days_ago=lmp_days_ago)
    upcoming = client.get("/anc-visits/upcoming?days=7", headers=world.headers("ac_a")).json()
    assert [v["id"] for v in upcoming["items"]] == [visits[0]["id"]]
    assert client.get("/anc-visits/upcoming", headers=world.headers("ac_b")).json()["total"] == 0
    assert client.get("/anc-visits/upcoming", headers=world.headers("lead")).json()["total"] == 1
    other = client.patch(
        f"/anc-visits/{visits[0]['id']}", json={"status": "done"}, headers=world.headers("ac_b")
    )
    assert other.status_code == 404


def test_visit_list_status_filter(client, world):
    _, pid, visits = _setup_visits(client, world)
    client.patch(
        f"/anc-visits/{visits[0]['id']}", json={"status": "missed"}, headers=world.headers("ac_a")
    )
    missed = client.get(
        f"/pregnancies/{pid}/anc-visits?status=missed", headers=world.headers("ac_a")
    )
    assert [v["id"] for v in missed.json()["items"]] == [visits[0]["id"]]


# --- Rappels ------------------------------------------------------------------


def test_reminders_planned_only_with_consent(client, world, db):
    _setup_visits(client, world, reminders=False)
    assert _reminders(db) == []
    _, _, visits = _setup_visits(client, world, reminders=True)
    scheduled = _reminders(db, ReminderStatus.SCHEDULED)
    assert len(scheduled) == len(visits)
    assert all(r.channel == "sms" and r.message_code.startswith("MSG_") for r in scheduled)


def test_channel_none_plans_no_reminder(client, world, db):
    _setup_visits(client, world, channel="none")
    assert _reminders(db) == []


def test_late_reminders_consent_plans_upcoming_visits(client, world, db):
    bid, _, visits = _setup_visits(client, world, reminders=False)
    _consent(client, world, bid, "reminders")
    assert len(_reminders(db, ReminderStatus.SCHEDULED)) == len(visits)


def test_withdrawing_reminders_consent_cancels_scheduled(client, world, db):
    bid, _, _ = _setup_visits(client, world, reminders=False)
    cid = _consent(client, world, bid, "reminders")
    assert _reminders(db, ReminderStatus.SCHEDULED)
    resp = client.post(f"/consents/{cid}/withdraw", headers=world.headers("ac_a"))
    assert resp.status_code == 200
    assert _reminders(db, ReminderStatus.SCHEDULED) == []
    assert all(r.status is ReminderStatus.CANCELLED for r in _reminders(db))


def _make_due(db):
    for reminder in _reminders(db, ReminderStatus.SCHEDULED):
        reminder.scheduled_at = utcnow() - timedelta(minutes=1)
    db.commit()


def _run_cli(monkeypatch, settings, session_factory, capsys):
    monkeypatch.setattr(cli, "get_settings", lambda: settings)
    monkeypatch.setattr(cli, "get_session_factory", lambda _s: session_factory)
    assert cli.main(["send-due-reminders"]) == 0
    return capsys.readouterr().out


def test_cli_sends_due_reminders_via_log_adapter(
    client, world, db, monkeypatch, settings, session_factory, capsys, caplog
):
    bid, _, visits = _setup_visits(client, world)
    client.put(
        f"/beneficiaries/{bid}/identity",
        json={"display_name": "Nom Fictif", "phone": "0342222222"},
        headers=world.headers("ac_a"),
    )
    _make_due(db)
    with caplog.at_level(logging.INFO, logger="fanilo.reminders.log_channel"):
        out = _run_cli(monkeypatch, settings, session_factory, capsys)
    assert f"Rappels envoyés : {len(visits)}" in out
    sent = _reminders(db, ReminderStatus.SENT)
    assert len(sent) == len(visits) and all(r.sent_at for r in sent)
    assert "Nom Fictif" not in caplog.text and "0342222222" not in caplog.text
    # Idempotent : rien de plus à envoyer.
    assert "Rappels envoyés : 0" in _run_cli(monkeypatch, settings, session_factory, capsys)


def test_cli_cancels_when_consent_missing_at_send_time(
    client, world, db, monkeypatch, settings, session_factory, capsys
):
    bid, _, _ = _setup_visits(client, world)
    from app.modules.beneficiaries.models import Consent

    # Retrait simulé sans passer par l'API (le rappel reste « scheduled »).
    for consent in db.scalars(select(Consent).where(Consent.scope == "reminders")):
        consent.withdrawn_at = utcnow()
    db.commit()
    _make_due(db)
    _run_cli(monkeypatch, settings, session_factory, capsys)
    assert _reminders(db, ReminderStatus.SENT) == []
    assert {r.last_error for r in _reminders(db)} == {"no_reminders_consent"}


def test_cli_uses_current_preferred_channel(
    client, world, db, monkeypatch, settings, session_factory, capsys
):
    bid, _, _ = _setup_visits(client, world)
    client.patch(
        f"/beneficiaries/{bid}",
        json={"version": 1, "preferred_channel": "none"},
        headers=world.headers("ac_a"),
    )
    _make_due(db)
    _run_cli(monkeypatch, settings, session_factory, capsys)
    assert {r.last_error for r in _reminders(db)} == {"no_channel"}
