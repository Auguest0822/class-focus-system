import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/app_colors.dart';
import 'classroom.dart';
import 'classroom_service.dart';

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
  Timer? _timer;
  bool _isLoading = true;
  String? _errorMessage;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadPhase();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadPhase() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phase = await widget.classroomService.getClassroomPhase(
        widget.classroom.id,
      );
      if (!mounted) return;

      setState(() {
        _phaseInfo = phase;
        _remainingSeconds = phase.remainingSeconds;
        _isLoading = false;
      });
      _startCountdown();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '课堂信息加载失败，请稍后重试';
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('课堂详情'),
        backgroundColor: AppColors.pageBackground,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPhase,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _ClassroomSummary(classroom: widget.classroom),
              const SizedBox(height: 16),
              if (_isLoading)
                const _LoadingCard()
              else if (_errorMessage != null)
                _ErrorCard(message: _errorMessage!, onRetry: _loadPhase)
              else
                _PhaseCard(
                  phaseInfo: _phaseInfo!,
                  remainingSeconds: _remainingSeconds,
                ),
              const SizedBox(height: 16),
              _TipCard(status: widget.classroom.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassroomSummary extends StatelessWidget {
  const _ClassroomSummary({required this.classroom});

  final Classroom classroom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            classroom.courseName,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            classroom.lessonName,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(label: '课堂码', value: classroom.code),
          _DetailRow(label: '课号', value: classroom.courseNo),
          _DetailRow(label: '时间', value: classroom.startTime),
          _DetailRow(label: '时长', value: classroom.durationText),
        ],
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.phaseInfo, required this.remainingSeconds});

  final PhaseInfo phaseInfo;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final progress = phaseInfo.totalPhaseSeconds <= 0
        ? 0.0
        : 1 - (remainingSeconds / phaseInfo.totalPhaseSeconds);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  phaseInfo.phaseName,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _formatDuration(remainingSeconds),
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 44,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 10,
              backgroundColor: AppColors.softGray,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(label: '专注一', value: '${phaseInfo.focus1Minutes} 分钟'),
          _DetailRow(label: '课间休息', value: '${phaseInfo.breakMinutes} 分钟'),
          _DetailRow(label: '专注二', value: '${phaseInfo.focus2Minutes} 分钟'),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final minutes = safeSeconds ~/ 60;
    final restSeconds = safeSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${restSeconds.toString().padLeft(2, '0')}';
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(color: AppColors.bodyText, height: 1.5),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.status});

  final ClassroomStatus status;

  @override
  Widget build(BuildContext context) {
    final text = status == ClassroomStatus.finished
        ? '课堂已结束，教师生成报告后可查看课堂表现。'
        : '保持本页打开可查看课堂阶段倒计时。';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.bodyText, height: 1.6),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.bodyText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
