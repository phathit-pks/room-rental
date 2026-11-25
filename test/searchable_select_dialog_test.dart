import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/core/theme/app_theme.dart';
import 'package:room_rental/shared/widgets/searchable_select_field.dart';

void main() {
  testWidgets('area picker closes without changing the selected area', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 440);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SearchableSelectField(
            label: 'แขวง',
            items: const ['เวียงจันทน์', 'จำปาสัก'],
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('แขวง'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    expect(selected, isNull);

    await tester.tap(find.text('แขวง'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'จำปา');
    await tester.pumpAndSettle();
    expect(find.text('เวียงจันทน์'), findsNothing);
    await tester.tap(find.text('จำปาสัก'));
    await tester.pumpAndSettle();
    expect(selected, 'จำปาสัก');
  });
}
