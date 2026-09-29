import 'package:room_rental/features/listings/domain/entities/rental_listing.dart';

class NearbySearchCache {
  NearbySearchCache({
    required this.province,
    required this.district,
    required this.village,
    required this.latitude,
    required this.longitude,
    required List<RentalListing> items,
  }) : items = List<RentalListing>.from(items),
       lastSynced = DateTime.now();

  final String? province;
  final String? district;
  final String? village;
  final double latitude;
  final double longitude;
  List<RentalListing> items;
  DateTime lastSynced;

  bool matches({String? province, String? district, String? village}) =>
      this.province == province &&
      this.district == district &&
      this.village == village;

  void merge(Iterable<RentalListing> updates) {
    final byId = {for (final item in items) item.id: item};
    for (final item in updates) {
      byId[item.id] = item;
    }
    items = byId.values.toList();
  }
}
