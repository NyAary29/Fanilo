"""Sites, audit, bénéficiaires, identité chiffrée, consentements, RENY et
synchronisation (lots P0.4, P0.5, P0.7, P0.9, F-10).

Écrite pour PostgreSQL (enums en VARCHAR + CHECK, UUID natifs, timestamptz) ;
testée aussi sur SQLite (batch pour la clé étrangère de ``users``).

Revision ID: 0002
Revises: 0001
Create Date: 2026-11-08
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0002"
down_revision: str | None = "0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

CHANNELS = ("sms", "ivr", "ac_visit", "none")


def _enum(name: str, *values: str, length: int = 32) -> sa.Enum:
    return sa.Enum(*values, name=name, native_enum=False, create_constraint=True, length=length)


def _sync_columns() -> list[sa.Column]:
    """Colonnes communes de synchronisation hors ligne (SyncMixin)."""
    return [
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    ]


def upgrade() -> None:
    # --- Sites (P0.4) ---------------------------------------------------------
    op.create_table(
        "sites",
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column(
            "kind",
            _enum("site_kind", "csb", "reference_facility", "community_zone"),
            nullable=False,
        ),
        sa.Column("code", sa.String(length=32), nullable=False),
        sa.Column("district", sa.String(length=100), nullable=False),
        sa.Column("region", sa.String(length=100), nullable=False),
        sa.Column("parent_site_id", sa.Uuid(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        *_sync_columns(),
        sa.ForeignKeyConstraint(
            ["parent_site_id"], ["sites.id"], name=op.f("fk_sites_parent_site_id_sites")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_sites")),
        sa.UniqueConstraint("code", name=op.f("uq_sites_code")),
    )
    op.create_index(op.f("ix_sites_parent_site_id"), "sites", ["parent_site_id"], unique=False)

    with op.batch_alter_table("users") as batch_op:
        batch_op.create_foreign_key(op.f("fk_users_site_id_sites"), "sites", ["site_id"], ["id"])

    # --- Audit (P0.9) : ajout seul, sans clé étrangère ---------------------------
    op.create_table(
        "audit_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("actor_user_id", sa.Uuid(), nullable=True),
        sa.Column("actor_role", sa.String(length=32), nullable=True),
        sa.Column("action", sa.String(length=64), nullable=False),
        sa.Column("entity_type", sa.String(length=64), nullable=True),
        sa.Column("entity_id", sa.String(length=64), nullable=True),
        sa.Column("request_id", sa.String(length=64), nullable=True),
        sa.Column("site_id", sa.Uuid(), nullable=True),
        sa.Column("login_fingerprint", sa.String(length=64), nullable=True),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_audit_events")),
    )
    op.create_index(
        op.f("ix_audit_events_login_fingerprint"),
        "audit_events",
        ["login_fingerprint"],
        unique=False,
    )
    op.create_index(op.f("ix_audit_events_at"), "audit_events", ["at"], unique=False)
    op.create_index(
        op.f("ix_audit_events_actor_user_id"), "audit_events", ["actor_user_id"], unique=False
    )
    op.create_index(
        "ix_audit_events_entity", "audit_events", ["entity_type", "entity_id"], unique=False
    )

    # --- Bénéficiaires, identité chiffrée, consentements (P0.5) ------------------
    op.create_table(
        "beneficiaries",
        sa.Column("code", sa.String(length=16), nullable=False),
        sa.Column("site_id", sa.Uuid(), nullable=False),
        sa.Column("birth_year", sa.Integer(), nullable=True),
        sa.Column(
            "preferred_channel", _enum("preferred_channel", *CHANNELS, length=16), nullable=False
        ),
        *_sync_columns(),
        sa.ForeignKeyConstraint(
            ["site_id"], ["sites.id"], name=op.f("fk_beneficiaries_site_id_sites")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_beneficiaries")),
        sa.UniqueConstraint("code", name=op.f("uq_beneficiaries_code")),
    )
    op.create_index(op.f("ix_beneficiaries_site_id"), "beneficiaries", ["site_id"], unique=False)
    op.create_index("ix_beneficiaries_sync", "beneficiaries", ["updated_at", "id"], unique=False)

    op.create_table(
        "beneficiary_identities",
        sa.Column("beneficiary_id", sa.Uuid(), nullable=False),
        # Jetons Fernet : jamais de valeur en clair.
        sa.Column("display_name_encrypted", sa.Text(), nullable=False),
        sa.Column("phone_encrypted", sa.Text(), nullable=True),
        sa.Column("village_encrypted", sa.Text(), nullable=True),
        *_sync_columns(),
        sa.ForeignKeyConstraint(
            ["beneficiary_id"],
            ["beneficiaries.id"],
            name=op.f("fk_beneficiary_identities_beneficiary_id_beneficiaries"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_beneficiary_identities")),
        sa.UniqueConstraint(
            "beneficiary_id", name=op.f("uq_beneficiary_identities_beneficiary_id")
        ),
    )
    op.create_index(
        "ix_beneficiary_identities_sync",
        "beneficiary_identities",
        ["updated_at", "id"],
        unique=False,
    )

    op.create_table(
        "consents",
        sa.Column("beneficiary_id", sa.Uuid(), nullable=False),
        sa.Column(
            "scope",
            _enum("consent_scope", "reny", "tanora", "reminders", "voice_processing"),
            nullable=False,
        ),
        sa.Column("method", _enum("consent_method", "oral", "written", length=16), nullable=False),
        sa.Column("information_version", sa.String(length=32), nullable=False),
        sa.Column("collected_by_user_id", sa.Uuid(), nullable=False),
        sa.Column("collected_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("withdrawn_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("withdrawn_by_user_id", sa.Uuid(), nullable=True),
        *_sync_columns(),
        sa.ForeignKeyConstraint(
            ["beneficiary_id"],
            ["beneficiaries.id"],
            name=op.f("fk_consents_beneficiary_id_beneficiaries"),
        ),
        sa.ForeignKeyConstraint(
            ["collected_by_user_id"],
            ["users.id"],
            name=op.f("fk_consents_collected_by_user_id_users"),
        ),
        sa.ForeignKeyConstraint(
            ["withdrawn_by_user_id"],
            ["users.id"],
            name=op.f("fk_consents_withdrawn_by_user_id_users"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_consents")),
    )
    op.create_index(
        op.f("ix_consents_beneficiary_id"), "consents", ["beneficiary_id"], unique=False
    )
    op.create_index("ix_consents_sync", "consents", ["updated_at", "id"], unique=False)

    # --- RENY (P0.7) -------------------------------------------------------------
    op.create_table(
        "pregnancies",
        sa.Column("beneficiary_id", sa.Uuid(), nullable=False),
        sa.Column(
            "status",
            _enum("pregnancy_status", "active", "delivered", "ended", "transferred", length=16),
            nullable=False,
        ),
        sa.Column("lmp_date", sa.Date(), nullable=True),
        sa.Column("estimated_due_date", sa.Date(), nullable=True),
        sa.Column(
            "dates_confirmed_by",
            _enum("dates_confirmed_by", "ac_declared", "health_worker", "ultrasound"),
            nullable=False,
        ),
        sa.Column("anc_schedule_id", sa.String(length=64), nullable=True),
        sa.Column("anc_schedule_version", sa.String(length=16), nullable=True),
        *_sync_columns(),
        sa.ForeignKeyConstraint(
            ["beneficiary_id"],
            ["beneficiaries.id"],
            name=op.f("fk_pregnancies_beneficiary_id_beneficiaries"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_pregnancies")),
    )
    op.create_index(
        op.f("ix_pregnancies_beneficiary_id"), "pregnancies", ["beneficiary_id"], unique=False
    )
    op.create_index("ix_pregnancies_sync", "pregnancies", ["updated_at", "id"], unique=False)

    op.create_table(
        "anc_visits",
        sa.Column("pregnancy_id", sa.Uuid(), nullable=False),
        sa.Column("sequence", sa.Integer(), nullable=False),
        sa.Column("scheduled_date", sa.Date(), nullable=False),
        sa.Column(
            "status",
            _enum("anc_visit_status", "planned", "done", "missed", "cancelled", length=16),
            nullable=False,
        ),
        sa.Column("done_date", sa.Date(), nullable=True),
        sa.Column("site_id", sa.Uuid(), nullable=True),
        *_sync_columns(),
        sa.ForeignKeyConstraint(
            ["pregnancy_id"],
            ["pregnancies.id"],
            name=op.f("fk_anc_visits_pregnancy_id_pregnancies"),
        ),
        sa.ForeignKeyConstraint(
            ["site_id"], ["sites.id"], name=op.f("fk_anc_visits_site_id_sites")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_anc_visits")),
    )
    op.create_index(
        op.f("ix_anc_visits_pregnancy_id"), "anc_visits", ["pregnancy_id"], unique=False
    )
    op.create_index(
        op.f("ix_anc_visits_scheduled_date"), "anc_visits", ["scheduled_date"], unique=False
    )
    op.create_index("ix_anc_visits_sync", "anc_visits", ["updated_at", "id"], unique=False)

    op.create_table(
        "reminders",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("beneficiary_id", sa.Uuid(), nullable=False),
        sa.Column("anc_visit_id", sa.Uuid(), nullable=True),
        sa.Column("channel", _enum("reminder_channel", *CHANNELS, length=16), nullable=False),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "status",
            _enum("reminder_status", "scheduled", "sent", "failed", "cancelled", length=16),
            nullable=False,
        ),
        sa.Column("message_code", sa.String(length=64), nullable=False),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["anc_visit_id"], ["anc_visits.id"], name=op.f("fk_reminders_anc_visit_id_anc_visits")
        ),
        sa.ForeignKeyConstraint(
            ["beneficiary_id"],
            ["beneficiaries.id"],
            name=op.f("fk_reminders_beneficiary_id_beneficiaries"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_reminders")),
    )
    op.create_index(op.f("ix_reminders_anc_visit_id"), "reminders", ["anc_visit_id"], unique=False)
    op.create_index(
        op.f("ix_reminders_beneficiary_id"), "reminders", ["beneficiary_id"], unique=False
    )
    op.create_index("ix_reminders_due", "reminders", ["status", "scheduled_at"], unique=False)

    # --- Synchronisation (F-10) : idempotence par change_id ----------------------
    op.create_table(
        "sync_changes",
        sa.Column("change_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("device_id", sa.String(length=128), nullable=False),
        sa.Column("entity", sa.String(length=32), nullable=False),
        sa.Column("entity_id", sa.Uuid(), nullable=False),
        sa.Column("op", sa.String(length=16), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("result", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_sync_changes_user_id_users")
        ),
        sa.PrimaryKeyConstraint("change_id", name=op.f("pk_sync_changes")),
    )
    op.create_index(op.f("ix_sync_changes_user_id"), "sync_changes", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_sync_changes_user_id"), table_name="sync_changes")
    op.drop_table("sync_changes")

    op.drop_index("ix_reminders_due", table_name="reminders")
    op.drop_index(op.f("ix_reminders_beneficiary_id"), table_name="reminders")
    op.drop_index(op.f("ix_reminders_anc_visit_id"), table_name="reminders")
    op.drop_table("reminders")

    op.drop_index("ix_anc_visits_sync", table_name="anc_visits")
    op.drop_index(op.f("ix_anc_visits_scheduled_date"), table_name="anc_visits")
    op.drop_index(op.f("ix_anc_visits_pregnancy_id"), table_name="anc_visits")
    op.drop_table("anc_visits")

    op.drop_index("ix_pregnancies_sync", table_name="pregnancies")
    op.drop_index(op.f("ix_pregnancies_beneficiary_id"), table_name="pregnancies")
    op.drop_table("pregnancies")

    op.drop_index("ix_consents_sync", table_name="consents")
    op.drop_index(op.f("ix_consents_beneficiary_id"), table_name="consents")
    op.drop_table("consents")

    op.drop_index("ix_beneficiary_identities_sync", table_name="beneficiary_identities")
    op.drop_table("beneficiary_identities")

    op.drop_index("ix_beneficiaries_sync", table_name="beneficiaries")
    op.drop_index(op.f("ix_beneficiaries_site_id"), table_name="beneficiaries")
    op.drop_table("beneficiaries")

    op.drop_index(op.f("ix_audit_events_login_fingerprint"), table_name="audit_events")
    op.drop_index("ix_audit_events_entity", table_name="audit_events")
    op.drop_index(op.f("ix_audit_events_actor_user_id"), table_name="audit_events")
    op.drop_index(op.f("ix_audit_events_at"), table_name="audit_events")
    op.drop_table("audit_events")

    with op.batch_alter_table("users") as batch_op:
        batch_op.drop_constraint(op.f("fk_users_site_id_sites"), type_="foreignkey")

    op.drop_index(op.f("ix_sites_parent_site_id"), table_name="sites")
    op.drop_table("sites")
