class GoogleMapsLocation {
  const GoogleMapsLocation({required this.url, this.latitude, this.longitude});

  final String url;
  final double? latitude;
  final double? longitude;

  static GoogleMapsLocation? tryParse(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      final coordinates = _coordinatesFromText(value);
      return GoogleMapsLocation(
        url: value,
        latitude: coordinates?.$1,
        longitude: coordinates?.$2,
      );
    }

    final coordinates = _coordinatesFromText(value);
    if (coordinates == null) return null;
    final latitude = coordinates.$1;
    final longitude = coordinates.$2;
    return GoogleMapsLocation(
      url: Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$latitude,$longitude',
      }).toString(),
      latitude: latitude,
      longitude: longitude,
    );
  }

  static (double, double)? _coordinatesFromText(String value) {
    String decoded;
    try {
      decoded = Uri.decodeFull(value);
    } catch (_) {
      decoded = value;
    }
    final commaMatch = RegExp(
      r'(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(decoded);
    final dataMatch = RegExp(
      r'!3d(-?\d{1,2}(?:\.\d+)?)!4d(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(decoded);
    final match = commaMatch ?? dataMatch;
    if (match == null) return null;
    final latitude = double.tryParse(match.group(1)!);
    final longitude = double.tryParse(match.group(2)!);
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return (latitude, longitude);
  }
}
