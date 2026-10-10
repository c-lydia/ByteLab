import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';

class WindowAppearance {
  static const channel = MethodChannel('bytelab/window');

  Future<bool> setOpacity(double opacity) async {
    if (!opacity.isFinite || opacity < 0.7 || opacity > 1) {
      throw const FormatException(
        'Window opacity must be between 70% and 100%',
      );
    }
    if (!Platform.isLinux) return false;
    try {
      return await channel
              .invokeMethod<bool>('setOpacity', opacity)
              .timeout(const Duration(seconds: 2)) ??
          false;
    } on TimeoutException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
