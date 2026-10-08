import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentlyViewedStore extends ChangeNotifier {
  RecentlyViewedStore._();

  static final instance = RecentlyViewedStore._();
  static const _storageKey = 'recently_viewed_listing_ids_v1';
  static const _maxItems = 12;

  final List<String> _ids = [];
  bool _loaded = false;

  List<String> get ids => List.unmodifiable(_ids);

  Future<void> load() async {
    if (_loaded) return;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is List) _ids.addAll(decoded.whereType<String>());
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> recordView(String listingId) async {
    if (!_loaded) await load();
    if (_ids.isNotEmpty && _ids.first == listingId) return;
    _ids.remove(listingId);
    _ids.insert(0, listingId);
    if (_ids.length > _maxItems) {
      _ids.removeRange(_maxItems, _ids.length);
    }
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(_ids));
  }
}
