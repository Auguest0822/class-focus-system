"""
老师侧接口:课堂管理、成员查询、课堂报告生成与导出。
"""
import json
from datetime import datetime, timedelta
from io import BytesIO
from urllib.parse import quote

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.deps import get_current_user, require_role
from app.models import AppUsage, Classroom, ClassroomMember, ClassroomReport, User
from app.schemas import (
    ApiResponse,
    AppRankingItem,
    AppTypeUsage,
    ClassroomCreate,
    ClassroomInCourse,
    ClassroomInfo,
    ClassroomReportInfo,
    CourseGroupInfo,
    PhaseInfo,
    StudentAppUsage,
    StudentReportItem,
    StudentSummary,
)
from app.utils.codegen import generate_classroom_code
from app.utils.phase import calculate_phase

router = APIRouter(prefix="/api/teacher", tags=["老师"])


# ─────────────────────────── App 分类 ───────────────────────────
# 基于 Android 包名前缀匹配，归类到常见分心类型
APP_CATEGORY_MAP: dict[str, str] = {
    # 社交
    "com.tencent.mm": "社交",
    "com.tencent.mobileqq": "社交",
    "com.tencent.tim": "社交",
    "com.sina.weibo": "社交",
    "com.zhiliaoapp.musically": "社交",
    "com.instagram.android": "社交",
    "com.twitter.android": "社交",
    "com.facebook.katana": "社交",
    "com.facebook.orca": "社交",
    "com.snapchat.android": "社交",
    "com.discord": "社交",
    "com.skype.raider": "社交",
    "com.whatsapp": "社交",
    "com.tencent.wework": "社交",
    "com.alibaba.android.rimet": "社交",  # 钉钉
    # 游戏
    "com.tencent.tmgp": "游戏",
    "com.tencent.ig": "游戏",
    "com.netease": "游戏",
    "com.miHoYo": "游戏",
    "com.mihoyo": "游戏",
    "com.supercell": "游戏",
    "com.mojang": "游戏",
    "com.riotgames": "游戏",
    "com.activision": "游戏",
    "com.ea.": "游戏",
    "com.ubisoft": "游戏",
    "com.kiloo": "游戏",
    "com.king.": "游戏",
    # 视频
    "com.ss.android.ugc.aweme": "视频",
    "com.smile.gifmaker": "视频",
    "com.youku": "视频",
    "com.qiyi": "视频",
    "com.bilibili": "视频",
    "tv.danmaku.bili": "视频",
    "com.tencent.qqlive": "视频",
    "com.sohu.sohuvideo": "视频",
    "com.example.souqidai": "视频",
    "com.hetao": "视频",
    "com.douyu": "视频",
    "com.huya": "视频",
    # 音乐
    "com.kugou": "音乐",
    "com.netease.cloudmusic": "音乐",
    "com.tencent.qqmusic": "音乐",
    "com.spotify": "音乐",
    # 购物
    "com.taobao": "购物",
    "com.jingdong": "购物",
    "com.xunmeng.pinduoduo": "购物",
    "com.meituan": "购物",
    "com.suning": "购物",
    "com.vipshop": "购物",
    "com.alibaba.wireless": "购物",  # 闲鱼
    # 浏览器
    "com.android.chrome": "浏览器",
    "com.UCMobile": "浏览器",
    "com.ucmobile": "浏览器",
    "com.qihoo.browser": "浏览器",
    "com.tencent.mtt": "浏览器",
    "com.microsoft.emmx": "浏览器",  # Edge
    "org.mozilla.firefox": "浏览器",
    "com.opera": "浏览器",
    # 阅读/小说
    "com.zhangyue": "阅读",
    "com.qidian": "阅读",
    "com.jjwxc": "阅读",
    "com.dragonread": "阅读",
    "com.chaozh.iReader": "阅读",
    # 系统工具 (非分心，但可能被误报)
    "com.android.settings": "系统工具",
    "com.android.systemui": "系统工具",
    "com.android.launcher": "系统工具",
    "com.android.deskclock": "系统工具",
    "com.google.android": "系统工具",
}

CATEGORY_COLORS: dict[str, str] = {
    "社交": "#3b82f6",
    "游戏": "#ef4444",
    "视频": "#f97316",
    "音乐": "#8b5cf6",
    "购物": "#ec4899",
    "浏览器": "#06b6d4",
    "阅读": "#84cc16",
    "系统工具": "#6b7280",
    "其他": "#94a3b8",
}


def _classify_app(package_name: str, app_name: str = "") -> str:
    """根据包名返回 App 分类。先尝试精确匹配，再前缀匹配，兜底为 '其他'。"""
    pkg = (package_name or "").lower()
    # 精确匹配
    if pkg in APP_CATEGORY_MAP:
        return APP_CATEGORY_MAP[pkg]
    # 前缀匹配: 从长到短尝试
    keys = sorted(APP_CATEGORY_MAP.keys(), key=len, reverse=True)
    for prefix in keys:
        if pkg.startswith(prefix.lower()):
            return APP_CATEGORY_MAP[prefix]
    return "其他"


def _category_color(category: str) -> str:
    return CATEGORY_COLORS.get(category, CATEGORY_COLORS["其他"])


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
    from app.utils.redis_client import cache_delete
    cache_delete(f"members:{classroom_id}")
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
    from app.utils.redis_client import cache_delete
    cache_delete(f"members:{classroom_id}")
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

    # ── Redis 缓存：直接返回序列化的 list[dict] ──
    cache_key = f"members:{classroom_id}"
    from app.utils.redis_client import cache_get, cache_set

    cached = cache_get(cache_key)
    if cached is not None:
        # 命中的是 list[dict]，需要还原为 list[StudentSummary]
        return ApiResponse(
            code=0, message="ok",
            data=[StudentSummary(**item) for item in cached],
        )

    # 查出所有学生成员及其用户资料
    members = (
        db.query(ClassroomMember, User)
        .join(User, ClassroomMember.student_id == User.id)
        .filter(ClassroomMember.classroom_id == classroom_id)
        .all()
    )

    # 一次性批量捞出所有学生的 AppUsage，避免 N+1
    student_ids = [user.id for _, user in members]
    all_records: list[AppUsage] = []
    if student_ids:
        all_records = (
            db.query(AppUsage)
            .filter(
                AppUsage.classroom_id == classroom_id,
                AppUsage.student_id.in_(student_ids),
            )
            .all()
        )

    # 按 student_id 预分组，纯内存操作
    records_by_student: dict[int, list[AppUsage]] = {}
    for r in all_records:
        records_by_student.setdefault(r.student_id, []).append(r)

    # 对每个学生聚合出总秒数和高频应用
    results: list[StudentSummary] = []
    for member, user in members:
        records = records_by_student.get(user.id, [])
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
                nickname=user.nickname,
                avatar_url=user.avatar_url,
                joined_at=member.joined_at,
                total_seconds=total,
                top_apps=[{"app": a, "seconds": s} for a, s in top_apps],
            )
        )

    # 写入 Redis 缓存，TTL 3 秒（短于前端 5 秒轮询，保证下次轮询能看到新数据）
    cache_set(cache_key, [r.model_dump() for r in results])
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
        report, student_stats = _generate_report(db, classroom)
    else:
        student_stats = _build_student_stats(db, classroom.id)

    result = _serialize_report(report)
    result.student_stats = [
        StudentReportItem(
            student_name=s["student_name"],
            student_no=s.get("student_no"),
            nickname=s.get("nickname"),
            avatar_url=s.get("avatar_url"),
            total_seconds=s["total_seconds"],
            apps=[
                StudentAppUsage(
                    app_name=a["app_name"],
                    app_package=a["app_package"],
                    category=a.get("category"),
                    usage_seconds=a["usage_seconds"],
                )
                for a in s["apps"]
            ],
        )
        for s in student_stats
    ]

    # 动态计算 App 类型概览、排行、主要分心类型
    type_overview = _compute_app_type_overview(db, classroom.id)
    result.app_type_overview = [
        AppTypeUsage(
            category=t["category"],
            total_seconds=t["total_seconds"],
            percent=t["percent"],
        )
        for t in type_overview
    ]
    result.app_ranking = [
        AppRankingItem(
            app_name=r["app_name"],
            app_package=r["app_package"],
            total_seconds=r["total_seconds"],
            student_count=r["student_count"],
        )
        for r in _compute_app_ranking(db, classroom.id)
    ]
    result.main_distract_type = _compute_main_distract_type(type_overview)

    return ApiResponse(code=0, message="ok", data=result)


# ─────────────────────────── 报告生成逻辑 ───────────────────────────
def _generate_report(db: Session, classroom: Classroom) -> tuple[ClassroomReport, list[dict]]:
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

    # 4) 专注度评分: 基于课堂总时长计算
    # 总分心时间占课堂总时长的比例越低，专注度越高
    total_class_seconds = (
        (classroom.focus1_minutes or 45)
        + (classroom.break_minutes or 5)
        + (classroom.focus2_minutes or 45)
    ) * 60
    if total_class_seconds > 0 and avg > 0:
        focus_score = max(0.0, 100.0 - (avg / total_class_seconds) * 100)
    else:
        focus_score = 100.0
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
    student_stats = _build_student_stats(db, classroom.id)
    return report, student_stats


def _build_student_stats(db: Session, classroom_id: int) -> list[dict]:
    """按 student_id + app 聚合 app_usages 表，构建每位学生的分心明细。"""
    detail_rows = (
        db.query(
            AppUsage.student_id,
            User.name,
            User.student_no,
            User.nickname,
            User.avatar_url,
            AppUsage.app_name,
            AppUsage.app_package,
            AppUsage.category,
            func.sum(AppUsage.usage_seconds).label("sec"),
        )
        .join(User, AppUsage.student_id == User.id)
        .filter(AppUsage.classroom_id == classroom_id)
        .group_by(
            AppUsage.student_id,
            User.name,
            User.student_no,
            User.nickname,
            User.avatar_url,
            AppUsage.app_name,
            AppUsage.app_package,
            AppUsage.category,
        )
        .order_by(AppUsage.student_id, func.sum(AppUsage.usage_seconds).desc())
        .all()
    )

    student_map: dict[int, dict] = {}
    for sid, name, sno, nickname, avatar_url, app_name, app_pkg, category, sec in detail_rows:
        if sid not in student_map:
            student_map[sid] = {
                "student_name": name or sno or f"学生{sid}",
                "student_no": sno,
                "nickname": nickname,
                "avatar_url": avatar_url,
                "total_seconds": 0,
                "apps": [],
            }
        student_map[sid]["total_seconds"] += int(sec or 0)
        student_map[sid]["apps"].append({
            "app_name": app_name or app_pkg or "未知应用",
            "app_package": app_pkg or "",
            "category": category or None,
            "usage_seconds": int(sec or 0),
        })

    return sorted(
        student_map.values(),
        key=lambda x: x["total_seconds"],
        reverse=True,
    )


def _compute_app_type_overview(db: Session, classroom_id: int) -> list[dict]:
    """按 App 分类聚合所有学生的使用记录，返回各分类的时长与占比。

    优先使用 Android 系统上传的 category 字段（API 26+），
    如果为空则回退到后端硬编码的包名规则匹配。
    """
    rows = (
        db.query(
            AppUsage.app_name,
            AppUsage.app_package,
            AppUsage.category,
            func.sum(AppUsage.usage_seconds).label("sec"),
        )
        .filter(AppUsage.classroom_id == classroom_id)
        .group_by(AppUsage.app_package, AppUsage.app_name, AppUsage.category)
        .all()
    )

    category_agg: dict[str, int] = {}
    for name, pkg, stored_cat, sec in rows:
        # 优先用 Android 系统分类，空则兜底硬编码规则
        category = stored_cat or _classify_app(pkg or "", name or "")
        category_agg[category] = category_agg.get(category, 0) + int(sec or 0)

    total = sum(category_agg.values()) or 1
    result = []
    for cat in sorted(category_agg.keys()):
        seconds = category_agg[cat]
        result.append({
            "category": cat,
            "total_seconds": seconds,
            "percent": round(seconds / total * 100, 1),
        })
    # 按占比降序排列
    result.sort(key=lambda x: x["total_seconds"], reverse=True)
    return result


def _compute_app_ranking(db: Session, classroom_id: int) -> list[dict]:
    """跨所有学生聚合各 App 总使用时长排行 + 使用人数。"""
    rows = (
        db.query(
            AppUsage.app_name,
            AppUsage.app_package,
            func.sum(AppUsage.usage_seconds).label("sec"),
            func.count(func.distinct(AppUsage.student_id)).label("stu_count"),
        )
        .filter(AppUsage.classroom_id == classroom_id)
        .group_by(AppUsage.app_package, AppUsage.app_name)
        .order_by(func.sum(AppUsage.usage_seconds).desc())
        .all()
    )

    return [
        {
            "app_name": (name or pkg or "未知应用"),
            "app_package": pkg or "",
            "total_seconds": int(sec or 0),
            "student_count": int(stu_count or 0),
        }
        for name, pkg, sec, stu_count in rows
    ]


def _compute_main_distract_type(app_type_overview: list[dict]) -> str | None:
    """从类型概览中找到占比最高的分心类型（排除 '系统工具'）。"""
    distraction_types = [t for t in app_type_overview if t["category"] != "系统工具"]
    if not distraction_types:
        return None
    return max(distraction_types, key=lambda x: x["total_seconds"])["category"]


# ─────────────────────────── Excel 导出 ───────────────────────────
# 样式常量
_HEADER_FONT = Font(name="微软雅黑", bold=True, size=11, color="FFFFFF")
_HEADER_FILL = PatternFill(start_color="2563EB", end_color="2563EB", fill_type="solid")
_HEADER_ALIGN = Alignment(horizontal="center", vertical="center", wrap_text=True)
_CELL_ALIGN = Alignment(vertical="center", wrap_text=True)
_CELL_ALIGN_CENTER = Alignment(horizontal="center", vertical="center")
_THIN_BORDER = Border(
    left=Side(style="thin", color="D5E5F2"),
    right=Side(style="thin", color="D5E5F2"),
    top=Side(style="thin", color="D5E5F2"),
    bottom=Side(style="thin", color="D5E5F2"),
)
_TITLE_FONT = Font(name="微软雅黑", bold=True, size=18, color="12355B")
_SUBTITLE_FONT = Font(name="微软雅黑", bold=True, size=12, color="12355B")
_LABEL_FONT = Font(name="微软雅黑", bold=True, size=10, color="516987")
_VALUE_FONT = Font(name="微软雅黑", size=10, color="12355B")


def _style_header_row(ws, row: int, col_count: int):
    """给表头行应用统一样式。"""
    for c in range(1, col_count + 1):
        cell = ws.cell(row=row, column=c)
        cell.font = _HEADER_FONT
        cell.fill = _HEADER_FILL
        cell.alignment = _HEADER_ALIGN
        cell.border = _THIN_BORDER


def _style_data_cell(ws, row: int, col: int, center: bool = False):
    """给数据单元格应用统一样式。"""
    cell = ws.cell(row=row, column=col)
    cell.font = _VALUE_FONT
    cell.alignment = _CELL_ALIGN_CENTER if center else _CELL_ALIGN
    cell.border = _THIN_BORDER
    return cell


def _auto_width(ws, min_width: int = 10, max_width: int = 42):
    """根据内容自动调整列宽。"""
    for col_cells in ws.columns:
        col_letter = get_column_letter(col_cells[0].column)
        lengths = []
        for cell in col_cells:
            if cell.value:
                # 中文字符按 ~2 个字符宽度计算
                text = str(cell.value)
                length = sum(2 if ord(ch) > 127 else 1 for ch in text)
                lengths.append(length)
        if lengths:
            best = max(lengths) + 4  # padding
            ws.column_dimensions[col_letter].width = max(min_width, min(best, max_width))


@router.get(
    "/classrooms/{classroom_id}/report/export",
    summary="导出课堂报告为 Excel",
    description="生成该课堂的专注报告并导出为 .xlsx 文件，包含概览、学生专注统计、应用排行、类型概览四个工作表。",
)
def export_classroom_report(
    classroom_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("teacher")),
):
    # ── 权限校验 ──
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

    # ── 获取或生成报告数据 ──
    report = (
        db.query(ClassroomReport)
        .filter(ClassroomReport.classroom_id == classroom_id)
        .first()
    )
    if not report:
        report, student_stats = _generate_report(db, classroom)
    else:
        student_stats = _build_student_stats(db, classroom.id)

    type_overview = _compute_app_type_overview(db, classroom.id)
    app_ranking = _compute_app_ranking(db, classroom.id)
    main_distract = _compute_main_distract_type(type_overview)

    # ── 构建课堂时间文本 ──
    start_str = (
        classroom.scheduled_start_at.strftime("%Y-%m-%d %H:%M")
        if classroom.scheduled_start_at
        else (classroom.started_at.strftime("%Y-%m-%d %H:%M") if classroom.started_at else "未记录")
    )
    end_str = (
        classroom.ended_at.strftime("%Y-%m-%d %H:%M")
        if classroom.ended_at
        else "进行中"
    )
    total_minutes = (
        (classroom.focus1_minutes or 45)
        + (classroom.break_minutes or 5)
        + (classroom.focus2_minutes or 45)
    )

    # ── 创建 Excel 工作簿 ──
    wb = Workbook()

    # ======================== Sheet 1: 课堂概览 ========================
    ws1 = wb.active
    ws1.title = "课堂概览"

    # 标题
    ws1.merge_cells("A1:D1")
    title_cell = ws1.cell(row=1, column=1, value="课堂专注报告")
    title_cell.font = _TITLE_FONT
    title_cell.alignment = Alignment(horizontal="center", vertical="center")

    # 基本信息区
    info_start = 3
    info_data = [
        ("课程名称", classroom.course_name or "—"),
        ("课次名称", classroom.lesson_name or classroom.course_name or "—"),
        ("课堂码", classroom.code or "—"),
        ("开始时间", start_str),
        ("结束时间", end_str),
        ("课堂时长", f"{total_minutes} 分钟"),
    ]
    for i, (label, value) in enumerate(info_data):
        r = info_start + i
        ws1.cell(row=r, column=1, value=label).font = _LABEL_FONT
        ws1.cell(row=r, column=1).alignment = _CELL_ALIGN
        ws1.cell(row=r, column=2, value=value).font = _VALUE_FONT
        ws1.cell(row=r, column=2).alignment = _CELL_ALIGN

    # 汇总指标
    summary_start = info_start + len(info_data) + 1
    ws1.merge_cells(f"A{summary_start}:D{summary_start}")
    ws1.cell(row=summary_start, column=1, value="📊 专注汇总").font = _SUBTITLE_FONT

    summary_data = [
        ("参与学生", f"{report.total_students} 人"),
        ("专注度评分", f"{report.focus_score}%"),
        ("平均分心时长", f"{round(report.average_usage_seconds / 60)} 分钟"),
        ("主要分心类型", main_distract or "无"),
    ]
    for i, (label, value) in enumerate(summary_data):
        r = summary_start + 1 + i
        ws1.cell(row=r, column=1, value=label).font = _LABEL_FONT
        ws1.cell(row=r, column=1).alignment = _CELL_ALIGN
        ws1.cell(row=r, column=2, value=value).font = _VALUE_FONT
        ws1.cell(row=r, column=2).alignment = _CELL_ALIGN

    # 建议
    sug_start = summary_start + len(summary_data) + 2
    ws1.merge_cells(f"A{sug_start}:D{sug_start}")
    ws1.cell(row=sug_start, column=1, value="💡 系统建议").font = _SUBTITLE_FONT
    if report.suggestions:
        suggestions = report.suggestions.split("; ")
        for i, sug in enumerate(suggestions):
            r = sug_start + 1 + i
            ws1.merge_cells(f"A{r}:D{r}")
            ws1.cell(row=r, column=1, value=f"• {sug}").font = _VALUE_FONT
            ws1.cell(row=r, column=1).alignment = _CELL_ALIGN

    # 列宽
    ws1.column_dimensions["A"].width = 18
    ws1.column_dimensions["B"].width = 28
    ws1.column_dimensions["C"].width = 16
    ws1.column_dimensions["D"].width = 16

    # ======================== Sheet 2: 学生专注统计 ========================
    ws2 = wb.create_sheet("学生专注统计")
    headers2 = ["序号", "学生姓名", "学号", "分心总时长(分钟)"]
    for c, h in enumerate(headers2, 1):
        ws2.cell(row=1, column=c, value=h)
    _style_header_row(ws2, 1, len(headers2))

    for i, s in enumerate(student_stats):
        r = i + 2
        display_name = s.get("nickname") or s["student_name"]
        row_data = [
            i + 1,
            display_name,
            s.get("student_no") or "—",
            round(s["total_seconds"] / 60),
        ]
        for c, val in enumerate(row_data, 1):
            cell = _style_data_cell(ws2, r, c, center=c in (1, 3, 4))
            cell.value = val

    _auto_width(ws2)

    # ======================== Sheet 3: 应用排行 ========================
    ws3 = wb.create_sheet("应用排行")
    headers3 = ["排名", "应用名称", "使用总时长(分钟)", "使用人数"]
    for c, h in enumerate(headers3, 1):
        ws3.cell(row=1, column=c, value=h)
    _style_header_row(ws3, 1, len(headers3))

    for i, app in enumerate(app_ranking):
        r = i + 2
        row_data = [
            i + 1,
            app["app_name"],
            round(app["total_seconds"] / 60),
            f'{app["student_count"]} 人',
        ]
        for c, val in enumerate(row_data, 1):
            cell = _style_data_cell(ws3, r, c, center=c in (1, 3, 4))
            cell.value = val

    _auto_width(ws3)

    # ======================== Sheet 4: 类型概览 ========================
    ws4 = wb.create_sheet("类型概览")
    headers4 = ["应用分类", "使用总时长(分钟)", "占比"]
    for c, h in enumerate(headers4, 1):
        ws4.cell(row=1, column=c, value=h)
    _style_header_row(ws4, 1, len(headers4))

    for i, t in enumerate(type_overview):
        r = i + 2
        row_data = [
            t["category"],
            round(t["total_seconds"] / 60),
            f'{t["percent"]}%',
        ]
        for c, val in enumerate(row_data, 1):
            cell = _style_data_cell(ws4, r, c, center=c in (2, 3))
            cell.value = val

    _auto_width(ws4)

    # ── 写入内存并返回 ──
    output = BytesIO()
    wb.save(output)
    output.seek(0)

    course_no = (classroom.course_no or "").replace("/", "-").replace("\\", "-")
    course_name = (classroom.course_name or "").replace("/", "-").replace("\\", "-")
    lesson_name = (classroom.lesson_name or "").replace("/", "-").replace("\\", "-")
    safe_name_parts = [p for p in [course_no, course_name, lesson_name] if p]
    safe_name = "_".join(safe_name_parts) if safe_name_parts else "课堂报告"
    filename = f"{safe_name}_专注报告.xlsx"

    return StreamingResponse(
        output,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename*=UTF-8''{quote(filename)}"},
    )
