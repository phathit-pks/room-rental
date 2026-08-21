import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/core/utils/google_maps_location.dart';

void main() {
  test('creates directions URL from coordinates', () {
    final location = GoogleMapsLocation.tryParse(
      '17.908634442903843, 102.63205905992898',
    );
    expect(location, isNotNull);
    expect(location!.latitude, closeTo(17.908634442903843, .000001));
    expect(location.longitude, closeTo(102.63205905992898, .000001));
    expect(location.url, contains('google.com/maps/dir'));
    expect(location.url, contains('destination='));
  });

  test('keeps a supplied maps link', () {
    const link = 'https://maps.app.goo.gl/example';
    expect(GoogleMapsLocation.tryParse(link)?.url, link);
    expect(GoogleMapsLocation.tryParse(link)?.latitude, isNull);
  });

  test('extracts URL encoded destination coordinates', () {
    final location = GoogleMapsLocation.tryParse(
      'https://www.google.com/maps/dir/?api=1&destination=18.0198%2C102.6308',
    );
    expect(location?.latitude, closeTo(18.0198, .000001));
    expect(location?.longitude, closeTo(102.6308, .000001));
  });

  test('extracts coordinates from Google Maps data format', () {
    final location = GoogleMapsLocation.tryParse(
      'https://www.google.com/maps/place/example/data=!3d18.0284!4d102.6410',
    );
    expect(location?.latitude, closeTo(18.0284, .000001));
    expect(location?.longitude, closeTo(102.6410, .000001));
  });

  test('rejects invalid coordinates', () {
    expect(GoogleMapsLocation.tryParse('190, 250'), isNull);
  });
}
