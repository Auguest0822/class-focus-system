import '../../core/api_client.dart';
import 'student.dart';

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

    await _apiClient.tokenStorage.saveToken(data['access_token'].toString());
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

    await _apiClient.tokenStorage.saveToken(data['access_token'].toString());
    return Student.fromJson(data);
  }

  Future<Student> getCurrentUser() async {
    final data = await _apiClient.get('/auth/me') as Map<String, dynamic>;
    return Student.fromJson(data);
  }

  Future<void> logout() {
    return _apiClient.tokenStorage.clearToken();
  }
}
