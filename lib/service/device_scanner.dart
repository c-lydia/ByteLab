import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'serial_service.dart';

@immutable
class DiscoveredDevice {
  final String path;
  final String label;
  final bool isConnected;
  const DiscoveredDevice({
    required this.path,
    required this.label,
    this.isConnected = false,
  });
}

class DeviceScanner {
  DeviceScanner({
    required this.serialService,
    this.interval = const Duration(seconds: 2),
    List<DiscoveredDevice> Function()? provider,
  }) : _provider = provider ?? nativePorts;
  final SerialService serialService;
  final Duration interval;
  final List<DiscoveredDevice> Function() _provider;
  final _controller = StreamController<List<DiscoveredDevice>>.broadcast();
  Timer? _timer;
  bool _disposed = false;
  List<DiscoveredDevice> devices = [];
  String? error;
  Stream<List<DiscoveredDevice>> get devicesStream => _controller.stream;

  static List<DiscoveredDevice> nativePorts() {
    final devices = <DiscoveredDevice>[];
    for (final path in SerialPort.availablePorts) {
      SerialPort? port;
      var label = path;
      try {
        port = SerialPort(path);
        final description = port.description;
        if (description != null && description.isNotEmpty) label = description;
      } catch (_) {
        /* Still show ports whose metadata cannot be read. */
      } finally {
        port?.dispose();
      }
      devices.add(DiscoveredDevice(path: path, label: label));
    }
    devices.sort((a, b) => a.path.compareTo(b.path));
    return devices;
  }

  void start() {
    if (_disposed) return;
    stop();
    refresh();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  void refresh() {
    if (_disposed) return;
    try {
      devices = _provider()
          .map(
            (p) => DiscoveredDevice(
              path: p.path,
              label: p.label,
              isConnected:
                  serialService.isConnected &&
                  p.path == serialService.connectedPort,
            ),
          )
          .toList();
      error = null;
    } catch (e) {
      devices = [];
      error = e.toString();
    }
    _controller.add(List.unmodifiable(devices));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stop();
    _controller.close();
  }
}
