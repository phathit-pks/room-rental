import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/features/locations/domain/location_matcher.dart';

void main() {
  final hierarchy = {
    'นครหลวงเวียงจันทน์': {
      'ไซเสดถา': ['ดงโดก', 'หนองบอน'],
      'สีโคดตะบอง': ['สีไค'],
    },
  };

  test('fills the hierarchy when two location levels match', () {
    final result = LocationMatcher.enrich(
      {
        'province': null,
        'district': 'เมืองไซเสดถา',
        'village': 'บ้านดงโดก',
        'missing_fields': ['province'],
      },
      'ห้องพักอยู่บ้านดงโดก เมืองไซเสดถา',
      hierarchy: hierarchy,
    );

    expect(result['province'], 'นครหลวงเวียงจันทน์');
    expect(result['district'], 'ไซเสดถา');
    expect(result['village'], 'ดงโดก');
    expect(result['location_matched'], isTrue);
    expect(result['missing_fields'], isEmpty);
  });

  test('does not infer from only one matching location level', () {
    final result = LocationMatcher.enrich(
      {
        'province': null,
        'district': null,
        'village': 'ดงโดก',
        'missing_fields': ['province', 'district'],
      },
      'ห้องพักอยู่ดงโดก',
      hierarchy: hierarchy,
    );

    expect(result['province'], isNull);
    expect(result['district'], isNull);
    expect(result['location_matched'], isNull);
  });
}
