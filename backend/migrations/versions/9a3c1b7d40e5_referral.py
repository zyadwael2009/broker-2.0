"""Phase G1: referral_code + referred_by on users

Adds:
  - users.referral_code (unique, indexed, nullable)
  - users.referred_by_user_id (FK self-referential, SET NULL on delete)

Data migration: backfills a fresh referral_code for every existing
user so the broker dashboard has something to display on day one.

Revision ID: 9a3c1b7d40e5
Revises: e2b91d5c6a7f
Create Date: 2026-08-17 12:00:00.000000
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.orm import Session


revision = '9a3c1b7d40e5'
down_revision = 'e2b91d5c6a7f'
branch_labels = None
depends_on = None


# Ambiguous-character-free alphabet — safe to dictate over the phone.
_ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789"


def _generate_code(rng):
    return "".join(rng.choice(_ALPHABET) for _ in range(8))


def upgrade():
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column('referral_code', sa.String(length=16), nullable=True)
        )
        batch_op.add_column(
            sa.Column('referred_by_user_id', sa.BigInteger(), nullable=True)
        )
        batch_op.create_index(
            batch_op.f('ix_users_referral_code'),
            ['referral_code'],
            unique=True,
        )
        batch_op.create_index(
            batch_op.f('ix_users_referred_by_user_id'),
            ['referred_by_user_id'],
            unique=False,
        )
        # Self-referential FK — outside the batch_alter_table context on
        # SQLite it needs `use_alter=True`, but batch handles it cleanly.
        batch_op.create_foreign_key(
            'fk_users_referred_by_user_id',
            'users',
            ['referred_by_user_id'],
            ['id'],
            ondelete='SET NULL',
        )

    # Backfill: give every existing user a fresh referral code.
    import random
    rng = random.SystemRandom()

    bind = op.get_bind()
    session = Session(bind=bind)
    users_table = sa.table(
        'users',
        sa.column('id', sa.BigInteger),
        sa.column('referral_code', sa.String),
    )
    rows = session.execute(sa.select(users_table.c.id)).fetchall()
    used = set()
    for (uid,) in rows:
        for _ in range(6):
            code = _generate_code(rng)
            if code in used:
                continue
            existing = session.execute(
                sa.select(users_table.c.id)
                .where(users_table.c.referral_code == code)
            ).first()
            if existing is None:
                used.add(code)
                session.execute(
                    users_table.update()
                    .where(users_table.c.id == uid)
                    .values(referral_code=code)
                )
                break
    session.commit()


def downgrade():
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_constraint('fk_users_referred_by_user_id', type_='foreignkey')
        batch_op.drop_index(batch_op.f('ix_users_referred_by_user_id'))
        batch_op.drop_index(batch_op.f('ix_users_referral_code'))
        batch_op.drop_column('referred_by_user_id')
        batch_op.drop_column('referral_code')
