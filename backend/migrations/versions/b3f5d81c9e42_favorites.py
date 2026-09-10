"""Phase 3 redesign — buyer favorites

- favorites (user_id, listing_id) join table with a uniqueness guard so a
  double-tapped heart can't create two rows. Both FKs cascade on delete:
  removing a listing or an account leaves no orphan saves.

Revision ID: b3f5d81c9e42
Revises: d4a72e1f8b60
Create Date: 2026-09-09 10:00:00.000000
"""
from alembic import op
import sqlalchemy as sa


revision = 'b3f5d81c9e42'
down_revision = 'd4a72e1f8b60'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'favorites',
        sa.Column('id', sa.BigInteger().with_variant(sa.Integer(), 'sqlite'),
                  nullable=False),
        sa.Column('user_id', sa.BigInteger(), nullable=False),
        sa.Column('listing_id', sa.BigInteger(), nullable=False),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('(CURRENT_TIMESTAMP)'),
            nullable=False,
        ),
        sa.Column(
            'updated_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('(CURRENT_TIMESTAMP)'),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(['listing_id'], ['listings.id'],
                                ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'listing_id',
                            name='uq_favorites_user_listing'),
    )
    with op.batch_alter_table('favorites', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_favorites_user_id'),
                              ['user_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_favorites_listing_id'),
                              ['listing_id'], unique=False)


def downgrade():
    with op.batch_alter_table('favorites', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_favorites_listing_id'))
        batch_op.drop_index(batch_op.f('ix_favorites_user_id'))
    op.drop_table('favorites')
