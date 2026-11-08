"""Schémas d'entrée / sortie de l'API d'authentification."""

import uuid

from pydantic import BaseModel, ConfigDict, Field

from app.modules.users.models import LOGIN_MAX_LENGTH
from app.modules.users.roles import Role


class LoginRequest(BaseModel):
    login: str = Field(min_length=1, max_length=LOGIN_MAX_LENGTH)
    password: str = Field(min_length=1, max_length=1024)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1, max_length=512)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"  # noqa: S105 (type de jeton OAuth2, pas un secret)
    expires_in: int
    refresh_token: str
    refresh_expires_in: int


class MeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    login: str
    role: Role
    site_id: uuid.UUID | None
    is_active: bool
