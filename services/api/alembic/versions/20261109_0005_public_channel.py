"""Canal public anonyme : auteur facultatif, canal, empreinte du jeton de suivi.

Revision ID: 0005
Revises: 0004
Create Date: 2026-11-09
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0005"
down_revision: str | None = "0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    with op.batch_alter_table("interactions") as batch:
        batch.alter_column("asked_by_user_id", existing_type=sa.Uuid(), nullable=True)
        batch.add_column(
            sa.Column("channel", sa.String(length=16), nullable=False, server_default="agent")
        )
        batch.add_column(sa.Column("follow_up_token_hash", sa.String(length=64), nullable=True))


def downgrade() -> None:
    op.execute("DELETE FROM interactions WHERE asked_by_user_id IS NULL")
    with op.batch_alter_table("interactions") as batch:
        batch.drop_column("follow_up_token_hash")
        batch.drop_column("channel")
        batch.alter_column("asked_by_user_id", existing_type=sa.Uuid(), nullable=False)
