import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import '../service/serial_transport_base.dart';

@JS('navigator.serial')
external BrowserSerial get _serial;
extension type BrowserSerial(JSObject _) implements JSObject {
  external JSPromise<BrowserPort> requestPort();
}
extension type BrowserPort(JSObject _) implements JSObject {
  external JSPromise<JSAny?> open(SerialOptions options);
  external JSPromise<JSAny?> close();
  external web.ReadableStream? get readable;
  external web.WritableStream? get writable;
}
extension type SerialOptions._(JSObject _) implements JSObject {
  external factory SerialOptions({required int baudRate});
}

SerialTransport createSerialTransport() => BrowserSerialTransport();
List<String> availableSerialPorts() =>
    BrowserSerialTransport.ports.keys.toList();

class BrowserSerialTransport implements SerialTransport {
  static final ports = <String, BrowserPort>{};
  static bool get supported =>
      web.window.isSecureContext &&
      web.window.navigator.hasProperty('serial'.toJS).toDart;
  static Future<String> requestPort() async {
    if (!supported) {
      throw UnsupportedError(
        'Web Serial requires a supported browser such as Chrome or Edge, on HTTPS or localhost.',
      );
    }
    final port = await _serial.requestPort().toDart;
    for (final entry in ports.entries) {
      if (entry.value == port) return entry.key;
    }
    final id = 'Browser port ${ports.length + 1}';
    ports[id] = port;
    return id;
  }

  final _input = StreamController<List<int>>();
  BrowserPort? _port;
  web.ReadableStreamDefaultReader? _reader;
  web.WritableStreamDefaultWriter? _writer;
  Future<void>? _reading;
  bool _closing = false;
  Future<void>? _closeFuture;
  @override
  Stream<List<int>> get input => _input.stream;
  @override
  Future<void> open(String path, int baudRate) async {
    if (!supported) {
      throw UnsupportedError(
        'Web Serial is not available in this browser or connection.',
      );
    }
    final port = ports[path];
    if (port == null) throw StateError('Choose a serial device again');
    await port.open(SerialOptions(baudRate: baudRate)).toDart;
    _port = port;
    if (port.readable == null || port.writable == null) {
      throw StateError('Serial streams are unavailable');
    }
    _reader = web.ReadableStreamDefaultReader(port.readable!);
    _writer = web.WritableStreamDefaultWriter(port.writable!);
    _reading = _read();
  }

  Future<void> _read() async {
    try {
      while (!_closing) {
        final result = await _reader!.read().toDart;
        if (result.done) break;
        if (result.value != null) {
          _input.add((result.value as JSUint8Array).toDart);
        }
      }
    } catch (e, stack) {
      if (!_closing) _input.addError(e, stack);
    } finally {
      _reader?.releaseLock();
      _reader = null;
      unawaited(_input.close());
    }
  }

  @override
  Future<void> writeAll(Uint8List bytes) async {
    if (_closing || _writer == null) throw StateError('Not connected');
    await _writer!.write(bytes.toJS).toDart;
  }

  @override
  Future<void> close() => _closeFuture ??= _close();
  Future<void> _close() async {
    _closing = true;
    try {
      await _reader?.cancel().toDart;
    } catch (_) {
      /* Disconnected device. */
    }
    await _reading;
    _writer?.releaseLock();
    _writer = null;
    try {
      await _port?.close().toDart;
    } finally {
      _port = null;
      if (!_input.isClosed) unawaited(_input.close());
    }
  }
}
