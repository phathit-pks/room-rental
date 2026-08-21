import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/app/app.dart';
import 'package:room_rental/shared/widgets/app_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('requires both privacy consents on first visit', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RoomRentalApp());
    await tester.pumpAndSettle();

    expect(find.text('นโยบายการใช้งานและความเป็นส่วนตัว'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.text('ยอมรับและเข้าสู่เว็บไซต์'), findsOneWidget);
  });

  testWidgets('shows the rental search home page', (tester) async {
    SharedPreferences.setMockInitialValues({
      'privacy_consent_version': 'privacy-v2',
      'privacy_policy_accepted': true,
      'voluntary_data_consent': true,
    });
    await tester.pumpWidget(const RoomRentalApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('ค้นหา'), findsOneWidget);
  });
}
