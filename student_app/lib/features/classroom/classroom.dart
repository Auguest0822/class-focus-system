enum ClassroomStatus { waiting, running, finished }

class Classroom {
  const Classroom({
    required this.id,
    required this.courseNo,
    required this.courseName,
    required this.lessonName,
    required this.code,
    required this.startTime,
    required this.durationText,
    required this.status,
    required this.focus1Minutes,
    required this.breakMinutes,
    required this.focus2Minutes,
  });

  final int id;
  final String courseNo;
  final String courseName;
  final String lessonName;
  final String code;
  final String startTime;
  final String durationText;
  final ClassroomStatus status;
  final int focus1Minutes;
  final int breakMinutes;
  final int focus2Minutes;

  String get statusText {
    switch (status) {
      case ClassroomStatus.waiting:
        return '未开始';
      case ClassroomStatus.running:
        return '进行中';
      case ClassroomStatus.finished:
        return '已结束';
    }
  }

  factory Classroom.fromJson(Map<String, dynamic> json) {
    final duration = json['duration_minutes'] as int? ?? 0;
    return Classroom(
      id: json['id'] as int,
      courseNo: json['course_no']?.toString() ?? '',
      courseName: json['course_name']?.toString() ?? '',
      lessonName: json['lesson_name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      startTime: _displayTime(json),
      durationText: duration > 0 ? '$duration 分钟' : '待设置',
      status: _statusFromApi(json['status']?.toString()),
      focus1Minutes: json['focus1_minutes'] as int? ?? 50,
      breakMinutes: json['break_minutes'] as int? ?? 5,
      focus2Minutes: json['focus2_minutes'] as int? ?? 40,
    );
  }
}

/// 课堂阶段信息（从 phase 端点返回）
class PhaseInfo {
  const PhaseInfo({
    required this.phase,
    required this.phaseName,
    required this.remainingSeconds,
    required this.totalPhaseSeconds,
    required this.classroomStatus,
    required this.serverTime,
    required this.focus1Minutes,
    required this.breakMinutes,
    required this.focus2Minutes,
  });

  final String phase;
  final String phaseName;
  final int remainingSeconds;
  final int totalPhaseSeconds;
  final String classroomStatus;
  final double serverTime; // 服务器 Unix 时间戳(秒),用于本地倒计时校准
  final int focus1Minutes;
  final int breakMinutes;
  final int focus2Minutes;

  factory PhaseInfo.fromJson(Map<String, dynamic> json) {
    return PhaseInfo(
      phase: json['phase']?.toString() ?? 'waiting',
      phaseName: json['phase_name']?.toString() ?? '未开始',
      remainingSeconds: json['remaining_seconds'] as int? ?? 0,
      totalPhaseSeconds: json['total_phase_seconds'] as int? ?? 0,
      classroomStatus: json['classroom_status']?.toString() ?? 'waiting',
      serverTime: (json['server_time'] as num?)?.toDouble() ?? 0.0,
      focus1Minutes: json['focus1_minutes'] as int? ?? 50,
      breakMinutes: json['break_minutes'] as int? ?? 5,
      focus2Minutes: json['focus2_minutes'] as int? ?? 40,
    );
  }
}

ClassroomStatus _statusFromApi(String? status) {
  switch (status) {
    case 'running':
      return ClassroomStatus.running;
    case 'finished':
      return ClassroomStatus.finished;
    case 'waiting':
    default:
      return ClassroomStatus.waiting;
  }
}

String _displayTime(Map<String, dynamic> json) {
  final value =
      json['scheduled_start_at'] ??
      json['started_at'] ??
      json['created_at'] ??
      json['startTime'];
  if (value == null) return '待老师开始课堂';

  final text = value.toString();
  if (text.length >= 16) {
    return text.substring(0, 16).replaceFirst('T', ' ');
  }
  return text;
}
