import 'package:flutter/foundation.dart';
import '../models/serial_log_entry.dart';

@immutable
class TelemetrySample {
  final Map<String, double> values;

  const TelemetrySample({this.values = const {}});

  TelemetrySample mergedWith(TelemetrySample next) {
    return TelemetrySample(values: {...values, ...next.values});
  }

  double? operator [](String key) => values[key];

  static TelemetrySample? tryParse(SerialLogEntry entry) {
    if (entry.tag != 'telemetry') return null;

    final parsed = <String, double>{};
    for (final pair in (entry.message ?? '').split(',')) {
      final kv = pair.split('=');
      if (kv.length != 2) continue;
      final value = double.tryParse(kv[1].trim());
      if (value != null && value.isFinite) parsed[kv[0].trim()] = value;
    }
    return TelemetrySample(values: parsed);
  }
}
