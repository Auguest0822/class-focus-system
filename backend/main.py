"""
课堂专注管理系统 - Python 后端入口

本文件负责:
1. 创建 FastAPI 根应用(类似 Spring Boot 的启动类),并配置 OpenAPI 标题/描述/标签;
2. 挂接跨域中间件(CORSMiddleware)与请求耗时中间件;
3. 在应用启动时( startup)自动建库、自动建表(Base.metadata.create_all);
4. 注册子路由(认证/老师/学生/报告);
5. 暴露根路径 "/" 与健康检查接口 "/health"。

启动命令(开发模式,文件改动自动重载):
    uvicorn main:app --reload --host 0.0.0.0 --port 8000

启动后打开 http://localhost:8000/docs 即可看到可交互的 Swagger UI。
"""
from time import perf_counter

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.api import auth, student, teacher
from app.core.config import settings
from app.core.database import Base, engine, SessionLocal
from app.schemas import ApiResponse

# ─────────────────────────── 应用实例 ───────────────────────────
app = FastAPI(
    title="课堂专注管理系统 - Python 后端",
    description=(
        "为课堂专注管理系统提供用户注册/登录、课堂管理、App 使用记录上报、"
        "课堂专注报告等 RESTful 接口。响应统一使用 `ApiResponse{code, message, data}` 封装。"
    ),
    version="1.0.0",
    contact={"name": "项目维护者"},
    license_info={"name": "MIT"},
    openapi_tags=[
        {"name": "认证", "description": "注册、登录、获取当前用户信息。"},
        {"name": "老师", "description": "老师创建并管理课堂、查看成员与课堂报告。"},
        {"name": "学生", "description": "学生通过课堂码加入课堂、上传使用记录。"},
        {"name": "报告", "description": "课堂报告查询。"},
    ],
)

# ─────────────────────────── 跨域中间件 ───────────────────────────
# 老师端 Web / 学生端 Android App 运行在不同域名/端口,因此允许所有来源、
# 所有 Header、所有方法。生产环境请把 allow_origins 改为实际的前端域名白名单。
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─────────────────────────── 请求耗时日志 ───────────────────────────
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """记录每个请求的处理耗时,并塞进响应头 X-Process-Time-MS,方便排查慢请求。"""
    start = perf_counter()
    response = await call_next(request)
    elapsed_ms = (perf_counter() - start) * 1000
    response.headers["X-Process-Time-MS"] = f"{elapsed_ms:.2f}"
    return response


# ─────────────────────────── 启动事件 ───────────────────────────
@app.on_event("startup")
def on_startup():
    """应用启动时执行。
    - 先直接连接 MySQL 创建数据库,避免 `Unknown database` 报错;
    - 再用 Base.metadata.create_all 把所有模型类翻译为 CREATE TABLE 语句,
      已经存在的表会被跳过(类似 Hibernate 的 ddl-auto=update,但不做字段变更)。
    """
    # 连接到 MySQL 实例本身(不指定数据库),保证第一次启动时也能成功
    init_engine = engine.execution_options(isolation_level="AUTOCOMMIT")
    with init_engine.connect() as conn:
        conn.execute(
            text(
                f"CREATE DATABASE IF NOT EXISTS `{settings.MYSQL_DATABASE}` "
                f"DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
            )
        )

    # 使用目标数据库的 engine 创建/确认全部表
    Base.metadata.create_all(bind=engine)

    # ── 兼容 MySQL 的增量迁移：已有表加列 ──
    # create_all 不会修改已有表结构，所以用 information_schema 检查列是否存在
    with engine.connect() as conn:
        for col_name, col_default in [
            ("focus1_minutes", 50),
            ("break_minutes", 5),
            ("focus2_minutes", 40),
        ]:
            exists = conn.execute(
                text(
                    "SELECT COUNT(*) FROM information_schema.COLUMNS "
                    "WHERE TABLE_SCHEMA = :db AND TABLE_NAME = 'classrooms' "
                    "AND COLUMN_NAME = :col"
                ),
                {"db": settings.MYSQL_DATABASE, "col": col_name},
            ).scalar()
            if not exists:
                conn.execute(
                    text(
                        f"ALTER TABLE classrooms ADD COLUMN {col_name} "
                        f"INT NOT NULL DEFAULT {col_default}"
                    )
                )
        conn.commit()


# ─────────────────────────── 注册路由 ───────────────────────────
app.include_router(auth.router)
app.include_router(teacher.router)
app.include_router(student.router)


# ─────────────────────────── 根路径 & 健康检查 ───────────────────────────
@app.get("/", summary="应用信息", description="返回应用名称与基础信息。")
def index():
    return {"name": "课堂专注管理系统 - Python 后端", "version": "1.0.0"}


@app.get("/health", summary="健康检查", description="检查应用自身以及 MySQL 数据库连接是否可用。")
def health():
    # 尝试执行一次最简单的 SQL,成功则视为数据库健康
    healthy = True
    db_info = "ok"
    try:
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))
    except Exception as exc:
        healthy = False
        db_info = f"db_error: {exc}"

    return ApiResponse(
        code=0 if healthy else 500,
        message="healthy" if healthy else "unhealthy",
        data={"app": "ok", "database": db_info},
    )
