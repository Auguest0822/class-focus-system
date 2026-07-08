class AppValidators {
  const AppValidators._();

  static final _nameRegExp = RegExp(r'^[\u4e00-\u9fa5A-Za-z\s]{2,20}$');
  static final _accountRegExp = RegExp(r'^\d{10}$');
  static final _passwordRegExp = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{6,20}$',
  );
  static final _classCodeRegExp = RegExp(r'^[A-Za-z0-9]{6}$');

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入姓名';
    if (!_nameRegExp.hasMatch(text)) return '请输入 2-20 位中文或英文姓名';
    return null;
  }

  static String? account(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入账号';
    if (!_accountRegExp.hasMatch(text)) return '请输入 10 位数字账号';
    return null;
  }

  static String? passwordForLogin(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return '请输入密码';
    return null;
  }

  static String? passwordForRegister(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return '请输入密码';
    if (!_passwordRegExp.hasMatch(text)) return '请输入 6-20 位字母数字组合';
    return null;
  }

  static String? classCode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入课堂码';
    if (!_classCodeRegExp.hasMatch(text)) return '请输入 6 位课堂码';
    return null;
  }
}
