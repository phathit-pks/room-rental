import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
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

  static Future<CompressedThumbnail> compress(
    Uint8List source,
    String fileName,
  ) async {
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

    final normalizedJpeg = Uint8List.fromList(
      image.encodeJpg(working, quality: 90),
    );
    Uint8List? result;
    for (var quality = 85; quality >= 35; quality -= 10) {
      result = await FlutterImageCompress.compressWithList(
        normalizedJpeg,
        minWidth: 1600,
        minHeight: 1600,
        quality: quality,
        format: CompressFormat.webp,
      );
      if (result.lengthInBytes <= targetBytes) break;
    }

    var reducedMaxDimension = 1280;
    while (result!.lengthInBytes > targetBytes && reducedMaxDimension >= 480) {
      working = image.copyResize(
        working,
        width: working.width > working.height ? reducedMaxDimension : null,
        height: working.height >= working.width ? reducedMaxDimension : null,
      );
      result = await FlutterImageCompress.compressWithList(
        Uint8List.fromList(image.encodeJpg(working, quality: 85)),
        minWidth: reducedMaxDimension,
        minHeight: reducedMaxDimension,
        quality: 65,
        format: CompressFormat.webp,
      );
      reducedMaxDimension = (reducedMaxDimension * .75).round();
    }

    if (result.lengthInBytes > maxBytes) {
      throw const FormatException('รูปมีรายละเอียดสูงเกินไป กรุณาเลือกรูปอื่น');
    }
    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    return CompressedThumbnail(
      bytes: result,
      fileName: '$baseName.webp',
      wasCompressed: source.lengthInBytes != result.lengthInBytes,
    );
  }
}
