import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/error_handler.dart';
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
  });

  final Classroom classroom;
  final ClassroomService classroomService;

  @override
  State<ActiveClassroomPage> createState() => _ActiveClassroomPageState();
}

class _ActiveClassroomPageState extends State<ActiveClassroomPage> {
  PhaseInfo? _phaseInfo;
  Timer? _countdownTimer; // 1 秒本地倒计时
  Timer? _syncTimer; // 后端校准（waiting 5s / running 30s）
  int? _localEndTimeMs; // 本地阶段结束时间戳(毫秒)
  int _localRemaining = 0; // 本地 1 秒更新的剩余秒数
  bool _isLoading = true;
  bool _isSyncing = false; // 防止手动刷新连点

  @override
  void initState() {
    super.initState();
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

      // 课堂已结束 → 停止所有定时器
      if (!_isClassroomRunning &&
          info.classroomStatus != 'running' &&
          info.phase == 'finished') {
        _stopAllTimers();
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

  // ── 停止所有定时器 ──
  void _stopAllTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  @override
  void dispose() {
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
                    ],
                  ),
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
