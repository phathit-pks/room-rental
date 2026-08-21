import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const sourcePath = 'assets/branding/source/icon/logo-icon.png';
  final source = img.decodePng(File(sourcePath).readAsBytesSync());
  if (source == null) throw StateError('Cannot decode $sourcePath');

  void save(String path, int size) {
    final resized = img.copyResize(
      source,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(resized, level: 9));
  }

  save('web/favicon.png', 64);
  save('web/icons/Icon-192.png', 192);
  save('web/icons/Icon-512.png', 512);
  save('web/icons/Icon-maskable-192.png', 192);
  save('web/icons/Icon-maskable-512.png', 512);
}
