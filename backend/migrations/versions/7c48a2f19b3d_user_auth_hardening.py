"""Phase A2: phone verification + password reset columns on users

Revision ID: 7c48a2f19b3d
Revises: 4a91b7c3e208
Create Date: 2026-08-16 18:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '7c48a2f19b3d'
down_revision = '4a91b7c3e208'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                'phone_verified', sa.Boolean(),
                nullable=False, server_default=sa.text('0'),
            )
        )
        batch_op.add_column(sa.Column('phone_verified_at', sa.DateTime(timezone=True), nullable=True))
        batch_op.add_column(sa.Column('phone_otp_hash', sa.String(length=128), nullable=True))
        batch_op.add_column(sa.Column('phone_otp_expires_at', sa.DateTime(timezone=True), nullable=True))
        batch_op.add_column(sa.Column('password_reset_hash', sa.String(length=128), nullable=True))
        batch_op.add_column(sa.Column('password_reset_expires_at', sa.DateTime(timezone=True), nullable=True))


def downgrade():
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('password_reset_expires_at')
        batch_op.drop_column('password_reset_hash')
        batch_op.drop_column('phone_otp_expires_at')
        batch_op.drop_column('phone_otp_hash')
        batch_op.drop_column('phone_verified_at')
        batch_op.drop_column('phone_verified')
