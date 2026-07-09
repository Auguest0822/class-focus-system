class AppUsageRecord {
  const AppUsageRecord({
    required this.appPackage,
    required this.usageSeconds,
    this.appName,
    this.startTime,
    this.endTime,
  });

  final String appPackage;
  final String? appName;
  final int usageSeconds;
  final String? startTime;
  final String? endTime;

  Map<String, dynamic> toJson() {
    return {
      'app_package': appPackage,
      'app_name': appName,
      'usage_seconds': usageSeconds,
      'start_time': startTime,
      'end_time': endTime,
    };
  }
}

class AppUsageInfo {
  const AppUsageInfo({
    required this.id,
    required this.classroomId,
    required this.studentId,
    required this.appPackage,
    required this.usageSeconds,
    this.appName,
    this.startTime,
    this.endTime,
    this.createdAt,
  });

  final int id;
  final int classroomId;
  final int studentId;
  final String appPackage;
  final String? appName;
  final int usageSeconds;
  final String? startTime;
  final String? endTime;
  final String? createdAt;

  factory AppUsageInfo.fromJson(Map<String, dynamic> json) {
    return AppUsageInfo(
      id: json['id'] as int,
      classroomId: json['classroom_id'] as int,
      studentId: json['student_id'] as int,
      appPackage: json['app_package']?.toString() ?? '',
      appName: json['app_name']?.toString(),
      usageSeconds: json['usage_seconds'] as int? ?? 0,
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class ClassroomReport {
  const ClassroomReport({
    required this.id,
    required this.classroomId,
    required this.totalStudents,
    required this.averageUsageSeconds,
    required this.focusScore,
    this.topApps,
    this.suggestions,
    this.generatedAt,
  });

  final int id;
  final int classroomId;
  final int totalStudents;
  final double averageUsageSeconds;
  final double focusScore;
  final String? topApps;
  final String? suggestions;
  final String? generatedAt;

  factory ClassroomReport.fromJson(Map<String, dynamic> json) {
    return ClassroomReport(
      id: json['id'] as int? ?? 0,
      classroomId: json['classroom_id'] as int? ?? 0,
      totalStudents: json['total_students'] as int? ?? 0,
      averageUsageSeconds: (json['average_usage_seconds'] as num? ?? 0)
          .toDouble(),
      focusScore: (json['focus_score'] as num? ?? 0).toDouble(),
      topApps: json['top_apps']?.toString(),
      suggestions: json['suggestions']?.toString(),
      generatedAt: json['generated_at']?.toString(),
    );
  }
}
