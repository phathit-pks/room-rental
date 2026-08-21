import 'package:room_rental/core/config/supabase_config.dart';
import 'package:room_rental/core/utils/google_maps_location.dart';
import 'package:room_rental/features/listings/domain/entities/rental_listing.dart';

class ListingPage {
  const ListingPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalItems,
  });

  final List<RentalListing> items;
  final int page;
  final int pageSize;
  final int totalItems;

  int get totalPages => totalItems == 0 ? 1 : (totalItems / pageSize).ceil();
}

abstract interface class ListingRepository {
  Future<List<RentalListing>> search({
    String? province,
    String? district,
    String? village,
  });

  Future<ListingPage> searchPage({
    String? province,
    String? district,
    String? village,
    int page = 1,
    int pageSize = 9,
  });

  Future<List<RentalListing>> searchWithinRadius({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  });
}

class SupabaseListingRepository implements ListingRepository {
  const SupabaseListingRepository();

  Future<List<RentalListing>> featuredAdvertisements() async {
    final client = SupabaseConfig.client;
    if (client == null) return const [];
    final now = DateTime.now().toUtc().toIso8601String();
    final response = await client
        .from('listing_advertisements')
        .select(
          'ends_at,scraped_listings!inner(id,title,monthly_price,monthly_price_min,'
          'monthly_price_max,currency,province,district,village,source_url,'
          'contact_phone,property_type,thumbnail_url,map_url,latitude,longitude,'
          'parsed_data,gallery_urls)',
        )
        .eq('active', true)
        .lte('starts_at', now)
        .gte('ends_at', now)
        .order('priority', ascending: false)
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(response)
        .where((row) => row['scraped_listings'] is Map)
        .map(
          (row) => _fromRow(
            Map<String, dynamic>.from(row['scraped_listings'] as Map),
            advertisementEndsAt: DateTime.tryParse('${row['ends_at']}'),
          ),
        )
        .toList();
  }

  @override
  Future<List<RentalListing>> searchWithinRadius({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) return const [];
    final response = await client.rpc(
      'search_listings_in_radius',
      params: {
        'center_lat': latitude,
        'center_lng': longitude,
        'radius_meters': radiusMeters,
      },
    );
    final listings =
        List<Map<String, dynamic>>.from(response).map(_fromRow).toList()
          ..sort((a, b) {
            final first = a.distanceMeters ?? double.infinity;
            final second = b.distanceMeters ?? double.infinity;
            return first.compareTo(second);
          });
    return listings.take(30).toList();
  }

  @override
  Future<ListingPage> searchPage({
    String? province,
    String? district,
    String? village,
    int page = 1,
    int pageSize = 9,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      return ListingPage(
        items: const [],
        page: page,
        pageSize: pageSize,
        totalItems: 0,
      );
    }
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 365))
        .toIso8601String();
    var request = client
        .from('scraped_listings')
        .select(
          'id,title,monthly_price,monthly_price_min,monthly_price_max,'
          'currency,province,district,village,source_url,contact_phone,'
          'property_type,thumbnail_url,map_url,latitude,longitude,'
          'parsed_data,gallery_urls',
        )
        .eq('status', 'approved')
        .contains('parsed_data', const {'manual_entry': true})
        .or('source_posted_at.is.null,source_posted_at.gte.$cutoff');
    if (province != null) request = request.eq('province', province);
    if (district != null) request = request.eq('district', district);
    if (village != null) request = request.eq('village', village);
    final from = (page - 1) * pageSize;
    final response = await request
        .order('created_at', ascending: false)
        .range(from, from + pageSize - 1)
        .count();
    return ListingPage(
      items: List<Map<String, dynamic>>.from(
        response.data,
      ).map(_fromRow).toList(),
      page: page,
      pageSize: pageSize,
      totalItems: response.count,
    );
  }

  Future<ListingPage> recommendNearby({
    required double latitude,
    required double longitude,
  }) async {
    final results = await Future.wait([
      searchWithinRadius(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: 50000,
      ),
      searchPage(pageSize: 9),
    ]);
    final nearby = results[0] as List<RentalListing>;
    final latest = (results[1] as ListingPage).items;
    final nearbyById = {for (final item in nearby) item.id: item};
    final recommendations = <RentalListing>[];
    if (latest.isNotEmpty) {
      final newest = latest.first;
      recommendations.add(nearbyById.remove(newest.id) ?? newest);
    }
    recommendations.addAll(nearbyById.values);
    if (recommendations.length < 9) {
      for (final item in latest.skip(1)) {
        if (recommendations.any((existing) => existing.id == item.id)) continue;
        recommendations.add(item);
        if (recommendations.length == 9) break;
      }
    }
    return ListingPage(
      items: recommendations.take(9).toList(),
      page: 1,
      pageSize: 9,
      totalItems: recommendations.take(9).length,
    );
  }

  @override
  Future<List<RentalListing>> search({
    String? province,
    String? district,
    String? village,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) return const [];

    var rows = await _fetch(
      province: province,
      district: district,
      village: village,
    );
    if (rows.isEmpty && village != null) {
      rows = await _fetch(province: province, district: district);
    }
    if (rows.isEmpty && district != null) {
      rows = await _fetch(province: province);
    }
    if (rows.isEmpty && province != null) {
      rows = await _fetch();
    }

    return rows.take(9).map(_fromRow).toList();
  }

  Future<List<Map<String, dynamic>>> _fetch({
    String? province,
    String? district,
    String? village,
  }) async {
    final client = SupabaseConfig.client!;
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 365))
        .toIso8601String();
    var request = client
        .from('scraped_listings')
        .select(
          'id,title,monthly_price,monthly_price_min,monthly_price_max,'
          'currency,province,district,village,'
          'source_url,contact_phone,property_type,thumbnail_url,map_url,'
          'latitude,longitude,parsed_data,gallery_urls',
        )
        .eq('status', 'approved')
        .contains('parsed_data', const {'manual_entry': true})
        .or('source_posted_at.is.null,source_posted_at.gte.$cutoff');
    if (province != null) request = request.eq('province', province);
    if (district != null) request = request.eq('district', district);
    if (village != null) request = request.eq('village', village);
    return List<Map<String, dynamic>>.from(
      await request.order('created_at', ascending: false).limit(12),
    );
  }

  RentalListing _fromRow(
    Map<String, dynamic> row, {
    DateTime? advertisementEndsAt,
  }) {
    final parsedData = row['parsed_data'] is Map
        ? Map<String, dynamic>.from(row['parsed_data'] as Map)
        : const <String, dynamic>{};
    final location = [
      row['village'],
      row['district'],
      row['province'],
    ].whereType<String>().where((value) => value.isNotEmpty).join(' • ');
    final storedMapUrl = row['map_url'] as String?;
    final mapLocation = GoogleMapsLocation.tryParse(storedMapUrl ?? '');
    return RentalListing(
      id: row['id'] as String,
      title: (row['title'] as String?)?.trim().isNotEmpty == true
          ? row['title'] as String
          : 'ห้องพักให้เช่า',
      location: location.isEmpty ? 'ไม่ระบุพื้นที่' : location,
      monthlyPrice: (row['monthly_price'] as num?)?.round() ?? 0,
      monthlyPriceMin:
          (row['monthly_price_min'] as num?)?.round() ??
          (row['monthly_price'] as num?)?.round() ??
          0,
      monthlyPriceMax:
          (row['monthly_price_max'] as num?)?.round() ??
          (row['monthly_price'] as num?)?.round() ??
          0,
      imageUrl: row['thumbnail_url'] as String? ?? '',
      currency: row['currency'] as String? ?? 'LAK',
      propertyType: row['property_type'] as String? ?? 'apartment',
      mapUrl: mapLocation?.url ?? storedMapUrl,
      latitude: (row['latitude'] as num?)?.toDouble() ?? mapLocation?.latitude,
      longitude:
          (row['longitude'] as num?)?.toDouble() ?? mapLocation?.longitude,
      distanceMeters: (row['distance_meters'] as num?)?.toDouble(),
      description: parsedData['description'] as String?,
      address: parsedData['address'] as String?,
      amenities: parsedData['amenities'] is List
          ? List<String>.from(parsedData['amenities'] as List)
          : const [],
      galleryUrls: row['gallery_urls'] is List
          ? List<String>.from(row['gallery_urls'] as List)
          : const [],
      sourceUrl: row['source_url'] as String?,
      contactPhone: row['contact_phone'] as String?,
      submittedByName: parsedData['submitted_by_name'] as String?,
      submittedByEmail: parsedData['submitted_by_email'] as String?,
      advertisementEndsAt: advertisementEndsAt,
    );
  }
}
