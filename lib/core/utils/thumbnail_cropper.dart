import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:image/image.dart' as image;

/// A decoded, upright copy of a picked photo that can be cropped repeatedly.
class ThumbnailCropSource {
  ThumbnailCropSource._(this._image, this.fileName)
    : previewBytes = Uint8List.fromList(image.encodeJpg(_image, quality: 85));

  /// Matches the listing card photo area so the crop is what visitors see.
  static const double aspectRatio = 4 / 3;
  static const int _maxDimension = 2000;

  final image.Image _image;
  final String fileName;
  final Uint8List previewBytes;

  Size get size => Size(_image.width.toDouble(), _image.height.toDouble());

  static ThumbnailCropSource decode(Uint8List bytes, String fileName) {
    final decoded = image.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('ไม่สามารถอ่านไฟล์รูปนี้ได้');
    }
    var upright = image.bakeOrientation(decoded);
    if (upright.width > _maxDimension || upright.height > _maxDimension) {
      upright = upright.width >= upright.height
          ? image.copyResize(upright, width: _maxDimension)
          : image.copyResize(upright, height: _maxDimension);
    }
    return ThumbnailCropSource._(upright, fileName);
  }

  /// [area] is in this image's pixel coordinates.
  Uint8List crop(Rect area) {
    final left = area.left.round().clamp(0, _image.width - 1);
    final top = area.top.round().clamp(0, _image.height - 1);
    final cropped = image.copyCrop(
      _image,
      x: left,
      y: top,
      width: area.width.round().clamp(1, _image.width - left),
      height: area.height.round().clamp(1, _image.height - top),
    );
    return Uint8List.fromList(image.encodeJpg(cropped, quality: 92));
  }
}
