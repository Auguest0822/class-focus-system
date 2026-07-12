"""
数据库模型(类似于 JPA 的 @Entity 类)

- User            : 账号(老师 / 学生)
- Classroom       : 课堂(老师创建,有唯一 6 位加入码 code)
- ClassroomMember : 学生加入课堂的多对多中间表
- AppUsage        : 学生端上报的 App 使用记录
- ClassroomReport : 根据 AppUsage 计算得到的课堂专注报告
"""
from datetime import datetime

from sqlalchemy import (
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


class User(Base):
    """账号表。角色由 ``role`` 区分,学生用 ``student_no``,老师用 ``teacher_no`` 登录。"""

    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)                              # 主键
    password_hash = Column(String(255), nullable=False)                                      # bcrypt 哈希后存的密码
    role = Column(String(16), nullable=False, comment="teacher / student")                   # 角色
    student_no = Column(String(32), unique=True, nullable=True, index=True)                  # 学号(学生登录凭据)
    teacher_no = Column(String(32), unique=True, nullable=True, index=True)                  # 工号(老师登录凭据)
    name = Column(String(64), nullable=False)                                                # 显示名 / 真实姓名
    nickname = Column(String(64), nullable=True, comment="自定义昵称")
    avatar_url = Column(String(512), nullable=True, comment="头像 URL")
    created_at = Column(DateTime, default=datetime.now)                                      # 注册时间


class Classroom(Base):
    """课堂表。由老师创建,自动生成一个 6 位加入码(code),学生通过该码加入。"""

    __tablename__ = "classrooms"  # 对应数据库表名

    id = Column(Integer, primary_key=True, autoincrement=True)
    teacher_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)         # 创建该课堂的老师
    course_no = Column(String(32), nullable=False, index=True)                                # 课号, 例如 100001 (课程维度唯一)
    course_name = Column(String(128), nullable=False)                                         # 课程名称, 例如 高等数学
    lesson_name = Column(String(64), nullable=False)                                          # 课次名, 例如 第 1 次课
    code = Column(String(16), unique=True, nullable=False, index=True)                       # 学生加入用的唯一码
    duration_minutes = Column(Integer, nullable=False, default=45)                           # 课堂时长(分钟)
    focus1_minutes = Column(Integer, nullable=False, default=45, comment="第一专注段时长(分钟)")
    break_minutes = Column(Integer, nullable=False, default=5, comment="课间休息时长(分钟)")
    focus2_minutes = Column(Integer, nullable=False, default=45, comment="第二专注段时长(分钟)")
    status = Column(String(16), default="waiting", comment="waiting / running / finished")   # waiting:未开始,running:进行中,finished:已结束
    scheduled_start_at = Column(DateTime, nullable=True)                                      # 计划开课时间
    started_at = Column(DateTime, nullable=True)                                             # 老师点开始的时间
    ended_at = Column(DateTime, nullable=True)                                               # 老师点结束的时间
    created_at = Column(DateTime, default=datetime.now)                                      # 创建时间

    # ORM 级别的关联对象:classroom.teacher 可直接拿到 User 对象
    teacher = relationship("User", foreign_keys=[teacher_id])  # 关联到 User 表,通过 teacher_id 字段


class ClassroomMember(Base):
    """课堂成员表(多对多中间表)。一个学生不能重复加入同一个课堂。"""

    __tablename__ = "classroom_members"
    # 数据库级的唯一约束:避免同一个学生重复加入同一个课堂
    __table_args__ = (UniqueConstraint("classroom_id", "student_id", name="uq_classroom_student"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    classroom_id = Column(Integer, ForeignKey("classrooms.id"), nullable=False, index=True)
    student_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    joined_at = Column(DateTime, default=datetime.now)


class AppUsage(Base):
    """App 使用记录表。Android 学生端批量上报,一条记录是该课堂、该学生、该 App 的一次时长。"""

    __tablename__ = "app_usages"

    id = Column(Integer, primary_key=True, autoincrement=True)
    classroom_id = Column(Integer, ForeignKey("classrooms.id"), nullable=False, index=True)
    student_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    app_package = Column(String(128), nullable=False, index=True)                            # 应用包名(例如 com.tencent.mm)
    app_name = Column(String(128), nullable=True)                                            # 应用显示名(例如 微信)
    category = Column(String(32), nullable=True, comment="Android 系统分类(API 26+);null 时交后端规则兜底")
    usage_seconds = Column(Integer, nullable=False, default=0)                               # 本次记录的使用秒数
    start_time = Column(DateTime, nullable=True)                                             # 可选:本次使用起始时间
    end_time = Column(DateTime, nullable=True)                                               # 可选:本次使用结束时间
    created_at = Column(DateTime, default=datetime.now, index=True)                          # 上报时间


class ClassroomReport(Base):
    """课堂报告表。把课堂内所有学生的 App 记录汇总出人均时长、高频应用、专注评分和建议。"""

    __tablename__ = "classroom_reports"

    id = Column(Integer, primary_key=True, autoincrement=True)
    classroom_id = Column(Integer, ForeignKey("classrooms.id"), unique=True, nullable=False, index=True)
    total_students = Column(Integer, nullable=False, default=0)                              # 加入课堂的学生数
    average_usage_seconds = Column(Float, nullable=False, default=0.0)                       # 人均 App 使用秒数
    top_apps = Column(Text, nullable=True, comment="JSON 字符串")                            # 高频应用列表,存 JSON 字符串,例如 [{"app":"微信","seconds":120}]
    focus_score = Column(Float, nullable=False, default=0.0)                                 # 专注度评分(0-100,越高越好)
    suggestions = Column(Text, nullable=True)                                                # 基于结果生成的文字建议
    generated_at = Column(DateTime, default=datetime.now)                                     # 报告生成时间
