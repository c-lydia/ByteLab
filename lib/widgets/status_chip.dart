import 'package:flutter/material.dart';

import '../core/byte_color.dart';

enum DeviceStatus { connected, connecting, disconnected, error }

class StatusChip extends StatelessWidget {
  final DeviceStatus status;

  const StatusChip({super.key, required this.status});

  String get label {
    switch (status) {
      case DeviceStatus.connected:
        return "CONNECTED";
      case DeviceStatus.connecting:
        return "CONNECTING";
      case DeviceStatus.disconnected:
        return "DISCONNECTED";
      case DeviceStatus.error:
        return "ERROR";
    }
  }

  Color get color {
    switch (status) {
      case DeviceStatus.connected:
        return ByteColor.success;
      case DeviceStatus.connecting:
        return ByteColor.warning;
      case DeviceStatus.disconnected:
        return ByteColor.mutedText;
      case DeviceStatus.error:
        return ByteColor.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ByteColor.panelLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ByteColor.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
