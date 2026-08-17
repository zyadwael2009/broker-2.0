"""device tokens for push notifications

Revision ID: 3d2f8e1b5a01
Revises: 2851ee096757
Create Date: 2026-08-15 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '3d2f8e1b5a01'
down_revision = '2851ee096757'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'device_tokens',
        sa.Column('id', sa.BigInteger().with_variant(sa.Integer(), 'sqlite'), nullable=False),
        sa.Column('user_id', sa.BigInteger(), nullable=False),
        sa.Column('token', sa.String(length=4096), nullable=False),
        sa.Column(
            'platform',
            sa.Enum('android', 'ios', 'web', name='device_platform'),
            nullable=False,
        ),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('(CURRENT_TIMESTAMP)'),
            nullable=False,
        ),
        sa.Column(
            'last_seen_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('(CURRENT_TIMESTAMP)'),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'token', name='uq_device_tokens_user_token'),
    )
    with op.batch_alter_table('device_tokens', schema=None) as batch_op:
        batch_op.create_index(
            batch_op.f('ix_device_tokens_user_id'),
            ['user_id'],
            unique=False,
        )


def downgrade():
    with op.batch_alter_table('device_tokens', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_device_tokens_user_id'))
    op.drop_table('device_tokens')
    # SQLite doesn't have named enums to drop; Postgres does — this is
    # safe on both because SQLAlchemy skips the drop_type on SQLite.
    sa.Enum(name='device_platform').drop(op.get_bind(), checkfirst=True)
