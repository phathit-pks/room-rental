import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ListingQueryCache {
  static const _maxEntries = 48;
  static final _inFlight = <String, Future<Map<String, dynamic>>>{};

  static Future<Map<String, dynamic>> read({
    required String scope,
    required List<Object?> query,
    required Duration maxAge,
    required Future<Map<String, dynamic>> Function() fetch,
  }) async {
    final prefix = 'public_listing_queries_v1:$scope:';
    final key = '$prefix${jsonEncode(query)}';
    return _inFlight.putIfAbsent(
      key,
      () => _load(prefix, key, maxAge, fetch).whenComplete(() {
        _inFlight.remove(key);
      }),
    );
  }

  static Future<Map<String, dynamic>> _load(
    String prefix,
    String key,
    Duration maxAge,
    Future<Map<String, dynamic>> Function() fetch,
  ) async {
    SharedPreferences? preferences;
    Map<String, dynamic>? stale;
    try {
      preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(key);
      if (saved != null) {
        final separator = saved.indexOf('\n');
        final timestamp = DateTime.fromMillisecondsSinceEpoch(
          int.parse(saved.substring(0, separator)),
        );
        stale =
            jsonDecode(saved.substring(separator + 1)) as Map<String, dynamic>;
        final age = DateTime.now().difference(timestamp);
        if (!age.isNegative && age < maxAge) return stale;
      }
    } catch (_) {
      // A missing or invalid cache must not prevent a live request.
    }

    final Map<String, dynamic> result;
    try {
      result = await fetch();
    } on Exception {
      if (stale != null) return stale;
      rethrow;
    }

    if (preferences != null) {
      try {
        final storage = preferences;
        await storage.setString(
          key,
          '${DateTime.now().millisecondsSinceEpoch}\n${jsonEncode(result)}',
        );
        final entries =
            storage
                .getKeys()
                .where((entry) => entry.startsWith(prefix) && entry != key)
                .toList()
              ..sort(
                (a, b) => (storage.getString(b) ?? '').compareTo(
                  storage.getString(a) ?? '',
                ),
              );
        for (final entry in entries.skip(_maxEntries - 1)) {
          await storage.remove(entry);
        }
      } catch (_) {
        // Keep the remote result if local storage is full or unavailable.
      }
    }
    return result;
  }
}
