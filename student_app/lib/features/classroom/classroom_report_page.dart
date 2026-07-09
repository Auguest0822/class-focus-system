import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/app_colors.dart';
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
        _errorMessage = 'Report failed to load. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('Class Report'),
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
                _ReportCard(report: _report!),
                const SizedBox(height: 16),
                _SoftwareUsageCard(items: _report!.appUsageDetails),
              ],
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
          _DetailRow(label: 'Code', value: classroom.code),
          _DetailRow(label: 'Course', value: classroom.courseNo),
          _DetailRow(label: 'Time', value: classroom.startTime),
          _DetailRow(label: 'Duration', value: classroom.durationText),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final ClassroomReport report;

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
            'Class Performance',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Focus Score',
                  value: '${report.focusScore.toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Avg Distraction',
                  value: _formatSeconds(report.averageUsageSeconds),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(label: 'Students', value: '${report.totalStudents}'),
          if (report.topApps != null && report.topApps!.isNotEmpty)
            _DetailRow(label: 'Top Apps', value: report.topApps!),
          if (report.generatedAt != null && report.generatedAt!.isNotEmpty)
            _DetailRow(label: 'Generated', value: _formatTime(report.generatedAt!)),
          if (report.suggestions != null && report.suggestions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Suggestion',
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
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

  static String _formatSeconds(double seconds) {
    final minutes = (seconds / 60).round();
    return '$minutes min';
  }

  static String _formatTime(String value) {
    if (value.length >= 16) {
      return value.substring(0, 16).replaceFirst('T', ' ');
    }
    return value;
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

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
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftwareUsageCard extends StatelessWidget {
  const _SoftwareUsageCard({required this.items});

  final List<AppUsageDetail> items;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = items.isEmpty
        ? 0
        : items
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
            'Software Usage',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text(
              'No app usage records yet.',
              style: TextStyle(color: AppColors.bodyText, height: 1.5),
            )
          else
            for (final item in items) ...[
              _SoftwareUsageRow(
                item: item,
                progress: maxSeconds <= 0
                    ? 0.0
                    : item.usageSeconds / maxSeconds,
              ),
              if (item != items.last) const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

class _SoftwareUsageRow extends StatelessWidget {
  const _SoftwareUsageRow({required this.item, required this.progress});

  final AppUsageDetail item;
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
            value: progress.clamp(0.0, 1.0).toDouble(),
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
    return '${minutes} min';
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
            label: const Text('Retry'),
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
