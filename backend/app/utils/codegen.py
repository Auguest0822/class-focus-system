"""
工具函数:生成课堂加入码。
"""
import secrets
import string


def generate_classroom_code(length: int = 6) -> str:
    """使用加密安全的随机源,生成 ``length`` 位的课堂加入码。

    字符集为: A-Z + 0-9 (共 36 个字符),
    默认 6 位,冲突概率约 1 / 36^6 ≈ 1 / 21 亿。
    """
    alphabet = string.ascii_uppercase + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))
