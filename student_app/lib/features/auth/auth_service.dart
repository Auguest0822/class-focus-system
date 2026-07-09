import 'dart:convert';

import '../../core/api_client.dart';
import 'student.dart';

class LoginCredential {
  const LoginCredential({required this.username, required this.password});

  final String username;
  final String password;

  factory LoginCredential.fromJson(Map<String, dynamic> json) {
    return LoginCredential(
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'username': username, 'password': password};
  }
}

class AuthService {
  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Student> login({
    required String username,
    required String password,
  }) async {
    final data =
        await _apiClient.post(
              '/auth/login',
              data: {'username': username, 'password': password},
            )
            as Map<String, dynamic>;

    await _saveSession(data);
    await saveLoginCredential(username: username.trim(), password: password);
    return Student.fromJson(data);
  }

  Future<Student> register({
    required String name,
    required String username,
    required String password,
  }) async {
    final data =
        await _apiClient.post(
              '/auth/register',
              data: {
                'username': username,
                'password': password,
                'role': 'student',
                'name': name,
                'student_no': username,
              },
            )
            as Map<String, dynamic>;

    await _saveSession(data);
    await saveLoginCredential(username: username.trim(), password: password);
    return Student.fromJson(data);
  }

  Future<Student> getCurrentUser() async {
    final data = await _apiClient.get('/auth/me') as Map<String, dynamic>;
    await _apiClient.tokenStorage.saveStudentJson(jsonEncode(data));
    return Student.fromJson(data);
  }

  Future<Student?> restoreSession() async {
    final token = await _apiClient.tokenStorage.getToken();
    if (token == null || token.isEmpty) return null;

    final cachedStudent = await _apiClient.tokenStorage.getStudentJson();
    if (cachedStudent != null && cachedStudent.isNotEmpty) {
      final data = jsonDecode(cachedStudent);
      if (data is Map<String, dynamic>) {
        return Student.fromJson(data);
      }
      if (data is Map) {
        return Student.fromJson(Map<String, dynamic>.from(data));
      }
    }

    return getCurrentUser();
  }

  Future<void> logout() {
    return _apiClient.tokenStorage.clearToken();
  }

  Future<List<LoginCredential>> getLoginHistory() async {
    final raw = await _apiClient.tokenStorage.getLoginHistoryJson();
    if (raw == null || raw.isEmpty) return [];

    final data = jsonDecode(raw);
    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((item) => LoginCredential.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.username.isNotEmpty && item.password.isNotEmpty)
        .toList();
  }

  Future<void> saveLoginCredential({
    required String username,
    required String password,
  }) async {
    if (username.isEmpty || password.isEmpty) return;

    final history = await getLoginHistory();
    final updated = [
      LoginCredential(username: username, password: password),
      ...history.where((item) => item.username != username),
    ].take(8).toList();

    await _apiClient.tokenStorage.saveLoginHistoryJson(
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    await _apiClient.tokenStorage.saveToken(data['access_token'].toString());
    await _apiClient.tokenStorage.saveStudentJson(jsonEncode(data));
  }
}
