"""
课堂倒计时阶段计算（服务端唯一时间源）

所有客户端（老师 Web / 学生 App）轮询 phase 端点，
后端根据 ``started_at`` + 三段时长实时计算当前阶段和剩余秒数，
不依赖任何一个客户端的时钟。
"""
import time
from datetime import datetime

# 阶段元数据：phase key → (中文名, 该阶段秒数计算函数)
PHASE_META = {
    "waiting":  ("未开始",   lambda _: 0),
    "focus1":   ("第一专注段", lambda c: (c.focus1_minutes or 45) * 60),
    "break":    ("课间休息",  lambda c: (c.break_minutes or 5) * 60),
    "focus2":   ("第二专注段", lambda c: (c.focus2_minutes or 45) * 60),
    "finished": ("已结束",   lambda _: 0),
}


def calculate_phase(classroom):
    """纯服务端阶段计算，不依赖客户端时间。

    Args:
        classroom: Classroom ORM 对象（需有 status, started_at,
                   focus1_minutes, break_minutes, focus2_minutes 属性）

    Returns:
        dict: {
            "phase": str,               # waiting/focus1/break/focus2/finished
            "phase_name": str,          # 中文名称
            "remaining_seconds": int,   # 当前阶段剩余秒数
            "total_phase_seconds": int, # 当前阶段总秒数
            "server_time": float,       # 服务器当前 Unix 时间戳(秒)
            "auto_finish": bool,        # 是否应该自动结束（已超时但 DB 还没写）
        }
    """
    status = getattr(classroom, "status", "waiting")

    now_ts = time.time()

    if status == "waiting":
        return {
            "phase": "waiting",
            "phase_name": "未开始",
            "remaining_seconds": 0,
            "total_phase_seconds": 0,
            "server_time": now_ts,
            "auto_finish": False,
        }

    started_at = getattr(classroom, "started_at", None)
    if status == "finished" or not started_at:
        return {
            "phase": "finished",
            "phase_name": "已结束",
            "remaining_seconds": 0,
            "total_phase_seconds": 0,
            "server_time": now_ts,
            "auto_finish": False,
        }

    # status == "running" — 根据 started_at 实时计算
    now = datetime.now()
    elapsed = (now - started_at).total_seconds()

    f1 = (classroom.focus1_minutes or 45) * 60
    br = (classroom.break_minutes or 5) * 60
    f2 = (classroom.focus2_minutes or 45) * 60
    total = f1 + br + f2

    # 时钟偏移容错（极少见）
    if elapsed < 0:
        return {
            "phase": "focus1",
            "phase_name": "第一专注段",
            "remaining_seconds": f1,
            "total_phase_seconds": f1,
            "server_time": now_ts,
            "auto_finish": False,
        }

    if elapsed < f1:
        return {
            "phase": "focus1",
            "phase_name": "第一专注段",
            "remaining_seconds": int(f1 - elapsed),
            "total_phase_seconds": f1,
            "server_time": now_ts,
            "auto_finish": False,
        }
    elif elapsed < f1 + br:
        return {
            "phase": "break",
            "phase_name": "课间休息",
            "remaining_seconds": int((f1 + br) - elapsed),
            "total_phase_seconds": br,
            "server_time": now_ts,
            "auto_finish": False,
        }
    elif elapsed < total:
        return {
            "phase": "focus2",
            "phase_name": "第二专注段",
            "remaining_seconds": int(total - elapsed),
            "total_phase_seconds": f2,
            "server_time": now_ts,
            "auto_finish": False,
        }
    else:
        # 已超过总时长 → 触发自动结束
        return {
            "phase": "finished",
            "phase_name": "已结束",
            "remaining_seconds": 0,
            "total_phase_seconds": 0,
            "server_time": now_ts,
            "auto_finish": True,
        }
