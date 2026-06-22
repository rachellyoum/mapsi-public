"""add trending trips feature

Revision ID: da1b95dd422e
Revises: d30f0d15894b
Create Date: 2026-04-24 23:48:00.792719

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'da1b95dd422e'
down_revision: Union[str, Sequence[str], None] = 'd30f0d15894b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("trips", sa.Column("is_public", sa.Boolean(), nullable=False, server_default=sa.text("false")))
    op.add_column("trips", sa.Column("views_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("trips", sa.Column("likes_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("trips", sa.Column("copies_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("trips", sa.Column("source_trip_id", sa.String(), nullable=True))

    op.create_index("ix_trips_source_trip_id", "trips", ["source_trip_id"])

    op.create_foreign_key(
        "fk_trips_source_trip_id_trips",
        "trips",
        "trips",
        ["source_trip_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.create_table(
        "trip_likes",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("trip_id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("trip_id", "user_id", name="uq_trip_like_trip_user"),
    )

    op.create_index("ix_trip_likes_trip_id", "trip_likes", ["trip_id"])
    op.create_index("ix_trip_likes_user_id", "trip_likes", ["user_id"])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_trip_likes_user_id", table_name="trip_likes")
    op.drop_index("ix_trip_likes_trip_id", table_name="trip_likes")
    op.drop_table("trip_likes")

    op.drop_constraint("fk_trips_source_trip_id_trips", "trips", type_="foreignkey")
    op.drop_index("ix_trips_source_trip_id", table_name="trips")

    op.drop_column("trips", "source_trip_id")
    op.drop_column("trips", "copies_count")
    op.drop_column("trips", "likes_count")
    op.drop_column("trips", "views_count")
    op.drop_column("trips", "is_public")
