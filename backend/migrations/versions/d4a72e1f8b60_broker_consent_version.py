"""Pre-launch — PDPL consent audit trail

- broker_profiles.consent_version  (String(16), nullable — pre-consent
  rows are legitimately NULL)

Revision ID: d4a72e1f8b60
Revises: c8b47f2e0a9d
Create Date: 2026-08-17 16:00:00.000000
"""
from alembic import op
import sqlalchemy as sa


revision = 'd4a72e1f8b60'
down_revision = 'c8b47f2e0a9d'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('broker_profiles', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column('consent_version', sa.String(length=16), nullable=True)
        )


def downgrade():
    with op.batch_alter_table('broker_profiles', schema=None) as batch_op:
        batch_op.drop_column('consent_version')
