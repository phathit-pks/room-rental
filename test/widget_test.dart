import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/app/app.dart';
import 'package:room_rental/shared/widgets/app_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the rental search home page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RoomRentalApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('ค้นหา'), findsOneWidget);
    expect(find.text('ล้างค่า'), findsOneWidget);
  });
}
