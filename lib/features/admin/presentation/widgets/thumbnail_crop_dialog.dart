import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:room_rental/core/theme/app_colors.dart';
import 'package:room_rental/core/utils/thumbnail_cropper.dart';

/// Lets the user pan and zoom a photo inside the card frame. Pops the chosen
/// area in image pixel coordinates, or null when cancelled.
class ThumbnailCropDialog extends StatefulWidget {
  const ThumbnailCropDialog({super.key, required this.source});

  final ThumbnailCropSource source;

  @override
  State<ThumbnailCropDialog> createState() => _ThumbnailCropDialogState();
}

class _ThumbnailCropDialogState extends State<ThumbnailCropDialog> {
  final _controller = TransformationController();
  Size? _viewport;
  double _coverScale = 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initialize(Size viewport) {
    if (_viewport != null) return;
    final imageSize = widget.source.size;
    _viewport = viewport;
    _coverScale = math.max(
      viewport.width / imageSize.width,
      viewport.height / imageSize.height,
    );
    _controller.value = Matrix4.translationValues(
      (viewport.width - imageSize.width * _coverScale) / 2,
      (viewport.height - imageSize.height * _coverScale) / 2,
      0,
    );
  }

  Rect _visibleArea() {
    final viewport = _viewport!;
    final matrix = _controller.value;
    final scale = _coverScale * matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    return Rect.fromLTWH(
      -translation.x / scale,
      -translation.y / scale,
      viewport.width / scale,
      viewport.height / scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = widget.source.size;
    // Leave room for the title, hint and buttons on short screens.
    final frameHeight = math.max(
      160.0,
      MediaQuery.sizeOf(context).height - 320,
    );
    return AlertDialog(
      title: const Text('ปรับตำแหน่งรูป Thumbnail'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: frameHeight * ThumbnailCropSource.aspectRatio,
              ),
              child: AspectRatio(
                aspectRatio: ThumbnailCropSource.aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColoredBox(
                    color: context.colors.surfaceMuted,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _initialize(constraints.biggest);
                        return InteractiveViewer(
                          transformationController: _controller,
                          constrained: false,
                          minScale: 1,
                          maxScale: 5,
                          // Gentler than the default so each wheel tick zooms ~20%.
                          scaleFactor: 600,
                          child: SizedBox.fromSize(
                            size: imageSize * _coverScale,
                            child: Image.memory(
                              widget.source.previewBytes,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.pan_tool_alt_outlined,
                  size: 18,
                  color: context.colors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ลากเพื่อเลื่อนรูป • ใช้ scroll เมาส์หรือ 2 นิ้วเพื่อซูม\n'
                    'ส่วนในกรอบคือสิ่งที่จะแสดงบนการ์ด',
                    style: TextStyle(color: context.colors.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _visibleArea()),
          icon: const Icon(Icons.check),
          label: const Text('ใช้รูปนี้'),
        ),
      ],
    );
  }
}
