import 'dart:convert';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import 'student.dart';

class LoginCredential {
  const LoginCredential({required this.studentNo, required this.password});

  final String studentNo;
  final String password;

  factory LoginCredential.fromJson(Map<String, dynamic> json) {
    return LoginCredential(
      studentNo: json['studentNo']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'studentNo': studentNo, 'password': password};
  }
}

class AuthService {
  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Student> login({
    required String studentNo,
    required String password,
  }) async {
    final data =
        await _apiClient.post(
              '/auth/login',
              data: {
                'account': studentNo,
                'password': password,
                'role': 'student',
              },
            )
            as Map<String, dynamic>;

    await _saveSession(data);
    await saveLoginCredential(studentNo: studentNo.trim(), password: password);
    return Student.fromJson(data);
  }

  Future<Student> register({
    required String name,
    required String studentNo,
    required String password,
  }) async {
    final data =
        await _apiClient.post(
              '/auth/register',
              data: {
                'password': password,
                'role': 'student',
                'name': name,
                'student_no': studentNo,
              },
            )
            as Map<String, dynamic>;

    await _saveSession(data);
    await saveLoginCredential(studentNo: studentNo.trim(), password: password);
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

    // 优先用 /auth/me 校验 token 是否仍然有效
    try {
      return await getCurrentUser();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // token 已过期，清除并让用户重新登录
        await logout();
        return null;
      }
      // 其他服务端错误（500 等），回退到缓存
    } catch (_) {
      // 网络不通，回退到本地缓存
    }

    // 离线回退：使用上次缓存的用户数据
    final cachedStudent = await _apiClient.tokenStorage.getStudentJson();
    if (cachedStudent != null && cachedStudent.isNotEmpty) {
      try {
        final data = jsonDecode(cachedStudent);
        if (data is Map<String, dynamic>) {
          return Student.fromJson(data);
        }
        if (data is Map) {
          return Student.fromJson(Map<String, dynamic>.from(data));
        }
      } catch (_) {
        // JSON 解析失败
      }
    }

    return null;
  }

  /// 更新个人资料（昵称）。
  Future<Student> updateProfile({String? nickname}) async {
    final data = await _apiClient.put(
      '/auth/profile',
      data: {'nickname': nickname},
    ) as Map<String, dynamic>;
    await _apiClient.tokenStorage.saveStudentJson(jsonEncode(data));
    return Student.fromJson(data);
  }

  /// 上传头像图片，返回更新后的 Student。
  Future<Student> uploadAvatar(String filePath) async {
    final data = await _apiClient.uploadFile(
      '/auth/avatar',
      filePath: filePath,
      fieldName: 'file',
    ) as Map<String, dynamic>;
    await _apiClient.tokenStorage.saveStudentJson(jsonEncode(data));
    return Student.fromJson(data);
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
        .where((item) => item.studentNo.isNotEmpty && item.password.isNotEmpty)
        .toList();
  }

  Future<void> saveLoginCredential({
    required String studentNo,
    required String password,
  }) async {
    if (studentNo.isEmpty || password.isEmpty) return;

    final history = await getLoginHistory();
    final updated = [
      LoginCredential(studentNo: studentNo, password: password),
      ...history.where((item) => item.studentNo != studentNo),
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
