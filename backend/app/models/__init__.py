"""
models 模块导出入口,集中导出所有模型类,避免外部直接 ``from app.models.models import ...``
"""
from app.models.models import (
    AppUsage,
    Classroom,
    ClassroomMember,
    ClassroomReport,
    User,
)

__all__ = ["User", "Classroom", "ClassroomMember", "AppUsage", "ClassroomReport"]
