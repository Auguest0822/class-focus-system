/// API 异常，携带 HTTP 状态码与可读消息。
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  /// 用户可读的错误消息
  final String message;

  /// HTTP 状态码，网络错误时为 null
  final int? statusCode;

  /// 是否为 401 未授权
  bool get isUnauthorized => statusCode == 401;

  /// 是否为 404 资源不存在
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}
