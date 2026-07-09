"""
安全相关:密码哈希 + JWT 签发 / 校验

- 使用 ``passlib[bcrypt]`` 对密码做 bcrypt 哈希(等价于 Spring 的 BCryptPasswordEncoder)。
- 使用 ``python-jose[cryptography]`` 做 JWT 签发与校验(等价于 jjwt / auth0-java-jwt)。
"""
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings

# ─── 密码哈希 ─────────────────────────────────────────
# bcrypt 是一个带盐(salt)的迭代哈希算法;它能防御彩虹表攻击。
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    """返回 bcrypt 哈希字符串,供写入数据库。"""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """比较明文密码和数据库里存的哈希是否一致。"""
    try:
        return pwd_context.verify(plain_password, hashed_password)
    except Exception:
        return False


# ─── JWT 工具函数 ────────────────────────────────────
def create_access_token(
    subject: Any,
    extra: Optional[dict] = None,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """签发一个 JWT access_token。

    - ``sub`` 声明: 主体,这里统一是用户 id 的字符串。
    - ``exp`` 声明: 过期时间。默认使用配置中的 ACCESS_TOKEN_EXPIRE_MINUTES。
    - ``extra``: 额外字段,例如 ``{"role": "student", "account": "2024001"}``,
      方便前端/接口直接读到角色信息,避免额外查库。
    """
    if expires_delta is not None:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        )

    to_encode = {"exp": expire, "sub": str(subject)}
    if extra:
        to_encode.update(extra)

    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_token(token: str) -> Optional[dict]:
    """校验并解析 JWT,失败时返回 ``None``(过期 / 签名错误一律视为无效)。"""
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        return payload
    except JWTError:
        return None
