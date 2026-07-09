class AppValidators {
  const AppValidators._();

  static final _nameRegExp = RegExp(r'^[一-龥A-Za-z\s]{2,20}$');
  static final _studentNoRegExp = RegExp(r'^\S{3,32}$');
  static final _passwordRegExp = RegExp(r'^.{6,64}$');
  static final _classCodeRegExp = RegExp(r'^[A-Za-z0-9]{6}$');

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入姓名';
    if (!_nameRegExp.hasMatch(text)) return '请输入 2-20 位中文或英文姓名';
    return null;
  }

  static String? studentNo(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入学号';
    if (!_studentNoRegExp.hasMatch(text)) return '请输入 3-32 位学号';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return '请输入密码';
    if (!_passwordRegExp.hasMatch(text)) return '密码至少需要 6 位';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final text = value ?? '';
    if (text.isEmpty) return '请再次输入密码';
    if (text != password) return '两次输入的密码不一致';
    return null;
  }

  static String? classCode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入课堂码';
    if (!_classCodeRegExp.hasMatch(text)) return '请输入 6 位课堂码';
    return null;
  }
}
