import 'package:room_rental/core/config/supabase_config.dart';
import 'package:room_rental/features/locations/domain/location_matcher.dart';

class RentalPostParser {
  const RentalPostParser();

  Future<Map<String, dynamic>> parse({
    required String text,
    String? sourceUrl,
    DateTime? postedAt,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) throw StateError('Supabase is not configured');

    final response = await client.functions.invoke(
      'parse-rental-post',
      body: {
        'text': text.trim(),
        if (sourceUrl?.trim().isNotEmpty ?? false)
          'source_url': sourceUrl!.trim(),
        if (postedAt != null) 'posted_at': postedAt.toUtc().toIso8601String(),
      },
    );

    final payload = response.data;
    if (payload is! Map) throw const FormatException('Invalid parser response');
    if (payload['error'] != null) throw StateError(payload['error'].toString());
    final data = payload['data'];
    if (data is! Map) throw const FormatException('Parser returned no data');
    return LocationMatcher.enrich(Map<String, dynamic>.from(data), text);
  }
}
