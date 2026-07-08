import 'package:flutter_test/flutter_test.dart';

import 'package:student_app/app.dart';

void main() {
  testWidgets('shows login page first', (WidgetTester tester) async {
    await tester.pumpWidget(const StudentApp());

    expect(find.text('学生登录'), findsOneWidget);
    expect(find.text('还没有账号？注册'), findsOneWidget);
  });
}
