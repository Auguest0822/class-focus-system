"""
学生侧接口:加入课堂、上传使用记录、查询自己的记录。
"""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.deps import get_current_user, require_role
from app.models import AppUsage, Classroom, ClassroomMember, ClassroomReport, User
from app.schemas import (
    ApiResponse,
    AppUsageBatch,
    AppUsageInfo,
    ClassroomInfo,
    ClassroomJoin,
    PhaseInfo,
)
from app.utils.phase import calculate_phase

router = APIRouter(prefix="/api/student", tags=["学生"])


@router.post(
    "/classrooms/join",
    summary="加入课堂",
    description="学生通过 6 位课堂加入码加入某个课堂,重复提交不会报错,直接返回已加入的课堂信息。",
    response_model=ApiResponse[ClassroomInfo],
)
def join_classroom(
    body: ClassroomJoin,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("student")),
):
    # 课堂码做一次大写规范化
    classroom = db.query(Classroom).filter(Classroom.code == body.code.upper()).first()
    if not classroom:
        raise HTTPException(status_code=404, detail="课堂码无效")

    existing = (
        db.query(ClassroomMember)
        .filter(
            ClassroomMember.classroom_id == classroom.id,
            ClassroomMember.student_id == current_user.id,
        )
        .first()
    )
    # 没加过的才插入
    if not existing:
        db.add(ClassroomMember(classroom_id=classroom.id, student_id=current_user.id))
        db.commit()

    return ApiResponse(
        code=0, message="加入成功", data=ClassroomInfo.model_validate(classroom)
    )


@router.get(
    "/classrooms",
    summary="我加入的课堂",
    description="返回当前学生已加入的全部课堂列表,按创建时间倒序。",
    response_model=ApiResponse[list[ClassroomInfo]],
)
def my_classrooms(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("student")),
):
    items = (
        db.query(Classroom)
        .join(ClassroomMember, ClassroomMember.classroom_id == Classroom.id)
        .filter(ClassroomMember.student_id == current_user.id)
        .order_by(Classroom.created_at.desc())
        .all()
    )
    result = []
    for c in items:
        info = ClassroomInfo.model_validate(c)
        # 附加老师信息
        teacher = db.query(User).filter(User.id == c.teacher_id).first()
        if teacher:
            info.teacher_name = teacher.nickname or teacher.name
            info.teacher_avatar_url = teacher.avatar_url
        result.append(info)
    return ApiResponse(
        code=0, message="ok", data=result
    )


@router.post(
    "/usages",
    summary="批量上传使用记录",
    description="上传本学生在某课堂的应用使用记录(秒)。"
    "上传成功后会清空该课堂已生成的旧报告,以便老师下次访问时重新生成最新结果。",
    response_model=ApiResponse[int],
)
def upload_usage_records(
    body: AppUsageBatch,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("student")),
):
    classroom: Optional[Classroom] = (
        db.query(Classroom).filter(Classroom.id == body.classroom_id).first()
    )
    if not classroom:
        raise HTTPException(status_code=404, detail="课堂不存在")

    # 必须是已加入该课堂的学生才能上传
    member = (
        db.query(ClassroomMember)
        .filter(
            ClassroomMember.classroom_id == body.classroom_id,
            ClassroomMember.student_id == current_user.id,
        )
        .first()
    )
    if not member:
        raise HTTPException(status_code=403, detail="未加入该课堂")

    inserted = 0
    for record in body.records: #逐条插入
        db.add(
            AppUsage(
                classroom_id=body.classroom_id,
                student_id=current_user.id,
                app_package=record.app_package,
                app_name=record.app_name,
                category=record.category,
                usage_seconds=record.usage_seconds,
                start_time=record.start_time,
                end_time=record.end_time,
            )
        )
        inserted += 1
    db.commit()

    # 删除该课堂已有的旧报告,让后续查询时自动重新生成
    db.query(ClassroomReport).filter(
        ClassroomReport.classroom_id == body.classroom_id
    ).delete()
    db.commit()

    return ApiResponse(code=0, message="上传成功", data=inserted)


@router.get(
    "/classrooms/{classroom_id}/usages",
    summary="查询本人使用记录",
    description="查询当前学生在指定课堂中自己上传过的使用记录。",
    response_model=ApiResponse[list[AppUsageInfo]],
)
def my_usage_in_classroom(
    classroom_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("student")),
):
    records = (
        db.query(AppUsage)
        .filter(
            AppUsage.classroom_id == classroom_id,
            AppUsage.student_id == current_user.id,
        )
        .order_by(AppUsage.created_at.desc())
        .all()
    )
    return ApiResponse(
        code=0,
        message="ok",
        data=[AppUsageInfo.model_validate(r) for r in records],
    )


@router.get(
    "/classrooms/{classroom_id}/phase",
    summary="查询课堂倒计时阶段(学生端)",
    description="学生查询其已加入课堂的当前阶段与剩余秒数。"
    "适合每 3-5 秒轮询一次，实现与老师端同步倒计时。",
    response_model=ApiResponse[PhaseInfo],
)
def get_classroom_phase_student(
    classroom_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("student")),
):
    # 验证学生已加入
    member = (
        db.query(ClassroomMember)
        .filter(
            ClassroomMember.classroom_id == classroom_id,
            ClassroomMember.student_id == current_user.id,
        )
        .first()
    )
    if not member:
        raise HTTPException(status_code=403, detail="未加入该课堂")

    classroom = db.query(Classroom).filter(Classroom.id == classroom_id).first()
    if not classroom:
        raise HTTPException(status_code=404, detail="课堂不存在")

    phase_data = calculate_phase(classroom)

    # 超时自动结束
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
