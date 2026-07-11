import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/token_storage.dart';
import '../auth/student.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.student, required this.onLogout});

  final Student student;
  final VoidCallback onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = const TokenStorage();
  String _serverUrl = ApiClient.runtimeBaseUrl ?? ApiClient.defaultBaseUrl;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    final stored = await _storage.getServerUrl();
    if (mounted) {
      setState(() {
        _serverUrl = (stored != null && stored.isNotEmpty)
            ? stored
            : ApiClient.defaultBaseUrl;
      });
    }
  }

  Future<void> _editServerUrl() async {
    final controller = TextEditingController(text: _serverUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('服务器地址'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'http://10.162.151.59:8000/api',
            labelText: 'API 地址',
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty || url == _serverUrl) return;

    await _storage.saveServerUrl(url);
    setState(() => _serverUrl = url);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('服务器地址已保存，重启 App 后生效'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          const Text(
            '我的',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '查看账号信息与登录状态',
            style: TextStyle(color: AppColors.bodyText, fontSize: 16),
          ),
          const SizedBox(height: 24),
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
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.softBlue,
                  child: Text(
                    student.avatarText,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  student.name,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '学生',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _ProfileRow(label: '学号', value: student.studentNo ?? '-'),
                _ProfileRow(label: '姓名', value: student.name),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── 服务器地址设置 ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '服务器设置',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _editServerUrl,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.dns, size: 18, color: AppColors.mutedText),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _serverUrl,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.edit, size: 16, color: AppColors.mutedText),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '点击修改服务器地址，修改后需重启 App 生效。',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── 退出登录 ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '账户操作',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: widget.onLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('退出登录'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.bodyText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
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
