"""
老师侧接口:课堂管理、成员查询、课堂报告生成。
"""
import json
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.deps import get_current_user, require_role
from app.models import AppUsage, Classroom, ClassroomMember, ClassroomReport, User
from app.schemas import (
    ApiResponse,
    ClassroomCreate,
    ClassroomInCourse,
    ClassroomInfo,
    ClassroomReportInfo,
    CourseGroupInfo,
    PhaseInfo,
    StudentSummary,
)
from app.utils.codegen import generate_classroom_code
from app.utils.phase import calculate_phase

router = APIRouter(prefix="/api/teacher", tags=["老师"])


# ─────────────────────────── 工具函数 ───────────────────────────
def _serialize_report(report: ClassroomReport) -> ClassroomReportInfo:
    """把数据库里的 ``ClassroomReport`` 转换成响应体对象。"""
    return ClassroomReportInfo.model_validate(report)


# ─────────────────────────── 接口 ───────────────────────────
@router.get(
    "/courses",
    summary="按课程分组的课堂列表",
    description="返回当前老师创建的所有课堂,按 course_no / course_name 聚合分组,"
    "方便前端做 '课程 → 课次' 两层页面结构。",
    response_model=ApiResponse[list[CourseGroupInfo]],
)
def list_courses(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("teacher")),
):
    classrooms = (
        db.query(Classroom)
        .filter(Classroom.teacher_id == current_user.id)
        .order_by(
            Classroom.course_no.asc(),
            Classroom.created_at.asc(),
        )
        .all()
    )

    # 按 (course_no, course_name) 分组
    groups: dict[tuple[str, str], list[Classroom]] = {}
    for c in classrooms:
        key = (c.course_no or "", c.course_name or "")
        groups.setdefault(key, []).append(c)

    result: list[CourseGroupInfo] = []
    for (course_no, course_name), items in groups.items():
        result.append(
            CourseGroupInfo(
                course_no=course_no,
                course_name=course_name,
                lesson_count=len(items),
                classrooms=[
                    ClassroomInCourse(
                        id=c.id,
                        lesson_name=c.lesson_name or "",
                        code=c.code,
                        duration_minutes=c.duration_minutes,
                        focus1_minutes=c.focus1_minutes or 45,
                        break_minutes=c.break_minutes or 5,
                        focus2_minutes=c.focus2_minutes or 45,
                        status=c.status,
                        scheduled_start_at=c.scheduled_start_at,
                        started_at=c.started_at,
                        ended_at=c.ended_at,
                    )
                    for c in items
                ],
            )
        )

    return ApiResponse(code=0, message="ok", data=result)


@router.post(
    "/classrooms",
    summary="创建课堂",
    description="由老师创建一个新的课堂。传入课号 course_no、课程名称 course_name、"
    "课次名 lesson_name;系统会自动生成 6 位课堂加入码。",
    response_model=ApiResponse[ClassroomInfo],
)
def create_classroom(
    body: ClassroomCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("teacher")),
):
    # 最多重试 5 次生成不重复的加入码
    code: str = ""
    for _ in range(5):
        code = generate_classroom_code()
        exists = db.query(Classroom).filter(Classroom.code == code).first()
        if not exists:
            break
    else:
        raise HTTPException(status_code=500, detail="生成课堂码失败,请重试")

    # 课号不能为空
    course_no = (body.course_no or "").strip()
    if not course_no:
        raise HTTPException(status_code=422, detail="课号不能为空")

    # 课号 → 课程名字一致性校验：一个课号只能对应一个课程名字
    existing = (
        db.query(Classroom)
        .filter(Classroom.course_no == course_no)
        .first()
    )
    if existing and (existing.course_name or "").strip() != body.course_name.strip():
        raise HTTPException(
            status_code=422,
            detail=f"课号 {course_no} 已对应课程「{existing.course_name}」，"
                   f"与当前输入的「{body.course_name}」不一致",
        )

    classroom = Classroom(
        teacher_id=current_user.id,
        course_no=course_no,
        course_name=body.course_name.strip(),
        lesson_name=body.lesson_name,
        code=code,
        duration_minutes=body.duration_minutes or 45,
        focus1_minutes=body.focus1_minutes or 45,
        break_minutes=body.break_minutes or 5,
        focus2_minutes=body.focus2_minutes or 45,
        status="waiting",
        scheduled_start_at=body.scheduled_start_at,
    )
    db.add(classroom)
    db.commit()
    db.refresh(classroom)
    return ApiResponse(
        code=0, message="创建成功", data=ClassroomInfo.model_validate(classroom)
    )


@router.post(
    "/classrooms/{classroom_id}/start",
    summary="开始课堂",
    description="把课堂状态切换为进行中,并记录开始时间。",
    response_model=ApiResponse[ClassroomInfo],
)
def start_classroom(
    classroom_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("teacher")),
):
    classroom = (
        db.query(Classroom)
        .filter(
            Classroom.id == classroom_id,
            Classroom.teacher_id == current_user.id,
        )
        .first()
    )
    if not classroom:
        raise HTTPException(status_code=404, detail="课堂不存在")

    classroom.status = "running"
    classroom.started_at = datetime.now()
    db.commit()
    db.refresh(classroom)
    return ApiResponse(
        code=0, message="已开始", data=ClassroomInfo.model_validate(classroom)
    )


@router.post(
    "/classrooms/{classroom_id}/end",
    summary="结束课堂",
    description="把课堂状态切换为已结束,并记录结束时间。",
    response_model=ApiResponse[ClassroomInfo],
)
def end_classroom(
    classroom_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("teacher")),
):
    classroom = (
        db.query(Classroom)
        .filter(
            Classroom.id == classroom_id,
            Classroom.teacher_id == current_user.id,
        )
        .first()
    )
    if not classroom:
        raise HTTPException(status_code=404, detail="课堂不存在")

    classroom.status = "finished"
    classroom.ended_at = datetime.now()
    db.commit()
    db.refresh(classroom)
    return ApiResponse(
        code=0, message="已结束", data=ClassroomInfo.model_validate(classroom)
    )


@router.get(
    "/classrooms/{classroom_id}/phase",
    summary="查询课堂倒计时阶段",
    description="返回课堂当前所处的阶段（focus1 / break / focus2 / finished）、"
    "剩余秒数与阶段总时长。如果已超过总时长，自动将课堂标记为已结束。"
    "前端每 3-5 秒轮询一次即可实现多端同步倒计时。",
    response_model=ApiResponse[PhaseInfo],
)
def get_classroom_phase(
    classroom_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("teacher")),
):
    classroom = (
        db.query(Classroom)
        .filter(
            Classroom.id == classroom_id,
            Classroom.teacher_id == current_user.id,
        )
        .first()
    )
    if not classroom:
        raise HTTPException(status_code=404, detail="课堂不存在")

    phase_data = calculate_phase(classroom)

    # 超时自动结束：把 DB 状态同步为 finished
    if phase_data.pop("auto_finish", False):
        classroom.status = "finished"
        classroom.ended_at = datetime.now()
        db.commit()
        db.refresh(classroom)

    return ApiResponse(
        code=0,
        message="ok",
        data=PhaseInfo(
            phase=phase_data["phase"],
            phase_name=phase_data["phase_name"],
            remaining_seconds=phase_data["remaining_seconds"],
            total_phase_seconds=phase_data["total_phase_seconds"],
            classroom_status=classroom.status,
            server_time=phase_data["server_time"],
            focus1_minutes=classroom.focus1_minutes or 45,
            break_minutes=classroom.break_minutes or 5,
            focus2_minutes=classroom.focus2_minutes or 45,
        ),
    )


@router.get(
    "/classrooms/{classroom_id}/members",
    summary="查询成员加入情况",
    description="返回已加入该课堂的学生列表以及每人的使用情况(总秒数 + 高频应用)。",
    response_model=ApiResponse[list[StudentSummary]],
)
def classroom_members(
    classroom_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("teacher")),
):
    classroom = (
        db.query(Classroom)
        .filter(
            Classroom.id == classroom_id,
            Classroom.teacher_id == current_user.id,
        )
        .first()
    )
    if not classroom:
        raise HTTPException(status_code=404, detail="课堂不存在")

    # 查出所有学生成员及其用户资料
    members = (
        db.query(ClassroomMember, User)
        .join(User, ClassroomMember.student_id == User.id)
        .filter(ClassroomMember.classroom_id == classroom_id)
        .all()
    )

    # 对每个学生聚合出总秒数和高频应用
    results: list[StudentSummary] = []
    for _, user in members:
        records = (
            db.query(AppUsage)
            .filter(
                AppUsage.classroom_id == classroom_id,
                AppUsage.student_id == user.id,
            )
            .all()
        )
        total = sum(r.usage_seconds for r in records)
        app_agg: dict[str, int] = {}
        for r in records:
            key = r.app_name or r.app_package
            app_agg[key] = app_agg.get(key, 0) + r.usage_seconds
        top_apps = sorted(app_agg.items(), key=lambda x: x[1], reverse=True)[:5]

        results.append(
            StudentSummary(
                student_id=user.id,
                student_name=user.name,
                student_no=user.student_no,
                total_seconds=total,
                top_apps=[{"app": a, "seconds": s} for a, s in top_apps],
            )
        )
    return ApiResponse(code=0, message="ok", data=results)


@router.get(
    "/classrooms/{classroom_id}/report",
    summary="生成 / 查询课堂报告",
    description="返回该课堂的整体专注度评分、高频应用以及建议文案。"
    "尚未生成报告时系统会基于现有使用记录实时生成一份。",
    response_model=ApiResponse[ClassroomReportInfo],
)
def get_classroom_report(
    classroom_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("teacher")),
):
    classroom = (
        db.query(Classroom)
        .filter(
            Classroom.id == classroom_id,
            Classroom.teacher_id == current_user.id,
        )
        .first()
    )
    if not classroom:
        raise HTTPException(status_code=404, detail="课堂不存在")

    report = (
        db.query(ClassroomReport)
        .filter(ClassroomReport.classroom_id == classroom_id)
        .first()
    )
    if not report:
        report = _generate_report(db, classroom)
    return ApiResponse(code=0, message="ok", data=_serialize_report(report))


# ─────────────────────────── 报告生成逻辑 ───────────────────────────
def _generate_report(db: Session, classroom: Classroom) -> ClassroomReport:
    """根据课堂内的 App 使用记录生成一份报告,并写入数据库。"""

    # 1) 成员总数
    member_count = (
        db.query(func.count(func.distinct(ClassroomMember.student_id)))
        .filter(ClassroomMember.classroom_id == classroom.id)
        .scalar()
        or 0
    )

    # 2) 按学生聚合使用秒数
    rows = (
        db.query(
            AppUsage.student_id,
            func.sum(AppUsage.usage_seconds).label("sec"),
        )
        .filter(AppUsage.classroom_id == classroom.id)
        .group_by(AppUsage.student_id)
        .all()
    )
    total_seconds = sum(int(r.sec or 0) for r in rows)
    avg = (total_seconds / member_count) if member_count else 0.0

    # 3) 按应用聚合,取前 10 名
    app_rows = (
        db.query(
            AppUsage.app_name,
            AppUsage.app_package,
            func.sum(AppUsage.usage_seconds).label("sec"),
        )
        .filter(AppUsage.classroom_id == classroom.id)
        .group_by(AppUsage.app_package, AppUsage.app_name)
        .order_by(func.sum(AppUsage.usage_seconds).desc())
        .limit(10)
        .all()
    )
    top_apps_list = [
        {
            "app": (name or pkg),
            "package": pkg,
            "seconds": int(sec or 0),
        }
        for name, pkg, sec in app_rows
    ]

    # 4) 简单的专注度评分:人均使用越久分数越低
    baseline = max(avg, 1)
    focus_score = max(0.0, 100.0 - (avg / baseline) * 50) if avg else 100.0
    focus_score = round(focus_score, 2)

    # 5) 简单的规则化建议
    suggestions: list[str] = []
    if avg > 300:
        suggestions.append("平均使用手机时间较长,建议提醒学生集中注意力")
    if top_apps_list and top_apps_list[0]["seconds"] > 600:
        suggestions.append(f"高频应用: {top_apps_list[0]['app']},可考虑限制使用")
    if member_count == 0:
        suggestions.append("本课堂暂无学生加入")
    if not suggestions:
        suggestions.append("课堂专注度良好")

    report = ClassroomReport(
        classroom_id=classroom.id,
        total_students=member_count,
        average_usage_seconds=round(avg, 2),
        top_apps=json.dumps(top_apps_list, ensure_ascii=False),
        focus_score=focus_score,
        suggestions="; ".join(suggestions),
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return report
