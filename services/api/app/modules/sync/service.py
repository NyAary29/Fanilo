"""Synchronisation hors ligne : ``pull`` (curseur) et ``push`` (idempotent).

Push :
- chaque modification est traitée dans sa propre transaction et journalisée
  dans ``sync_changes`` avec son résultat ; un ``change_id`` déjà traité
  renvoie ce résultat sans rien réappliquer ;
- conflit si ``base_version`` diffère de la version serveur (ou si la ligne
  existe déjà / est supprimée) : rien n'est écrit, l'état serveur est renvoyé ;
- refus (``rejected``) pour une entité inconnue ou en lecture seule, un rôle
  insuffisant, une ligne hors périmètre (« introuvable », sans révéler son
  existence) ou des données invalides.

Pull : curseur opaque fondé sur la séquence de modification ``sync_seq``
(voir ``app.db.base``), et non sur l'horloge. Le serveur lit d'abord la borne
haute validée ``H`` du compteur, puis ne renvoie que les lignes de
``curseur < sync_seq <= H`` : toutes ces lignes sont déjà validées, une
transaction encore en cours ne peut pas en faire manquer une. Périmètre par
site ; lignes supprimées incluses (``deleted_at`` renseigné, ``data`` nul).
"""

import base64
import binascii
import json
import uuid
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field, ValidationError
from sqlalchemy.orm.exc import StaleDataError

from app.core.crypto import get_cipher
from app.core.errors import DomainError, InvalidDataError, NotFoundError, VersionConflictError
from app.db.base import current_sync_seq
from app.modules.sites.scope import ActorContext
from app.modules.sync.models import SyncChange
from app.modules.sync.registry import REGISTRY, SyncEntity

MAX_PULL_LIMIT = 1000
MAX_PUSH_CHANGES = 100
NOT_FOUND = "Enregistrement introuvable."


# --- Schémas ------------------------------------------------------------------


class PushChange(BaseModel):
    change_id: uuid.UUID
    entity: str = Field(min_length=1, max_length=32)
    op: Literal["upsert", "delete"]
    id: uuid.UUID
    base_version: int | None = None
    # Représentation complète des champs modifiables ; nul accepté pour ``delete``.
    data: dict[str, Any] | None = None


class PushRequest(BaseModel):
    device_id: str = Field(min_length=1, max_length=128)
    changes: list[PushChange] = Field(max_length=MAX_PUSH_CHANGES)


class PushError(BaseModel):
    code: str
    message: str


def _rejected(change: "PushChange", code: str, message: str) -> "PushResult":
    return PushResult(
        change_id=change.change_id,
        status="rejected",
        error=PushError(code=code, message=message),
    )


class PushResult(BaseModel):
    change_id: uuid.UUID
    status: Literal["applied", "conflict", "rejected"]
    server_version: int | None = None
    server_data: dict[str, Any] | None = None
    error: "PushError | None" = None


class PushResponse(BaseModel):
    results: list[PushResult]


class PullChange(BaseModel):
    entity: str
    id: uuid.UUID
    version: int
    deleted_at: datetime | None
    data: dict[str, Any] | None


class PullResponse(BaseModel):
    changes: list[PullChange]
    next_cursor: str | None
    has_more: bool


# --- Curseur ------------------------------------------------------------------


def encode_cursor(seq: int) -> str:
    """Curseur opaque (base64 URL) portant une valeur de ``sync_seq``."""
    raw = json.dumps({"s": seq}, separators=(",", ":"))
    return base64.urlsafe_b64encode(raw.encode()).decode().rstrip("=")


def decode_cursor(token: str) -> int:
    try:
        padded = token + "=" * (-len(token) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded.encode()))
        seq = payload["s"]
        if not isinstance(seq, int) or isinstance(seq, bool) or seq < 0:
            raise ValueError
        return seq
    except (ValueError, KeyError, TypeError, binascii.Error, json.JSONDecodeError):
        raise InvalidDataError("Curseur de synchronisation invalide.") from None


# --- Pull ---------------------------------------------------------------------


def _can_pull(ctx: ActorContext, entity: SyncEntity) -> bool:
    return entity.pull_roles is None or ctx.actor.role in entity.pull_roles


def pull(ctx: ActorContext, since: str | None, limit: int) -> PullResponse:
    after = decode_cursor(since) if since else 0
    # Borne haute lue AVANT les requêtes : seules des lignes validées en dessous.
    horizon = current_sync_seq(ctx.session)
    candidates: list[tuple[int, int, SyncEntity, Any]] = []
    for entity in REGISTRY.values():
        if not _can_pull(ctx, entity):
            continue
        model = entity.model
        stmt = (
            entity.scoped_select(ctx.scope)
            .where(model.sync_seq > after, model.sync_seq <= horizon)
            .order_by(model.sync_seq)
            .limit(limit + 1)
        )
        for obj in ctx.session.scalars(stmt):
            candidates.append((obj.sync_seq, entity.rank, entity, obj))
    candidates.sort(key=lambda item: (item[0], item[1]))
    page = candidates[:limit]
    has_more = len(candidates) > limit
    changes = []
    for _, _, entity, obj in page:
        deleted = obj.deleted_at is not None
        if not deleted and entity.on_pull is not None:
            entity.on_pull(ctx, obj)
        changes.append(
            PullChange(
                entity=entity.name,
                id=obj.id,
                version=obj.version,
                deleted_at=obj.deleted_at,
                data=None if deleted else entity.serialize(ctx, obj),
            )
        )
    ctx.session.commit()  # audit des lectures nominatives
    # Sans suite, tout ce qui est visible jusqu'à la borne haute a été transmis.
    next_seq = page[-1][0] if has_more else max(after, horizon)
    return PullResponse(changes=changes, next_cursor=encode_cursor(next_seq), has_more=has_more)


# --- Push ---------------------------------------------------------------------


def _store_result(entity: SyncEntity | None, result: PushResult, ctx: ActorContext) -> dict:
    payload = result.model_dump(mode="json")
    if entity is not None and entity.nominative:
        token = get_cipher(ctx.settings).encrypt(json.dumps(payload))
        return {"encrypted": token}
    return payload


def _load_result(stored: dict, ctx: ActorContext) -> PushResult:
    if "encrypted" in stored:
        stored = json.loads(get_cipher(ctx.settings).decrypt(stored["encrypted"]) or "{}")
    return PushResult.model_validate(stored)


def _visible(ctx: ActorContext, entity: SyncEntity, entity_id: uuid.UUID) -> Any | None:
    stmt = entity.scoped_select(ctx.scope).where(entity.model.id == entity_id)
    return ctx.session.scalar(stmt)


def _server_state(
    ctx: ActorContext, entity: SyncEntity, change: PushChange, status: str
) -> PushResult:
    obj = _visible(ctx, entity, change.id)
    if obj is None:
        return _rejected(change, "not_found", NOT_FOUND)
    deleted = obj.deleted_at is not None
    if not deleted and entity.on_pull is not None and status == "conflict":
        entity.on_pull(ctx, obj)
    return PushResult(
        change_id=change.change_id,
        status=status,  # type: ignore[arg-type]
        server_version=obj.version,
        server_data=None if deleted else entity.serialize(ctx, obj),
    )


def _apply(ctx: ActorContext, entity: SyncEntity, change: PushChange) -> PushResult:
    session = ctx.session
    ops = entity.push
    assert ops is not None  # noqa: S101 - vérifié par l'appelant
    if session.get(entity.model, change.id) is None:
        if change.op == "delete" or change.base_version is not None:
            raise NotFoundError(NOT_FOUND)
        if change.data is None:
            raise InvalidDataError("data est obligatoire pour un upsert.")
        ops.create(ctx, change.id, change.data)
        session.flush()
        return _server_state(ctx, entity, change, "applied")

    obj = _visible(ctx, entity, change.id)
    if obj is None:
        raise NotFoundError(NOT_FOUND)
    if obj.deleted_at is not None or change.base_version != obj.version:
        raise VersionConflictError
    if change.op == "delete":
        ops.delete(ctx, obj)
    elif change.data is None:
        raise InvalidDataError("data est obligatoire pour un upsert.")
    else:
        ops.update(ctx, obj, change.data, change.base_version)
    session.flush()
    return _server_state(ctx, entity, change, "applied")


def _process(ctx: ActorContext, device_id: str, change: PushChange) -> PushResult:
    session = ctx.session
    previous = session.get(SyncChange, change.change_id)
    if previous is not None:
        if previous.user_id != ctx.actor.id:
            return _rejected(change, "change_id_conflict", "change_id déjà utilisé.")
        return _load_result(previous.result, ctx)

    entity = REGISTRY.get(change.entity)
    result: PushResult
    if entity is None:
        result = _rejected(change, "unsupported_entity", f"Entité inconnue : {change.entity}.")
    elif entity.push is None:
        result = _rejected(change, "read_only", f"Entité en lecture seule : {change.entity}.")
    elif ctx.actor.role not in entity.push_roles:
        result = _rejected(change, "forbidden", "Accès refusé.")
    else:
        try:
            result = _apply(ctx, entity, change)
        except (VersionConflictError, StaleDataError):
            session.rollback()
            result = _server_state(ctx, entity, change, "conflict")
        except DomainError as exc:
            session.rollback()
            result = _rejected(change, exc.code, exc.detail)
        except ValidationError as exc:
            session.rollback()
            fields = ", ".join(".".join(map(str, e["loc"])) for e in exc.errors()) or "?"
            result = _rejected(change, "validation_error", f"Données invalides ({fields}).")

    session.add(
        SyncChange(
            change_id=change.change_id,
            user_id=ctx.actor.id,
            device_id=device_id,
            entity=change.entity[:32],
            entity_id=change.id,
            op=change.op,
            status=result.status,
            result=_store_result(entity, result, ctx),
        )
    )
    session.commit()
    return result


def push(ctx: ActorContext, request: PushRequest) -> PushResponse:
    return PushResponse(
        results=[_process(ctx, request.device_id, change) for change in request.changes]
    )
