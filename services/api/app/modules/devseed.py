"""Jeu de données de DÉMONSTRATION pour l'environnement local.

Crée (de façon idempotente) une hiérarchie de sites fictifs, un compte par
rôle et importe le catalogue de contenus de démonstration ::

    uv run python -m app.modules.devseed
    uv run python -m app.modules.devseed --history   # + 6 mois d'activité fictive
    uv run python -m app.modules.devseed --purge     # efface les données de suivi (garde
                                                     # comptes, sites et contenus)

Refusé en production. Toutes les données sont FICTIVES. Le mot de passe commun
est ``DEMO_PASSWORD`` : à n'utiliser qu'en local.
"""

import argparse
import sys
import uuid
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import DEFAULT_CONTENTS_DEMO_PATH, Environment, Settings, get_settings
from app.db.session import get_session_factory
from app.modules.contents.catalog import import_catalog, load_catalog
from app.modules.sites.models import Site, SiteKind
from app.modules.users.models import User
from app.modules.users.roles import Role
from app.modules.users.service import create_user, get_by_login

DEMO_PASSWORD = "fanilo-demo-2026"  # noqa: S105 - local uniquement, refusé en production


@dataclass(frozen=True)
class DemoSite:
    code: str
    name: str
    kind: SiteKind
    district: str
    region: str
    parent_code: str | None = None


DEMO_SITES: tuple[DemoSite, ...] = (
    DemoSite(
        "CHRR-BGL",
        "CHRR Démo Bongolava",
        SiteKind.REFERENCE_FACILITY,
        "Tsiroanomandidy",
        "Bongolava",
    ),
    DemoSite(
        "CSB-BGL-A",
        "CSB II Démo Bongolava A",
        SiteKind.CSB,
        "Tsiroanomandidy",
        "Bongolava",
        "CHRR-BGL",
    ),
    DemoSite(
        "ZC-BGL-A1",
        "Zone communautaire Démo A1",
        SiteKind.COMMUNITY_ZONE,
        "Tsiroanomandidy",
        "Bongolava",
        "CSB-BGL-A",
    ),
    DemoSite(
        "CSB-BGL-B", "CSB II Démo Bongolava B", SiteKind.CSB, "Fenoarivobe", "Bongolava", "CHRR-BGL"
    ),
    DemoSite(
        "ZC-BGL-B1",
        "Zone communautaire Démo B1",
        SiteKind.COMMUNITY_ZONE,
        "Fenoarivobe",
        "Bongolava",
        "CSB-BGL-B",
    ),
    DemoSite(
        "CSB-TNR-C",
        "CSB II Démo Antananarivo C",
        SiteKind.CSB,
        "Antananarivo Renivohitra",
        "Analamanga",
    ),
    DemoSite(
        "ZC-TNR-C1",
        "Zone communautaire Démo C1",
        SiteKind.COMMUNITY_ZONE,
        "Antananarivo Renivohitra",
        "Analamanga",
        "CSB-TNR-C",
    ),
)

# (login, rôle, code du site de rattachement)
DEMO_USERS: tuple[tuple[str, Role, str | None], ...] = (
    ("admin", Role.ADMIN, None),
    ("donnees", Role.DATA_OFFICER, None),
    ("technique", Role.TECHNICAL, None),
    ("responsable", Role.CLINICAL_LEAD, None),
    ("responsable2", Role.CLINICAL_LEAD, None),
    ("conseiller", Role.CLINICAL_ADVISOR, "CHRR-BGL"),
    ("conseiller.tnr", Role.CLINICAL_ADVISOR, "CSB-TNR-C"),
    ("chef.csb.a", Role.CSB_HEAD, "CSB-BGL-A"),
    ("chef.csb.b", Role.CSB_HEAD, "CSB-BGL-B"),
    ("chef.csb.c", Role.CSB_HEAD, "CSB-TNR-C"),
    ("ac.a1", Role.COMMUNITY_AGENT, "ZC-BGL-A1"),
    ("ac.b1", Role.COMMUNITY_AGENT, "ZC-BGL-B1"),
    ("ac.c1", Role.COMMUNITY_AGENT, "ZC-TNR-C1"),
)


@dataclass
class SeedReport:
    sites_created: int = 0
    users_created: int = 0
    contents_created: int = 0


def seed(session: Session, settings: Settings) -> SeedReport:
    if settings.environment is Environment.PRODUCTION:
        raise RuntimeError("Jeu de démonstration refusé en production.")
    report = SeedReport()
    ids: dict[str, uuid.UUID] = {}
    for demo in DEMO_SITES:
        site = session.scalar(select(Site).where(Site.code == demo.code))
        if site is None:
            site = Site(
                name=demo.name,
                kind=demo.kind,
                code=demo.code,
                district=demo.district,
                region=demo.region,
                parent_site_id=ids.get(demo.parent_code) if demo.parent_code else None,
                is_active=True,
            )
            session.add(site)
            session.flush()
            report.sites_created += 1
        ids[demo.code] = site.id
    for login, role, site_code in DEMO_USERS:
        if get_by_login(session, login) is None:
            create_user(
                session,
                login=login,
                password=DEMO_PASSWORD,
                role=role,
                site_id=ids[site_code] if site_code else None,
            )
            report.users_created += 1
    report.contents_created = import_catalog(
        session, load_catalog(DEFAULT_CONTENTS_DEMO_PATH)
    ).created
    return report


# --- Historique fictif (tableau de bord, espace agent) -----------------------

# Noms FICTIFS (combinaisons de prénoms et noms courants), aucune personne réelle.
DEMO_NAMES: tuple[str, ...] = (
    "Rasoarivelo Marie",
    "Andriamamonjy Lala",
    "Rakotomalala Hanta",
    "Razafindratsima Vero",
    "Solofoniaina Fanja",
    "Rasoanirina Voahirana",
    "Randriamanana Tiana",
    "Rabearisoa Miora",
    "Ravelojaona Nirina",
    "Rakotondrabe Fara",
    "Andrianarisoa Lova",
    "Ramanantsoa Haingo",
    "Rasolofo Mialy",
    "Razanakoto Onja",
    "Rahelinirina Sitraka",
    "Ranaivoson Noro",
    "Rafaralahy Zo",
    "Randrianasolo Holy",
    "Rakotoarisoa Tahina",
    "Ratsimbazafy Volana",
    "Rabemananjara Ony",
    "Razafimahefa Kanto",
    "Andriantsoa Mamy",
    "Raharimalala Nomena",
    "Rakotonirina Fitia",
    "Ravoninahitra Aina",
    "Randriambololona Soa",
    "Rasamimanana Ketaka",
    "Razafiarison Tsiky",
    "Ramaroson Lanto",
)
HISTORY_MARKER = "demo-history-v1"


def seed_history(session: Session, settings: Settings) -> int:
    """Crée ~30 patientes réparties sur 6 mois (grossesses, CPN réalisées ou
    manquées, alertes, questions). Idempotent (marqueur dans la source des
    consentements). Toutes les données sont FICTIVES."""
    import random
    from datetime import timedelta

    from app.core.crypto import get_cipher
    from app.db.types import utcnow
    from app.modules.alerts.models import Alert, AlertSeverity, AlertStatus
    from app.modules.beneficiaries.models import (
        Beneficiary,
        BeneficiaryIdentity,
        Consent,
        ConsentMethod,
        ConsentScope,
        PreferredChannel,
    )
    from app.modules.beneficiaries.service import generate_code
    from app.modules.interactions.models import (
        InputKind,
        Interaction,
        InteractionModule,
        Outcome,
        ReviewStatus,
        Severity,
    )
    from app.modules.reny.models import (
        AncVisit,
        AncVisitStatus,
        DatesConfirmedBy,
        Pregnancy,
        PregnancyStatus,
    )
    from app.modules.reny.schedule import get_schedule

    if settings.environment is Environment.PRODUCTION:
        raise RuntimeError("Historique de démonstration refusé en production.")
    if session.scalar(select(Consent.id).where(Consent.information_version == HISTORY_MARKER)):
        return 0
    rng = random.Random(2026)  # noqa: S311 - données fictives reproductibles
    cipher = get_cipher(settings)
    schedule = get_schedule(settings)
    now = utcnow()
    today = now.date()
    sites = {s.code: s for s in session.scalars(select(Site))}
    users = {u.login: u for u in session.scalars(select(User))}
    zones = [
        ("ZC-BGL-A1", "ac.a1", "chef.csb.a", ("Ambohimanga", "Ankadinondry", "Mahasolo")),
        ("ZC-BGL-B1", "ac.b1", "chef.csb.b", ("Fenoarivo", "Ambatomainty")),
        ("ZC-TNR-C1", "ac.c1", "chef.csb.c", ("Isotry", "Andavamamba", "67 Ha")),
    ]
    created = 0
    for index, name in enumerate(DEMO_NAMES):
        zone_code, agent_login, head_login, villages = zones[index % len(zones)]
        zone, agent, head = sites[zone_code], users[agent_login], users[head_login]
        registered = now - timedelta(days=rng.randint(3, 175), hours=rng.randint(0, 10))
        ben = Beneficiary(
            code=generate_code(session),
            site_id=zone.id,
            birth_year=today.year - rng.randint(16, 38),
            preferred_channel=rng.choice(list(PreferredChannel)),
            created_at=registered,
            updated_at=registered,
        )
        session.add(ben)
        session.flush()
        session.add(
            BeneficiaryIdentity(
                id=ben.id,
                beneficiary_id=ben.id,
                display_name_encrypted=cipher.encrypt(name),
                phone_encrypted=None,
                village_encrypted=cipher.encrypt(rng.choice(villages)),
                created_at=registered,
                updated_at=registered,
            )
        )
        for scope in (ConsentScope.RENY, ConsentScope.REMINDERS):
            session.add(
                Consent(
                    beneficiary_id=ben.id,
                    scope=scope,
                    method=ConsentMethod.ORAL,
                    information_version=HISTORY_MARKER,
                    collected_by_user_id=agent.id,
                    collected_at=registered,
                    created_at=registered,
                    updated_at=registered,
                )
            )
        # Âge gestationnel à l'enregistrement : 6 à 22 semaines.
        lmp = registered.date() - timedelta(weeks=rng.randint(6, 22))
        if (today - lmp).days > 290:
            lmp = today - timedelta(days=rng.randint(60, 250))
        preg = Pregnancy(
            beneficiary_id=ben.id,
            status=PregnancyStatus.ACTIVE,
            lmp_date=lmp,
            dates_confirmed_by=DatesConfirmedBy.AC_DECLARED,
            anc_schedule_id=schedule.schedule_id,
            anc_schedule_version=schedule.version,
            created_at=registered,
            updated_at=registered,
        )
        session.add(preg)
        session.flush()
        diligent = rng.random() < 0.75
        for sequence, when in schedule.visit_dates(lmp):
            if when < registered.date():
                continue
            if when < today:
                done = rng.random() < (0.9 if diligent else 0.5)
                session.add(
                    AncVisit(
                        pregnancy_id=preg.id,
                        sequence=sequence,
                        scheduled_date=when,
                        status=AncVisitStatus.DONE if done else AncVisitStatus.MISSED,
                        done_date=when + timedelta(days=rng.randint(0, 3)) if done else None,
                        site_id=sites[zone_code].parent_site_id,
                        created_at=registered,
                        updated_at=registered,
                    )
                )
            else:
                session.add(
                    AncVisit(
                        pregnancy_id=preg.id,
                        sequence=sequence,
                        scheduled_date=when,
                        status=AncVisitStatus.PLANNED,
                        created_at=registered,
                        updated_at=registered,
                    )
                )
        # Questions posées (thèmes) et quelques signes de danger.
        for _ in range(rng.randint(0, 3)):
            when = registered + timedelta(days=rng.randint(0, max(1, (now - registered).days)))
            intent, outcome, code = rng.choice(
                [
                    ("ask_anc_schedule", Outcome.ANSWER, "MSG_DEMO_INFO_ANC"),
                    ("ask_nutrition", Outcome.ANSWER, "MSG_DEMO_INFO_NUTRITION"),
                    ("out_of_scope", Outcome.FALLBACK, "MSG_DEMO_TRANSFER_COUNSELOR"),
                ]
            )
            session.add(
                Interaction(
                    created_at=when,
                    module=InteractionModule.RENY,
                    beneficiary_id=ben.id,
                    site_id=zone.id,
                    asked_by_user_id=agent.id,
                    input_kind=InputKind.TEXT,
                    language="mg",
                    transcript=None,
                    transcript_needs_review=False,
                    sign_codes=[],
                    intent=intent,
                    detection_confidence=0.7,
                    ai_model="démo-historique",
                    outcome=outcome,
                    actions=[] if outcome is Outcome.ANSWER else ["transfer_counselor"],
                    severity=None,
                    content_code=code,
                    is_demo=True,
                    fallback_reasons=[],
                    decision_trace=[],
                    review_status=ReviewStatus.REVIEWED
                    if outcome is Outcome.FALLBACK
                    else ReviewStatus.NOT_REQUIRED,
                )
            )
        if rng.random() < 0.3:
            when = registered + timedelta(days=rng.randint(1, max(2, (now - registered).days)))
            recent = (now - when).days < 4
            status = (
                rng.choice([AlertStatus.OPEN, AlertStatus.ACKNOWLEDGED])
                if recent
                else AlertStatus.RESOLVED
            )
            critical = rng.random() < 0.4
            session.add(
                Alert(
                    beneficiary_id=ben.id,
                    site_id=zone.id,
                    rule_id="DEMO-RENY-001" if critical else "DEMO-RENY-002",
                    ruleset_version="0.1.0",
                    severity=AlertSeverity.CRITICAL if critical else AlertSeverity.URGENT,
                    status=status,
                    recipient_user_id=head.id,
                    due_at=when + timedelta(minutes=settings.alert_demo_response_minutes),
                    due_at_is_demo=True,
                    acknowledged_at=(
                        None if status is AlertStatus.OPEN else when + timedelta(minutes=25)
                    ),
                    acknowledged_by_user_id=None if status is AlertStatus.OPEN else head.id,
                    resolved_at=when + timedelta(hours=5)
                    if status is AlertStatus.RESOLVED
                    else None,
                    is_demo=True,
                    created_at=when,
                    updated_at=when,
                )
            )
            session.add(
                Interaction(
                    created_at=when,
                    module=InteractionModule.RENY,
                    beneficiary_id=ben.id,
                    site_id=zone.id,
                    asked_by_user_id=agent.id,
                    input_kind=InputKind.SIGN_CODES,
                    language="mg",
                    transcript=None,
                    transcript_needs_review=False,
                    sign_codes=["SIGN_DEMO_01" if critical else "SIGN_DEMO_03"],
                    intent=None,
                    detection_confidence=None,
                    ai_model=None,
                    outcome=Outcome.DANGER_SIGN,
                    actions=["refer_reference_facility" if critical else "refer_csb"],
                    severity=Severity.CRITICAL if critical else Severity.URGENT,
                    content_code="MSG_DEMO_CRITICAL" if critical else "MSG_DEMO_URGENT",
                    is_demo=True,
                    fallback_reasons=[],
                    decision_trace=[],
                    review_status=ReviewStatus.REVIEWED,
                )
            )
        created += 1
    session.flush()
    return created


# Tables de données de suivi, dans l'ordre des clés étrangères (enfants d'abord).
PURGE_TABLES: tuple[str, ...] = (
    "reminders",
    "anc_visits",
    "alert_events",
    "referrals",
    "alerts",
    "interactions",
    "pregnancies",
    "consents",
    "beneficiary_identities",
    "beneficiaries",
    "sync_changes",
    "audit_events",
)


def purge(session: Session, settings: Settings) -> dict[str, int]:
    """Supprime toutes les données de suivi et le journal d'audit ; conserve les
    comptes, les sites et les contenus. Refusé en production. Un événement
    d'audit ``data.purge`` est ensuite enregistré."""
    from sqlalchemy import text

    from app.modules.audit.service import record_audit

    if settings.environment is Environment.PRODUCTION:
        raise RuntimeError("Purge refusée en production.")
    counts = {}
    for table in PURGE_TABLES:
        counts[table] = session.execute(text(f"DELETE FROM {table}")).rowcount  # noqa: S608
    record_audit(session, None, "data.purge", "database", None)
    return counts


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="fanilo-devseed", description=__doc__)
    parser.add_argument(
        "--purge",
        action="store_true",
        help="Effacer les données de suivi (garde comptes, sites, contenus)",
    )
    parser.add_argument(
        "--history", action="store_true", help="Ajouter 6 mois d'activité fictive (une seule fois)"
    )
    args = parser.parse_args(argv)
    settings = get_settings()
    if settings.environment is Environment.PRODUCTION:
        print("Erreur : jeu de démonstration refusé en production.", file=sys.stderr)
        return 1
    factory = get_session_factory(settings)
    if args.purge:
        with factory() as session, session.begin():
            counts = purge(session, settings)
        print("Données effacées : " + ", ".join(f"{t} {n}" for t, n in counts.items() if n))
        return 0
    with factory() as session, session.begin():
        report = seed(session, settings)
        history = seed_history(session, settings) if args.history else 0
        total_users = len(session.scalars(select(User.id)).all())
    print(
        f"Démo : {report.sites_created} site(s), {report.users_created} compte(s) et "
        f"{report.contents_created} contenu(s) créés ({total_users} comptes au total), "
        f"{history} patiente(s) d'historique fictif. "
        f"Mot de passe des comptes de démo : {DEMO_PASSWORD}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
