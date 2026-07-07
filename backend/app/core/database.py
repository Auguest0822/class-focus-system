"""
数据库核心

- `engine`:SQLAlchemy 连接池(类似于 Spring 的 DataSource + HikariCP)。
- `SessionLocal`:session 工厂,负责每次请求打开/关闭一个数据库会话。
- `Base`:声明式模型的基类。所有 ``@Entity`` 风格的类都继承它,
  ``Base.metadata.create_all(bind=engine)`` 会把它们翻译为 ``CREATE TABLE``。
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.core.config import settings

# ─────────────────────────── 连接池 ───────────────────────────
# pool_pre_ping=True: 每次从连接池取出连接前执行一次 SELECT 1 的轻量检查,
#                    如果连接已经被 MySQL 因 wait_timeout 断开,会透明地重建连接,
#                    这是避免 "MySQL 八小时断连" 的最常见做法。
# pool_recycle=3600 : 连接在池中最多存活 3600 秒就被回收。
# echo=False        : 关闭 SQL 日志(想调试可以改成 True)。
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    pool_recycle=3600,
    pool_size=20,
    max_overflow=10,
    echo=False,
)

# ─────────────────────────── Session 工厂 ───────────────────────────
# autocommit=False : 让事务显式地由我们 commit/rollback,与 JPA 类似。
# autoflush=False : 不自动把内存里的改动刷到数据库,以便我们显式控制。
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


# ─────────────────────────── 声明式模型基类 ───────────────────────────
# SQLAlchemy 2.x 推荐用 DeclarativeBase;这里只是声明一次即可。
class Base(DeclarativeBase):
    """所有模型类的父类。"""
    pass


# ─────────────────────────── 依赖注入 ───────────────────────────
def get_db():
    """FastAPI 依赖:在请求开始时打开 session,请求结束后关闭。

    用法示例::

        @router.get("/...")
        def some_api(db: Session = Depends(get_db)):
            ...
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

""" FastAPI 调用 get_db()
    │
    ▼
db = SessionLocal()   ← 执行到 yield 之前
    │
    ▼
yield db              ← 把 db 交给 list_classrooms 使用
    │                      （get_db 在这里"暂停"）
    ▼
list_classrooms 执行完毕（或报错）
    │
    ▼
finally: db.close()   ← 自动恢复执行，清理资源 """