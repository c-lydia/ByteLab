import 'package:flutter/material.dart';
import '../core/byte_color.dart';

@immutable
class MetricSpec {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String Function(double value) format;

  const MetricSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.format,
  });

  factory MetricSpec.fallback(String id) => MetricSpec(
        id: id,
        label: id.toUpperCase(),
        icon: Icons.show_chart,
        color: ByteColor.mutedText,
        format: (v) => v.toStringAsFixed(1),
      );
}

class MetricRegistry {
  static final Map<String, MetricSpec> _known = {
    'cpu': MetricSpec(
      id: 'cpu',
      label: 'CPU',
      icon: Icons.memory,
      color: ByteColor.cyan,
      format: (v) => '${v.toStringAsFixed(0)}%',
    ),
    'ram': MetricSpec(
      id: 'ram',
      label: 'RAM',
      icon: Icons.storage,
      color: const Color(0xffFFC857),
      format: (v) => '${v.toStringAsFixed(0)} KB',
    ),
    'flash': MetricSpec(
      id: 'flash',
      label: 'FLASH',
      icon: Icons.sd_storage,
      color: const Color(0xffB388FF),
      format: (v) => '${(v / 1024).toStringAsFixed(1)} MB',
    ),
    'temp': MetricSpec(
      id: 'temp',
      label: 'TEMP',
      icon: Icons.thermostat,
      color: const Color(0xffFF8A65),
      format: (v) => '${v.toStringAsFixed(1)}°C',
    ),
    'voltage': MetricSpec(
      id: 'voltage',
      label: 'VOLTAGE',
      icon: Icons.bolt,
      color: const Color(0xffFFD54F),
      format: (v) => '${v.toStringAsFixed(2)}V',
    ),
    'current': MetricSpec(
      id: 'current',
      label: 'CURRENT',
      icon: Icons.electric_bolt,
      color: const Color(0xff69F0AE),
      format: (v) => '${v.toStringAsFixed(0)}mA',
    ),
    'rssi': MetricSpec(
      id: 'rssi',
      label: 'RSSI',
      icon: Icons.wifi,
      color: const Color(0xff64B5F6),
      format: (v) => '${v.toStringAsFixed(0)}dBm',
    ),
  };

  static MetricSpec forId(String id) =>
      _known[id] ?? MetricSpec.fallback(id);
}