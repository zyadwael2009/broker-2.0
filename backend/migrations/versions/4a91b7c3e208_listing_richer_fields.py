"""Phase A1: richer listing fields

- listing_kind (sale|rent) — defaults to sale so seeded rows migrate cleanly
- bedrooms, bathrooms, floor_number — nullable integers
- is_furnished — tri-state nullable boolean
- compound_name — indexed nullable string
- delivery_status (ready|under_construction) — nullable

Revision ID: 4a91b7c3e208
Revises: 3d2f8e1b5a01
Create Date: 2026-08-16 15:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '4a91b7c3e208'
down_revision = '3d2f8e1b5a01'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('listings', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                'listing_kind',
                sa.Enum('sale', 'rent', name='listing_kind'),
                nullable=False,
                server_default='sale',
            )
        )
        batch_op.add_column(sa.Column('bedrooms', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('bathrooms', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('floor_number', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('is_furnished', sa.Boolean(), nullable=True))
        batch_op.add_column(sa.Column('compound_name', sa.String(length=120), nullable=True))
        batch_op.add_column(
            sa.Column(
                'delivery_status',
                sa.Enum('ready', 'under_construction', name='delivery_status'),
                nullable=True,
            )
        )
        batch_op.create_index(
            batch_op.f('ix_listings_compound_name'), ['compound_name'], unique=False
        )


def downgrade():
    with op.batch_alter_table('listings', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_listings_compound_name'))
        batch_op.drop_column('delivery_status')
        batch_op.drop_column('compound_name')
        batch_op.drop_column('is_furnished')
        batch_op.drop_column('floor_number')
        batch_op.drop_column('bathrooms')
        batch_op.drop_column('bedrooms')
        batch_op.drop_column('listing_kind')
    # Postgres named enums need explicit drop; SQLite is a no-op via checkfirst.
    sa.Enum(name='delivery_status').drop(op.get_bind(), checkfirst=True)
    sa.Enum(name='listing_kind').drop(op.get_bind(), checkfirst=True)
