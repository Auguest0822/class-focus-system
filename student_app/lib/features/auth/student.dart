class Student {
  const Student({
    required this.name,
    this.id,
    this.role = 'student',
    this.studentNo,
  });

  final int? id;
  final String name;
  final String role;
  final String? studentNo;

  String get avatarText => name.isEmpty ? '学' : name.substring(0, 1);

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as int? ?? json['user_id'] as int?,
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'student',
      studentNo: json['student_no']?.toString(),
    );
  }
}
