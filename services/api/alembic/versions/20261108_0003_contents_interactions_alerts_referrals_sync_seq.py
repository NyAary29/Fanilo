"""Contenus, interactions, alertes, références et séquence de synchronisation
``sync_seq`` (lots P0.6, F-05 à F-09, F-10).

Écrite pour PostgreSQL (enums en VARCHAR + CHECK, UUID natifs, timestamptz) ;
testée aussi sur SQLite.

``sync_seq`` : compteur transactionnel ``sync_counter`` (une ligne), voir
``app/db/base.py``. Les lignes existantes des tables synchronisées reçoivent
une valeur dans l'ordre (``updated_at``, ``id``), table par table (parents
d'abord), puis le compteur est positionné après la dernière valeur. Le défaut
temporaire ``0`` n'est retiré que sur PostgreSQL (SQLite ne sait pas modifier
une colonne en place ; le serveur renseigne toujours la valeur).

Revision ID: 0003
Revises: 0002
Create Date: 2026-11-08
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Tables synchronisées existantes, parents avant enfants.
SEQUENCED_TABLES = (
    "sites",
    "beneficiaries",
    "beneficiary_identities",
    "consents",
    "pregnancies",
    "anc_visits",
)
SEVERITIES = ("routine", "urgent", "critical")


def _enum(name: str, *values: str, length: int = 32) -> sa.Enum:
    return sa.Enum(*values, name=name, native_enum=False, create_constraint=True, length=length)


def _sync_columns() -> list[sa.Column]:
    """Colonnes communes (SyncMixin + SyncSequenced)."""
    return [
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("sync_seq", sa.BigInteger(), nullable=False),
    ]


def _fk(table: str, column: str, target: str) -> sa.ForeignKeyConstraint:
    return sa.ForeignKeyConstraint(
        [column], [f"{target}.id"], name=op.f(f"fk_{table}_{column}_{target}")
    )


def upgrade() -> None:
    # --- Séquence de synchronisation (F-10) -----------------------------------
    op.create_table(
        "sync_counter",
        sa.Column("id", sa.Integer(), autoincrement=False, nullable=False),
        sa.Column("value", sa.BigInteger(), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sync_counter")),
    )
    op.execute("INSERT INTO sync_counter (id, value) VALUES (1, 0)")

    for table in SEQUENCED_TABLES:
        op.add_column(
            table,
            sa.Column("sync_seq", sa.BigInteger(), nullable=False, server_default="0"),
        )
        # Ordre (updated_at, id) ; portable PostgreSQL / SQLite, y compris en
        # mode hors ligne (--sql).
        op.execute(
            f"UPDATE {table} SET sync_seq = "  # noqa: S608 - noms de tables constants
            "(SELECT value FROM sync_counter WHERE id = 1) + "
            f"(SELECT COUNT(*) FROM {table} AS o WHERE o.updated_at < {table}.updated_at "
            f"OR (o.updated_at = {table}.updated_at AND o.id <= {table}.id))"
        )
        op.execute(
            "UPDATE sync_counter SET value = value + "  # noqa: S608
            f"(SELECT COUNT(*) FROM {table}) WHERE id = 1"
        )
        op.create_index(op.f(f"ix_{table}_sync_seq"), table, ["sync_seq"], unique=True)
        if op.get_context().dialect.name != "sqlite":
            op.alter_column(table, "sync_seq", server_default=None)

    # --- Contenus (P0.6) ---------------------------------------------------------
    op.create_table(
        "content_items",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("code", sa.String(length=64), nullable=False),
        sa.Column(
            "module", _enum("content_module", "reny", "tanora", "common", length=16), nullable=False
        ),
        sa.Column("language", _enum("content_language", "mg", "fr", length=8), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("audio_url", sa.String(length=500), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column(
            "status",
            _enum(
                "content_status", "draft", "in_review", "validated", "retired", "demo", length=16
            ),
            nullable=False,
        ),
        sa.Column("author_id", sa.Uuid(), nullable=True),
        sa.Column("validator_id", sa.Uuid(), nullable=True),
        sa.Column("validated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("source_ref", sa.String(length=500), nullable=True),
        sa.Column("review_note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        _fk("content_items", "author_id", "users"),
        _fk("content_items", "validator_id", "users"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_content_items")),
        sa.UniqueConstraint(
            "code", "language", "version", name="uq_content_items_code_lang_version"
        ),
    )
    op.create_index(
        "ix_content_items_lookup", "content_items", ["code", "language", "status"], unique=False
    )

    # --- Interactions (F-05 à F-07) ------------------------------------------------
    op.create_table(
        "interactions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "module", _enum("interaction_module", "reny", "tanora", length=16), nullable=False
        ),
        sa.Column("beneficiary_id", sa.Uuid(), nullable=True),
        sa.Column("site_id", sa.Uuid(), nullable=True),
        sa.Column("asked_by_user_id", sa.Uuid(), nullable=False),
        sa.Column(
            "input_kind",
            _enum("interaction_input_kind", "audio", "text", "sign_codes", length=16),
            nullable=False,
        ),
        sa.Column("language", sa.String(length=8), nullable=False),
        sa.Column("transcript", sa.Text(), nullable=True),
        sa.Column("transcript_needs_review", sa.Boolean(), nullable=False),
        sa.Column("sign_codes", sa.JSON(), nullable=False),
        sa.Column("detection_confidence", sa.Float(), nullable=True),
        sa.Column("ai_model", sa.String(length=128), nullable=True),
        sa.Column(
            "outcome",
            _enum("interaction_outcome", "answer", "danger_sign", "fallback", length=16),
            nullable=False,
        ),
        sa.Column("actions", sa.JSON(), nullable=False),
        sa.Column("severity", _enum("interaction_severity", *SEVERITIES, length=16), nullable=True),
        sa.Column("content_code", sa.String(length=64), nullable=True),
        sa.Column("alert_id", sa.Uuid(), nullable=True),
        sa.Column("is_demo", sa.Boolean(), nullable=False),
        sa.Column("ruleset_id", sa.String(length=64), nullable=True),
        sa.Column("ruleset_version", sa.String(length=32), nullable=True),
        sa.Column("fallback_reasons", sa.JSON(), nullable=False),
        sa.Column("decision_trace", sa.JSON(), nullable=False),
        sa.Column(
            "review_status",
            _enum("interaction_review_status", "pending", "reviewed", "not_required", length=16),
            nullable=False,
        ),
        sa.Column("reviewed_by_user_id", sa.Uuid(), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("review_note", sa.Text(), nullable=True),
        _fk("interactions", "beneficiary_id", "beneficiaries"),
        _fk("interactions", "site_id", "sites"),
        _fk("interactions", "asked_by_user_id", "users"),
        _fk("interactions", "reviewed_by_user_id", "users"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_interactions")),
    )
    op.create_index(
        op.f("ix_interactions_created_at"), "interactions", ["created_at"], unique=False
    )
    op.create_index(
        op.f("ix_interactions_beneficiary_id"), "interactions", ["beneficiary_id"], unique=False
    )
    op.create_index(op.f("ix_interactions_site_id"), "interactions", ["site_id"], unique=False)
    op.create_index(
        "ix_interactions_review", "interactions", ["review_status", "created_at"], unique=False
    )

    # --- Alertes (F-08) ------------------------------------------------------------
    op.create_table(
        "alerts",
        sa.Column("beneficiary_id", sa.Uuid(), nullable=True),
        sa.Column("site_id", sa.Uuid(), nullable=True),
        sa.Column("interaction_id", sa.Uuid(), nullable=True),
        sa.Column("rule_id", sa.String(length=64), nullable=False),
        sa.Column("ruleset_version", sa.String(length=32), nullable=False),
        sa.Column("severity", _enum("alert_severity", *SEVERITIES, length=16), nullable=False),
        sa.Column(
            "status",
            _enum(
                "alert_status",
                "open",
                "acknowledged",
                "resolved",
                "escalated",
                "cancelled",
                length=16,
            ),
            nullable=False,
        ),
        sa.Column("recipient_user_id", sa.Uuid(), nullable=True),
        sa.Column("backup_user_id", sa.Uuid(), nullable=True),
        sa.Column("due_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("due_at_is_demo", sa.Boolean(), nullable=False),
        sa.Column("acknowledged_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("acknowledged_by_user_id", sa.Uuid(), nullable=True),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("escalated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_demo", sa.Boolean(), nullable=False),
        *_sync_columns(),
        _fk("alerts", "beneficiary_id", "beneficiaries"),
        _fk("alerts", "site_id", "sites"),
        _fk("alerts", "interaction_id", "interactions"),
        _fk("alerts", "recipient_user_id", "users"),
        _fk("alerts", "backup_user_id", "users"),
        _fk("alerts", "acknowledged_by_user_id", "users"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_alerts")),
    )
    op.create_index(op.f("ix_alerts_beneficiary_id"), "alerts", ["beneficiary_id"], unique=False)
    op.create_index(op.f("ix_alerts_site_id"), "alerts", ["site_id"], unique=False)
    op.create_index(
        op.f("ix_alerts_recipient_user_id"), "alerts", ["recipient_user_id"], unique=False
    )
    op.create_index("ix_alerts_status_due", "alerts", ["status", "due_at"], unique=False)
    op.create_index(op.f("ix_alerts_sync_seq"), "alerts", ["sync_seq"], unique=True)

    op.create_table(
        "alert_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("alert_id", sa.Uuid(), nullable=False),
        sa.Column("at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("actor_user_id", sa.Uuid(), nullable=True),
        sa.Column(
            "type",
            _enum(
                "alert_event_type",
                "created",
                "acknowledged",
                "escalated",
                "note",
                "resolved",
                "cancelled",
                length=16,
            ),
            nullable=False,
        ),
        sa.Column("note", sa.Text(), nullable=True),
        _fk("alert_events", "alert_id", "alerts"),
        _fk("alert_events", "actor_user_id", "users"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_alert_events")),
    )
    op.create_index(op.f("ix_alert_events_alert_id"), "alert_events", ["alert_id"], unique=False)

    # --- Références (F-09) ---------------------------------------------------------
    op.create_table(
        "referrals",
        sa.Column("beneficiary_id", sa.Uuid(), nullable=False),
        sa.Column("alert_id", sa.Uuid(), nullable=True),
        sa.Column("from_site_id", sa.Uuid(), nullable=True),
        sa.Column("to_site_id", sa.Uuid(), nullable=False),
        sa.Column(
            "status",
            _enum(
                "referral_status",
                "proposed",
                "accepted",
                "arrived",
                "transferred",
                "not_completed",
                length=16,
            ),
            nullable=False,
        ),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("outcome_note", sa.Text(), nullable=True),
        *_sync_columns(),
        _fk("referrals", "beneficiary_id", "beneficiaries"),
        _fk("referrals", "alert_id", "alerts"),
        _fk("referrals", "from_site_id", "sites"),
        _fk("referrals", "to_site_id", "sites"),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_referrals")),
    )
    op.create_index(
        op.f("ix_referrals_beneficiary_id"), "referrals", ["beneficiary_id"], unique=False
    )
    op.create_index(op.f("ix_referrals_alert_id"), "referrals", ["alert_id"], unique=False)
    op.create_index(op.f("ix_referrals_to_site_id"), "referrals", ["to_site_id"], unique=False)
    op.create_index(op.f("ix_referrals_sync_seq"), "referrals", ["sync_seq"], unique=True)


def downgrade() -> None:
    op.drop_index(op.f("ix_referrals_sync_seq"), table_name="referrals")
    op.drop_index(op.f("ix_referrals_to_site_id"), table_name="referrals")
    op.drop_index(op.f("ix_referrals_alert_id"), table_name="referrals")
    op.drop_index(op.f("ix_referrals_beneficiary_id"), table_name="referrals")
    op.drop_table("referrals")

    op.drop_index(op.f("ix_alert_events_alert_id"), table_name="alert_events")
    op.drop_table("alert_events")

    op.drop_index(op.f("ix_alerts_sync_seq"), table_name="alerts")
    op.drop_index("ix_alerts_status_due", table_name="alerts")
    op.drop_index(op.f("ix_alerts_recipient_user_id"), table_name="alerts")
    op.drop_index(op.f("ix_alerts_site_id"), table_name="alerts")
    op.drop_index(op.f("ix_alerts_beneficiary_id"), table_name="alerts")
    op.drop_table("alerts")

    op.drop_index("ix_interactions_review", table_name="interactions")
    op.drop_index(op.f("ix_interactions_site_id"), table_name="interactions")
    op.drop_index(op.f("ix_interactions_beneficiary_id"), table_name="interactions")
    op.drop_index(op.f("ix_interactions_created_at"), table_name="interactions")
    op.drop_table("interactions")

    op.drop_index("ix_content_items_lookup", table_name="content_items")
    op.drop_table("content_items")

    for table in reversed(SEQUENCED_TABLES):
        op.drop_index(op.f(f"ix_{table}_sync_seq"), table_name=table)
        with op.batch_alter_table(table) as batch_op:
            batch_op.drop_column("sync_seq")
    op.drop_table("sync_counter")
