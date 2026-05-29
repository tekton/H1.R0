"""Initial schema reflecting existing Rails database

Revision ID: 0001_initial
Revises:
Create Date: 2024-01-01 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create images table
    op.create_table(
        "images",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("location", sa.String(), nullable=True),
        sa.Column("name", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )

    # Create exif_data table
    op.create_table(
        "exif_data",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("parent", sa.Integer(), nullable=True),
        sa.Column("tag", sa.String(), nullable=True),
        sa.Column("value", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("image_id", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(["image_id"], ["images.id"]),
        sa.PrimaryKeyConstraint("id"),
    )

    # Create searches table
    op.create_table(
        "searches",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("md5hash", sa.String(), nullable=True),
        sa.Column("serial", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("new_tag", sa.String(), nullable=True),
        sa.Column("new_val", sa.String(), nullable=True),
        sa.Column("left", sa.String(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("md5hash"),
    )
    op.create_index("index_searches_on_md5hash", "searches", ["md5hash"], unique=True)


def downgrade() -> None:
    op.drop_index("index_searches_on_md5hash", table_name="searches")
    op.drop_table("searches")
    op.drop_table("exif_data")
    op.drop_table("images")
