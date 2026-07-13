import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/app_colors.dart';
import '../auth/student.dart';
import 'app_usage.dart';
import 'classroom.dart';
import 'classroom_service.dart';

class ClassroomReportPage extends StatefulWidget {
  const ClassroomReportPage({
    super.key,
    required this.classroom,
    required this.classroomService,
  });

  final Classroom classroom;
  final ClassroomService classroomService;

  @override
  State<ClassroomReportPage> createState() => _ClassroomReportPageState();
}

class _ClassroomReportPageState extends State<ClassroomReportPage> {
  ClassroomReport? _report;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report = await widget.classroomService.getClassroomReport(
        widget.classroom.id,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '报告加载失败，请重试';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('课堂报告'),
        backgroundColor: AppColors.pageBackground,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadReport,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _ClassroomSummary(classroom: widget.classroom),
              const SizedBox(height: 16),
              if (_isLoading)
                const _LoadingCard()
              else if (_errorMessage != null)
                _ErrorCard(message: _errorMessage!, onRetry: _loadReport)
              else ...[
                _PersonalPerformanceCard(report: _report!),
                const SizedBox(height: 16),
                _PersonalAppsCard(apps: _report!.personalApps),
                const SizedBox(height: 16),
                _ClassRankingCard(items: _report!.appRanking),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────── 卡片 1: 课堂概要 ───────────────────
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
          if (classroom.teacherName != null &&
              classroom.teacherName!.isNotEmpty)
            _TeacherDetailRow(
              teacherName: classroom.teacherName!,
              teacherAvatarUrl: classroom.teacherAvatarUrl,
            ),
        ],
      ),
    );
  }
}

class _TeacherDetailRow extends StatelessWidget {
  const _TeacherDetailRow({
    required this.teacherName,
    this.teacherAvatarUrl,
  });

  final String teacherName;
  final String? teacherAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final apiBase = ApiClient.runtimeBaseUrl ?? ApiClient.defaultBaseUrl;
    final avatarUrl = Student.resolveAvatarUrl(teacherAvatarUrl, apiBase);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 76,
            child: Text(
              '老师',
              style: TextStyle(color: AppColors.bodyText),
            ),
          ),
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.softBlue,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    teacherName.isNotEmpty ? teacherName[0] : '师',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              teacherName,
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

// ─────────────────── 卡片 2: 我的专注表现 ───────────────────
class _PersonalPerformanceCard extends StatelessWidget {
  const _PersonalPerformanceCard({required this.report});

  final ClassroomReport report;

  Color _scoreColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return const Color(0xFFEF4444); // red
  }

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
          const Text(
            '我的专注表现',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          // 2x2 指标网格
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: '个人专注度',
                  value: '${report.personalFocusScore.toStringAsFixed(0)}%',
                  valueColor: _scoreColor(report.personalFocusScore),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: '个人分心时长',
                  value: _formatSeconds(report.personalTotalSeconds),
                  valueColor: AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: '班级平均专注度',
                  value: '${report.classFocusScore.toStringAsFixed(0)}%',
                  valueColor: _scoreColor(report.classFocusScore),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: '参与学生',
                  value: '${report.totalStudents} 人',
                  valueColor: AppColors.navy,
                ),
              ),
            ],
          ),
          // 主要分心类型
          if (report.mainDistractType != null &&
              report.mainDistractType!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  '主要分心类型：',
                  style: TextStyle(color: AppColors.bodyText),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.softBlue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    report.mainDistractType!,
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
          // 建议
          if (report.suggestions != null &&
              report.suggestions!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            const Text(
              '建议',
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              report.suggestions!,
              style: const TextStyle(color: AppColors.bodyText, height: 1.6),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = (seconds / 60).round();
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainMin = minutes % 60;
      return remainMin > 0 ? '${hours}h ${remainMin}min' : '${hours}h';
    }
    return '$minutes min';
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────── 卡片 3: 我的应用使用 ───────────────────
class _PersonalAppsCard extends StatelessWidget {
  const _PersonalAppsCard({required this.apps});

  final List<PersonalAppUsage> apps;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = apps.isEmpty
        ? 0
        : apps
            .map((item) => item.usageSeconds)
            .reduce((max, value) => value > max ? value : max);

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
          const Text(
            '我的应用使用',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          if (apps.isEmpty)
            const Text(
              '暂无应用使用记录',
              style: TextStyle(color: AppColors.bodyText, height: 1.5),
            )
          else
            for (int i = 0; i < apps.length; i++) ...[
              _PersonalAppRow(
                item: apps[i],
                progress: maxSeconds <= 0
                    ? 0.0
                    : apps[i].usageSeconds / maxSeconds,
              ),
              if (i < apps.length - 1) const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

class _PersonalAppRow extends StatelessWidget {
  const _PersonalAppRow({required this.item, required this.progress});

  final PersonalAppUsage item;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.appName,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item.percent.toStringAsFixed(1),
              style: const TextStyle(
                color: AppColors.bodyText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatUsageSeconds(item.usageSeconds),
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.softGray,
            color: AppColors.primaryBlue,
          ),
        ),
      ],
    );
  }

  String _formatUsageSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}min';
    if (hours > 0) return '${hours}h';
    return '$minutes min';
  }
}

// ─────────────────── 卡片 4: 班级应用排行 ───────────────────
class _ClassRankingCard extends StatelessWidget {
  const _ClassRankingCard({required this.items});

  final List<AppRankingItem> items;

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
          const Text(
            '班级应用排行',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text(
              '暂无数据',
              style: TextStyle(color: AppColors.bodyText, height: 1.5),
            )
          else
            for (int i = 0; i < items.length; i++) ...[
              _RankingRow(index: i + 1, item: items[i]),
              if (i < items.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.index, required this.item});

  final int index;
  final AppRankingItem item;

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // gold
      case 2:
        return const Color(0xFFC0C0C0); // silver
      case 3:
        return const Color(0xFFCD7F32); // bronze
      default:
        return AppColors.softGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 排名序号
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _rankColor(index),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$index',
            style: TextStyle(
              color: index <= 3 ? Colors.white : AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 应用名 + 使用人数
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.appName,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              Text(
                '${item.studentCount} 人使用',
                style: const TextStyle(
                  color: AppColors.bodyText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // 总时长
        Text(
          _formatSeconds(item.totalSeconds),
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}min';
    if (hours > 0) return '${hours}h';
    return '$minutes min';
  }
}

// ─────────────────── 通用组件 ───────────────────
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
