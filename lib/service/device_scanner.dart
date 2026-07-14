import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'serial_service.dart';

@immutable
class DiscoveredDevice {
  final String path; // e.g. "/dev/ttyUSB0"
  final String label; // friendly name if the OS/driver reports one
  final bool isConnected; // matches SerialService.connectedPort

  const DiscoveredDevice({
    required this.path,
    required this.label,
    required this.isConnected,
  });
}

/// Polls the OS for available serial ports on an interval and marks
/// whichever one matches [SerialService.connectedPort] as connected.
///
/// Polling (not a native "device attached" event stream) because
/// libserialport doesn't expose OS-level hotplug notifications through
/// this binding — periodic re-scan is the simple, portable option.
class DeviceScanner {
  final SerialService serialService;
  final Duration interval;
  Timer? _timer;
  final _controller = StreamController<List<DiscoveredDevice>>.broadcast();

  DeviceScanner({
    required this.serialService,
    this.interval = const Duration(seconds: 2),
  });

  Stream<List<DiscoveredDevice>> get devicesStream => _controller.stream;

  void start() {
    _scan(); // immediate first scan, don't wait for the first tick
    _timer = Timer.periodic(interval, (_) => _scan());
  }

  void _scan() {
    final devices = <DiscoveredDevice>[];
    for (final path in SerialPort.availablePorts) {
      String label = path;
      try {
        final port = SerialPort(path);
        final description = port.description;
        if (description != null && description.isNotEmpty) {
          label = description;
        }
        port.dispose();
      } catch (_) {
        // Some ports fail to query metadata (permissions, in-use, etc.) —
        // fall back to just showing the raw path rather than failing
        // the whole scan.
      }

      devices.add(
        DiscoveredDevice(
          path: path,
          label: label,
          isConnected: path == serialService.connectedPort,
        ),
      );
    }
    _controller.add(devices);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}