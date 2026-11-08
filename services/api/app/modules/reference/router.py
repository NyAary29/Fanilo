"""Endpoints des référentiels (section 8 bis du contrat)."""

import logging
from typing import Literal

from fanilo_rules import Module
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.modules.beneficiaries.models import ConsentScope
from app.modules.interactions.rules_runtime import RulesRuntime, get_rules_runtime
from app.modules.reference.consent_information import (
    ConsentInformationError,
    load_consent_information,
    served_items,
)
from app.modules.sites.scope import ActorContext, get_actor_context

logger = logging.getLogger("fanilo.reference")

router = APIRouter(prefix="/reference", tags=["référentiels"])


class SignCodeItem(BaseModel):
    code: str
    label_fr: str
    label_mg: str | None
    modules: list[str]


class SignCodesResponse(BaseModel):
    catalog_id: str
    version: str
    status: str
    is_demo: bool
    items: list[SignCodeItem]


class ConsentInformationOut(BaseModel):
    scope: ConsentScope
    version: str
    status: Literal["demo", "draft", "in_review", "validated"]
    summary_fr: str
    summary_mg: str | None


class ConsentInformationResponse(BaseModel):
    items: list[ConsentInformationOut]


@router.get(
    "/sign-codes",
    response_model=SignCodesResponse,
    summary="Référentiel des codes de signes (validated, ou demo en mode démo)",
)
def sign_codes(
    module: Module | None = None,
    _ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
    rules: RulesRuntime = Depends(get_rules_runtime),  # noqa: B008
) -> SignCodesResponse:
    catalog = rules.catalog
    if catalog is None:
        # Refusé par la politique de chargement (ex. demo hors mode démo) ou invalide.
        raise HTTPException(status_code=503, detail="Référentiel des codes de signes indisponible.")
    # Le référentiel ne porte qu'un libellé, dans la langue déclarée du document.
    in_malagasy = catalog.language.startswith("mg")
    items = [
        SignCodeItem(
            code=sign.code,
            label_fr=sign.label,
            label_mg=sign.label if in_malagasy else None,
            modules=[str(m) for m in sign.modules],
        )
        for sign in catalog.signs
        if module is None or module in sign.modules
    ]
    return SignCodesResponse(
        catalog_id=catalog.catalog_id,
        version=catalog.version,
        status=str(catalog.status),
        is_demo=catalog.is_demo,
        items=items,
    )


@router.get(
    "/consent-information",
    response_model=ConsentInformationResponse,
    summary="Versions de l'information présentée lors du consentement",
)
def consent_information(
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> ConsentInformationResponse:
    try:
        document = load_consent_information(ctx.settings.consent_information_path)
    except ConsentInformationError as exc:
        logger.error("consent_information_unavailable", extra={"reason": str(exc)[:300]})
        raise HTTPException(
            status_code=503, detail="Information de consentement indisponible."
        ) from None
    items = served_items(document, allow_demo=ctx.settings.allow_demo_content)
    return ConsentInformationResponse(items=[ConsentInformationOut(**i) for i in items])
