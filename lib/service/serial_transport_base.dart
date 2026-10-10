import 'dart:typed_data';

/// Injectable boundary: tests never open physical serial devices.
abstract interface class SerialTransport {
  Stream<List<int>> get input;
  Future<void> open(String path, int baudRate);
  Future<void> writeAll(Uint8List bytes);
  Future<void> close();
}
