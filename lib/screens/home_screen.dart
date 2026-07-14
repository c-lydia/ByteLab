import 'dart:async';

import 'package:flutter/material.dart';

import '../service/build_service.dart';
import '../service/build_status.dart';
import '../service/device_info.dart';
import '../service/device_scanner.dart';
import '../service/metric_registry.dart';
import '../models/serial_log_entry.dart';
import '../service/serial_service.dart';
import '../service/telemetry_sample.dart';
import '../service/serial_service_scope.dart';
import '../widgets/action_tile.dart';
import '../widgets/byte_card.dart';
import '../widgets/device_header.dart';
import '../widgets/device_tile.dart';
import '../widgets/event_tile.dart';
import '../widgets/metric_chip.dart';
import '../widgets/telemetry_chart.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  SerialService? _serialService;
  StreamSubscription<SerialLogEntry>? _logSub;
  StreamSubscription<TelemetrySample>? _telemetrySub;

  final List<SerialLogEntry> _recentEvents = [];
  static const int _maxRecentEvents = 5;

  final Map<String, List<TelemetryPoint>> _telemetryHistory = {};
  final List<ChartMarker> _chartMarkers = [];
  static const int _maxHistoryPoints = 60;

  static const _chartedMetrics = ['cpu', 'ram', 'voltage'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final scope = SerialServiceScope.of(context);
    if (_serialService == scope.serialService) return;

    _logSub?.cancel();
    _telemetrySub?.cancel();
    _serialService = scope.serialService;

    _recentEvents
      ..clear()
      ..addAll(_serialService!.history.reversed.take(_maxRecentEvents));

    _telemetryHistory.clear();
    _chartMarkers.clear();
    for (final id in _chartedMetrics) {
      final value = _serialService!.latestTelemetry[id];
      if (value != null) {
        _telemetryHistory[id] = [TelemetryPoint(DateTime.now(), value)];
      }
    }

    _logSub = _serialService!.logStream.listen(_onLogEntry);
    _telemetrySub = _serialService!.telemetryStream.listen(_onTelemetry);
  }

  void _onLogEntry(SerialLogEntry entry) {
    if (!mounted) return;
    setState(() {
      _recentEvents.insert(0, entry);
      if (_recentEvents.length > _maxRecentEvents) _recentEvents.removeLast();

      if (entry.level == LogLevel.error || entry.level == LogLevel.warn) {
        _chartMarkers.add(ChartMarker(entry.receivedAt, entry.level));
        // Keep markers roughly aligned with the charted window instead of
        // growing forever.
        if (_chartMarkers.length > _maxHistoryPoints) {
          _chartMarkers.removeAt(0);
        }
      }
    });
  }

  void _onTelemetry(TelemetrySample sample) {
    if (!mounted) return;
    setState(() {
      final now = DateTime.now();
      for (final id in _chartedMetrics) {
        final value = sample[id];
        if (value == null) continue;
        final points = _telemetryHistory.putIfAbsent(id, () => []);
        points.add(TelemetryPoint(now, value));
        if (points.length > _maxHistoryPoints) points.removeAt(0);
      }
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _telemetrySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = SerialServiceScope.of(context);
    final serialService = scope.serialService;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<bool>(
            stream: serialService.connectionStream,
            initialData: serialService.isConnected,
            builder: (context, connSnapshot) {
              return StreamBuilder<DeviceInfo>(
                stream: serialService.deviceInfoStream,
                initialData: serialService.latestDeviceInfo,
                builder: (context, infoSnapshot) {
                  final info = infoSnapshot.data ?? const DeviceInfo();
                  return DeviceHeader(
                    isConnected: connSnapshot.data ?? false,
                    port: serialService.connectedPort ?? '--',
                    idfVersion: info.idfVersion ?? '--',
                    firmwareVersion: info.firmwareVersion ?? '--',
                    onRefresh: () => serialService.requestStatus(),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),

          // Live — updates whenever firmware sends a "telemetry" line
          // (see TelemetrySample.tryParse for the expected format).
          // Falls back to "--" for any field not yet received.
          // Which metrics show as chips — add/remove keys here as your
          // firmware's telemetry line grows (see MetricRegistry for how
          // each key is styled).
          StreamBuilder<TelemetrySample>(
            stream: serialService.telemetryStream,
            initialData: serialService.latestTelemetry,
            builder: (context, snapshot) {
              final t = snapshot.data ?? const TelemetrySample();
              const displayedMetrics = ['cpu', 'ram', 'flash', 'temp', 'voltage'];

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final id in displayedMetrics)
                    animatedChip(
                      Builder(builder: (context) {
                        final spec = MetricRegistry.forId(id);
                        final value = t[id];
                        return MetricChip(
                          icon: spec.icon,
                          title: spec.label,
                          value: value != null ? spec.format(value) : "--",
                        );
                      }),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          animatedCard(
            ByteCard(
              title: "Telemetry",
              child: Container(
                height: 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xff0E1824),
                      Color(0xff101C29),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: GridPainter()),
                    ),
                    if (_telemetryHistory.values.any((p) => p.length >= 2))
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: TelemetryChart(
                            series: _telemetryHistory,
                            markers: _chartMarkers,
                          ),
                        ),
                      )
                    else ...[
                      const Center(
                        child: Icon(
                          Icons.show_chart,
                          size: 64,
                          color: Colors.white24,
                        ),
                      ),
                      const Positioned(
                        bottom: 16,
                        left: 16,
                        child: Text(
                          "Waiting for telemetry...",
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: animatedCard(
                  ByteCard(
                    title: "Events",
                    child: _recentEvents.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              "No events yet",
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < _recentEvents.length; i++) ...[
                                if (i > 0) const SizedBox(height: 12),
                                stagger(
                                  _eventTileFor(_recentEvents[i]),
                                  i * 100,
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: animatedCard(
                  ByteCard(
                    title: "Quick Actions",
                    child: Column(
                      children: [
                        ActionTile(
                          icon: Icons.build,
                          title: "Build",
                          subtitle: "Compile firmware",
                          onTap: () => scope.buildService.start(),
                        ),
                        const SizedBox(height: 12),
                        ActionTile(
                          icon: Icons.flash_on,
                          title: "Flash",
                          subtitle: "Upload firmware",
                          onTap: () {},
                        ),
                        const SizedBox(height: 12),
                        ActionTile(
                          icon: Icons.terminal,
                          title: "Monitor",
                          subtitle: "Open serial console",
                          onTap: () => scope.terminalExpanded.value = true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: animatedCard(
                  ByteCard(
                    title: "Connected Devices",
                    child: StreamBuilder<List<DiscoveredDevice>>(
                      stream: scope.deviceScanner.devicesStream,
                      initialData: const [],
                      builder: (context, snapshot) {
                        final devices = snapshot.data ?? const [];
                        if (devices.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              "No devices found",
                              style: TextStyle(color: Colors.white38),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (var i = 0; i < devices.length; i++) ...[
                              if (i > 0) const SizedBox(height: 8),
                              stagger(
                                DeviceTile(
                                  name: devices[i].label,
                                  status: devices[i].path,
                                  isOnline: devices[i].isConnected,
                                ),
                                i * 100,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: animatedCard(
                  ByteCard(
                    title: "Build Status",
                    child: StreamBuilder<BuildStatus>(
                      stream: scope.buildService.statusStream,
                      initialData: scope.buildService.status,
                      builder: (context, snapshot) {
                        final build = snapshot.data ?? const BuildStatus();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _buildStateLabel(build.state),
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: build.state == BuildState.idle
                                    ? 0
                                    : build.progress,
                                minHeight: 8,
                                color: build.state == BuildState.failed
                                    ? const Color(0xffFF5C5C)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              build.currentStep.isEmpty
                                  ? (build.state == BuildState.idle
                                      ? "No build running"
                                      : "")
                                  : build.currentStep,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _eventTileFor(SerialLogEntry entry) {
    return EventTile(
      icon: _iconForLevel(entry.level),
      color: entry.level.color,
      title: entry.tag != null
    ? "${entry.tag}: ${entry.message ?? ''}"
    : (entry.message ?? ''),
      time: _relativeTime(entry.receivedAt),
    );
  }

  IconData _iconForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Icons.error_outline;
      case LogLevel.warn:
        return Icons.warning_amber_rounded;
      case LogLevel.info:
        return Icons.info_outline;
      case LogLevel.debug:
      case LogLevel.verbose:
        return Icons.code;
      case LogLevel.unknown:
        return Icons.circle_outlined;
    }
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 5) return "Now";
    if (diff.inMinutes < 1) return "${diff.inSeconds}s ago";
    if (diff.inHours < 1) return "${diff.inMinutes} min ago";
    return "${diff.inHours}h ago";
  }

  String _buildStateLabel(BuildState state) {
    switch (state) {
      case BuildState.idle:
        return "Ready";
      case BuildState.running:
        return "Building...";
      case BuildState.success:
        return "Build Succeeded";
      case BuildState.failed:
        return "Build Failed";
    }
  }

  Widget animatedChip(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .95, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: child,
    );
  }

  Widget animatedCard(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      builder: (_, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: .97 + value * .03, child: child),
        );
      },
      child: child,
    );
  }

  Widget stagger(Widget child, int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    const gap = 32.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}