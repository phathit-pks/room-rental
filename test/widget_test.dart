import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/app/app.dart';
import 'package:room_rental/shared/widgets/app_logo.dart';
import 'package:room_rental/shared/widgets/day_night_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'shows the rental search home page',
    (tester) async {
      const statusBarHeight = 59.0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.padding = const FakeViewPadding(top: statusBarHeight);
      addTearDown(tester.view.resetPadding);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const RoomRentalApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final logo = find.byType(AppLogo);
      expect(logo, findsOneWidget);
      expect(tester.getTopLeft(logo).dy, greaterThanOrEqualTo(statusBarHeight));
      final signIn = find.text('เข้าสู่ระบบ');
      expect(
        tester.getTopLeft(signIn).dy,
        greaterThanOrEqualTo(statusBarHeight),
      );
      expect(find.text('ค้นหา'), findsOneWidget);
      expect(find.text('ล้างค่า'), findsOneWidget);

      final trustLabels = [
        'ประกาศตรวจสอบแล้ว',
        'ติดต่อได้ทันที',
        'บันทึกห้องที่ชอบ',
      ].map((label) => tester.getTopLeft(find.text(label))).toList();
      expect(trustLabels.map((position) => position.dy).toSet(), hasLength(1));
      expect(trustLabels[0].dx, lessThan(trustLabels[1].dx));
      expect(trustLabels[1].dx, lessThan(trustLabels[2].dx));

      final themeToggle = find.byType(DayNightToggle);
      expect(themeToggle, findsNothing);

      final menuButton = find.byTooltip('เปิดเมนู');
      expect(
        tester.getTopLeft(menuButton).dy,
        greaterThanOrEqualTo(statusBarHeight),
      );
      await tester.tap(menuButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('ค้นหาบนแผนที่'), findsOneWidget);
      expect(find.text('ผู้ดูแลระบบ'), findsNothing);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routes,
        isNot(contains('/admin')),
      );
      expect(themeToggle.hitTestable(), findsOneWidget);
      await tester.tap(themeToggle);
      await tester.pump();
      expect(tester.widget<DayNightToggle>(themeToggle).isDark, isTrue);
      await tester.tap(themeToggle);
      await tester.pump();
      expect(tester.widget<DayNightToggle>(themeToggle).isDark, isFalse);
      await tester.tap(find.text('ค้นหาห้อง'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('ค้นหาบนแผนที่'), findsNothing);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
