import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A full-screen meteor shower ("ฝนดาวตก") played once over [duration]
/// when switching from day into night mode. Calls [onCompleted] when the
/// shower finishes so the caller can remove it from the tree.
class MeteorShowerOverlay extends StatefulWidget {
  const MeteorShowerOverlay({
    super.key,
    required this.duration,
    required this.onCompleted,
  });

  final Duration duration;
  final VoidCallback onCompleted;

  @override
  State<MeteorShowerOverlay> createState() => _MeteorShowerOverlayState();
}

class _MeteorShowerOverlayState extends State<MeteorShowerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_handleStatus);

  late final List<_Meteor> _meteors = _generateMeteors();

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onCompleted();
  }

  List<_Meteor> _generateMeteors() {
    final random = math.Random();
    return List.generate(14, (_) {
      return _Meteor(
        startFraction: random.nextDouble() * 0.55,
        durationFraction: 0.22 + random.nextDouble() * 0.18,
        startX: random.nextDouble(),
        startY: -0.2 + random.nextDouble() * 0.5,
        trailLength: 70 + random.nextDouble() * 110,
        thickness: 1.2 + random.nextDouble() * 1.6,
        dirX: -(0.45 + random.nextDouble() * 0.35),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _MeteorShowerPainter(
              progress: _controller.value,
              meteors: _meteors,
            ),
          );
        },
      ),
    );
  }
}

class _Meteor {
  const _Meteor({
    required this.startFraction,
    required this.durationFraction,
    required this.startX,
    required this.startY,
    required this.trailLength,
    required this.thickness,
    required this.dirX,
  });

  /// Fraction of the overall shower duration at which this meteor starts.
  final double startFraction;

  /// Fraction of the overall shower duration this meteor takes to fall.
  final double durationFraction;

  /// Relative (0..1) starting position within the screen.
  final double startX;
  final double startY;

  final double trailLength;
  final double thickness;

  /// Horizontal component of the fall direction (always negative, downward
  /// is implicit with a fixed vertical component of 1).
  final double dirX;
}

class _MeteorShowerPainter extends CustomPainter {
  _MeteorShowerPainter({required this.progress, required this.meteors});

  final double progress;
  final List<_Meteor> meteors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final travel = size.longestSide * 1.15;

    for (final meteor in meteors) {
      final localT =
          (progress - meteor.startFraction) / meteor.durationFraction;
      if (localT <= 0 || localT >= 1) continue;

      final direction = Offset(meteor.dirX, 1);
      final unit = direction / direction.distance;
      final start = Offset(
        meteor.startX * size.width,
        meteor.startY * size.height,
      );
      final head = start + unit * travel * localT;
      final tailT = (localT - meteor.trailLength / travel).clamp(0.0, 1.0);
      final tail = start + unit * travel * tailT;

      final fade = math.sin(localT * math.pi).clamp(0.0, 1.0);

      final tailPaint = Paint()
        ..strokeWidth = meteor.thickness
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.white.withAlpha((fade * 235).round()),
            Colors.white.withAlpha(0),
          ],
        ).createShader(Rect.fromPoints(tail, head));
      canvas.drawLine(tail, head, tailPaint);

      final headPaint = Paint()
        ..color = Colors.white.withAlpha((fade * 255).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, meteor.thickness * 1.4);
      canvas.drawCircle(head, meteor.thickness * 0.9, headPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeteorShowerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
