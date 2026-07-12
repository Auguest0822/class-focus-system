"""
MinIO 对象存储客户端封装。

提供头像上传、删除和 URL 生成功能。Bucket 设为 public-read，
直接返回 HTTP URL，前端无需签名即可访问。

缓存策略
--------
- 内存缓存：``get_avatar_stream()`` 把头像字节缓存 TTL 秒，避免每次请求都打 MinIO。
- 上传/删除时自动刷新缓存，保证头像更新即时生效。
"""
import hashlib
import time
import uuid
from typing import Optional

from minio import Minio
from minio.error import S3Error

from app.core.config import settings

_client: Optional[Minio] = None

# ── 内存缓存 ──────────────────────────────────────────────
# key: object_name → value: (data, content_type, size, mtime, cached_at)
_avatar_cache: dict = {}
_AVATAR_CACHE_TTL = 1800  # 30 分钟——头像极少变动，TTL 可以很长


def _cache_key(object_name: str) -> str:
    return object_name


def _cache_get(object_name: str):
    """命中返回 (data, content_type, size, etag)，否则返回 None。"""
    entry = _avatar_cache.get(_cache_key(object_name))
    if entry is None:
        return None
    _data, ctype, size, _mtime, cached_at = entry
    if time.time() - cached_at > _AVATAR_CACHE_TTL:
        _avatar_cache.pop(_cache_key(object_name), None)
        return None
    etag = hashlib.md5(_data).hexdigest()
    return _data, ctype, size, etag


def _cache_set(object_name: str, data: bytes, content_type: str, size: int):
    _avatar_cache[_cache_key(object_name)] = (data, content_type, size, time.time(), time.time())


def _cache_invalidate(object_name: str):
    _avatar_cache.pop(_cache_key(object_name), None)


def get_minio_client() -> Minio:
    """获取全局单例 MinIO 客户端。"""
    global _client
    if _client is None:
        _client = Minio(
            endpoint=settings.MINIO_ENDPOINT,
            access_key=settings.MINIO_ACCESS_KEY,
            secret_key=settings.MINIO_SECRET_KEY,
            secure=settings.MINIO_SECURE,
        )
        _ensure_bucket(_client)
    return _client


def _ensure_bucket(client: Minio) -> None:
    """确保目标 bucket 存在且可公开访问。"""
    bucket = settings.MINIO_BUCKET
    found = client.bucket_exists(bucket)
    if not found:
        client.make_bucket(bucket)
        # 设 public-read 策略，允许免签名直接下载
        policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {"AWS": ["*"]},
                    "Action": ["s3:GetObject"],
                    "Resource": [f"arn:aws:s3:::{bucket}/*"],
                },
            ],
        }
        import json

        client.set_bucket_policy(bucket, json.dumps(policy))


def upload_avatar(file_bytes: bytes, filename: str, content_type: str) -> str:
    """上传头像到 MinIO，返回 object_name（如 ``abc123.jpg``）。

    调用方应把返回值存入 User.avatar_url 字段，
    前端通过 ``GET /api/auth/avatar-file/{object_name}`` 获取图片。
    """
    client = get_minio_client()
    bucket = settings.MINIO_BUCKET

    # 生成唯一文件名：uuid + 原始扩展名
    ext = ""
    if "." in (filename or ""):
        ext = filename.rsplit(".", 1)[-1].lower()
        if ext not in ("jpg", "jpeg", "png", "gif", "webp", "bmp"):
            ext = "jpg"
    else:
        ext = "jpg"
    object_name = f"{uuid.uuid4().hex}.{ext}"

    from io import BytesIO

    client.put_object(
        bucket_name=bucket,
        object_name=object_name,
        data=BytesIO(file_bytes),
        length=len(file_bytes),
        content_type=content_type,
    )

    return object_name


def delete_avatar(object_name: str) -> None:
    """从 MinIO 中删除指定头像文件并清除缓存（静默失败，不存在也不报错）。"""
    if not object_name:
        return
    _cache_invalidate(object_name)
    client = get_minio_client()
    try:
        client.remove_object(settings.MINIO_BUCKET, object_name)
    except S3Error:
        pass


def get_avatar_stream(object_name: str) -> tuple:
    """从缓存或 MinIO 获取头像文件流。

    返回 (data, content_type, size, etag)。
    etag 用于 HTTP 条件请求（If-None-Match → 304）。
    """
    if not object_name:
        return None, None, 0, None

    # 1) 先查内存缓存
    cached = _cache_get(object_name)
    if cached is not None:
        return cached

    # 2) 缓存未命中 → 从 MinIO 拉取
    client = get_minio_client()
    try:
        stat = client.stat_object(settings.MINIO_BUCKET, object_name)
        response = client.get_object(settings.MINIO_BUCKET, object_name)
        data = response.read()
        response.close()
        response.release_conn()

        content_type = stat.content_type or "image/jpeg"
        # 加入缓存
        _cache_set(object_name, data, content_type, stat.size or 0)
        etag = hashlib.md5(data).hexdigest()
        return data, content_type, stat.size or 0, etag
    except S3Error:
        return None, None, 0, None
