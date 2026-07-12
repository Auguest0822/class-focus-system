import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/app_colors.dart';
import 'core/error_handler.dart';
import 'core/token_storage.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/auth/student.dart';
import 'features/classroom/classroom.dart';
import 'features/classroom/classroom_page.dart';
import 'features/classroom/classroom_service.dart';
import 'features/classroom/join_classroom_page.dart';
import 'features/profile/profile_page.dart';

class StudentApp extends StatefulWidget {
  const StudentApp({super.key});

  @override
  State<StudentApp> createState() => _StudentAppState();
}

class _StudentAppState extends State<StudentApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final AuthService _authService;
  late final ClassroomService _classroomService;

  Student? _student;
  bool _showRegister = false;
  bool _isLoadingClassrooms = false;
  bool _isRestoring = true;
  int _selectedIndex = 0;
  List<Classroom> _classrooms = [];

  @override
  void initState() {
    super.initState();
    AppErrorHandler.onForceLogout = _handleForceLogout;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 1. 先加载存储的服务器地址
    final stored = await TokenStorage().getServerUrl();
    if (stored != null && stored.isNotEmpty) {
      ApiClient.runtimeBaseUrl = stored;
    }
    // 2. 然后再创建服务（ApiClient 此时已拿到正确地址）
    _authService = AuthService();
    _classroomService = ClassroomService();
    // 3. 尝试恢复登录
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    try {
      final student = await _authService.restoreSession();
      if (!mounted) return;
      if (student != null) {
        setState(() {
          _student = student;
          _isRestoring = false;
        });
        _loadClassrooms();
        return;
      }
    } catch (_) {
      // token 过期或网络不通都静默处理，直接让用户登录
    }
    if (mounted) {
      setState(() => _isRestoring = false);
    }
  }

  void _handleForceLogout() {
    if (!mounted) return;
    _authService.logout();
    setState(() {
      _student = null;
      _showRegister = false;
      _selectedIndex = 0;
      _classrooms = [];
    });
    _showMessage('登录已过期，请重新登录');
  }

  void _handleLogin(Student student) {
    setState(() {
      _student = student;
      _selectedIndex = 0;
    });
    _loadClassrooms();
  }

  void _handleLogout() {
    _authService.logout();
    setState(() {
      _student = null;
      _showRegister = false;
      _selectedIndex = 0;
      _classrooms = [];
    });
  }

  Future<void> _loadClassrooms() async {
    setState(() {
      _isLoadingClassrooms = true;
    });

    try {
      final classrooms = await _classroomService.getClassrooms();
      setState(() {
        _classrooms = classrooms;
      });
    } catch (error) {
      if (mounted) AppErrorHandler.show(context, error);
    } finally {
      if (mounted) {
        setState(() => _isLoadingClassrooms = false);
      }
    }
  }

  Future<void> _handleJoinClassroom(String code) async {
    try {
      final joinedClassroom = await _classroomService.joinClassroom(code);
      await _loadClassrooms();
      if (!mounted) return;
      setState(() {
        _selectedIndex = 0;
      });
      _showMessage('已加入课堂：${joinedClassroom.courseName}');
    } catch (error) {
      if (mounted) AppErrorHandler.show(context, error);
    }
  }

  void _showMessage(String message) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '课堂专注管理系统',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.pageBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          primary: AppColors.primaryBlue,
          surface: AppColors.cardBackground,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputBackground,
          labelStyle: const TextStyle(color: AppColors.bodyText),
          hintStyle: const TextStyle(color: AppColors.mutedText),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primaryBlue,
              width: 1.4,
            ),
          ),
        ),
      ),
      home: _isRestoring
          ? const _SplashScreen()
          : _student == null
              ? (_showRegister
                    ? RegisterPage(
                        authService: _authService,
                        onRegistered: _handleLogin,
                        onBackToLogin: () => setState(() => _showRegister = false),
                      )
                    : LoginPage(
                        authService: _authService,
                        onLoggedIn: _handleLogin,
                        onShowRegister: () => setState(() => _showRegister = true),
                      ))
              : _MainShell(
              student: _student!,
              selectedIndex: _selectedIndex,
              classrooms: _classrooms,
              isLoadingClassrooms: _isLoadingClassrooms,
              onTabChanged: (index) => setState(() => _selectedIndex = index),
              onJoinTap: () => setState(() => _selectedIndex = 1),
              onJoinClassroom: _handleJoinClassroom,
              onLogout: _handleLogout,
              onRefreshClassrooms: () => _loadClassrooms(),
            ),
    );
  }
}

class _MainShell extends StatelessWidget {
  const _MainShell({
    required this.student,
    required this.selectedIndex,
    required this.classrooms,
    required this.isLoadingClassrooms,
    required this.onTabChanged,
    required this.onJoinTap,
    required this.onJoinClassroom,
    required this.onLogout,
    required this.onRefreshClassrooms,
  });

  final Student student;
  final int selectedIndex;
  final List<Classroom> classrooms;
  final bool isLoadingClassrooms;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onJoinTap;
  final Future<void> Function(String code) onJoinClassroom;
  final VoidCallback onLogout;
  final VoidCallback onRefreshClassrooms;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ClassroomPage(
        student: student,
        classrooms: classrooms,
        isLoading: isLoadingClassrooms,
        onJoinTap: onJoinTap,
        onRefresh: onRefreshClassrooms,
      ),
      JoinClassroomPage(onJoinClassroom: onJoinClassroom),
      ProfilePage(student: student, onLogout: onLogout),
    ];

    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onTabChanged,
        backgroundColor: AppColors.cardBackground,
        indicatorColor: AppColors.selectedNavBackground,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '课堂',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: '加入',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '课堂专注',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
