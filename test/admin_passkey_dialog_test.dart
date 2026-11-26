import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/core/theme/app_theme.dart';
import 'package:room_rental/features/admin/data/admin_passkey_entry.dart';
import 'package:room_rental/features/admin/presentation/widgets/admin_passkey_dialog.dart';

void main() {
  testWidgets(
    'only removes a passkey after confirmed successful verification',
    (tester) async {
      final entries = <AdminPasskeyEntry>[
        (id: 'first-key', name: 'MacBook', createdAt: DateTime.utc(2026, 1, 1)),
      ];
      var verificationAttempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AdminPasskeyDialog(
                    load: () async => List.of(entries),
                    register: () async => false,
                    delete: (id) async {
                      verificationAttempts++;
                      if (verificationAttempts == 1) {
                        throw StateError('Verification cancelled');
                      }
                      entries.removeWhere((entry) => entry.id == id);
                    },
                    errorMessage: (_, fallback) => fallback,
                  ),
                ),
                child: const Text('Open menu'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('ลงทะเบียน Passkey แล้ว'), findsNothing);
      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();
      expect(find.text('ลงทะเบียน Passkey แล้ว'), findsOneWidget);
      expect(
        find.text('เพิ่ม Passkey สำหรับอุปกรณ์นี้').hitTestable(),
        findsOneWidget,
      );

      final delete = find.byTooltip('ลบ Passkey');
      final confirm = find.text('ยืนยันตัวตนและลบ');
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(verificationAttempts, 0);
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();
      expect(verificationAttempts, 0);

      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('ลบ Passkey ไม่สำเร็จ'), findsOneWidget);
      expect(find.text('MacBook'), findsOneWidget);

      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(verificationAttempts, 2);
      expect(find.text('ลบ Passkey แล้ว'), findsOneWidget);
      expect(find.text('MacBook'), findsNothing);
      expect(find.text('ลงทะเบียน Passkey'), findsOneWidget);
    },
  );
}
