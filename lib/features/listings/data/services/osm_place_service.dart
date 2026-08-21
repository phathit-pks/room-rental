import 'package:room_rental/core/config/supabase_config.dart';
import 'package:room_rental/features/listings/domain/entities/osm_place.dart';

class OsmPlaceService {
  const OsmPlaceService();

  Future<List<OsmPlace>> search({
    String? province,
    String? district,
    String? village,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) return const [];
    final response = await client.functions.invoke(
      'search-osm-places',
      body: {'province': ?province, 'district': ?district, 'village': ?village},
    );
    final payload = response.data;
    if (payload is! Map) throw const FormatException('Invalid OSM response');
    if (payload['error'] != null) throw StateError(payload['error'].toString());
    final rows = payload['places'];
    if (rows is! List) return const [];
    return rows.map((row) {
      final item = Map<String, dynamic>.from(row as Map);
      return OsmPlace(
        id: item['id'] as String,
        name: item['name'] as String,
        address: item['address'] as String?,
        latitude: (item['latitude'] as num).toDouble(),
        longitude: (item['longitude'] as num).toDouble(),
        osmUrl: item['osm_url'] as String,
      );
    }).toList();
  }
}
