import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/features/listings/data/repositories/listing_query_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const scope = 'test-project';
  const query = ['page', 'Vientiane', null, null, 1, 9];
  const key =
      'public_listing_queries_v1:$scope:["page","Vientiane",null,null,1,9]';
  const maxAge = Duration(minutes: 5);

  test('loads a fresh persisted result without fetching', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      key: '$now\n${jsonEncode({'rows': [], 'count': 0})}',
    });

    final result = await ListingQueryCache.read(
      scope: scope,
      query: query,
      maxAge: maxAge,
      fetch: () async => throw StateError('Unexpected fetch'),
    );

    expect(result, {'rows': [], 'count': 0});
  });

  test('coalesces refreshes and keeps an expired result offline', () async {
    const oldResult = {'rows': [], 'count': 0};
    final expired = DateTime.now().subtract(const Duration(minutes: 6));
    SharedPreferences.setMockInitialValues({
      key: '${expired.millisecondsSinceEpoch}\n${jsonEncode(oldResult)}',
    });
    final response = Completer<Map<String, dynamic>>();
    var calls = 0;
    Future<Map<String, dynamic>> read() => ListingQueryCache.read(
      scope: scope,
      query: query,
      maxAge: maxAge,
      fetch: () {
        calls++;
        return response.future;
      },
    );

    final first = read();
    final second = read();
    final results = Future.wait([first, second]);
    await Future<void>.delayed(Duration.zero);
    response.completeError(Exception('offline'));

    expect(await results, [oldResult, oldResult]);
    expect(calls, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(key),
      startsWith('${expired.millisecondsSinceEpoch}'),
    );
  });
}
