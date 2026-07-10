import 'package:flutter/material.dart';

import 'api_exception.dart';

/// 全局错误处理入口。
///
/// 使用方式：
/// 1. 在 App 启动时注册 [onForceLogout] 回调；
/// 2. 各页面 catch 到异常后调用 [AppErrorHandler.show] 即可。
class AppErrorHandler {
  AppErrorHandler._();

  /// 当收到 401 时触发，通常由 App 层注册为『跳转登录页』。
  static VoidCallback? onForceLogout;

  /// 展示异常信息并自动处理 401。
  ///
  /// 返回 `true` 表示异常已被处理（如 401 已触发强制登出），
  /// 调用方可以据此跳过后续的 `setState` 等操作。
  static bool show(BuildContext context, Object error) {
    // 非 ApiException → 友好提示
    if (error is! ApiException) {
      _showSnackBar(context, '发生未知错误，请稍后重试');
      return false;
    }

    // 401 → 先展示错误消息，再强制登出
    if (error.isUnauthorized) {
      debugPrint('[AppErrorHandler] 401 — ${error.message}');
      _showSnackBar(context, error.message);
      final callback = onForceLogout;
      if (callback != null) {
        callback();
      }
      return true;
    }

    // 其他 → 展示 SnackBar
    _showSnackBar(context, error.message);
    return false;
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
