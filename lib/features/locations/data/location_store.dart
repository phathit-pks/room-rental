import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:room_rental/core/config/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationStore extends ChangeNotifier {
  LocationStore._();

  static final instance = LocationStore._();
  static const _storageKey = 'location_hierarchy_v1';
  static const _cacheVersionKey = 'location_cache_version';
  static const _cacheVersion = String.fromEnvironment(
    'CACHE_VERSION',
    defaultValue: '2026-08-05-1',
  );

  Map<String, Map<String, List<String>>> data = {};
  final Map<String, String> _provinceIds = {};
  final Map<String, String> _districtIds = {};
  bool remoteConnected = false;
  String? syncError;

  SupabaseClient get _client => SupabaseConfig.client!;

  Future<void> load() async {
    await _loadCache();
    if (SupabaseConfig.client != null) unawaited(refreshFromRemote());
  }

  Future<void> _loadCache() async {
    final preferences = await SharedPreferences.getInstance();
    final savedVersion = preferences.getString(_cacheVersionKey);
    if (savedVersion != _cacheVersion) {
      await preferences.remove(_storageKey);
      await preferences.setString(_cacheVersionKey, _cacheVersion);
      data = {};
      return;
    }
    final raw = preferences.getString(_storageKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    data = decoded.map(
      (province, districts) => MapEntry(
        province,
        (districts as Map<String, dynamic>).map(
          (district, villages) =>
              MapEntry(district, List<String>.from(villages as List)),
        ),
      ),
    );
  }

  Future<void> refreshFromRemote() async {
    try {
      final responses = await Future.wait([
        _client
            .from('provinces')
            .select('id,name')
            .order('sort_order')
            .order('name'),
        _client
            .from('districts')
            .select('id,province_id,name')
            .order('sort_order')
            .order('name'),
        _client
            .from('villages')
            .select('district_id,name')
            .order('sort_order')
            .order('name'),
      ]);
      final provinces = List<Map<String, dynamic>>.from(responses[0]);
      final districts = List<Map<String, dynamic>>.from(responses[1]);
      final villages = List<Map<String, dynamic>>.from(responses[2]);
      final next = <String, Map<String, List<String>>>{};
      _provinceIds.clear();
      _districtIds.clear();
      for (final row in provinces) {
        final name = row['name'] as String;
        _provinceIds[name] = row['id'] as String;
        next[name] = {};
      }
      for (final row in districts) {
        final province = _provinceIds.entries
            .firstWhere((entry) => entry.value == row['province_id'])
            .key;
        final name = row['name'] as String;
        _districtIds[_districtKey(province, name)] = row['id'] as String;
        next[province]![name] = [];
      }
      for (final row in villages) {
        final key = _districtIds.entries
            .firstWhere((entry) => entry.value == row['district_id'])
            .key;
        final parts = key.split('\u0000');
        next[parts[0]]![parts[1]]!.add(row['name'] as String);
      }
      data = next;
      remoteConnected = true;
      syncError = null;
      await _saveCache();
    } catch (error) {
      remoteConnected = false;
      syncError = error.toString();
    }
    notifyListeners();
  }

  String _districtKey(String province, String district) =>
      '$province\u0000$district';

  Future<void> _saveCache() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_cacheVersionKey, _cacheVersion);
    await preferences.setString(_storageKey, jsonEncode(data));
  }

  Future<void> _finishMutation() async {
    await refreshFromRemote();
    if (!remoteConnected) throw StateError(syncError ?? 'Supabase sync failed');
  }

  Future<void> addProvince(String name) async {
    await _client.from('provinces').insert({'name': name.trim()});
    await _finishMutation();
  }

  Future<void> renameProvince(String oldName, String newName) async {
    await _client
        .from('provinces')
        .update({'name': newName.trim()})
        .eq('id', _provinceIds[oldName]!);
    await _finishMutation();
  }

  Future<void> deleteProvince(String name) async {
    await _client.from('provinces').delete().eq('id', _provinceIds[name]!);
    await _finishMutation();
  }

  Future<void> addDistrict(String province, String name) async {
    await _client.from('districts').insert({
      'province_id': _provinceIds[province],
      'name': name.trim(),
    });
    await _finishMutation();
  }

  Future<int> importDistricts(String province, List<String> names) async {
    final uniqueNames = names
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    final existing = data[province]?.keys.toSet() ?? <String>{};
    final newNames = uniqueNames.difference(existing);
    if (newNames.isEmpty) return 0;
    await _client
        .from('districts')
        .insert(
          newNames
              .map(
                (name) => {'province_id': _provinceIds[province], 'name': name},
              )
              .toList(),
        );
    await _finishMutation();
    return newNames.length;
  }

  Future<void> renameDistrict(
    String province,
    String oldName,
    String newName,
  ) async {
    await _client
        .from('districts')
        .update({'name': newName.trim()})
        .eq('id', _districtIds[_districtKey(province, oldName)]!);
    await _finishMutation();
  }

  Future<void> deleteDistrict(String province, String name) async {
    await _client
        .from('districts')
        .delete()
        .eq('id', _districtIds[_districtKey(province, name)]!);
    await _finishMutation();
  }

  Future<void> addVillage(String province, String district, String name) async {
    await _client.from('villages').insert({
      'district_id': _districtIds[_districtKey(province, district)],
      'name': name.trim(),
    });
    await _finishMutation();
  }

  Future<int> importVillages(
    String province,
    String district,
    List<String> names,
  ) async {
    final uniqueNames = names
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    final existing = data[province]?[district]?.toSet() ?? <String>{};
    final newNames = uniqueNames.difference(existing);
    if (newNames.isEmpty) return 0;
    await _client
        .from('villages')
        .insert(
          newNames
              .map(
                (name) => {
                  'district_id': _districtIds[_districtKey(province, district)],
                  'name': name,
                },
              )
              .toList(),
        );
    await _finishMutation();
    return newNames.length;
  }

  Future<int> replaceVillages(
    String province,
    String district,
    List<String> names,
  ) async {
    final uniqueNames = names
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueNames.isEmpty) {
      throw const FormatException('ไฟล์ต้องมีรายชื่อบ้านอย่างน้อย 1 รายการ');
    }
    final result = await _client.rpc(
      'replace_district_villages',
      params: {
        'target_district_id': _districtIds[_districtKey(province, district)],
        'village_names': uniqueNames,
      },
    );
    await _finishMutation();
    return (result as num).toInt();
  }

  Future<void> renameVillage(
    String province,
    String district,
    String oldName,
    String newName,
  ) async {
    await _client
        .from('villages')
        .update({'name': newName.trim()})
        .eq('district_id', _districtIds[_districtKey(province, district)]!)
        .eq('name', oldName);
    await _finishMutation();
  }

  Future<void> deleteVillage(
    String province,
    String district,
    String name,
  ) async {
    await _client
        .from('villages')
        .delete()
        .eq('district_id', _districtIds[_districtKey(province, district)]!)
        .eq('name', name);
    await _finishMutation();
  }

  Future<int> importRows(List<(String, String, String)> rows) async {
    var imported = 0;
    for (final row in rows) {
      final province = row.$1.trim();
      final district = row.$2.trim();
      final village = row.$3.trim();
      if (province.isEmpty || district.isEmpty || village.isEmpty) continue;
      var provinceId = _provinceIds[province];
      if (provinceId == null) {
        final created = await _client
            .from('provinces')
            .insert({'name': province})
            .select('id')
            .single();
        provinceId = created['id'] as String;
        _provinceIds[province] = provinceId;
      }
      final key = _districtKey(province, district);
      var districtId = _districtIds[key];
      if (districtId == null) {
        final created = await _client
            .from('districts')
            .insert({'province_id': provinceId, 'name': district})
            .select('id')
            .single();
        districtId = created['id'] as String;
        _districtIds[key] = districtId;
      }
      final exists = await _client
          .from('villages')
          .select('id')
          .eq('district_id', districtId)
          .eq('name', village)
          .maybeSingle();
      if (exists == null) {
        await _client.from('villages').insert({
          'district_id': districtId,
          'name': village,
        });
        imported++;
      }
    }
    await _finishMutation();
    return imported;
  }

  int get districtCount =>
      data.values.fold(0, (total, districts) => total + districts.length);

  int get villageCount => data.values.fold(
    0,
    (total, districts) =>
        total + districts.values.fold(0, (sum, list) => sum + list.length),
  );
}
