"""Rating aggregate helper.

Kept in its own module so it can be reused from the broker public
profile route, the listing feed's broker sub-object, and the seed CLI
without a cross-blueprint import cycle."""
from __future__ import annotations

from typing import Iterable

from sqlalchemy import func

from ..extensions import db
from ..models.broker_rating import BrokerRating


def aggregate_for(broker_id: int) -> dict:
    """`{avg, count, distribution}` for one broker in a single query."""
    rows = (
        db.session.query(BrokerRating.stars, func.count())
        .filter(BrokerRating.broker_user_id == broker_id)
        .group_by(BrokerRating.stars)
        .all()
    )
    return _shape(rows)


def aggregate_for_many(broker_ids: Iterable[int]) -> dict[int, dict]:
    """Batched — one query, N brokers. Used by the listing feed so we
    don't fire an N+1 for every card. Keys missing from the result get
    the empty aggregate."""
    ids = list(broker_ids)
    if not ids:
        return {}
    rows = (
        db.session.query(BrokerRating.broker_user_id, BrokerRating.stars, func.count())
        .filter(BrokerRating.broker_user_id.in_(ids))
        .group_by(BrokerRating.broker_user_id, BrokerRating.stars)
        .all()
    )
    grouped: dict[int, list[tuple[int, int]]] = {i: [] for i in ids}
    for broker_id, stars, count in rows:
        grouped[broker_id].append((stars, count))
    return {bid: _shape(rows) for bid, rows in grouped.items()}


def _shape(rows: list[tuple[int, int]]) -> dict:
    dist = {str(s): 0 for s in range(1, 6)}
    total = 0
    weighted = 0
    for stars, count in rows:
        dist[str(stars)] = count
        total += count
        weighted += stars * count
    avg = round(weighted / total, 2) if total else 0.0
    return {"avg": avg, "count": total, "distribution": dist}
