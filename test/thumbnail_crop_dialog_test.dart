import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:room_rental/core/theme/app_theme.dart';
import 'package:room_rental/core/utils/thumbnail_cropper.dart';
import 'package:room_rental/features/admin/presentation/widgets/thumbnail_crop_dialog.dart';

void main() {
  final wideJpeg = Uint8List.fromList(
    image.encodeJpg(image.Image(width: 800, height: 400)),
  );

  Future<Rect?> openAndConfirm(
    WidgetTester tester, {
    Offset drag = Offset.zero,
  }) async {
    final source = ThumbnailCropSource.decode(wideJpeg, 'room.jpg');
    Rect? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<Rect>(
                context: context,
                builder: (_) => ThumbnailCropDialog(source: source),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    if (drag != Offset.zero) {
      await tester.drag(find.byType(InteractiveViewer), drag);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('ใช้รูปนี้'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('starts with a centered 4:3 crop covering the full height', (
    tester,
  ) async {
    final area = (await openAndConfirm(tester))!;
    expect(area.top, closeTo(0, 0.5));
    expect(area.height, closeTo(400, 0.5));
    expect(area.width, closeTo(400 * 4 / 3, 0.5));
    expect(area.left, closeTo((800 - 400 * 4 / 3) / 2, 0.5));
  });

  testWidgets('dragging the photo right moves the crop toward its left edge', (
    tester,
  ) async {
    final area = (await openAndConfirm(tester, drag: const Offset(2000, 0)))!;
    expect(area.left, closeTo(0, 0.5));
    expect(area.width, closeTo(400 * 4 / 3, 0.5));
  });

  test('crop returns an image of the requested size', () {
    final source = ThumbnailCropSource.decode(wideJpeg, 'room.jpg');
    final cropped = image.decodeImage(
      source.crop(const Rect.fromLTWH(100, 0, 400, 300)),
    )!;
    expect(cropped.width, 400);
    expect(cropped.height, 300);
  });
}
