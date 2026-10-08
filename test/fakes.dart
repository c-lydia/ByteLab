import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:bytelab/service/serial_transport.dart';

class FakeTransport implements SerialTransport {
  final inputController = StreamController<List<int>>.broadcast();
  final writes = <List<int>>[];
  String? path;
  int? baud;
  bool closed = false;
  void Function(List<int>)? onWrite;
  @override
  Stream<List<int>> get input => inputController.stream;
  @override
  Future<void> open(String path, int baudRate) async {
    this.path = path;
    baud = baudRate;
  }

  @override
  Future<void> writeAll(Uint8List bytes) async {
    writes.add(List.of(bytes));
    onWrite?.call(bytes);
  }

  void emit(String text) => inputController.add(utf8.encode(text));
  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await inputController.close();
  }
}
