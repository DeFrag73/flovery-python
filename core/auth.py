from fastapi import Security, HTTPException, status
from fastapi.security import APIKeyHeader
from core.config import get_settings

settings = get_settings()

api_key_header = APIKeyHeader(name="X-Admin-Token", auto_error=False)


async def require_admin_token(api_key: str | None = Security(api_key_header)) -> str:
    """Dependency that validates the admin API token from X-Admin-Token header."""
    if not api_key or api_key != settings.ADMIN_API_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing admin token. Provide it via 'X-Admin-Token' header.",
            headers={"WWW-Authenticate": "ApiKey"},
        )
    return api_key