"""Orientation vers un centre de santé dans la réponse du conseiller.

Revision ID: 0006
Revises: 0005
Create Date: 2026-11-10
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0006"
down_revision: str | None = "0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    with op.batch_alter_table("interactions") as batch:
        batch.add_column(sa.Column("orientation_site_id", sa.Uuid(), nullable=True))
        batch.create_foreign_key(
            "fk_interactions_orientation_site", "sites", ["orientation_site_id"], ["id"]
        )


def downgrade() -> None:
    with op.batch_alter_table("interactions") as batch:
        batch.drop_constraint("fk_interactions_orientation_site", type_="foreignkey")
        batch.drop_column("orientation_site_id")
