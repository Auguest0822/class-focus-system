import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../auth/student.dart';
import 'active_classroom_page.dart';
import 'classroom.dart';
import 'classroom_report_page.dart';
import 'classroom_service.dart';

class ClassroomPage extends StatelessWidget {
  const ClassroomPage({
    super.key,
    required this.student,
    required this.classrooms,
    required this.isLoading,
    required this.onJoinTap,
    this.onRefresh,
  });

  final Student student;
  final List<Classroom> classrooms;
  final bool isLoading;
  final VoidCallback onJoinTap;
  final VoidCallback? onRefresh;

  void _openClassroom(BuildContext context, Classroom classroom) {
    final classroomService = ClassroomService();
    final page = classroom.status == ClassroomStatus.finished
        ? ClassroomReportPage(
            classroom: classroom,
            classroomService: classroomService,
          )
        : ActiveClassroomPage(
            classroom: classroom,
            classroomService: classroomService,
            student: student,
          );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) => onRefresh?.call());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          _ClassroomHeader(student: student),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onJoinTap,
            icon: const Icon(Icons.add),
            label: const Text('加入课堂'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (isLoading)
            const _ClassroomLoading()
          else if (classrooms.isEmpty)
            const _EmptyClassrooms()
          else
            for (final classroom in classrooms) ...[
              _ClassroomCard(
                classroom: classroom,
                onTap: () => _openClassroom(context, classroom),
              ),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _ClassroomLoading extends StatelessWidget {
  const _ClassroomLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 40),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyClassrooms extends StatelessWidget {
  const _EmptyClassrooms();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        '暂未加入课堂，请点击上方按钮输入课堂码。',
        style: TextStyle(color: AppColors.bodyText, height: 1.6),
      ),
    );
  }
}

class _ClassroomHeader extends StatelessWidget {
  const _ClassroomHeader({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final apiBase = ApiClient.runtimeBaseUrl ?? ApiClient.defaultBaseUrl;
    final avatarUrl = Student.resolveAvatarUrl(student.avatarUrl, apiBase);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '我的课堂',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '你好，${student.name}',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '查看已加入课堂，进入课堂后上传使用记录。',
                style: TextStyle(color: AppColors.bodyText, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.softBlue,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  student.avatarText,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

class _ClassroomCard extends StatelessWidget {
  const _ClassroomCard({required this.classroom, this.onTap});

  final Classroom classroom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1012355B),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classroom.courseName,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      classroom.lessonName,
                      style: const TextStyle(
                        color: AppColors.bodyText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: classroom.status, text: classroom.statusText),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(label: '课号', value: classroom.courseNo),
          _InfoRow(label: '课堂码', value: classroom.code),
          _InfoRow(label: '时间', value: classroom.startTime),
          _InfoRow(label: '时长', value: classroom.durationText),
          if (classroom.teacherName != null && classroom.teacherName!.isNotEmpty)
            _TeacherRow(
              teacherName: classroom.teacherName!,
              teacherAvatarUrl: classroom.teacherAvatarUrl,
            ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: const Size.fromHeight(42),
            ),
            child: Text(
              classroom.status == ClassroomStatus.finished ? '查看报告' : '查看课堂',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.text});

  final ClassroomStatus status;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      ClassroomStatus.running => (AppColors.primaryBlue, AppColors.softBlue),
      ClassroomStatus.finished => (AppColors.success, AppColors.softGreen),
      ClassroomStatus.waiting => (AppColors.bodyText, AppColors.softGray),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors.$1,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 62,
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

class _TeacherRow extends StatelessWidget {
  const _TeacherRow({
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
        children: [
          const SizedBox(
            width: 62,
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
