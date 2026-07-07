"""
FastAPI 依赖注入:当前用户识别 + 角色校验

- ``get_current_user``: 从 ``Authorization: Bearer <token>`` 中取出 JWT,
  解析出用户 id,并从数据库加载对应的 User。失败一律抛 401。
- ``require_role("teacher")``: 基于 ``get_current_user`` 的上层依赖,
  要求登录用户必须匹配指定角色之一,否则抛 403。

这些函数用 ``Depends(...)`` 的方式挂到接口上,就像 Spring 里的
``@PreAuthorize`` 或是 ``AuthenticationPrincipal`` 一样。
"""
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import decode_token
from app.models import User

# HTTPBearer 会自动从请求头中解析 "Authorization: Bearer <token>"
# auto_error=False: 没传 token 时先不报错,由我们自己决定什么时候抛 401
_bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    """解析 JWT 并返回当前登录的用户对象。
    - token 缺失 / 无效 / 用户不存在,一律返回 401。
    """
    token = credentials.credentials if credentials else None
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供认证令牌",
        )

    payload = decode_token(token)
    if not payload or "sub" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的认证令牌",
        )

    user_id = int(payload["sub"])
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户不存在",
        )
    return user


def require_role(*roles: str):
    """返回一个依赖函数:要求当前登录用户的 role 必须属于给定的角色之一。

    用法::

        def my_api(current_user: User = Depends(require_role("teacher"))):
            ...
    """

    def _checker(user: User = Depends(get_current_user)) -> User:
        allowed = set(roles)
        if allowed and user.role not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="权限不足",
            )
        return user

    return _checker
