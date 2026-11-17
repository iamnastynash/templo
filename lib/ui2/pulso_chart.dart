// The Pulso line: a smooth curve coloured point by point on the quality scale
// (P.quality), a soft glow under it, an area that fades downward, and a
// one-time entrance — the line draws itself in, then one light passes along
// it. No loop: the entrance is a single forward run of a controller whose
// duration comes from [motion], so reduced motion shows the finished line.
//
// It draws only the values it is given. Fewer than two values draw nothing;
// the caller says why in words, as every other absence here does.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'skeleton/guide_plot.dart';
import 'theme.dart';

class GlowLine extends StatefulWidget {
  /// Oldest first.
  final List<double> values;

  /// How good each value is, 0 (bad) … 1 (good). Null draws the whole line in
  /// [color] instead — for a series this app makes no value judgement about.
  final double Function(double v)? quality;

  /// The line's colour when [quality] is null. Defaults to the page ink.
  final Color? color;

  final double height;
  final bool area;

  const GlowLine(
    this.values, {
    super.key,
    this.quality,
    this.color,
    this.height = 48,
    this.area = true,
  });

  @override
  State<GlowLine> createState() => _GlowLineState();
}

class _GlowLineState extends State<GlowLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final d = motion(context, Motion.chartDraw);
    if (d == Duration.zero) {
      _t.value = 1;
    } else {
      _t.duration = d;
      _t.forward();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final q = widget.quality;
    final cols = [
      for (final v in widget.values)
        q == null ? (widget.color ?? p.ink) : p.qualityOf(q(v)),
    ];
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(
            painter: GlowLinePainter(widget.values, cols,
                glow: p.glow, ring: p.bg, area: widget.area, t: _t),
          ),
        ),
      ),
    );
  }
}

/// Public so a test can read what was drawn.
class GlowLinePainter extends CustomPainter implements GuidePlot {
  final List<double> values;
  final List<Color> colors;
  final double glow;
  final Color ring;
  final bool area;
  final Animation<double> t;

  GlowLinePainter(this.values, this.colors,
      {required this.glow,
      required this.ring,
      required this.area,
      required this.t})
      : super(repaint: t);

  @override
  Color get guideLineColor => colors.isEmpty ? C.white : colors.last;

  // The entrance: the first 60 % draws the line, the rest carries the light.
  static const _drawShare = .6;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0) return;
    const padX = 5.0, padTop = 6.0, padBottom = 6.0;
    final mn = values.reduce(math.min), mx = values.reduce(math.max);
    final span = (mx - mn) == 0 ? 1.0 : mx - mn;
    final pts = [
      for (var i = 0; i < values.length; i++)
        Offset(
          padX + i / (values.length - 1) * (size.width - 2 * padX),
          padTop +
              (1 - (values[i] - mn) / span) *
                  (size.height - padTop - padBottom),
        ),
    ];
    final path = _smooth(pts);
    final x0 = pts.first.dx, x1 = pts.last.dx;
    final stops = [for (final o in pts) (o.dx - x0) / (x1 - x0)];
    final shader =
        ui.Gradient.linear(Offset(x0, 0), Offset(x1, 0), colors, stops);

    final v = t.value;
    final draw = Curves.easeOutCubic.transform((v / _drawShare).clamp(0.0, 1.0));
    final metric = path.computeMetrics().first;
    final shown = metric.extractPath(0, metric.length * draw);

    // Area: the line's own colours, fading downward, fading in with the line.
    if (area && draw > 0) {
      final rect = Offset.zero & size;
      final fill = Path.from(path)
        ..lineTo(x1, size.height)
        ..lineTo(x0, size.height)
        ..close();
      canvas.saveLayer(rect, Paint());
      canvas.drawPath(
          fill,
          Paint()
            ..shader = shader
            ..color = C.white.withValues(alpha: .12 * draw));
      canvas.drawRect(
          rect,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = ui.Gradient.linear(
                Offset.zero,
                Offset(0, size.height),
                [C.white, C.white.withValues(alpha: 0)]));
      canvas.restore();
    }

    // Glow, then the crisp line on top of it.
    canvas.drawPath(
        shown,
        Paint()
          ..shader = shader
          ..color = C.white.withValues(alpha: glow)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6));
    canvas.drawPath(
        shown,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round);

    // The light passing along, once.
    if (v > _drawShare && v < 1) {
      final k = Curves.easeInOut.transform((v - _drawShare) / (1 - _drawShare));
      final len = metric.length;
      final seg = len * .1;
      final head = (len + seg) * k;
      final piece = metric.extractPath(
          math.max(0, head - seg), math.min(len, head));
      final fade = math.sin(k * math.pi);
      canvas.drawPath(
          piece,
          Paint()
            ..color = C.white.withValues(alpha: .85 * fade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6));
    }

    // Today's point, once the line has reached it.
    if (draw >= 1) {
      final end = pts.last;
      canvas.drawCircle(end, 7, Paint()..color = colors.last.withValues(alpha: .22));
      canvas.drawCircle(end, 4.6, Paint()..color = ring);
      canvas.drawCircle(end, 3.4, Paint()..color = colors.last);
    }
  }

  /// Catmull-Rom through every point, as cubic segments.
  static Path _smooth(List<Offset> p) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 0; i < p.length - 1; i++) {
      final p0 = i == 0 ? p[i] : p[i - 1];
      final p1 = p[i], p2 = p[i + 1];
      final p3 = i + 2 < p.length ? p[i + 2] : p2;
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(GlowLinePainter o) =>
      o.values != values || o.colors != colors || o.glow != glow;
}
