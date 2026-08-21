import 'dart:typed_data';

import 'package:image/image.dart' as image;

class CompressedThumbnail {
  const CompressedThumbnail({
    required this.bytes,
    required this.fileName,
    required this.wasCompressed,
  });

  final Uint8List bytes;
  final String fileName;
  final bool wasCompressed;
}

class ThumbnailCompressor {
  static const int maxBytes = 1024 * 1024;
  // A smaller target makes cards load quickly on mobile networks while the
  // hard upload limit remains 1 MB.
  static const int targetBytes = 450 * 1024;

  static CompressedThumbnail compress(Uint8List source, String fileName) {
    if (source.lengthInBytes <= maxBytes) {
      return CompressedThumbnail(
        bytes: source,
        fileName: fileName,
        wasCompressed: false,
      );
    }

    final decoded = image.decodeImage(source);
    if (decoded == null) {
      throw const FormatException('ไม่สามารถอ่านไฟล์รูปนี้ได้');
    }

    var working = decoded;
    const maxDimension = 1600;
    if (working.width > maxDimension || working.height > maxDimension) {
      working = working.width >= working.height
          ? image.copyResize(working, width: maxDimension)
          : image.copyResize(working, height: maxDimension);
    }

    Uint8List? result;
    for (var quality = 85; quality >= 35; quality -= 10) {
      result = Uint8List.fromList(image.encodeJpg(working, quality: quality));
      if (result.lengthInBytes <= targetBytes) break;
    }

    while (result!.lengthInBytes > targetBytes &&
        (working.width > 480 || working.height > 480)) {
      working = image.copyResize(
        working,
        width: (working.width * .8).round(),
        height: (working.height * .8).round(),
      );
      result = Uint8List.fromList(image.encodeJpg(working, quality: 65));
    }

    if (result.lengthInBytes > maxBytes) {
      throw const FormatException('รูปมีรายละเอียดสูงเกินไป กรุณาเลือกรูปอื่น');
    }
    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    return CompressedThumbnail(
      bytes: result,
      fileName: '$baseName.jpg',
      wasCompressed: true,
    );
  }
}
