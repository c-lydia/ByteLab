import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'device_info.dart';
import '../models/serial_log_entry.dart';
import 'telemetry_sample.dart';

class SerialService {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _readSub;

  final StringBuffer _lineBuffer = StringBuffer();

  final _logController = StreamController<SerialLogEntry>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _telemetryController = StreamController<TelemetrySample>.broadcast();
  final _deviceInfoController = StreamController<DeviceInfo>.broadcast();

  String? connectedPort;

  TelemetrySample latestTelemetry = const TelemetrySample();

  DeviceInfo latestDeviceInfo = const DeviceInfo();

  Stream<SerialLogEntry> get logStream => _logController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<TelemetrySample> get telemetryStream => _telemetryController.stream;

  Stream<DeviceInfo> get deviceInfoStream => _deviceInfoController.stream;

  bool get isConnected => _port?.isOpen ?? false;

  final List<SerialLogEntry> history = [];
  static const int _maxHistory = 5000;

  static List<String> availablePorts() => SerialPort.availablePorts;

  Future<void> connect(String path, {int baudRate = 115200}) async {
    await disconnect(); // ensure any previous connection is cleaned up first

    final port = SerialPort(path);
    if (!port.openReadWrite()) {
      final error = SerialPort.lastError;
      throw SerialConnectionException(
        'Could not open $path: ${error?.message ?? "unknown error"}',
      );
    }

    port.config
      ..baudRate = baudRate
      ..bits = 8
      ..parity = SerialPortParity.none
      ..stopBits = 1;

    _port = port;
    connectedPort = path;
    _reader = SerialPortReader(port);
    _readSub = _reader!.stream.listen(
      _handleBytes,
      onError: (_) => _connectionController.add(false),
    );

    _connectionController.add(true);
  }

  void _handleBytes(Uint8List chunk) {
    _lineBuffer.write(String.fromCharCodes(chunk));
    final buffered = _lineBuffer.toString();

    final lines = buffered.split('\n');
    final incomplete = lines.removeLast();

    for (final rawLine in lines) {
      final line = rawLine.replaceAll('\r', '').trimRight();
      if (line.isEmpty) continue;

      final entry = SerialLogEntry.parse(line);
      history.add(entry);
      if (history.length > _maxHistory) history.removeAt(0);
      _logController.add(entry);

      final telemetry = TelemetrySample.tryParse(entry);
      if (telemetry != null) {
        latestTelemetry = latestTelemetry.mergedWith(telemetry);
        _telemetryController.add(latestTelemetry);
      }

      final deviceInfo = DeviceInfo.tryParse(entry);
      if (deviceInfo != null) {
        latestDeviceInfo = latestDeviceInfo.mergedWith(deviceInfo);
        _deviceInfoController.add(latestDeviceInfo);
      }
    }

    _lineBuffer
      ..clear()
      ..write(incomplete);
  }

  Future<void> write(String data) async {
    final port = _port;
    if (port == null || !port.isOpen) {
      throw SerialConnectionException('Not connected');
    }
    port.write(Uint8List.fromList(data.codeUnits));
  }

  Future<void> requestStatus({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final completer = Completer<void>();
    late final StreamSubscription<SerialLogEntry> sub;

    sub = logStream.listen((entry) {
      if (entry.tag == 'status' && !completer.isCompleted) {
        completer.complete();
      }
    });

    await write('STATUS?\n');

    try {
      await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  Future<void> disconnect() async {
    await _readSub?.cancel();
    _readSub = null;
    _reader = null;
    _port?.close();
    _port = null;
    connectedPort = null;
    _lineBuffer.clear();
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _logController.close();
    _connectionController.close();
    _telemetryController.close();
    _deviceInfoController.close();
  }
}

class SerialConnectionException implements Exception {
  final String message;
  SerialConnectionException(this.message);

  @override
  String toString() => 'SerialConnectionException: $message';
}