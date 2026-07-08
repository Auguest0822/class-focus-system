import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/validators.dart';

class JoinClassroomPage extends StatefulWidget {
  const JoinClassroomPage({super.key, required this.onJoinClassroom});

  final Future<void> Function(String code) onJoinClassroom;

  @override
  State<JoinClassroomPage> createState() => _JoinClassroomPageState();
}

class _JoinClassroomPageState extends State<JoinClassroomPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    await widget.onJoinClassroom(_codeController.text);
    _codeController.clear();

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          const Text(
            '加入课堂',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '输入老师提供的 6 位课堂码',
            style: TextStyle(color: AppColors.bodyText, fontSize: 16),
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1012355B),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '课堂码',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _CodePreview(code: _codeController.text),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      labelText: '输入课堂码',
                      hintText: '例如 MA2027',
                    ),
                    validator: AppValidators.classCode,
                    onChanged: (value) {
                      final upper = value.toUpperCase();
                      if (value != upper) {
                        _codeController.value = _codeController.value.copyWith(
                          text: upper,
                          selection: TextSelection.collapsed(
                            offset: upper.length,
                          ),
                        );
                      }
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_isSubmitting ? '加入中...' : '加入课堂'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              '课堂码由任课老师在课堂页面展示。加入成功后可在我的课堂中查看。',
              style: TextStyle(color: AppColors.bodyText, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodePreview extends StatelessWidget {
  const _CodePreview({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final chars = code.padRight(6, ' ').split('').take(6).toList();
    return Row(
      children: [
        for (var index = 0; index < chars.length; index++) ...[
          Expanded(
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                chars[index].trim().isEmpty ? '' : chars[index],
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (index != chars.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
