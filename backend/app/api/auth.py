"""
认证相关接口:注册、登录、获取当前用户信息。
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.deps import get_current_user
from app.core.security import create_access_token, hash_password, verify_password
from app.models import User
from app.schemas import ApiResponse, LoginRequest, RegisterRequest, TokenResponse, UserInfo

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

    # 2) 检查账号、学号、工号是否已被占用
    existing = (
        db.query(User)
        .filter(
            or_(
                User.username == body.username,
                User.student_no == body.student_no if body.student_no else False,
                User.teacher_no == body.teacher_no if body.teacher_no else False,
            )
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="用户名 / 学号 / 工号 已存在")

    # 3) 新建用户(密码用 bcrypt 做哈希)
    user = User(
        username=body.username,
        password_hash=hash_password(body.password),
        role=body.role,
        name=body.name,
        student_no=body.student_no,
        teacher_no=body.teacher_no,
    )
    db.add(user)
    db.commit()
    db.refresh(user)  # 重新加载,拿到数据库自动生成的 id 等字段

    # 4) 签发 token 并返回
    token = create_access_token(
        user.id,
        extra={"role": user.role, "username": user.username},
    )
    return ApiResponse(
        code=0,
        message="注册成功",
        data=TokenResponse(
            access_token=token,
            user_id=user.id,
            username=user.username,
            role=user.role,
            name=user.name,
        ),
    )


@router.post(
    "/login",
    summary="用户登录",
    description="使用账号和密码登录,登录成功后返回 JWT access_token。"
    "后续接口需要在请求头中携带 `Authorization: Bearer <token>`。",
    response_model=ApiResponse[TokenResponse],
)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    """根据账号找用户,校验密码,并可选校验角色。"""

    user = db.query(User).filter(User.username == body.username).first()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="用户名或密码错误"
        )

    # 如果请求里指定了角色,则要匹配
    if body.role and user.role != body.role:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="角色不匹配"
        )

    token = create_access_token(
        user.id,
        extra={"role": user.role, "username": user.username},
    )
    return ApiResponse(
        code=0,
        message="登录成功",
        data=TokenResponse(
            access_token=token,
            user_id=user.id,
            username=user.username,
            role=user.role,
            name=user.name,
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
