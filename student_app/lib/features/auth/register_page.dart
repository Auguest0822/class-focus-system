import 'package:flutter/material.dart';

import '../../core/error_handler.dart';
import '../../core/validators.dart';
import 'auth_service.dart';
import 'student.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.authService,
    required this.onRegistered,
    required this.onBackToLogin,
  });

  final AuthService authService;
  final ValueChanged<Student> onRegistered;
  final VoidCallback onBackToLogin;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _studentNoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _studentNoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final student = await widget.authService.register(
        name: _nameController.text.trim(),
        studentNo: _studentNoController.text.trim(),
        password: _passwordController.text,
      );
      widget.onRegistered(student);
    } catch (error) {
      if (!mounted) return;
      AppErrorHandler.show(context, error);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _RegisterBrand(),
              const SizedBox(height: 32),
              _RegisterCard(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '姓名',
                          hintText: '请输入中文或英文姓名',
                        ),
                        validator: AppValidators.name,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _studentNoController,
                        decoration: const InputDecoration(
                          labelText: '学号',
                          hintText: '请输入学号',
                        ),
                        validator: AppValidators.studentNo,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '密码',
                          hintText: '请输入密码（至少 6 位）',
                        ),
                        validator: AppValidators.password,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '确认密码',
                          hintText: '请再次输入密码',
                        ),
                        validator: (value) => AppValidators.confirmPassword(
                          value,
                          _passwordController.text,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF12355B),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Text(_isSubmitting ? '注册中...' : '注册并登录'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: widget.onBackToLogin,
                child: const Text('已有账号？返回登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterBrand extends StatelessWidget {
  const _RegisterBrand();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '课堂专注\n管理系统',
          style: TextStyle(
            color: Color(0xFF12355B),
            fontSize: 34,
            height: 1.08,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Student App',
          style: TextStyle(
            color: Color(0xFF00AECA),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RegisterCard extends StatelessWidget {
  const _RegisterCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD5E5F2)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1412355B),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '学生注册',
            style: TextStyle(
              color: Color(0xFF12355B),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}
