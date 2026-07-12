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
