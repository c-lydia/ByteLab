import 'package:flutter/material.dart';

import 'device_model.dart';

class DeviceManager extends ChangeNotifier {
  Device? _device;
  Device? get device => _device; 

  bool? get connection => _device != null;

  void connect(Device device) {
    _device = device;
    notifyListeners();
  }

  void disconnect() {
    _device = null;
    notifyListeners();
  }

  void update(Device device) {
    _device = device;
    notifyListeners();
  }
}