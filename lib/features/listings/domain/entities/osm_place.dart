class OsmPlace {
  const OsmPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.osmUrl,
    this.address,
  });

  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String osmUrl;
}
