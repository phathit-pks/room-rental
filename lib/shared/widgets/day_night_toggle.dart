import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A sliding day/night switch: the thumb crossfades between a sun and a
/// moon while the sky behind it fades from clouds to stars with a
/// looping shooting star once night mode is active.
class DayNightToggle extends StatefulWidget {
  const DayNightToggle({
    super.key,
    required this.isDark,
    required this.onChanged,
    this.width = 96,
    this.height = 48,
  });

  final bool isDark;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;

  @override
  State<DayNightToggle> createState() => _DayNightToggleState();
}

class _DayNightToggleState extends State<DayNightToggle>
    with TickerProviderStateMixin {
  late final AnimationController _toggleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: widget.isDark ? 1 : 0,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _toggleController,
    curve: Curves.easeInOutCubic,
  );
  late final AnimationController _shootController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isDark) _shootController.repeat();
  }

  @override
  void didUpdateWidget(covariant DayNightToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDark != oldWidget.isDark) {
      if (widget.isDark) {
        _toggleController.forward();
        _shootController.repeat();
      } else {
        _toggleController.reverse();
        _shootController.stop();
      }
    }
  }

  @override
  void dispose() {
    _toggleController.dispose();
    _shootController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onChanged(!widget.isDark),
      child: Semantics(
        toggled: widget.isDark,
        button: true,
        label: widget.isDark ? 'สลับเป็นโหมดกลางวัน' : 'สลับเป็นโหมดกลางคืน',
        child: AnimatedBuilder(
          animation: Listenable.merge([_curve, _shootController]),
          builder: (context, _) {
            final t = _curve.value;
            return SizedBox(
              width: widget.width,
              height: widget.height,
              child: CustomPaint(
                painter: _SkyPainter(t: t, shootT: _shootController.value),
                child: Align(
                  alignment: Alignment(-1 + 2 * t, 0),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _Thumb(size: widget.height - 8, t: t),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.size, required this.t});

  final double size;
  final double t;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 1 - t, child: _Sun(size: size)),
          Opacity(opacity: t, child: _Moon(size: size)),
        ],
      ),
    );
  }
}

class _Sun extends StatelessWidget {
  const _Sun({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Colors.white, Color(0xFFFDE68A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFDE68A).withAlpha(140),
            blurRadius: size * 0.6,
            spreadRadius: size * 0.05,
          ),
        ],
      ),
    );
  }
}

class _Moon extends StatelessWidget {
  const _Moon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFF1F5F9), Color(0xFFCBD5E1)],
        ),
      ),
      child: CustomPaint(painter: _MoonCratersPainter()),
    );
  }
}

class _MoonCratersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFCBD5E1).withAlpha(160);
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center + const Offset(-4, -2), size.width * 0.12, paint);
    canvas.drawCircle(center + const Offset(3, 4), size.width * 0.09, paint);
    canvas.drawCircle(center + const Offset(5, -5), size.width * 0.06, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.t, required this.shootT});

  /// 0 = day, 1 = night.
  final double t;

  /// 0..1 looping progress of the shooting star / star twinkle.
  final double shootT;

  static const _dayTop = Color(0xFF7DD3FC);
  static const _dayBottom = Color(0xFFBFDBFE);
  static const _nightTop = Color(0xFF0F172A);
  static const _nightBottom = Color(0xFF1E3A5F);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );

    final top = Color.lerp(_dayTop, _nightTop, t)!;
    final bottom = Color.lerp(_dayBottom, _nightBottom, t)!;
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(rect);
    canvas.drawRRect(rrect, skyPaint);

    canvas.save();
    canvas.clipRRect(rrect);

    if (t < 0.98) _paintClouds(canvas, size, opacity: 1 - t);
    if (t > 0.02) {
      _paintStars(canvas, size, opacity: t);
      _paintShootingStar(canvas, size, opacity: t);
    }

    canvas.restore();
  }

  void _paintClouds(Canvas canvas, Size size, {required double opacity}) {
    final paint = Paint()
      ..color = Colors.white.withAlpha((opacity * 230).round());
    final puffs = [
      Offset(size.width * 0.62, size.height * 0.78),
      Offset(size.width * 0.74, size.height * 0.68),
      Offset(size.width * 0.84, size.height * 0.80),
      Offset(size.width * 0.50, size.height * 0.88),
    ];
    for (final puff in puffs) {
      canvas.drawCircle(puff, size.height * 0.22, paint);
    }
  }

  void _paintStars(Canvas canvas, Size size, {required double opacity}) {
    final positions = [
      Offset(size.width * 0.18, size.height * 0.28),
      Offset(size.width * 0.30, size.height * 0.60),
      Offset(size.width * 0.42, size.height * 0.22),
      Offset(size.width * 0.55, size.height * 0.45),
      Offset(size.width * 0.22, size.height * 0.75),
    ];
    final paint = Paint()
      ..color = Colors.white.withAlpha((opacity * 230).round());
    for (var i = 0; i < positions.length; i++) {
      final twinkle = (math.sin(shootT * 2 * math.pi + i) + 1) / 2;
      canvas.drawCircle(positions[i], 1.0 + twinkle * 0.6, paint);
    }
  }

  void _paintShootingStar(Canvas canvas, Size size, {required double opacity}) {
    final progress = shootT;
    final fade = math.sin(progress * math.pi).clamp(0.0, 1.0);
    final start = Offset(size.width * 0.15, size.height * 0.15);
    final end = Offset(size.width * 0.65, size.height * 0.55);
    final head = Offset.lerp(start, end, progress)!;
    final tail = Offset.lerp(start, end, (progress - 0.18).clamp(0.0, 1.0))!;

    final tailPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withAlpha((opacity * fade * 200).round()),
          Colors.white.withAlpha(0),
        ],
      ).createShader(Rect.fromPoints(tail, head))
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tail, head, tailPaint);

    final headPaint = Paint()
      ..color = Colors.white.withAlpha((opacity * fade * 255).round());
    canvas.drawCircle(head, 1.6, headPaint);
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.shootT != shootT;
  }
}
