import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient({Dio? dio, TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? TokenStorage(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'http://localhost:8000/api',
              ),
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              contentType: Headers.jsonContentType,
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.reject(error);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;

  TokenStorage get tokenStorage => _tokenStorage;

  Future<dynamic> get(String path) async {
    final response = await _send(() => _dio.get(path));
    return _unwrap(response.data);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? data}) async {
    final response = await _send(() => _dio.post(path, data: data));
    return _unwrap(response.data);
  }

  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        throw ApiException(
          data['detail']?.toString() ??
              data['message']?.toString() ??
              '请求失败，请稍后再试',
        );
      }
      throw ApiException(error.message ?? '网络连接失败');
    }
  }

  dynamic _unwrap(dynamic body) {
    if (body is! Map<String, dynamic>) {
      throw const ApiException('响应格式不正确');
    }

    final code = body['code'];
    if (code != 0) {
      throw ApiException(body['message']?.toString() ?? '请求失败');
    }

    return body['data'];
  }
}
