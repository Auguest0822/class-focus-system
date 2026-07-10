"""
请求/响应 Pydantic 模型(类似 Spring 的 DTO / @RequestBody 类)

这些模型同时承担:
- 请求体的类型校验与默认值;
- 自动生成 OpenAPI / Swagger 的字段说明;
- 将 SQLAlchemy 的实体对象序列化为 JSON 响应。
"""
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


# ─────────────────────────── 认证相关 ───────────────────────────
class LoginRequest(BaseModel):
    """登录请求体。"""

    account: str = Field(description="学号 或 工号")
    password: str = Field(description="登录密码")
    role: Optional[str] = Field(default=None, description="角色:teacher / student")


class RegisterRequest(BaseModel):
    """注册请求体。"""

    password: str = Field(description="登录密码")
    role: str = Field(description="角色:teacher 或 student")
    name: str = Field(description="真实姓名")
    student_no: Optional[str] = Field(default=None, description="学号(role=student 时必填)")
    teacher_no: Optional[str] = Field(default=None, description="工号(role=teacher 时必填)")


class TokenResponse(BaseModel):
    """登录 / 注册成功后的 token 响应。"""

    access_token: str = Field(
        description="JWT 访问令牌,后续接口在请求头中携带 Authorization: Bearer <token>"
    )
    token_type: str = Field(default="bearer", description="令牌类型,固定为 bearer")
    user_id: int = Field(description="用户 ID")
    role: str = Field(description="角色:teacher / student")
    name: str = Field(description="真实姓名")


class UserInfo(BaseModel):
    """当前登录用户信息。"""

    model_config = ConfigDict(from_attributes=True)

    id: int = Field(description="用户 ID")
    role: str = Field(description="角色")
    name: str = Field(description="真实姓名")
    student_no: Optional[str] = Field(default=None, description="学号")
    teacher_no: Optional[str] = Field(default=None, description="工号")
    created_at: Optional[datetime] = Field(default=None, description="注册时间")


# ─────────────────────────── 课堂相关 ───────────────────────────
class ClassroomCreate(BaseModel):
    """创建课堂时的请求体。

    前端以 "课程 → 课次" 两层结构为主,所以要求给出课号、课程名、课次名。
    """

    course_no: str = Field(description="课号,例如 100001;同一课程的多节课相同")
    course_name: str = Field(description="课程名称,例如 高等数学")
    lesson_name: str = Field(description="课次名,例如 第 1 次课")
    duration_minutes: int = Field(default=45, description="课堂时长(分钟)")
    focus1_minutes: int = Field(default=45, description="第一专注段时长(分钟)")
    break_minutes: int = Field(default=5, description="课间休息时长(分钟)")
    focus2_minutes: int = Field(default=45, description="第二专注段时长(分钟)")
    scheduled_start_at: Optional[datetime] = Field(
        default=None,
        description="(可选)计划开课时间,ISO 8601,例如 2026-07-06T08:00:00",
    )

    @field_validator("scheduled_start_at", mode="before")
    @classmethod
    def _empty_str_to_none(cls, v):
        """前端传空字符串时转为 None,避免 Pydantic datetime 解析报 422"""
        if isinstance(v, str) and not v.strip():
            return None
        return v


class ClassroomInfo(BaseModel):
    """课堂信息响应体(支持从 Classroom 实体直接转换)。"""

    model_config = ConfigDict(from_attributes=True)

    id: int = Field(description="课堂 ID")
    teacher_id: int = Field(description="创建该课堂的老师 ID")
    course_no: str = Field(description="课号")
    course_name: str = Field(description="课程名称")
    lesson_name: str = Field(description="课次名")
    code: str = Field(description="课堂加入码(6 位)")
    duration_minutes: int = Field(description="课堂时长(分钟)")
    focus1_minutes: int = Field(default=45, description="第一专注段时长(分钟)")
    break_minutes: int = Field(default=5, description="课间休息时长(分钟)")
    focus2_minutes: int = Field(default=45, description="第二专注段时长(分钟)")
    status: str = Field(description="课堂状态:waiting(未开始)/running(进行中)/finished(已结束)")
    scheduled_start_at: Optional[datetime] = Field(default=None, description="计划开课时间")
    started_at: Optional[datetime] = Field(default=None, description="实际开始时间")
    ended_at: Optional[datetime] = Field(default=None, description="实际结束时间")
    created_at: Optional[datetime] = Field(default=None, description="创建时间")


# ─────────────────────────── 按课程分组的列表 ───────────────────────────
class ClassroomInCourse(BaseModel):
    """在课程分组视图中,单节课次的精简信息。"""

    id: int = Field(description="课堂 ID")
    lesson_name: str = Field(description="课次名")
    code: str = Field(description="课堂加入码")
    duration_minutes: int = Field(description="课堂时长(分钟)")
    focus1_minutes: int = Field(default=45, description="第一专注段时长(分钟)")
    break_minutes: int = Field(default=5, description="课间休息时长(分钟)")
    focus2_minutes: int = Field(default=45, description="第二专注段时长(分钟)")
    status: str = Field(description="课堂状态:waiting/running/finished")
    scheduled_start_at: Optional[datetime] = Field(default=None, description="计划开课时间")
    started_at: Optional[datetime] = Field(default=None, description="实际开始时间")
    ended_at: Optional[datetime] = Field(default=None, description="实际结束时间")


class CourseGroupInfo(BaseModel):
    """按课程分组的结果体。"""

    course_no: str = Field(description="课号")
    course_name: str = Field(description="课程名称")
    lesson_count: int = Field(description="该课程下已创建的课次数量")
    classrooms: List[ClassroomInCourse] = Field(description="课次列表")


class ClassroomJoin(BaseModel):
    """学生加入课堂的请求体。"""

    code: str = Field(description="课堂加入码(6 位,不区分大小写)")


# ─────────────────────────── App 使用记录 ───────────────────────────
class AppUsageCreate(BaseModel):
    """单条 App 使用记录。"""

    app_package: str = Field(description="应用包名,例如 com.tencent.mm")
    app_name: Optional[str] = Field(default=None, description="应用显示名,例如 微信")
    usage_seconds: int = Field(description="在课堂中使用该应用的秒数")
    start_time: Optional[datetime] = Field(default=None, description="开始使用时间(可选)")
    end_time: Optional[datetime] = Field(default=None, description="结束使用时间(可选)")


class AppUsageBatch(BaseModel):
    """批量上传使用记录。"""

    classroom_id: int = Field(description="课堂 ID")
    records: List[AppUsageCreate] = Field(description="该课堂下的使用记录列表")


class AppUsageInfo(BaseModel):
    """App 使用记录响应体。"""

    model_config = ConfigDict(from_attributes=True)

    id: int = Field(description="记录 ID")
    classroom_id: int = Field(description="课堂 ID")
    student_id: int = Field(description="学生 ID")
    app_package: str = Field(description="应用包名")
    app_name: Optional[str] = Field(default=None, description="应用显示名")
    usage_seconds: int = Field(description="使用秒数")
    start_time: Optional[datetime] = Field(default=None, description="开始时间")
    end_time: Optional[datetime] = Field(default=None, description="结束时间")
    created_at: Optional[datetime] = Field(default=None, description="提交时间")


class StudentSummary(BaseModel):
    """学生在某课堂的使用情况摘要(仅用于接口内部结构,不直接做入参)。"""

    student_id: int = Field(description="学生 ID")
    student_name: str = Field(description="学生姓名")
    student_no: Optional[str] = Field(default=None, description="学号")
    total_seconds: int = Field(default=0, description="该学生在课堂内使用手机的总秒数")
    top_apps: List[dict] = Field(
        default_factory=list,
        description='最常使用的几个应用,例如 [{"app":"微信","seconds":120}]',
    )


class ClassroomReportInfo(BaseModel):
    """课堂报告响应体。"""

    model_config = ConfigDict(from_attributes=True)

    id: int = Field(description="报告 ID")
    classroom_id: int = Field(description="课堂 ID")
    total_students: int = Field(description="加入课堂的学生总数")
    average_usage_seconds: float = Field(description="人均使用秒数")
    top_apps: Optional[str] = Field(default=None, description="高频应用(JSON 字符串)")
    focus_score: float = Field(description="专注度评分,0-100,越高越专注")
    suggestions: Optional[str] = Field(default=None, description="系统生成的课堂建议")
    generated_at: Optional[datetime] = Field(default=None, description="报告生成时间")


# ─────────────────────────── 课堂阶段(倒计时) ───────────────────────────
class PhaseInfo(BaseModel):
    """课堂阶段信息,由 phase 端点返回给老师端和学生端。

    所有客户端向后端轮询此数据,实现多端同步倒计时。
    """

    phase: str = Field(description="当前阶段: waiting / focus1 / break / focus2 / finished")
    phase_name: str = Field(description="阶段中文名: 未开始 / 第一专注段 / 课间休息 / 第二专注段 / 已结束")
    remaining_seconds: int = Field(description="当前阶段剩余秒数,0 表示阶段已结束")
    total_phase_seconds: int = Field(description="当前阶段总秒数")
    classroom_status: str = Field(description="课堂状态: waiting / running / finished")
    server_time: float = Field(description="服务器当前 Unix 时间戳(秒),前端用于本地倒计时校准")
    focus1_minutes: int = Field(description="第一专注段时长(分钟)")
    break_minutes: int = Field(description="课间休息时长(分钟)")
    focus2_minutes: int = Field(description="第二专注段时长(分钟)")


# ─────────────────────────── 统一响应包装 ───────────────────────────
class ApiResponse[T](BaseModel):
    """所有接口统一使用的响应体包装。

    - ``code``: 业务状态码,``0`` 表示成功,其余表示错误。
    - ``message``: 对业务状态的文字说明。
    - ``data``: 实际返回的业务数据,可以是对象、列表或空。
    """
# Field(...)	Pydantic 提供的字段配置函数
    code: int = Field(default=0, description="业务状态码,0 表示成功")
    message: str = Field(default="ok", description="业务状态的文字说明")
    data: Optional[T] = Field(default=None, description="返回的业务数据对象 / 数组")
