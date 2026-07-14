import 'package:flutter/material.dart';

import '../service/build_service.dart';
import '../service/device_scanner.dart';
import '../service/serial_service.dart';

class SerialServiceScope extends InheritedWidget {
  final SerialService serialService;
  final ValueNotifier<bool> terminalExpanded;
  final DeviceScanner deviceScanner;
  final BuildService buildService;

  const SerialServiceScope({
    super.key,
    required this.serialService,
    required this.terminalExpanded,
    required this.deviceScanner,
    required this.buildService,
    required super.child,
  });

  static SerialServiceScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SerialServiceScope>();
    assert(scope != null, 'No SerialServiceScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(SerialServiceScope oldWidget) =>
      serialService != oldWidget.serialService ||
      terminalExpanded != oldWidget.terminalExpanded ||
      deviceScanner != oldWidget.deviceScanner ||
      buildService != oldWidget.buildService;
}