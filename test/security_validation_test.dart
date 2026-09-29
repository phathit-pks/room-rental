import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/core/utils/safe_external_uri.dart';
import 'package:room_rental/core/utils/thumbnail_compressor.dart';

void main() {
  group('external URL validation', () {
    test('allows ordinary HTTPS URLs', () {
      expect(
        SafeExternalUri.https('https://example.com/listing?id=1'),
        Uri.parse('https://example.com/listing?id=1'),
      );
    });

    test('blocks unsafe schemes and URLs containing credentials', () {
      expect(SafeExternalUri.https('javascript:alert(1)'), isNull);
      expect(SafeExternalUri.https('http://example.com'), isNull);
      expect(SafeExternalUri.https('https://user:pass@example.com'), isNull);
    });

    test('normalizes valid phone numbers and rejects injected values', () {
      expect(
        SafeExternalUri.telephone('+856 20 5555-1234'),
        Uri(scheme: 'tel', path: '+8562055551234'),
      );
      expect(SafeExternalUri.telephone('12345?body=payload'), isNull);
    });
  });

  test('rejects non-image upload bytes even when the file is small', () async {
    await expectLater(
      ThumbnailCompressor.compress(
        Uint8List.fromList('<script>alert(1)</script>'.codeUnits),
        'photo.jpg',
      ),
      throwsFormatException,
    );
  });
}
