"""Test de fumée de bout en bout contre une API FANILO locale en marche.

Parcours : AC → bénéficiaire + identité + consentements → grossesse (CPN) →
signes de danger → alerte → acquittement par le chef CSB → référence →
tableau de bord → journal d'audit.

    cd services/api && uv run python ../../scripts/smoke_e2e.py [--api http://localhost:8000]

Nécessite le jeu de démonstration (``python -m app.modules.devseed``) et
``FANILO_ALLOW_DEMO_CONTENT=true``. Crée des données FICTIVES.
"""

import argparse
import sys
import uuid
from datetime import date, timedelta

import httpx

PASSWORD = "fanilo-demo-2026"  # noqa: S105 - comptes de démonstration locaux


class Smoke:
    def __init__(self, api: str) -> None:
        self.api = api.rstrip("/")
        self.steps = 0

    def login(self, login: str) -> httpx.Client:
        client = httpx.Client(base_url=self.api, timeout=15)
        r = client.post("/auth/login", json={"login": login, "password": PASSWORD})
        self.check(r, 200, f"connexion {login}")
        client.headers["Authorization"] = f"Bearer {r.json()['access_token']}"
        return client

    def check(self, r: httpx.Response, expected: int, label: str) -> dict:
        if r.status_code != expected:
            print(f"ÉCHEC  {label} : HTTP {r.status_code} {r.text[:400]}")
            sys.exit(1)
        self.steps += 1
        print(f"ok     {label}")
        return r.json() if r.content else {}


def run(api: str) -> None:
    s = Smoke(api)
    ac = s.login("ac.a1")
    me = s.check(ac.get("/auth/me"), 200, "profil AC")

    ben_id = str(uuid.uuid4())
    ben = s.check(
        ac.post("/beneficiaries", json={"id": ben_id, "birth_year": 2001,
                                        "preferred_channel": "sms"}),
        201, "création bénéficiaire",
    )
    assert ben["code"].startswith("FAN-") and ben["site_id"] == me["site_id"]
    s.check(ac.put(f"/beneficiaries/{ben_id}/identity",
                   json={"display_name": "Personne fictive smoke", "village": "Village démo"}),
            200, "identité chiffrée")
    info = s.check(ac.get("/reference/consent-information"), 200, "information consentement")
    versions = {i["scope"]: i["version"] for i in info["items"]}
    for scope in ("reny", "reminders", "voice_processing"):
        s.check(ac.post(f"/beneficiaries/{ben_id}/consents",
                        json={"scope": scope, "method": "oral",
                              "information_version": versions[scope]}),
                201, f"consentement {scope}")
    preg = s.check(ac.post(f"/beneficiaries/{ben_id}/pregnancies",
                           json={"lmp_date": (date.today() - timedelta(weeks=10)).isoformat()}),
                   201, "déclaration grossesse")
    visits = s.check(ac.get(f"/pregnancies/{preg['id']}/anc-visits"), 200, "calendrier CPN")
    assert visits["total"] > 0, "aucune CPN générée"

    signs = s.check(ac.get("/reference/sign-codes", params={"module": "reny"}), 200,
                    "référentiel des signes")
    assert any(i["code"] == "SIGN_DEMO_01" for i in signs["items"])
    ask = s.check(ac.post("/interactions/ask",
                          json={"module": "reny", "beneficiary_id": ben_id,
                                "sign_codes": ["SIGN_DEMO_01"]}),
                  200, "signalement signe de danger")
    assert ask["outcome"] == "danger_sign" and ask["alert_id"], ask
    text = s.check(ac.post("/interactions/ask",
                           json={"module": "reny", "text": "fanontaniana tsy fantatra"}),
                   200, "question texte non couverte")
    assert text["outcome"] == "fallback", text

    chef = s.login("chef.csb.a")
    alert = s.check(chef.get(f"/alerts/{ask['alert_id']}"), 200, "alerte vue par le chef CSB")
    assert alert["recipient_user_id"], "alerte sans destinataire nominatif"
    s.check(chef.post(f"/alerts/{ask['alert_id']}/acknowledge"), 200, "acquittement")
    s.check(chef.post(f"/alerts/{ask['alert_id']}/resolve", json={"note": "Vue au CSB (démo)"}),
            200, "résolution")

    sites = s.check(ac.get("/sites", params={"limit": 100}), 200, "liste des sites")
    chrr = next(x for x in sites["items"] if x["code"] == "CHRR-BGL")
    ref = s.check(ac.post("/referrals", json={"beneficiary_id": ben_id, "to_site_id": chrr["id"],
                                              "alert_id": ask["alert_id"],
                                              "reason": "Démo"}),
                  201, "création référence")
    for status in ("accepted", "arrived"):
        s.check(chef.post(f"/referrals/{ref['id']}/transition", json={"to_status": status}),
                200, f"référence → {status}")

    pull = s.check(ac.get("/sync/pull", params={"limit": 500}), 200, "sync pull AC")
    assert any(c["entity"] == "beneficiary" and c["id"] == ben_id for c in pull["changes"])

    s.check(chef.get("/dashboard/summary"), 200, "tableau de bord")
    adv = s.login("conseiller")
    pending = s.check(adv.get("/interactions", params={"review_status": "pending"}), 200,
                      "questions à revoir")
    assert pending["total"] >= 1
    data = s.login("donnees")
    audit = s.check(data.get("/audit", params={"limit": 20}), 200, "journal d'audit")
    assert audit["total"] > 0
    s.check(s.login("admin").get(f"/beneficiaries/{ben_id}/identity"), 403,
            "admin sans accès nominatif")
    print(f"\nSUCCÈS : {s.steps} vérifications de bout en bout.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", default="http://localhost:8000")
    run(parser.parse_args().api)
