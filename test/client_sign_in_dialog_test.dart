import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/core/theme/app_theme.dart';
import 'package:room_rental/features/auth/presentation/widgets/client_auth_button.dart';

void main() {
  testWidgets('sign-in dialog can open and close on a compact screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 440);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showClientSignInDialog(context),
              child: const Text('เข้าสู่ระบบ'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pumpAndSettle();
    expect(find.text('เข้าสู่ระบบหรือสมัครสมาชิก'), findsOneWidget);
    expect(find.text('ดำเนินการต่อด้วย Google').hitTestable(), findsOneWidget);

    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}
