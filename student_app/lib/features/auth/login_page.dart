import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/error_handler.dart';
import '../../core/validators.dart';
import 'auth_service.dart';
import 'student.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authService,
    required this.onLoggedIn,
    required this.onShowRegister,
  });

  final AuthService authService;
  final ValueChanged<Student> onLoggedIn;
  final VoidCallback onShowRegister;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _accountFocusNode = FocusNode();
  List<LoginCredential> _loginHistory = [];
  bool _isSubmitting = false;
  bool _showLoginHistory = false;

  @override
  void initState() {
    super.initState();
    _loadLoginHistory();
    _accountController.addListener(_handleAccountChanged);
    _accountFocusNode.addListener(_handleAccountFocusChanged);
  }

  @override
  void dispose() {
    _accountFocusNode.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadLoginHistory() async {
    final history = await widget.authService.getLoginHistory();
    if (!mounted) return;
    setState(() {
      _loginHistory = history;
      _showLoginHistory = _accountFocusNode.hasFocus && history.isNotEmpty;
    });
  }

  void _handleAccountChanged() {
    if (!_accountFocusNode.hasFocus) return;
    setState(() {
      _showLoginHistory = _filteredLoginHistory.isNotEmpty;
    });
  }

  void _handleAccountFocusChanged() {
    setState(() {
      _showLoginHistory =
          _accountFocusNode.hasFocus && _filteredLoginHistory.isNotEmpty;
    });
  }

  List<LoginCredential> get _filteredLoginHistory {
    final keyword = _accountController.text.trim();
    if (keyword.isEmpty) return _loginHistory;
    return _loginHistory
        .where((item) => item.username.startsWith(keyword))
        .toList();
  }

  void _selectLoginCredential(LoginCredential credential) {
    _accountController.text = credential.username;
    _passwordController.text = credential.password;
    _accountController.selection = TextSelection.collapsed(
      offset: _accountController.text.length,
    );
    _accountFocusNode.unfocus();
    setState(() {
      _showLoginHistory = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _showLoginHistory = false;
    });

    try {
      final student = await widget.authService.login(
        username: _accountController.text.trim(),
        password: _passwordController.text,
      );
      widget.onLoggedIn(student);
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
          padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BrandHeader(),
              const SizedBox(height: 42),
              _AuthCard(
                title: '学生登录',
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _accountController,
                        focusNode: _accountFocusNode,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '账号',
                          hintText: '请输入 10 位数字账号',
                        ),
                        validator: AppValidators.account,
                      ),
                      if (_showLoginHistory) ...[
                        const SizedBox(height: 8),
                        _LoginHistoryDropdown(
                          credentials: _filteredLoginHistory,
                          onSelected: _selectLoginCredential,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '密码',
                          hintText: '请输入密码',
                        ),
                        validator: AppValidators.passwordForLogin,
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: _primaryButtonStyle(),
                        child: Text(_isSubmitting ? '登录中...' : '登录'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: widget.onShowRegister,
                child: const Text('还没有账号？注册'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginHistoryDropdown extends StatelessWidget {
  const _LoginHistoryDropdown({
    required this.credentials,
    required this.onSelected,
  });

  final List<LoginCredential> credentials;
  final ValueChanged<LoginCredential> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1212355B),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        shrinkWrap: true,
        itemCount: credentials.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          color: AppColors.border,
        ),
        itemBuilder: (context, index) {
          final credential = credentials[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.history, color: AppColors.primaryBlue),
            title: Text(
              credential.username,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              'Saved password',
              style: const TextStyle(color: AppColors.bodyText),
            ),
            onTap: () => onSelected(credential),
          );
        },
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '课堂专注\n管理系统',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 36,
            height: 1.08,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Student App',
          style: TextStyle(
            color: AppColors.cyan,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.border),
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
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
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

ButtonStyle _primaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: AppColors.navy,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
  );
}
