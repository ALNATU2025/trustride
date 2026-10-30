import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

enum MapMode { idle, route, tracking, driver }

/// A stylised, animated map of the Freetown peninsula drawn with a painter.
/// No API key needed. Replace with google_maps_flutter or flutter_map when
/// you connect real location services.
class TRMap extends StatefulWidget {
  const TRMap({
    super.key,
    this.mode = MapMode.idle,
    this.progress = 0,
    this.showHeat = false,
  });

  final MapMode mode;

  /// 0..1 — position of the trip car along the route in [MapMode.tracking].
  final double progress;
  final bool showHeat;

  @override
  State<TRMap> createState() => _TRMapState();
}

class _TRMapState extends State<TRMap> with TickerProviderStateMixin {
  late final AnimationController _ambient =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))
        ..repeat();
  late final AnimationController _draw = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward();

  @override
  void didUpdateWidget(covariant TRMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _draw.forward(from: 0);
  }

  @override
  void dispose() {
    _ambient.dispose();
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_ambient, _draw]),
        builder: (context, _) => CustomPaint(
          painter: _MapPainter(
            t: _ambient.value,
            draw: Curves.easeInOutCubic.transform(_draw.value),
            mode: widget.mode,
            progress: widget.progress,
            heat: widget.showHeat,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.t,
    required this.draw,
    required this.mode,
    required this.progress,
    required this.heat,
  });

  final double t;
  final double draw;
  final MapMode mode;
  final double progress;
  final bool heat;

  Offset _p(Size s, double x, double y) => Offset(s.width * x, s.height * y);

  Path _roadA(Size s) => Path()
    ..moveTo(-20, s.height * 0.30)
    ..cubicTo(s.width * 0.3, s.height * 0.27, s.width * 0.6, s.height * 0.36,
        s.width + 20, s.height * 0.29);

  Path _roadB(Size s) => Path()
    ..moveTo(s.width * 0.18, s.height + 20)
    ..cubicTo(s.width * 0.25, s.height * 0.7, s.width * 0.36, s.height * 0.45,
        s.width * 0.46, s.height * 0.12);

  Path _roadC(Size s) => Path()
    ..moveTo(-20, s.height * 0.58)
    ..cubicTo(s.width * 0.35, s.height * 0.55, s.width * 0.65, s.height * 0.60,
        s.width + 20, s.height * 0.50);

  Path _roadD(Size s) => Path()
    ..moveTo(s.width * 0.72, s.height + 20)
    ..cubicTo(s.width * 0.68, s.height * 0.75, s.width * 0.78, s.height * 0.5,
        s.width * 0.86, s.height * 0.18);

  Path _route(Size s) => Path()
    ..moveTo(s.width * 0.76, s.height * 0.78)
    ..cubicTo(s.width * 0.70, s.height * 0.62, s.width * 0.52, s.height * 0.56,
        s.width * 0.42, s.height * 0.44)
    ..cubicTo(s.width * 0.32, s.height * 0.32, s.width * 0.22, s.height * 0.26,
        s.width * 0.18, s.height * 0.20);

  @override
  void paint(Canvas canvas, Size s) {
    // Land
    canvas.drawRect(Offset.zero & s, Paint()..color = TR.land);

    // Atlantic coastline
    final sea = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height * 0.10)
      ..cubicTo(s.width * 0.8, s.height * 0.17, s.width * 0.62, s.height * 0.08,
          s.width * 0.48, s.height * 0.15)
      ..cubicTo(s.width * 0.32, s.height * 0.22, s.width * 0.15, s.height * 0.16,
          0, s.height * 0.20)
      ..close();
    canvas.drawPath(sea, Paint()..color = TR.sea);
    // gentle waves
    final wave = Paint()
      ..color = Colors.white.fade(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final y = s.height * (0.03 + i * 0.03);
      final dx = math.sin((t * 2 * math.pi) + i) * 8;
      canvas.drawLine(Offset(s.width * 0.08 + dx + i * 40, y),
          Offset(s.width * 0.08 + dx + i * 40 + 22, y), wave);
    }

    // Parks
    final park = Paint()..color = TR.park;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s.width * 0.02, s.height * 0.66, s.width * 0.2,
                s.height * 0.14),
            const Radius.circular(18)),
        park);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s.width * 0.6, s.height * 0.70, s.width * 0.34,
                s.height * 0.16),
            const Radius.circular(22)),
        park);

    // Blocks
    final block = Paint()..color = const Color(0xFFE4E8E2);
    final rnd = math.Random(7);
    for (var i = 0; i < 26; i++) {
      final x = rnd.nextDouble() * s.width;
      final y = s.height * 0.22 + rnd.nextDouble() * s.height * 0.78;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, 18 + rnd.nextDouble() * 26,
                  12 + rnd.nextDouble() * 18),
              const Radius.circular(4)),
          block);
    }

    // Roads: casing then fill
    final roads = [_roadA(s), _roadB(s), _roadC(s), _roadD(s)];
    final casing = Paint()
      ..color = const Color(0xFFDDE2E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    for (final r in roads) {
      canvas.drawPath(r, casing);
    }
    for (final r in roads) {
      canvas.drawPath(r, fill);
    }

    _label(canvas, 'Atlantic Ocean', _p(s, 0.06, 0.05), const Color(0xFF5C7A96),
        11, FontWeight.w700);
    _label(canvas, 'Lumley', _p(s, 0.05, 0.62), TR.subtle, 10, FontWeight.w600);
    _label(canvas, 'Congo Cross', _p(s, 0.70, 0.84), TR.subtle, 10,
        FontWeight.w600);
    _label(canvas, 'Wilkinson Rd', _p(s, 0.50, 0.34), TR.subtle, 10,
        FontWeight.w600);

    // Heat zones for drivers
    if (heat) {
      final pulse = 0.85 + 0.15 * math.sin(t * 2 * math.pi * 2);
      for (final z in [
        [0.30, 0.42, 70.0, TR.green],
        [0.76, 0.62, 58.0, TR.green],
        [0.62, 0.22, 44.0, TR.gold],
      ]) {
        final c = z[3] as Color;
        canvas.drawCircle(
            _p(s, z[0] as double, z[1] as double),
            (z[2] as double) * pulse,
            Paint()
              ..shader = RadialGradient(colors: [c.fade(0.32), c.fade(0.0)])
                  .createShader(Rect.fromCircle(
                      center: _p(s, z[0] as double, z[1] as double),
                      radius: z[2] as double)));
      }
      _label(canvas, 'Busy · Central', _p(s, 0.22, 0.42), TR.green, 11,
          FontWeight.w800);
    }

    // Ambient cars
    if (mode == MapMode.idle || mode == MapMode.driver) {
      for (var i = 0; i < roads.length; i++) {
        final metric = roads[i].computeMetrics().first;
        final phase = (t + i * 0.27) % 1.0;
        final tan = metric.getTangentForOffset(metric.length * phase);
        if (tan != null) _car(canvas, tan.position, tan.angle, TR.navy, 0.9);
      }
    }

    final route = _route(s);
    final metric = route.computeMetrics().first;

    if (mode == MapMode.route || mode == MapMode.tracking) {
      final drawn = metric.extractPath(0, metric.length * draw);
      canvas.drawPath(
          drawn,
          Paint()
            ..color = TR.navy.fade(0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..strokeCap = StrokeCap.round);
      canvas.drawPath(
          drawn,
          Paint()
            ..shader = const LinearGradient(colors: [TR.green, TR.navy])
                .createShader(Offset.zero & s)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round);
      if (mode == MapMode.tracking) {
        final done = metric.extractPath(0, metric.length * progress);
        canvas.drawPath(
            done,
            Paint()
              ..color = TR.greenBright
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..strokeCap = StrokeCap.round);
      }
    }

    // Pickup pulse
    final start = metric.getTangentForOffset(0)!.position;
    final end = metric.getTangentForOffset(metric.length)!.position;
    final pulse = (t * 6) % 1.0;
    if (mode != MapMode.tracking) {
      canvas.drawCircle(start, 14 + 26 * pulse,
          Paint()..color = TR.green.fade(0.28 * (1 - pulse)));
      canvas.drawCircle(start, 11, Paint()..color = Colors.white);
      canvas.drawCircle(start, 7.5, Paint()..color = TR.green);
    }

    if (mode == MapMode.route || mode == MapMode.tracking) {
      // Destination pin
      final pin = Paint()..color = TR.navy;
      canvas.drawCircle(end.translate(0, -16), 13, pin);
      final tail = Path()
        ..moveTo(end.dx - 8, end.dy - 10)
        ..lineTo(end.dx, end.dy + 2)
        ..lineTo(end.dx + 8, end.dy - 10)
        ..close();
      canvas.drawPath(tail, pin);
      canvas.drawCircle(end.translate(0, -16), 5, Paint()..color = Colors.white);
    }

    if (mode == MapMode.tracking) {
      final tan = metric.getTangentForOffset(
          metric.length * progress.clamp(0.0, 1.0))!;
      canvas.drawCircle(tan.position, 22 + 6 * math.sin(t * 2 * math.pi * 3),
          Paint()..color = TR.green.fade(0.18));
      _car(canvas, tan.position, tan.angle, TR.green, 1.3);
    }

    if (mode == MapMode.driver) {
      final c = _p(s, 0.5, 0.55);
      canvas.drawCircle(
          c, 26 + 18 * pulse, Paint()..color = TR.navy.fade(0.2 * (1 - pulse)));
      _car(canvas, c, -math.pi / 2, TR.navy, 1.4);
    }
  }

  void _car(Canvas canvas, Offset at, double angle, Color color, double scale) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(-angle);
    canvas.scale(scale);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(1, 2), width: 26, height: 15),
            const Radius.circular(5)),
        Paint()..color = Colors.black.fade(0.12));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 26, height: 15),
            const Radius.circular(5)),
        Paint()..color = color);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(5, 0), width: 7, height: 11),
            const Radius.circular(2)),
        Paint()..color = Colors.white.fade(0.7));
    canvas.restore();
  }

  void _label(Canvas canvas, String text, Offset at, Color color, double size,
      FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: weight,
              fontFamily: 'PlusJakartaSans')),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}
