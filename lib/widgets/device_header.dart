import 'package:flutter/material.dart';

import '../../core/byte_color.dart';
import '../widgets/panel_header.dart';

class DeviceHeader extends StatelessWidget {
  final String deviceName;
  final bool isConnected;
  final String port;
  final String idfVersion;
  final String firmwareVersion;
  final VoidCallback? onRefresh;

  const DeviceHeader({
    super.key,
    this.deviceName = 'ESP32-S3 Controller',
    this.isConnected = true,
    this.port = '/dev/ttyUSB0',
    this.idfVersion = 'ESP-IDF 5.2',
    this.firmwareVersion = 'FW v1.0.3',
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isConnected ? ByteColor.cyan : ByteColor.text;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ByteColor.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ByteColor.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ByteColor.surfaceHover,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.memory, color: ByteColor.cyan, size: 22),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: const TextStyle(
                    color: ByteColor.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Text(
                  '$port  •  $idfVersion  •  $firmwareVersion',
                  style: const TextStyle(
                    color: ByteColor.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          if (onRefresh != null)
            PanelHeaderAction(
              icon: Icons.refresh,
              tooltip: 'Refresh',
              onTap: onRefresh!,
            ),
        ],
      ),
    );
  }
}