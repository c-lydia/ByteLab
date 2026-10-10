export 'serial_transport_base.dart';
export 'serial_transport_native.dart'
    if (dart.library.js_interop) '../web/serial_transport_web.dart';
