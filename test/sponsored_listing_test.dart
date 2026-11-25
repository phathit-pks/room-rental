import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/core/theme/app_theme.dart';
import 'package:room_rental/features/home/presentation/widgets/sponsored_listing.dart';
import 'package:room_rental/features/listings/domain/entities/rental_listing.dart';

void main() {
  testWidgets('rotating ads keep their height and action position', (
    tester,
  ) async {
    final advertisements = Future.value([
      _listing('1', 'Short title', 'Vientiane'),
      _listing(
        '2',
        'A longer title for an apartment near the city center',
        'A longer location that wraps on narrow mobile screens',
        amenities: ['Parking', 'Air conditioning', 'Internet access'],
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 320,
              child: Column(
                children: [
                  SponsoredListing(advertisements: advertisements),
                  const Text('Search section'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final searchSection = find.text('Search section');
    final action = find.widgetWithText(FilledButton, 'ดูรายละเอียด');
    expect(find.text('Short title'), findsOneWidget);
    final searchTop = tester.getTopLeft(searchSection).dy;
    final actionTop = tester.getTopLeft(action).dy;

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getTopLeft(searchSection).dy, searchTop);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Short title'), findsNothing);
    expect(action, findsOneWidget);
    expect(tester.getTopLeft(searchSection).dy, searchTop);
    expect(tester.getTopLeft(action).dy, actionTop);
  });
}

RentalListing _listing(
  String id,
  String title,
  String location, {
  List<String> amenities = const [],
}) => RentalListing(
  id: id,
  title: title,
  location: location,
  monthlyPrice: 0,
  monthlyPriceMin: 0,
  monthlyPriceMax: 0,
  imageUrl: '',
  currency: 'LAK',
  propertyType: 'apartment',
  amenities: amenities,
);
