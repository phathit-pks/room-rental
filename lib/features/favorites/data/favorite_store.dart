import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteStore extends ChangeNotifier {
  FavoriteStore._();

  static final instance = FavoriteStore._();
  static const _storageKey = 'favorite_listing_ids_v1';

  final Set<String> _ids = {};
  bool _loaded = false;

  bool contains(String listingId) => _ids.contains(listingId);

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

  Future<bool> toggle(String listingId) async {
    if (!_loaded) await load();
    final liked = !_ids.remove(listingId);
    if (liked) _ids.add(listingId);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(_ids.toList()));
    return liked;
  }
}
