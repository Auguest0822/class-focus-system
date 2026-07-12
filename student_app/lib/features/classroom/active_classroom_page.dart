import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_usage_tracker.dart';
import '../../core/error_handler.dart';
import '../auth/student.dart';
import 'app_usage.dart';
import 'classroom.dart';
import 'classroom_service.dart';

/// 课堂倒计时页面（学生视角）
///
/// 策略：
/// - 课堂 **未开始(waiting)** 时：每 5 秒轮询后端，快速感知老师开课
/// - 课堂 **进行中(running)** 时：本地 1 秒倒计时 + 每 30 秒后端校准，平滑不跳秒
/// - 课堂 **已结束(finished)** 时：停止所有定时器
/// - AppBar 右侧提供手动刷新按钮
class ActiveClassroomPage extends StatefulWidget {
  const ActiveClassroomPage({
    super.key,
    required this.classroom,
    required this.classroomService,
    required this.student,
  });

  final Classroom classroom;
  final ClassroomService classroomService;
  final Student student;

  @override
  State<ActiveClassroomPage> createState() => _ActiveClassroomPageState();
}

class _ActiveClassroomPageState extends State<ActiveClassroomPage>
    with WidgetsBindingObserver {
  PhaseInfo? _phaseInfo;
  Timer? _countdownTimer; // 1 秒本地倒计时
  Timer? _syncTimer; // 后端校准（waiting 5s / running 30s）
  int? _localEndTimeMs; // 本地阶段结束时间戳(毫秒)
  int _localRemaining = 0; // 本地 1 秒更新的剩余秒数
  bool _isLoading = true;
  bool _isSyncing = false; // 防止手动刷新连点
  bool _isUploading = false; // 防止并发上传
  bool _trackingEnabled = false; // 是否已获得使用情况访问权限

  final AppUsageTracker _tracker = AppUsageTracker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTracking();
    _startTimers();
  }

  // ── 课堂是否在进行中 ──
  bool get _isClassroomRunning {
    final info = _phaseInfo;
    if (info == null) return false;
    return info.classroomStatus == 'running' && info.phase != 'finished';
  }

  // ── 当前应使用的同步间隔(秒) ──
  int get _syncIntervalSeconds => _isClassroomRunning ? 30 : 5;

  // ── 启动所有定时器 ──
  void _startTimers() {
    _syncFromBackend(showErrors: true); // 首次同步，展示异常
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickLocalCountdown(),
    );
    _scheduleSync();
  }

  // ── 按当前状态调度下次同步 ──
  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(seconds: _syncIntervalSeconds),
      (_) => _syncFromBackend(),
    );
  }

  // ── 本地 1 秒倒计时刷新(纯本地计算,不发起网络请求) ──
  void _tickLocalCountdown() {
    if (_localEndTimeMs == null) return;
    final remaining =
        ((_localEndTimeMs! - DateTime.now().millisecondsSinceEpoch) / 1000)
            .ceil()
            .clamp(0, 999999);
    if (!mounted) return;
    setState(() {
      _localRemaining = remaining;
    });
    // 本地倒计时归零 → 立刻向后端同步,获取下一阶段
    if (remaining <= 0 && _isClassroomRunning) {
      _syncFromBackend();
    }
  }

  // ── 向后端校准阶段信息 ──
  /// [showErrors] 为 true 时向用户展示错误（首次加载 / 手动刷新）；
  /// 后台定时器传 false，只处理 401 强制登出，不弹 SnackBar 打扰用户。
  Future<void> _syncFromBackend({bool showErrors = false}) async {
    if (_isSyncing) return; // 防重入
    _isSyncing = true;
    try {
      final info =
          await widget.classroomService.getClassroomPhase(widget.classroom.id);
      if (!mounted) return;
      final wasRunning = _isClassroomRunning;
      setState(() {
        _phaseInfo = info;
        _isLoading = false;
        // 用后端返回的剩余秒数重新锚定本地结束时间
        _localEndTimeMs =
            DateTime.now().millisecondsSinceEpoch + info.remainingSeconds * 1000;
        _localRemaining = info.remainingSeconds;
      });

      // 状态切换时调整同步间隔
      if (wasRunning != _isClassroomRunning) {
        _scheduleSync();
      }

      // 课堂进行中 → 顺便上传积压的 App 使用数据
      if (_isClassroomRunning) {
        _uploadPendingUsage();
      }

      // 课堂已结束 → 停止所有定时器，上传最后一批数据
      if (!_isClassroomRunning &&
          info.classroomStatus != 'running' &&
          info.phase == 'finished') {
        _stopAllTimers();
        _uploadPendingUsage();
        _tracker.stopTracking();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      // 401 始终处理；其他错误仅在非静默模式下展示
      if (error is ApiException && error.isUnauthorized) {
        AppErrorHandler.show(context, error);
      } else if (showErrors) {
        AppErrorHandler.show(context, error);
      }
    } finally {
      _isSyncing = false;
    }
  }

  // ── 手动刷新（AppBar 按钮触发） ──
  Future<void> _handleRefresh() async {
    await _syncFromBackend(showErrors: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已刷新'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // ── App 使用时长追踪 ────────────────────────────────────────────

  Future<void> _initTracking() async {
    final granted = await _tracker.isPermissionGranted();
    if (!mounted) return;
    setState(() => _trackingEnabled = granted);
    if (granted) {
      _tracker.startTracking();
    } else {
      // 首次进入且无权限 → 弹窗引导；用户也可以点底部状态栏重新打开
      _showPermissionDialog();
    }
  }

  /// 重新检查权限（从设置页回来后调用）。
  Future<void> _recheckPermission() async {
    final granted = await _tracker.isPermissionGranted();
    if (!mounted) return;
    if (granted && !_tracker.isTracking) {
      _tracker.startTracking();
      setState(() => _trackingEnabled = true);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要开启使用情况访问'),
        content: const Text(
          '为了记录课堂期间的 App 使用情况，'
          '需要在系统设置中开启"使用情况访问权限"。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('暂不开启'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx); // 先关闭对话框
              await _tracker.openUsageAccessSettings();
              // 从设置返回后重新检查
              _recheckPermission();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  /// 上传所有积压数据。上传成功才清空 _pendingRecords，
  /// 失败则保留数据下次重试。[_isUploading] 防止并发调用。
  Future<void> _uploadPendingUsage() async {
    if (!_tracker.isTracking || _isUploading) return;
    final records = _tracker.pendingRecords;
    if (records.isEmpty) return;
    _isUploading = true;
    try {
      await widget.classroomService.uploadUsageRecords(
        classroomId: widget.classroom.id,
        records: records,
      );
      // 上传成功 → 清空已上传的记录
      _tracker.clearPendingRecords();
    } catch (_) {
      // 上传失败 → 数据保留，下次同步时重试
    } finally {
      _isUploading = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _tracker.onAppBackground();
    } else if (state == AppLifecycleState.resumed) {
      // 从设置页返回后可能已授权 → 重新检查
      if (!_tracker.isTracking && mounted) {
        await _recheckPermission();
      }
      await _tracker.onAppForeground();
      // 回到前台立即上传一次（失败也不丢数据，_pendingRecords 保留）
      if (mounted) await _uploadPendingUsage();
    }
  }

  // ── 停止所有定时器 ──
  void _stopAllTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uploadPendingUsage();
    _tracker.stopTracking();
    _stopAllTimers();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool _isPhaseDone(String name) {
    const order = ['第一专注段', '课间休息', '第二专注段'];
    final currentIdx = order.indexOf(_phaseInfo?.phaseName ?? '');
    final thisIdx = order.indexOf(name);
    return currentIdx > thisIdx;
  }

  @override
  Widget build(BuildContext context) {
    final classroom = widget.classroom;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text(classroom.courseName),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _isSyncing ? null : _handleRefresh,
          ),
          _buildStudentAvatar(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── 阶段倒计时卡片 ──
                if (_phaseInfo != null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navy.withAlpha(15),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 阶段名称
                        Text(
                          _phaseInfo!.phaseName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _phaseInfo!.phase == 'break'
                                ? AppColors.warning
                                : AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // 倒计时(本地 1 秒刷新,平滑无跳秒)
                        Text(
                          _isClassroomRunning
                              ? _formatTime(_localRemaining)
                              : '--:--',
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                            color: _isClassroomRunning && _localRemaining <= 60
                                ? Colors.red
                                : AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 18),
                        // 进度条
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _phaseInfo!.totalPhaseSeconds > 0
                                ? 1 -
                                    (_localRemaining /
                                        _phaseInfo!.totalPhaseSeconds)
                                : 0,
                            minHeight: 8,
                            backgroundColor: AppColors.border,
                            color: _phaseInfo!.phase == 'break'
                                ? AppColors.warning
                                : AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 18),
                        // 阶段指示器
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: ['第一专注段', '课间休息', '第二专注段']
                              .map((label) {
                            final active = _phaseInfo?.phaseName == label;
                            final done = _isPhaseDone(label);
                            return Expanded(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 6),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.primaryBlue
                                      : (done
                                          ? AppColors.softGreen
                                          : AppColors.softGray),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: active || done
                                        ? Colors.white
                                        : AppColors.bodyText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 22),

                // ── 课堂信息卡片 ──
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '课堂信息',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _infoRow('课号', classroom.courseNo),
                      _infoRow('课次', classroom.lessonName),
                      _infoRow('时长', classroom.durationText),
                      _infoRow('状态', _phaseInfo?.phaseName ?? '未开始'),
                      if (classroom.teacherName != null && classroom.teacherName!.isNotEmpty)
                        _teacherInfoRow(classroom.teacherName!, classroom.teacherAvatarUrl),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ── 追踪状态指示条 ──
                _buildTrackingStatus(),
              ],
            ),
    );
  }

  Widget _buildTrackingStatus() {
    return GestureDetector(
      onTap: _trackingEnabled
          ? null
          : () => _showPermissionDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _trackingEnabled
              ? AppColors.softGreen
              : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _trackingEnabled
                ? AppColors.success.withAlpha(60)
                : AppColors.warning.withAlpha(80),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _trackingEnabled ? Icons.visibility : Icons.visibility_off,
              size: 20,
              color: _trackingEnabled
                  ? AppColors.success
                  : AppColors.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _trackingEnabled ? '正在记录 App 使用情况' : '未开启使用记录',
                style: TextStyle(
                  color: _trackingEnabled
                      ? AppColors.success
                      : const Color(0xFFE65100),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            if (!_trackingEnabled)
              const Icon(Icons.chevron_right, color: Color(0xFFE65100)),
            if (_trackingEnabled)
              const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentAvatar() {
    final student = widget.student;
    final apiBase = ApiClient.runtimeBaseUrl ?? ApiClient.defaultBaseUrl;
    final avatarUrl = Student.resolveAvatarUrl(student.avatarUrl, apiBase);

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white24,
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null
            ? Text(
                student.avatarText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              )
            : null,
      ),
    );
  }

  Widget _teacherInfoRow(String name, String? avatarUrlRaw) {
    final apiBase = ApiClient.runtimeBaseUrl ?? ApiClient.defaultBaseUrl;
    final avatarUrl = Student.resolveAvatarUrl(avatarUrlRaw, apiBase);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('老师', style: TextStyle(color: AppColors.mutedText)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.softBlue,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0] : '师',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.mutedText)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.navy)),
        ],
      ),
    );
  }
}
