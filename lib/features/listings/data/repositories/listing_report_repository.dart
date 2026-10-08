import 'package:room_rental/core/config/supabase_config.dart';

class ListingReportRepository {
  const ListingReportRepository();

  Future<void> submit({
    required String listingId,
    required String reason,
    String? description,
  }) async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw StateError('ต้องเข้าสู่ระบบก่อนรายงานประกาศ');
    }
    final trimmedDescription = description?.trim();
    await client.from('listing_reports').insert({
      'listing_id': listingId,
      'reporter_id': user.id,
      'reason': reason,
      'description': trimmedDescription?.isEmpty == true
          ? null
          : trimmedDescription,
    });
  }
}
