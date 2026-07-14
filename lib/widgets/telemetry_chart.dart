import 'package:flutter/material.dart';

import '../service/metric_registry.dart';
import '../models/serial_log_entry.dart';

class TelemetryPoint {
  final DateTime time;
  final double value;
  const TelemetryPoint(this.time, this.value);
}

class ChartMarker {
  final DateTime time;
  final LogLevel level;
  const ChartMarker(this.time, this.level);
}

class TelemetryChart extends StatelessWidget {
  final Map<String, List<TelemetryPoint>> series;
  final List<ChartMarker> markers;

  const TelemetryChart({
    super.key,
    required this.series,
    this.markers = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Legend(seriesIds: series.keys.toList()),
        const SizedBox(height: 8),
        Expanded(
          child: CustomPaint(
            painter: _ChartPainter(series: series, markers: markers),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final List<String> seriesIds;
  const _Legend({required this.seriesIds});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      children: [
        for (final id in seriesIds)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: MetricRegistry.forId(id).color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                MetricRegistry.forId(id).label,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final Map<String, List<TelemetryPoint>> series;
  final List<ChartMarker> markers;

  _ChartPainter({required this.series, required this.markers});

  @override
  void paint(Canvas canvas, Size size) {
    final nonEmpty = series.values.where((points) => points.isNotEmpty);
    if (nonEmpty.isEmpty) return;

    final allTimes = [
      for (final points in nonEmpty) ...points.map((p) => p.time),
      ...markers.map((m) => m.time),
    ];
    final minTime = allTimes.reduce((a, b) => a.isBefore(b) ? a : b);
    final maxTime = allTimes.reduce((a, b) => a.isAfter(b) ? a : b);
    final totalMs = maxTime.difference(minTime).inMilliseconds;

    double xFor(DateTime t) {
      if (totalMs <= 0) return 0;
      return (t.difference(minTime).inMilliseconds / totalMs) * size.width;
    }

    for (final entry in series.entries) {
      final points = entry.value;
      if (points.length < 2) continue;

      final spec = MetricRegistry.forId(entry.key);
      final values = points.map((p) => p.value);
      final minV = values.reduce((a, b) => a < b ? a : b);
      final maxV = values.reduce((a, b) => a > b ? a : b);
      final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);

      double yFor(double v) {
        final normalized = (v - minV) / range; // 0..1
        return size.height - (normalized * size.height * 0.85) - (size.height * 0.075);
      }

      final path = Path();
      path.moveTo(xFor(points.first.time), yFor(points.first.value));
      for (final p in points.skip(1)) {
        path.lineTo(xFor(p.time), yFor(p.value));
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = spec.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );

      final last = points.last;
      canvas.drawCircle(
        Offset(xFor(last.time), yFor(last.value)),
        3,
        Paint()..color = spec.color,
      );
    }

    for (final marker in markers) {
      final x = xFor(marker.time);
      final color = marker.level == LogLevel.error
          ? const Color(0xffFF5C5C)
          : const Color(0xffFFC857);

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = color.withOpacity(0.35)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(Offset(x, 6), 2.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.series != series || oldDelegate.markers != markers;
}