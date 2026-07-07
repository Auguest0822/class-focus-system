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
  });

  final int id;
  final String courseNo;
  final String courseName;
  final String lessonName;
  final String code;
  final String startTime;
  final String durationText;
  final ClassroomStatus status;

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
