"""
认证相关接口:注册、登录、获取当前用户信息、修改个人资料、上传头像。
"""
from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from fastapi.responses import Response
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.deps import get_current_user
from app.core.security import create_access_token, hash_password, verify_password
from app.models import User
from app.schemas import (
    ApiResponse,
    LoginRequest,
    RegisterRequest,
    TokenResponse,
    UpdateProfileRequest,
    UserInfo,
)
from app.utils.minio_client import delete_avatar, get_avatar_stream, upload_avatar

router = APIRouter(prefix="/api/auth", tags=["认证"])


@router.post(
    "/register",
    summary="注册用户",
    description="注册一个新的老师或学生账号,成功后直接返回可用的 access_token。",
    response_model=ApiResponse[TokenResponse],
)
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    """参数校验 + 幂等判断 + 写入数据库。"""

    # 1) 角色必须是 teacher 或 student
    if body.role not in ("teacher", "student"):
        raise HTTPException(status_code=400, detail="角色必须为 teacher 或 student")

    # 2) 根据角色校验必填字段，并检查是否已被注册
    if body.role == "student":
        if not body.student_no or not body.student_no.strip():
            raise HTTPException(status_code=400, detail="学生注册需要填写学号")
        student_no = body.student_no.strip()
        teacher_no = None
        existing = db.query(User).filter(User.student_no == student_no).first()
        if existing:
            raise HTTPException(status_code=400, detail="该学号已注册，请直接登录")
    else:
        if not body.teacher_no or not body.teacher_no.strip():
            raise HTTPException(status_code=400, detail="老师注册需要填写工号")
        student_no = None
        teacher_no = body.teacher_no.strip()
        existing = db.query(User).filter(User.teacher_no == teacher_no).first()
        if existing:
            raise HTTPException(status_code=400, detail="该工号已注册，请直接登录")

    # 3) 新建用户(密码用 bcrypt 做哈希)
    user = User(
        password_hash=hash_password(body.password),
        role=body.role,
        name=body.name,
        student_no=student_no,
        teacher_no=teacher_no,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # 4) 签发 token 并返回
    account = student_no or teacher_no
    token = create_access_token(
        user.id,
        extra={"role": user.role, "account": account},
    )
    return ApiResponse(
        code=0,
        message="注册成功",
        data=TokenResponse(
            access_token=token,
            user_id=user.id,
            role=user.role,
            name=user.name,
            nickname=user.nickname,
            avatar_url=user.avatar_url,
            student_no=student_no,
            teacher_no=teacher_no,
        ),
    )


@router.post(
    "/login",
    summary="用户登录",
    description="使用学号/工号和密码登录,登录成功后返回 JWT access_token。"
    "后续接口需要在请求头中携带 `Authorization: Bearer <token>`。",
    response_model=ApiResponse[TokenResponse],
)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    """根据学号或工号查找用户,校验密码,并可选校验角色。"""

    account = body.account.strip()
    if not account:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="请输入学号或工号"
        )

    # 按角色过滤或同时搜索两列
    if body.role == "student":
        user = db.query(User).filter(User.student_no == account).first()
    elif body.role == "teacher":
        user = db.query(User).filter(User.teacher_no == account).first()
    else:
        user = db.query(User).filter(
            or_(User.student_no == account, User.teacher_no == account)
        ).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="该学号/工号未注册，请检查后重试",
        )

    if not verify_password(body.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="密码错误，请重新输入",
        )

    token = create_access_token(
        user.id,
        extra={"role": user.role, "account": account},
    )
    return ApiResponse(
        code=0,
        message="登录成功",
        data=TokenResponse(
            access_token=token,
            user_id=user.id,
            role=user.role,
            name=user.name,
            nickname=user.nickname,
            avatar_url=user.avatar_url,
            student_no=user.student_no,
            teacher_no=user.teacher_no,
        ),
    )


@router.get(
    "/me",
    summary="获取当前登录用户信息",
    description="使用登录后拿到的 token 访问,返回当前用户的基本资料。",
    response_model=ApiResponse[UserInfo],
)
def get_me(current_user: User = Depends(get_current_user)):
    """依赖注入:``get_current_user`` 失败时会自动返回 401。"""
    return ApiResponse(code=0, message="ok", data=UserInfo.model_validate(current_user))


@router.put(
    "/profile",
    summary="修改个人资料",
    description="更新当前用户的昵称。传 nickname 字段即可（可选，为空不修改）。",
    response_model=ApiResponse[UserInfo],
)
def update_profile(
    body: UpdateProfileRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if body.nickname is not None:
        current_user.nickname = body.nickname.strip() or None
        db.commit()
        db.refresh(current_user)
    return ApiResponse(
        code=0, message="更新成功", data=UserInfo.model_validate(current_user)
    )


@router.post(
    "/avatar",
    summary="上传头像",
    description="上传一张图片作为头像（支持 jpg/png/gif/webp），"
    "上传成功后会删除旧头像文件并更新 avatar_url。",
    response_model=ApiResponse[UserInfo],
)
async def upload_avatar_endpoint(
    file: UploadFile = File(description="头像图片文件"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # 校验文件类型
    allowed = {"image/jpeg", "image/png", "image/gif", "image/webp", "image/bmp"}
    if file.content_type and file.content_type not in allowed:
        raise HTTPException(
            status_code=400,
            detail=f"不支持的图片格式：{file.content_type}，仅支持 jpg/png/gif/webp/bmp",
        )

    # 读取文件内容
    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=400, detail="上传的文件为空")

    max_size = 5 * 1024 * 1024  # 5MB
    if len(contents) > max_size:
        raise HTTPException(status_code=400, detail="文件大小不能超过 5MB")

    # 删除旧头像（avatar_url 现在存的是 object_name）
    if current_user.avatar_url:
        delete_avatar(current_user.avatar_url)

    # 上传新头像到 MinIO，只拿 object_name
    filename = file.filename or "avatar.jpg"
    object_name = upload_avatar(contents, filename, file.content_type or "image/jpeg")
    current_user.avatar_url = object_name
    db.commit()
    db.refresh(current_user)

    return ApiResponse(
        code=0, message="头像上传成功", data=UserInfo.model_validate(current_user)
    )


@router.get(
    "/avatar-file/{object_name}",
    summary="获取头像图片",
    description="代理 MinIO 中的头像文件。支持 ETag/If-None-Match 条件请求和浏览器缓存。",
)
def get_avatar_file(object_name: str, request: Request):
    data, content_type, size, etag = get_avatar_stream(object_name)
    if data is None:
        raise HTTPException(status_code=404, detail="头像文件不存在")

    headers = {
        # 浏览器缓存：头像极少变动，缓存 24 小时
        "Cache-Control": "public, max-age=86400, immutable",
    }
    if etag:
        headers["ETag"] = f'"{etag}"'

    # 支持条件请求：ETag 匹配时返回 304，浏览器直接用缓存
    if etag:
        if_none_match = request.headers.get("If-None-Match", "")
        if if_none_match == f'"{etag}"':
            return Response(status_code=304, headers=headers)

    return Response(content=data, media_type=content_type or "image/jpeg", headers=headers)
