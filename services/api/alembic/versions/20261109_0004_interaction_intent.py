"""Intention proposée par le classifieur sur les interactions (F-06, F-16).

Revision ID: 0004
Revises: 0003
Create Date: 2026-11-09
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0004"
down_revision: str | None = "0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    with op.batch_alter_table("interactions") as batch:
        batch.add_column(sa.Column("intent", sa.String(length=64), nullable=True))
        batch.create_index("ix_interactions_intent", ["intent"])


def downgrade() -> None:
    with op.batch_alter_table("interactions") as batch:
        batch.drop_index("ix_interactions_intent")
        batch.drop_column("intent")
