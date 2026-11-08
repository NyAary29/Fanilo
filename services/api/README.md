# fanilo-api

Voir le README racine.

## Dépendance au moteur de règles

`fanilo-rules` est une dépendance de chemin (`[tool.uv.sources]`, `../rules`) : le
contexte de build doit inclure `services/rules`.

## Commandes

```bash
uv run alembic upgrade head
uv run python -m app.modules.users.cli create-admin --login admin
# Contenus de DÉMONSTRATION (non validés ; servis si FANILO_ALLOW_DEMO_CONTENT=true)
uv run python -m app.modules.contents.cli import-demo
# Tâches planifiées (cron)
uv run python -m app.modules.reny.cli send-due-reminders
uv run python -m app.modules.alerts.cli escalate   # code 1 si une alerte reste sans destinataire
```
