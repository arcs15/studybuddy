import 'dart:math' as math;
import 'package:flutter/material.dart';

String shortNum(double v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k' : v.toStringAsFixed(0);

class CopyrightFooter extends StatelessWidget {
  const CopyrightFooter({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            '© ${DateTime.now().year} arcXstudio. All rights reserved.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
}

class DonutChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final Widget center;
  final double size;
  const DonutChart({super.key, required this.values, required this.colors, required this.center, this.size = 150});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(values, colors, Theme.of(context).colorScheme.surfaceContainerHighest),
          ),
          center,
        ]),
      );
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color track;
  _DonutPainter(this.values, this.colors, this.track);

  @override
  void paint(Canvas canvas, Size s) {
    const stroke = 20.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s.width - stroke, s.height - stroke);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, 2 * math.pi, false, bg);
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      if (sweep <= 0) continue;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = colors[i];
      canvas.drawArc(rect, start, sweep, false, p);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Bars for each month. Bar color turns orange at 80% of the limit and red above it.
class MonthBars extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final double? limit;
  final double height;
  const MonthBars({super.key, required this.labels, required this.values, this.limit, this.height = 150});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    var maxV = 1.0;
    for (final v in values) {
      if (v > maxV) maxV = v;
    }
    if (limit != null && limit! > maxV) maxV = limit!;
    maxV = maxV * 1.1;

    Color barColor(double v) {
      final l = limit;
      if (l == null || l <= 0) return cs.primary;
      if (v >= l) return Colors.red;
      if (v >= l * 0.8) return Colors.orange;
      return Colors.green;
    }

    return SizedBox(
      height: height + 44,
      child: Stack(children: [
        Positioned.fill(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(shortNum(values[i]), style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 4),
                  Container(
                    height: values[i] / maxV * height,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: barColor(values[i]),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i], style: const TextStyle(fontSize: 11)),
                ]),
              ),
          ]),
        ),
        if (limit != null && limit! > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 19 + limit! / maxV * height,
            child: Container(height: 1.5, color: Colors.red),
          ),
      ]),
    );
  }
}
