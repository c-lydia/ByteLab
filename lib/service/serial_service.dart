import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../models/serial_log_entry.dart';
import 'device_info.dart';
import 'serial_transport.dart';
import 'telemetry_sample.dart';

class SerialService {
  SerialService({SerialTransport Function()? transportFactory})
    : _factory = transportFactory ?? createSerialTransport;
  final SerialTransport Function() _factory;
  SerialTransport? _transport;
  StreamSubscription<String>? _readSub;
  final _logs = StreamController<SerialLogEntry>.broadcast();
  final _connections = StreamController<bool>.broadcast();
  final _telemetry = StreamController<TelemetrySample>.broadcast();
  final _info = StreamController<DeviceInfo>.broadcast();
  Future<void> _writes = Future<void>.value();
  String _buffer = '';
  int _generation = 0;
  bool _disposed = false;
  bool isConnecting = false;
  String? connectedPort;
  int baudRate = 115200;
  TelemetrySample latestTelemetry = const TelemetrySample();
  DeviceInfo latestDeviceInfo = const DeviceInfo();
  final List<SerialLogEntry> history = [];
  final List<String> rawHistory = [];
  static const maxHistory = 5000;
  static const maxLineLength = 65536;
  Stream<SerialLogEntry> get logStream => _logs.stream;
  Stream<bool> get connectionStream => _connections.stream;
  Stream<TelemetrySample> get telemetryStream => _telemetry.stream;
  Stream<DeviceInfo> get deviceInfoStream => _info.stream;
  bool get isConnected => _transport != null;
  static List<String> availablePorts() => availableSerialPorts();

  Future<void> connect(String path, {int baudRate = 115200}) async {
    if (_disposed) throw StateError('Serial service has been disposed');
    if (isConnecting) {
      throw const SerialConnectionException(
        'A connection is already in progress',
      );
    }
    if (path.trim().isEmpty || baudRate <= 0) {
      throw ArgumentError('Choose a port and a positive baud rate');
    }
    isConnecting = true;
    SerialTransport? candidate;
    try {
      await disconnect();
      final generation = _generation;
      candidate = _factory();
      await candidate.open(path, baudRate);
      if (_disposed || generation != _generation) {
        throw const SerialConnectionException('Connection cancelled');
      }
      _transport = candidate;
      connectedPort = path;
      this.baudRate = baudRate;
      latestTelemetry = const TelemetrySample();
      latestDeviceInfo = const DeviceInfo();
      clearHistory();
      _telemetry.add(latestTelemetry);
      _info.add(latestDeviceInfo);
      _readSub = candidate.input
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            (text) {
              if (generation == _generation && !_disposed) _handleText(text);
            },
            onError: (Object error) => _lost(generation, error.toString()),
            onDone: () => _lost(generation, 'Serial device disconnected'),
          );
      _connections.add(true);
    } catch (error) {
      if (candidate != null) await candidate.close();
      _transport = null;
      connectedPort = null;
      if (!_disposed) _connections.add(false);
      throw SerialConnectionException(error.toString());
    } finally {
      isConnecting = false;
    }
  }

  void _lost(int generation, String reason) {
    if (_disposed || generation != _generation) return;
    _append('W (0) bytelab: $reason');
    unawaited(disconnect().catchError((Object _) {}));
  }

  void _handleText(String chunk) {
    _buffer += chunk;
    var newline = _buffer.indexOf('\n');
    while (newline >= 0) {
      final line = _buffer.substring(0, newline).replaceAll('\r', '');
      _buffer = _buffer.substring(newline + 1);
      if (line.length <= maxLineLength) {
        if (line.isNotEmpty) _append(line);
      } else {
        _append('W (0) bytelab: Discarded a serial line larger than 64 KiB');
      }
      newline = _buffer.indexOf('\n');
    }
    if (_buffer.length > maxLineLength) {
      _buffer = '';
      _append(
        'W (0) bytelab: Discarded unterminated serial data larger than 64 KiB',
      );
    }
  }

  void _append(String line) {
    if (_disposed) return;
    final entry = SerialLogEntry.parse(line);
    history.add(entry);
    rawHistory.add(line);
    if (history.length > maxHistory) history.removeAt(0);
    if (rawHistory.length > maxHistory) rawHistory.removeAt(0);
    _logs.add(entry);
    final sample = TelemetrySample.tryParse(entry);
    if (sample != null) {
      latestTelemetry = latestTelemetry.mergedWith(sample);
      _telemetry.add(latestTelemetry);
    }
    final info = DeviceInfo.tryParse(entry);
    if (info != null) {
      latestDeviceInfo = latestDeviceInfo.mergedWith(info);
      _info.add(latestDeviceInfo);
    }
  }

  void clearHistory() {
    history.clear();
    rawHistory.clear();
  }

  Future<void> write(String data) =>
      writeBytes(Uint8List.fromList(utf8.encode(data)));
  Future<void> writeBytes(Uint8List bytes) {
    if (bytes.length > 65536) {
      throw ArgumentError('Send at most 64 KiB at a time');
    }
    final generation = _generation;
    final task = _writes.then((_) async {
      final transport = _transport;
      if (_disposed || transport == null || generation != _generation) {
        throw const SerialConnectionException('Not connected');
      }
      await transport.writeAll(bytes);
    });
    _writes = task.catchError((Object _) {});
    return task;
  }

  Future<void> requestStatus({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final response = Completer<void>();
    final sub = logStream.listen((entry) {
      if ((entry.tag == 'status' || entry.tag == 'device') &&
          !response.isCompleted) {
        response.complete();
      }
    });
    try {
      await write('STATUS?\n');
      await response.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  Future<void> disconnect() async {
    _generation++;
    final reader = _readSub;
    final transport = _transport;
    _readSub = null;
    _transport = null;
    connectedPort = null;
    _buffer = '';
    try {
      await reader?.cancel();
    } finally {
      await transport?.close();
      if (!_disposed) _connections.add(false);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    await Future.wait([
      _logs.close(),
      _connections.close(),
      _telemetry.close(),
      _info.close(),
    ]);
  }
}

class SerialConnectionException implements Exception {
  final String message;
  const SerialConnectionException(this.message);
  @override
  String toString() => message;
}
