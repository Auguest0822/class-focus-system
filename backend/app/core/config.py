"""
核心配置

使用 pydantic-settings 从环境变量(或 `.env` 文件)中读取配置,
并通过 `DATABASE_URL` 属性拼出 SQLAlchemy 需要的数据库 URL。

等价于 Spring Boot 中 `@ConfigurationProperties` + `application.yml` 的组合。
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    全局配置类。字段值默认从环境变量中读取,`.env` 文件的优先级更高。
    ① 系统环境变量   (最高)
        ↓
    ② .env 文件
        ↓
    ③ config.py 字段上的 = 默认值    (最低 / 兜底)
    两者配合、互不冲突 — .env 覆盖 config.py 的默认值 。
    """

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # ─── MySQL ───────────────────────────────────────────────
    MYSQL_HOST: str = "127.0.0.1"
    MYSQL_PORT: int = 3306
    MYSQL_USER: str = "root"
    MYSQL_PASSWORD: str = "1234"
    MYSQL_DATABASE: str = "classroom_focus"

    # ─── JWT ─────────────────────────────────────────────────
    # 签发 JWT 的密钥,生产环境务必修改并保证不在代码仓库中明文泄露。
    SECRET_KEY: str = "classroom-focus-secret-key-change-me-please"
    ALGORITHM: str = "HS256"
    # token 有效期(分钟)
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24

    # ─── 应用服务 ────────────────────────────────────────────
    APP_HOST: str = "0.0.0.0"
    APP_PORT: int = 8000

    @property
    def DATABASE_URL(self) -> str:
        """组装 SQLAlchemy 用的数据库 URL。

        使用 pymysql 驱动:mysql+pymysql://user:pass@host:port/dbname
        等价于 JDBC 的 jdbc:mysql://user:pass@host:port/dbname
        """
        return (
            f"mysql+pymysql://{self.MYSQL_USER}:{self.MYSQL_PASSWORD}"
            f"@{self.MYSQL_HOST}:{self.MYSQL_PORT}/{self.MYSQL_DATABASE}"
        )


settings = Settings()
