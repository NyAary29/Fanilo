"""Classement par le conseiller (triage) et suivi par le centre (code, statut).

Revision ID: 0007
Revises: 0006
Create Date: 2026-11-10
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0007"
down_revision: str | None = "0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _enum(name: str, *values: str) -> sa.Enum:
    return sa.Enum(*values, name=name, native_enum=False, create_constraint=True, length=16)


def upgrade() -> None:
    with op.batch_alter_table("interactions") as batch:
        batch.add_column(
            sa.Column("triage", _enum("interaction_triage", "urgent", "follow_up", "info"))
        )
        batch.add_column(sa.Column("follow_up_code", sa.String(length=8), nullable=True))
        batch.add_column(
            sa.Column(
                "follow_up_status",
                _enum("interaction_follow_up_status", "expected", "came", "no_show"),
                nullable=True,
            )
        )
        batch.add_column(sa.Column("follow_up_at", sa.DateTime(timezone=True), nullable=True))
        batch.add_column(sa.Column("follow_up_by_user_id", sa.Uuid(), nullable=True))
        batch.add_column(sa.Column("follow_up_note", sa.Text(), nullable=True))
        batch.create_foreign_key(
            "fk_interactions_follow_up_by", "users", ["follow_up_by_user_id"], ["id"]
        )
        batch.create_index("ix_interactions_follow_up_code", ["follow_up_code"])
        batch.create_index("ix_interactions_orientation_site_id", ["orientation_site_id"])


def downgrade() -> None:
    with op.batch_alter_table("interactions") as batch:
        batch.drop_index("ix_interactions_orientation_site_id")
        batch.drop_index("ix_interactions_follow_up_code")
        batch.drop_constraint("fk_interactions_follow_up_by", type_="foreignkey")
        batch.drop_constraint("interaction_follow_up_status", type_="check")
        batch.drop_constraint("interaction_triage", type_="check")
        for column in (
            "follow_up_note",
            "follow_up_by_user_id",
            "follow_up_at",
            "follow_up_status",
            "follow_up_code",
            "triage",
        ):
            batch.drop_column(column)
