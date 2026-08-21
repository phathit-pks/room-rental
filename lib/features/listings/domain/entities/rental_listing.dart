class RentalListing {
  const RentalListing({
    required this.id,
    required this.title,
    required this.location,
    required this.monthlyPrice,
    required this.monthlyPriceMin,
    required this.monthlyPriceMax,
    required this.imageUrl,
    required this.currency,
    required this.propertyType,
    this.mapUrl,
    this.latitude,
    this.longitude,
    this.distanceMeters,
    this.description,
    this.address,
    this.amenities = const [],
    this.galleryUrls = const [],
    this.sourceUrl,
    this.contactPhone,
    this.submittedByName,
    this.submittedByEmail,
    this.advertisementEndsAt,
  });

  final String id;
  final String title;
  final String location;
  final int monthlyPrice;
  final int monthlyPriceMin;
  final int monthlyPriceMax;
  final String imageUrl;
  final String currency;
  final String propertyType;
  final String? mapUrl;
  final double? latitude;
  final double? longitude;
  final double? distanceMeters;
  final String? description;
  final String? address;
  final List<String> amenities;
  final List<String> galleryUrls;
  final String? sourceUrl;
  final String? contactPhone;
  final String? submittedByName;
  final String? submittedByEmail;
  final DateTime? advertisementEndsAt;
}
