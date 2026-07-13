class AppUsageRecord {
  const AppUsageRecord({
    required this.appPackage,
    required this.usageSeconds,
    this.appName,
    this.startTime,
    this.endTime,
    this.category,
  });

  final String appPackage;
  final String? appName;
  final int usageSeconds;
  final String? startTime;
  final String? endTime;
  final String? category;

  Map<String, dynamic> toJson() {
    return {
      'app_package': appPackage,
      'app_name': appName,
      'usage_seconds': usageSeconds,
      'start_time': startTime,
      'end_time': endTime,
      if (category != null && category!.isNotEmpty) 'category': category,
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
    // 班级汇总
    required this.totalStudents,
    required this.classAverageUsageSeconds,
    required this.classFocusScore,
    this.mainDistractType,
    this.suggestions,
    this.generatedAt,
    // 个人数据
    required this.personalTotalSeconds,
    required this.personalFocusScore,
    this.personalApps = const [],
    // 班级排行
    this.appRanking = const [],
  });

  final int id;
  final int classroomId;
  final int totalStudents;
  final double classAverageUsageSeconds;
  final double classFocusScore;
  final String? mainDistractType;
  final String? suggestions;
  final String? generatedAt;
  final int personalTotalSeconds;
  final double personalFocusScore;
  final List<PersonalAppUsage> personalApps;
  final List<AppRankingItem> appRanking;

  factory ClassroomReport.fromJson(Map<String, dynamic> json) {
    return ClassroomReport(
      id: json['classroom_id'] as int? ?? 0,
      classroomId: json['classroom_id'] as int? ?? 0,
      totalStudents: json['total_students'] as int? ?? 0,
      classAverageUsageSeconds:
          (json['class_average_usage_seconds'] as num? ?? 0).toDouble(),
      classFocusScore:
          (json['class_focus_score'] as num? ?? 0).toDouble(),
      mainDistractType: json['main_distract_type']?.toString(),
      suggestions: json['suggestions']?.toString(),
      generatedAt: json['generated_at']?.toString(),
      personalTotalSeconds: json['personal_total_seconds'] as int? ?? 0,
      personalFocusScore:
          (json['personal_focus_score'] as num? ?? 0).toDouble(),
      personalApps: _parsePersonalApps(json['personal_apps']),
      appRanking: _parseAppRanking(json['app_ranking']),
    );
  }

  static List<PersonalAppUsage> _parsePersonalApps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(PersonalAppUsage.fromJson)
        .where((item) => item.usageSeconds > 0)
        .toList();
  }

  static List<AppRankingItem> _parseAppRanking(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(AppRankingItem.fromJson)
        .toList();
  }
}

class PersonalAppUsage {
  const PersonalAppUsage({
    required this.appName,
    required this.usageSeconds,
    required this.percent,
    this.appPackage,
    this.category,
  });

  final String appName;
  final int usageSeconds;
  final double percent;
  final String? appPackage;
  final String? category;

  factory PersonalAppUsage.fromJson(Map<String, dynamic> json) {
    final appName =
        json['app_name']?.toString() ??
        json['app_package']?.toString() ??
        '未知应用';

    return PersonalAppUsage(
      appName: appName,
      usageSeconds: json['usage_seconds'] as int? ?? 0,
      percent: (json['percent'] as num? ?? 0).toDouble(),
      appPackage: json['app_package']?.toString(),
      category: json['category']?.toString(),
    );
  }
}

class AppRankingItem {
  const AppRankingItem({
    required this.appName,
    required this.totalSeconds,
    required this.studentCount,
    this.appPackage,
  });

  final String appName;
  final int totalSeconds;
  final int studentCount;
  final String? appPackage;

  factory AppRankingItem.fromJson(Map<String, dynamic> json) {
    final appName =
        json['app_name']?.toString() ??
        json['app_package']?.toString() ??
        '未知应用';

    return AppRankingItem(
      appName: appName,
      totalSeconds: json['total_seconds'] as int? ?? 0,
      studentCount: json['student_count'] as int? ?? 0,
      appPackage: json['app_package']?.toString(),
    );
  }
}
