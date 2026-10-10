import 'package:flutter/material.dart';
import 'app/desktop_app.dart' if (dart.library.js_interop) 'web/web_app.dart';
export 'app/desktop_app.dart' if (dart.library.js_interop) 'web/web_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ByteLabApp());
}
