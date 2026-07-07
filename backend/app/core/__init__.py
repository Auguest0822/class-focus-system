"""
core 模块导出入口,方便在其他位置用 ``from app.core import settings, get_db`` 这样写。
"""
from app.core.config import settings
from app.core.database import Base, engine, get_db
from app.core.deps import get_current_user, require_role
from app.core.security import create_access_token, decode_token, hash_password, verify_password

__all__ = [
    "settings",
    "Base",
    "engine",
    "get_db",
    "create_access_token",
    "decode_token",
    "hash_password",
    "verify_password",
    "get_current_user",
    "require_role",
]
