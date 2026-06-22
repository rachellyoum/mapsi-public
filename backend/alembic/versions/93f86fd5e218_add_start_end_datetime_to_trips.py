"""add start/end datetime to trips

Revision ID: 93f86fd5e218
Revises: 
Create Date: 2026-03-04 17:49:54.187271

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '93f86fd5e218'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.add_column(
        "trips",
        sa.Column("start_datetime", sa.DateTime(timezone=True), nullable=True)
    )

    op.add_column(
        "trips",
        sa.Column("end_datetime", sa.DateTime(timezone=True), nullable=True)
    )

    # optional: convert existing DATE values to DATETIME
    op.execute("""
        UPDATE trips
        SET start_datetime = start_date::timestamptz,
            end_datetime   = end_date::timestamptz
        WHERE start_date IS NOT NULL OR end_date IS NOT NULL;
    """)


def downgrade():
    op.drop_column("trips", "start_datetime")
    op.drop_column("trips", "end_datetime")
