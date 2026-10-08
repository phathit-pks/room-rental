import 'package:room_rental/core/config/supabase_config.dart';

class ListingRatingSummary {
  const ListingRatingSummary({
    required this.average,
    required this.count,
    this.myRating,
  });

  final double average;
  final int count;
  final int? myRating;
}

class ListingRatingRepository {
  const ListingRatingRepository();

  Future<ListingRatingSummary> fetchSummary(String listingId) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      return const ListingRatingSummary(average: 0, count: 0);
    }
    final response = await client
        .from('listing_ratings')
        .select('rating,rater_id')
        .eq('listing_id', listingId);
    final rows = List<Map<String, dynamic>>.from(response);
    if (rows.isEmpty) {
      return const ListingRatingSummary(average: 0, count: 0);
    }
    final currentUserId = client.auth.currentUser?.id;
    var total = 0;
    int? myRating;
    for (final row in rows) {
      final rating = (row['rating'] as num).toInt();
      total += rating;
      if (currentUserId != null && row['rater_id'] == currentUserId) {
        myRating = rating;
      }
    }
    return ListingRatingSummary(
      average: total / rows.length,
      count: rows.length,
      myRating: myRating,
    );
  }

  Future<void> rate(String listingId, int rating) async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw StateError('ต้องเข้าสู่ระบบก่อนให้คะแนน');
    }
    await client
        .from('listing_ratings')
        .upsert({
          'listing_id': listingId,
          'rater_id': user.id,
          'rating': rating,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'listing_id,rater_id');
  }
}
