import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'student_access_token';
  static const _studentKey = 'student_profile';
  static const _loginHistoryKey = 'student_login_history';

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() {
    return _storage.read(key: _tokenKey);
  }

  Future<void> saveStudentJson(String studentJson) {
    return _storage.write(key: _studentKey, value: studentJson);
  }

  Future<String?> getStudentJson() {
    return _storage.read(key: _studentKey);
  }

  Future<void> saveLoginHistoryJson(String historyJson) {
    return _storage.write(key: _loginHistoryKey, value: historyJson);
  }

  Future<String?> getLoginHistoryJson() {
    return _storage.read(key: _loginHistoryKey);
  }

  Future<void> clearToken() {
    return Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _studentKey),
    ]).then((_) {});
  }
}
