import 'package:flutter/foundation.dart';

import '../models/serial_log_entry.dart';

@immutable
class DeviceInfo {
  final String? idfVersion;
  final String? firmwareVersion;

  const DeviceInfo({this.idfVersion, this.firmwareVersion});

  DeviceInfo mergedWith(DeviceInfo next) {
    return DeviceInfo(
      idfVersion: next.idfVersion ?? idfVersion,
      firmwareVersion: next.firmwareVersion ?? firmwareVersion,
    );
  }

  static DeviceInfo? tryParse(SerialLogEntry entry) {
    if (entry.tag != 'device') return null;

    String? idf, fw;
    for (final pair in entry.message!.split(',')) {
      final kv = pair.split('=');
      if (kv.length != 2) continue;
      switch (kv[0].trim()) {
        case 'idf':
          idf = kv[1].trim();
        case 'fw':
          fw = kv[1].trim();
      }
    }
    return DeviceInfo(idfVersion: idf, firmwareVersion: fw);
  }
}