"""Phase A3: password_changed_at column for session invalidation.

Every JWT the app issues carries an `iat` claim (seconds since epoch).
The blocklist loader compares `iat < password_changed_at` and treats
older tokens as revoked. Setting this on any password change (reset,
future admin-forced change) invalidates every existing session.

Revision ID: e2b91d5c6a7f
Revises: 7c48a2f19b3d
Create Date: 2026-08-16 22:00:00.000000
"""
from alembic import op
import sqlalchemy as sa


revision = 'e2b91d5c6a7f'
down_revision = '7c48a2f19b3d'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column('password_changed_at', sa.DateTime(timezone=True), nullable=True)
        )


def downgrade():
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('password_changed_at')
