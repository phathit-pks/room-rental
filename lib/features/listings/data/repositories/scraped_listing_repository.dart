import 'dart:typed_data';

import 'package:room_rental/core/config/supabase_config.dart';

class ScrapedListingRepository {
  const ScrapedListingRepository();

  Future<String> saveDraft({
    required String rawText,
    required Map<String, dynamic> parsedData,
    String? sourceUrl,
    String status = 'approved',
  }) async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw StateError('กรุณาเข้าสู่ระบบ Admin อีกครั้ง');
    }

    final row = await client
        .from('scraped_listings')
        .insert(
          _databaseRow(
            userId: user.id,
            rawText: rawText,
            sourceUrl: sourceUrl,
            parsedData: parsedData,
            status: status,
          ),
        )
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<int> saveManyDrafts(List<Map<String, dynamic>> items) async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw StateError('กรุณาเข้าสู่ระบบ Admin อีกครั้ง');
    }
    var imported = 0;
    for (var start = 0; start < items.length; start += 100) {
      final end = (start + 100).clamp(0, items.length);
      final rows = items.sublist(start, end).map((item) {
        final parsedData = item['parsed_data'] as Map<String, dynamic>;
        return _databaseRow(
          userId: user.id,
          rawText: item['raw_text'] as String,
          sourceUrl: item['source_url'] as String?,
          parsedData: parsedData,
        );
      }).toList();
      await client.from('scraped_listings').insert(rows);
      imported += rows.length;
    }
    return imported;
  }

  Map<String, dynamic> _databaseRow({
    required String userId,
    required String rawText,
    required String? sourceUrl,
    required Map<String, dynamic> parsedData,
    String status = 'approved',
  }) {
    return {
      'raw_text': rawText.trim(),
      'source_url': _nullable(sourceUrl),
      'source_posted_at': _nullable(parsedData['posted_at']?.toString()),
      'parsed_data': parsedData,
      'title': _nullable(parsedData['title']?.toString()),
      'property_type': _normalizedPropertyType(
        parsedData['property_type']?.toString(),
      ),
      'thumbnail_url': _nullable(parsedData['thumbnail_url']?.toString()),
      'gallery_urls': List<String>.from(
        parsedData['gallery_urls'] as List? ?? const [],
      ),
      'map_url': _nullable(parsedData['map_url']?.toString()),
      'latitude': parsedData['latitude'],
      'longitude': parsedData['longitude'],
      'monthly_price': parsedData['monthly_price'],
      'monthly_price_min':
          parsedData['monthly_price_min'] ?? parsedData['monthly_price'],
      'monthly_price_max':
          parsedData['monthly_price_max'] ?? parsedData['monthly_price'],
      'currency': _nullable(parsedData['currency']?.toString()),
      'province': _nullable(parsedData['province']?.toString()),
      'district': _nullable(parsedData['district']?.toString()),
      'village': _nullable(parsedData['village']?.toString()),
      'contact_phone': _nullable(parsedData['contact_phone']?.toString()),
      'status': status,
      'created_by': userId,
    };
  }

  String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _normalizedPropertyType(String? value) => switch (value) {
    'room' || 'apartment' || 'house' || 'condo' => value!,
    _ => 'apartment',
  };

  Future<String> uploadThumbnail({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return _uploadImage(bytes: bytes, fileName: fileName, folder: 'thumbnails');
  }

  Future<List<String>> uploadGalleryImages(
    List<({Uint8List bytes, String fileName})> images,
  ) async {
    if (images.length > 4) {
      throw const FormatException('อัปโหลดรูปภายในได้ไม่เกิน 4 รูป');
    }
    final urls = <String>[];
    for (final image in images) {
      urls.add(
        await _uploadImage(
          bytes: image.bytes,
          fileName: image.fileName,
          folder: 'gallery',
        ),
      );
    }
    return urls;
  }

  Future<String> _uploadImage({
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw StateError('กรุณาเข้าสู่ระบบ Admin อีกครั้ง');
    }
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    final path =
        '$folder/${user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await client.storage.from('property-images').uploadBinary(path, bytes);
    return client.storage.from('property-images').getPublicUrl(path);
  }
}
