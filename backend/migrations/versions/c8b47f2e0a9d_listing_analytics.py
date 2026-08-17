"""Phase G2 — listing view analytics

- listings.total_views  (integer counter, default 0)
- listing_view_days      (per-day roll-up, unique on listing_id+day)

Revision ID: c8b47f2e0a9d
Revises: 9a3c1b7d40e5
Create Date: 2026-08-17 15:00:00.000000
"""
from alembic import op
import sqlalchemy as sa


revision = 'c8b47f2e0a9d'
down_revision = '9a3c1b7d40e5'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('listings', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                'total_views', sa.Integer(),
                nullable=False, server_default=sa.text('0'),
            )
        )

    op.create_table(
        'listing_view_days',
        sa.Column(
            'id',
            sa.BigInteger().with_variant(sa.Integer(), 'sqlite'),
            nullable=False,
        ),
        sa.Column('listing_id', sa.BigInteger(), nullable=False),
        sa.Column('day', sa.Date(), nullable=False),
        sa.Column('count', sa.Integer(), nullable=False,
                  server_default=sa.text('0')),
        sa.ForeignKeyConstraint(['listing_id'], ['listings.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('listing_id', 'day', name='uq_view_day'),
    )
    with op.batch_alter_table('listing_view_days', schema=None) as batch_op:
        batch_op.create_index(
            batch_op.f('ix_listing_view_days_listing_id'),
            ['listing_id'],
            unique=False,
        )
        batch_op.create_index(
            batch_op.f('ix_listing_view_days_day'),
            ['day'],
            unique=False,
        )
        batch_op.create_index(
            'ix_view_day_listing_day',
            ['listing_id', 'day'],
            unique=False,
        )


def downgrade():
    with op.batch_alter_table('listing_view_days', schema=None) as batch_op:
        batch_op.drop_index('ix_view_day_listing_day')
        batch_op.drop_index(batch_op.f('ix_listing_view_days_day'))
        batch_op.drop_index(batch_op.f('ix_listing_view_days_listing_id'))
    op.drop_table('listing_view_days')
    with op.batch_alter_table('listings', schema=None) as batch_op:
        batch_op.drop_column('total_views')
