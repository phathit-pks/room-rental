import 'package:room_rental/features/locations/data/location_store.dart';

abstract final class LocationMatcher {
  static Map<String, dynamic> enrich(
    Map<String, dynamic> parsed,
    String sourceText, {
    Map<String, Map<String, List<String>>>? hierarchy,
  }) {
    final locationData = hierarchy ?? LocationStore.instance.data;
    final candidates = <_Candidate>[];
    final normalizedSource = _normalize(sourceText);

    for (final provinceEntry in locationData.entries) {
      for (final districtEntry in provinceEntry.value.entries) {
        for (final village in districtEntry.value) {
          final path = [provinceEntry.key, districtEntry.key, village];
          var score = 0;
          for (var index = 0; index < path.length; index++) {
            final field = const ['province', 'district', 'village'][index];
            final expected = _normalize(path[index]);
            final supplied = _normalize(parsed[field]?.toString() ?? '');
            if (supplied.isNotEmpty && supplied == expected) {
              score++;
            } else if (expected.length >= 3 &&
                normalizedSource.contains(expected)) {
              score++;
            }
          }
          if (score >= 2) candidates.add(_Candidate(path, score));
        }
      }
    }

    if (candidates.isEmpty) return parsed;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final best = candidates.first;
    if (candidates.length > 1 && candidates[1].score == best.score) {
      return parsed;
    }

    final enriched = Map<String, dynamic>.from(parsed)
      ..['province'] = best.path[0]
      ..['district'] = best.path[1]
      ..['village'] = best.path[2]
      ..['location_matched'] = true;
    final missing = List<String>.from(
      enriched['missing_fields'] as List? ?? const [],
    );
    missing.removeWhere(
      (field) => const ['province', 'district', 'village'].contains(field),
    );
    enriched['missing_fields'] = missing;
    return enriched;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceFirst(RegExp(r'^(แขวง|เมือง|บ้าน|ນະຄອນ|ແຂວງ|ເມືອງ|ບ້ານ)'), '');
}

class _Candidate {
  const _Candidate(this.path, this.score);

  final List<String> path;
  final int score;
}
