class Student {
  const Student({
    required this.name,
    this.id,
    this.role = 'student',
    this.studentNo,
    this.nickname,
    this.avatarUrl,
  });

  final int? id;
  final String name;
  final String role;
  final String? studentNo;
  final String? nickname;

  /// 后端返回的原始值：可能是 object_name（新格式）或完整 URL（旧格式兼容）。
  final String? avatarUrl;

  /// 展示名：优先用自定义昵称，否则用真实姓名。
  String get displayName =>
      (nickname != null && nickname!.isNotEmpty) ? nickname! : name;

  String get avatarText => displayName.isEmpty ? '学' : displayName.substring(0, 1);

  /// 解析为可被 NetworkImage 使用的完整头像 URL。
  ///
  /// 后端 agent 模式：avatar_url 存的是 object_name，
  /// 通过后端代理 ``GET /api/auth/avatar-file/{name}`` 访问。
  static String? resolveAvatarUrl(String? raw, String apiBaseUrl) {
    if (raw == null || raw.isEmpty) return null;
    // 旧格式兼容：已经是完整 HTTP URL
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    // 新格式：object_name → 后端代理 URL
    final base = apiBaseUrl.endsWith('/api')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 4)
        : apiBaseUrl;
    return '$base/api/auth/avatar-file/$raw';
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as int? ?? json['user_id'] as int?,
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'student',
      studentNo: json['student_no']?.toString(),
      nickname: json['nickname']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}
