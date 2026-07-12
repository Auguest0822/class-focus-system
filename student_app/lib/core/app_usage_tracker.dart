import 'package:flutter/services.dart';

import '../features/classroom/app_usage.dart';

/// App 使用时长追踪器（学生端）。
///
/// 通过 Android [MethodChannel] 桥接原生 `UsageStatsManager`，
/// 在课堂进行期间记录学生离开 App 后在其他应用中的停留时长。
///
/// 数据流：
/// ```
/// App 切后台 → onAppBackground() 记时间戳
/// App 回前台 → onAppForeground() 查 UsageStats → 积累到 _pendingRecords
/// 定时 / 退出 → flushPendingRecords() → 上传后端
/// ```
class AppUsageTracker {
  static const _channel = MethodChannel('com.example.student_app/usage');

  bool _isTracking = false;
  DateTime? _lastBackgroundTime;
  final List<AppUsageRecord> _pendingRecords = [];

  // ── 权限 ────────────────────────────────────────────────────────

  /// 检查用户是否已在系统设置中授权"使用情况访问权限"。
  Future<bool> isPermissionGranted() async {
    try {
      final result = await _channel.invokeMethod('isPermissionGranted');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// 打开系统"使用情况访问权限"设置页面。
  Future<void> openUsageAccessSettings() async {
    await _channel.invokeMethod('openUsageAccessSettings');
  }

  // ── 生命周期 ────────────────────────────────────────────────────

  /// 开始追踪。应在课堂进行（running）时调用。
  void startTracking() {
    _isTracking = true;
  }

  /// App 进入后台时调用，记录离开时间戳。
  void onAppBackground() {
    if (!_isTracking) return;
    _lastBackgroundTime = DateTime.now();
  }

  /// App 回到前台时调用，查询离开期间各 App 使用时长并积累。
  ///
  /// 返回本次查询到的记录列表。
  Future<List<AppUsageRecord>> onAppForeground() async {
    final beginMs = _lastBackgroundTime?.millisecondsSinceEpoch;
    _lastBackgroundTime = null; // 立即清空防止重入
    if (beginMs == null || !_isTracking) return [];

    // Android UsageEvents 写入有约 200-500ms 延迟，
    // 稍等一下确保刚产生的 foreground/background 事件已入库
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final records = await _queryUsageStats(
      beginMs,
      DateTime.now().millisecondsSinceEpoch,
    );
    _pendingRecords.addAll(records);
    return records;
  }

  /// 停止追踪并返回所有未上传的记录。
  List<AppUsageRecord> stopTracking() {
    _isTracking = false;
    final records = List<AppUsageRecord>.from(_pendingRecords);
    _pendingRecords.clear();
    _lastBackgroundTime = null;
    return records;
  }

  /// 查看待上传记录（只读，不清空）。
  List<AppUsageRecord> get pendingRecords =>
      List<AppUsageRecord>.unmodifiable(_pendingRecords);

  /// 清空待上传记录（上传成功后调用）。
  void clearPendingRecords() {
    _pendingRecords.clear();
  }

  /// 获取并清空待上传记录（用于停止追踪时一次性取出）。
  List<AppUsageRecord> flushPendingRecords() {
    final records = List<AppUsageRecord>.from(_pendingRecords);
    _pendingRecords.clear();
    return records;
  }

  /// 是否正在追踪。
  bool get isTracking => _isTracking;

  // ── 原生调用 ────────────────────────────────────────────────────

  /// 通过 MethodChannel 调用 Android UsageStatsManager 查询指定时间段内
  /// 各 App 的前台使用时长。
  Future<List<AppUsageRecord>> _queryUsageStats(
    int beginMs,
    int endMs,
  ) async {
    try {
      final result = await _channel.invokeMethod('queryUsageStats', {
        'begin': beginMs,
        'end': endMs,
      });

      if (result is! List) return [];

      return result
          .whereType<Map>()
          .map((item) {
            final map = Map<String, dynamic>.from(item);
            return AppUsageRecord(
              appPackage: map['packageName']?.toString() ?? '',
              appName: map['appName']?.toString(),
              usageSeconds: map['usageSeconds'] as int? ?? 0,
              startTime: map['startTime']?.toString(),
              endTime: map['endTime']?.toString(),
              category: map['category']?.toString(),
            );
          })
          .where((r) => r.usageSeconds > 0)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
