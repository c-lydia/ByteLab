import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';

/// Injectable boundary: tests never open physical serial devices.
abstract interface class SerialTransport {
  Stream<List<int>> get input;
  Future<void> open(String path, int baudRate);
  Future<void> writeAll(Uint8List bytes);
  Future<void> close();
}

class LibSerialTransport implements SerialTransport {
  SerialPort? _port;
  SerialPortReader? _reader;
  @override
  Stream<List<int>> get input => _reader!.stream;
  @override
  Future<void> open(String path, int baudRate) async {
    final port = SerialPort(path);
    try {
      if (!port.openReadWrite()) {
        throw StateError(SerialPort.lastError?.message ?? 'Cannot open $path');
      }
      final config = port.config
        ..baudRate = baudRate
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = 1;
      config.setFlowControl(SerialPortFlowControl.none);
      port.config = config;
      _port = port;
      _reader = SerialPortReader(port);
    } catch (_) {
      if (port.isOpen) port.close();
      port.dispose();
      rethrow;
    }
  }

  @override
  Future<void> writeAll(Uint8List bytes) async {
    final port = _port;
    if (port == null || !port.isOpen) throw StateError('Not connected');
    final elapsed = Stopwatch()..start();
    var offset = 0;
    while (offset < bytes.length) {
      if (_port != port || !port.isOpen) {
        throw StateError('Device disconnected');
      }
      final count = port.write(Uint8List.sublistView(bytes, offset));
      if (count < 0) {
        throw StateError(
          SerialPort.lastError?.message ?? 'Serial write failed',
        );
      }
      offset += count;
      if (offset == bytes.length) return;
      if (elapsed.elapsed > const Duration(seconds: 3)) {
        throw TimeoutException('Serial write timed out after $offset bytes');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  @override
  Future<void> close() async {
    final port = _port;
    _port = null;
    _reader?.close();
    _reader = null;
    if (port != null) {
      try {
        if (port.isOpen) port.close();
      } finally {
        port.dispose();
      }
    }
  }
}
