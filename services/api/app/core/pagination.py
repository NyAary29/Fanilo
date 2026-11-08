"""Pagination commune : ``?limit=50&offset=0`` → ``{"items": [...], "total": n}``."""

from dataclasses import dataclass

from fastapi import Query
from pydantic import BaseModel
from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session

MAX_LIMIT = 200


@dataclass(frozen=True)
class PageParams:
    limit: int
    offset: int


def page_params(
    limit: int = Query(50, ge=1, le=MAX_LIMIT),
    offset: int = Query(0, ge=0),
) -> PageParams:
    return PageParams(limit=limit, offset=offset)


class Page[T](BaseModel):
    items: list[T]
    total: int


def paginate(session: Session, stmt: Select, params: PageParams) -> tuple[list, int]:
    """Exécute ``stmt`` paginé ; renvoie (objets, total)."""
    total = session.scalar(select(func.count()).select_from(stmt.order_by(None).subquery())) or 0
    items = list(session.scalars(stmt.limit(params.limit).offset(params.offset)))
    return items, total
