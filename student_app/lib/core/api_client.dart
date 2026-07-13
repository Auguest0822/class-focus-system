import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'token_storage.dart';

class ApiClient {
  /// 运行时服务器地址，null 时使用编译期默认值。
  static String? runtimeBaseUrl;

  /// 编译期默认地址，可通过 flutter run --dart-define=API_BASE_URL=... 覆盖。
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.33.100.176:8000/api',
  );

  static String _resolveBaseUrl() {
    final url = runtimeBaseUrl;
    if (url != null && url.isNotEmpty) return url;
    return defaultBaseUrl;
  }

  ApiClient({Dio? dio, TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? TokenStorage(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: _resolveBaseUrl(),
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

  Future<dynamic> put(String path, {Map<String, dynamic>? data}) async {
    final response = await _send(() => _dio.put(path, data: data));
    return _unwrap(response.data);
  }

  /// 上传文件（multipart/form-data），返回解析后的业务数据。
  /// [filePath] 本地文件路径，[fieldName] 服务端接收字段名。
  Future<dynamic> uploadFile(
    String path, {
    required String filePath,
    String fieldName = 'file',
  }) async {
    final formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath),
    });
    final response = await _send(() => _dio.post(path, data: formData));
    return _unwrap(response.data);
  }

  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  /// 把 Dio 异常转为带状态码的 [ApiException]。
  ApiException _toApiException(DioException error) {
    final statusCode = error.response?.statusCode;

    // 有 HTTP 响应 → 按状态码分类
    if (statusCode != null) {
      final data = error.response?.data;

      // 优先取后端返回的 detail / message 字段
      String? serverMessage;
      if (data is Map<String, dynamic>) {
        serverMessage =
            data['detail']?.toString() ?? data['message']?.toString();
      }

      switch (statusCode) {
        case 401:
          return ApiException(
            serverMessage ?? '登录已过期，请重新登录',
            statusCode: statusCode,
          );
        case 403:
          return ApiException(
            serverMessage ?? '无权访问该资源',
            statusCode: statusCode,
          );
        case 404:
          return ApiException(
            serverMessage ?? '请求的资源不存在',
            statusCode: statusCode,
          );
        case 422:
          return ApiException(
            serverMessage ?? '请求参数有误',
            statusCode: statusCode,
          );
        case 500:
          return ApiException(
            serverMessage ?? '服务器内部错误，请稍后重试',
            statusCode: statusCode,
          );
        default:
          return ApiException(
            serverMessage ?? '请求失败（$statusCode），请稍后再试',
            statusCode: statusCode,
          );
      }
    }

    // 无 HTTP 响应 → 网络层错误
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('请求超时，请检查网络后重试');
      case DioExceptionType.connectionError:
        return ApiException('网络连接失败，请检查网络设置');
      default:
        return ApiException(error.message ?? '网络连接失败');
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
