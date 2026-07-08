"""
schemas 模块导出入口,集中导出所有请求 / 响应模型。
"""
from app.schemas.schemas import (
    ApiResponse,
    AppUsageBatch,
    AppUsageCreate,
    AppUsageInfo,
    ClassroomCreate,
    ClassroomInCourse,
    ClassroomInfo,
    ClassroomJoin,
    ClassroomReportInfo,
    CourseGroupInfo,
    LoginRequest,
    PhaseInfo,
    RegisterRequest,
    StudentSummary,
    TokenResponse,
    UserInfo,
)

__all__ = [
    "ApiResponse",
    "AppUsageBatch",
    "AppUsageCreate",
    "AppUsageInfo",
    "ClassroomCreate",
    "ClassroomInCourse",
    "ClassroomInfo",
    "ClassroomJoin",
    "ClassroomReportInfo",
    "CourseGroupInfo",
    "LoginRequest",
    "PhaseInfo",
    "RegisterRequest",
    "StudentSummary",
    "TokenResponse",
    "UserInfo",
]
