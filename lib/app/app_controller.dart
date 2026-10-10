import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/serial_log_entry.dart';
import '../service/build_service.dart';
import '../service/neovim_service.dart';
import '../service/window_appearance.dart';
import '../service/build_status.dart';
import '../service/device_scanner.dart';
import '../service/serial_service.dart';
import '../widgets/telemetry_chart.dart';
import 'project_store.dart';
import 'settings_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    SerialService? serialService,
    SettingsStore? settingsStore,
    BuildService? buildService,
    List<DiscoveredDevice> Function()? portProvider,
  }) : serial = serialService ?? SerialService(),
       store = settingsStore ?? SettingsStore(),
       jobs =
           buildService ?? BuildService(projectPath: Directory.current.path) {
    scanner = DeviceScanner(serialService: serial, provider: portProvider);
    neovim = NeovimService(
      onChanged: () {
        if (neovim.needsAttention) {
          unsavedEditors.add(neovim);
        } else {
          unsavedEditors.remove(neovim);
        }
        _notifySoon();
      },
    );
    _subscriptions.addAll([
      scanner.devicesStream.listen((_) => _notifySoon()),
      serial.connectionStream.listen((_) {
        scanner.refresh();
        _notifySoon();
      }),
      serial.deviceInfoStream.listen((_) => _notifySoon()),
      serial.logStream.listen((entry) {
        if (entry.level == LogLevel.error || entry.level == LogLevel.warn) {
          markers.add(ChartMarker(entry.receivedAt, entry.level));
          if (markers.length > 180) markers.removeAt(0);
        }
        _notifySoon();
      }),
      serial.telemetryStream.listen((sample) {
        if (sample.values.isEmpty) {
          series.clear();
          markers.clear();
        }
        final now = DateTime.now();
        for (final item in sample.values.entries) {
          final points = series.putIfAbsent(item.key, () => []);
          points.add(TelemetryPoint(now, item.value));
          if (points.length > 180) points.removeAt(0);
        }
        lastTelemetryAt = sample.values.isEmpty ? null : now;
        _notifySoon();
      }),
      jobs.statusStream.listen((_) => _notifySoon()),
      jobs.outputStream.listen((_) => _notifySoon()),
    ]);
  }

  late final NeovimService neovim;
  final WindowAppearance window = WindowAppearance();
  bool windowOpacitySupported = false;
  final SerialService serial;
  final SettingsStore store;
  final BuildService jobs;
  final ProjectStore project = ProjectStore();
  late final DeviceScanner scanner;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Map<String, List<TelemetryPoint>> series = {};
  final List<ChartMarker> markers = [];
  AppSettings settings = const AppSettings();
  DateTime? lastTelemetryAt;
  String? notice;
  bool ready = false;
  int selectedPage = 0;
  final Set<Object> unsavedEditors = {};
  bool _operation = false;
  bool _disposed = false;
  Timer? _notifyTimer;
  Future<void>? _closing;
  bool get busy => _operation || jobs.isRunning;
  bool get hasProject => project.root != null;

  void navigate(int page) {
    if (page < 0 || page > 9 || _disposed) return;
    selectedPage = page;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (ready || _disposed) return;
    try {
      settings = await store.load();
    } catch (error) {
      notice = 'Could not load saved settings: $error';
    }
    if (settings.projectPath.isNotEmpty) {
      try {
        await project.open(settings.projectPath);
      } catch (error) {
        notice = 'Reopen your project: $error';
      }
    }
    if (_disposed) return;
    try {
      windowOpacitySupported = await window.setOpacity(settings.windowOpacity);
    } catch (error) {
      notice = 'Could not apply window opacity: $error';
    }
    if (_disposed) return;
    ready = true;
    scanner.start();
    notifyListeners();
  }

  void _notifySoon() {
    if (_disposed || _notifyTimer != null) return;
    _notifyTimer = Timer(const Duration(milliseconds: 60), () {
      _notifyTimer = null;
      if (!_disposed) notifyListeners();
    });
  }

  void dismissNotice() {
    notice = null;
    _notifySoon();
  }

  Future<void> saveSettings(AppSettings next) async {
    if (busy || serial.isConnecting) {
      throw StateError(
        'Wait for the current operation before changing settings',
      );
    }
    if (next.baudRate <= 0 ||
        next.baudRate > 4000000 ||
        next.flashBaudRate <= 0 ||
        next.flashBaudRate > 4000000) {
      throw const FormatException('Baud rates must be between 1 and 4,000,000');
    }
    if (!['LF', 'CRLF', 'None'].contains(next.lineEnding)) {
      throw const FormatException('Choose a valid line ending');
    }
    if (next.exportScript.isNotEmpty &&
        !await File(next.exportScript).exists()) {
      throw const FileSystemException(
        'The ESP-IDF export.sh file does not exist',
      );
    }
    if (!next.windowOpacity.isFinite ||
        next.windowOpacity < 0.7 ||
        next.windowOpacity > 1) {
      throw const FormatException(
        'Window opacity must be between 70% and 100%',
      );
    }
    if (next.editor != settings.editor ||
        next.neovimClean != settings.neovimClean) {
      await neovim.ensureSaved();
      if (unsavedEditors.isNotEmpty) {
        throw StateError(
          'Save or reload editor changes before changing editor settings',
        );
      }
      await neovim.close();
    }
    await store.save(next);
    settings = next;
    windowOpacitySupported = await window.setOpacity(next.windowOpacity);
    _notifySoon();
  }

  Future<void> selectPort(String port) =>
      saveSettings(settings.copyWith(port: port));

  Future<void> openProject(String path) async {
    if (busy) throw StateError('Wait for the firmware operation to finish');
    await neovim.ensureSaved();
    if (unsavedEditors.isNotEmpty) {
      throw StateError(
        'Save or reload unsaved files before switching projects',
      );
    }
    await project.open(path);
    await neovim.close();
    settings = settings.copyWith(projectPath: project.root);
    _notifySoon();
    await store.save(settings);
  }

  Future<void> createProject(String parent, String name) async {
    if (busy) throw StateError('Wait for the firmware operation to finish');
    await neovim.ensureSaved();
    if (unsavedEditors.isNotEmpty) {
      throw StateError(
        'Save or reload unsaved files before creating a project',
      );
    }
    await project.create(parent, name);
    await neovim.close();
    settings = settings.copyWith(projectPath: project.root);
    _notifySoon();
    await store.save(settings);
  }

  Future<void> connect([String? path]) async {
    if (busy) throw StateError('Wait for the firmware operation to finish');
    final port = path ?? settings.port;
    if (port.isEmpty) throw StateError('Select a serial port first');
    final connection = serial.connect(port, baudRate: settings.baudRate);
    _notifySoon();
    try {
      await connection;
      settings = settings.copyWith(port: port);
      await store.save(settings);
    } finally {
      _notifySoon();
    }
  }

  Future<void> disconnect() async {
    await serial.disconnect();
    _notifySoon();
  }

  Future<void> runFirmware(
    List<String> arguments,
    String label, {
    bool needsProject = true,
    bool flashing = false,
  }) async {
    if (busy || serial.isConnecting) {
      throw StateError('Another operation is in progress');
    }
    if (needsProject && !hasProject) {
      throw StateError('Open an ESP-IDF project first');
    }
    if (needsProject) await neovim.ensureSaved();
    if (busy || serial.isConnecting) {
      throw StateError('Another operation is in progress');
    }
    if (needsProject && unsavedEditors.isNotEmpty) {
      throw StateError(
        'Save or reload unsaved files before running firmware commands',
      );
    }
    if (flashing && settings.port.isEmpty) {
      throw StateError('Select the board port before flashing');
    }
    _operation = true;
    _notifySoon();
    final reconnectPort = flashing ? serial.connectedPort : null;
    final reconnectBaud = serial.baudRate;
    try {
      if (flashing) await serial.disconnect();
      jobs.projectPath = project.root ?? Directory.current.path;
      jobs.exportScript = settings.exportScript;
      jobs.command = 'idf.py';
      await jobs.start(arguments: arguments, title: label);
      if (jobs.status.state == BuildState.failed) {
        throw StateError('$label failed. Read the command output for details');
      }
    } finally {
      if (reconnectPort != null && !_disposed) {
        try {
          await serial.connect(reconnectPort, baudRate: reconnectBaud);
        } catch (error) {
          notice = 'Serial monitor could not reconnect: $error';
        }
      }
      _operation = false;
      _notifySoon();
    }
  }

  Future<void> build() => runFirmware(['build'], 'Build');
  Future<void> flash() => runFirmware(
    ['-p', settings.port, '-b', '${settings.flashBaudRate}', 'flash'],
    'Flash',
    flashing: true,
  );
  Future<void> checkToolchain() =>
      runFirmware(['--version'], 'Toolchain check', needsProject: false);

  Future<void> send(String text) async {
    if (text.isEmpty) return;
    final ending = switch (settings.lineEnding) {
      'LF' => '\n',
      'CRLF' => '\r\n',
      _ => '',
    };
    await serial.write('$text$ending');
  }

  Future<void> sendHex(String text) async {
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty ||
        compact.length.isOdd ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(compact)) {
      throw const FormatException(
        'Enter complete hex bytes, for example: 48 49 0A',
      );
    }
    final bytes = <int>[];
    for (var i = 0; i < compact.length; i += 2) {
      bytes.add(int.parse(compact.substring(i, i + 2), radix: 16));
    }
    await serial.writeBytes(Uint8List.fromList(bytes));
  }

  void clearLogs() {
    serial.clearHistory();
    _notifySoon();
  }

  Future<void> exportLog(String path, {bool firmware = false}) async {
    final file = File(path);
    if (await file.exists()) {
      throw const FileSystemException(
        'A file already exists at that path; choose a new filename',
      );
    }
    final lines = List<String>.of(
      firmware ? jobs.outputLines : serial.rawHistory,
    );
    await file.writeAsString('${lines.join('\n')}\n', flush: true);
  }

  Future<void> shutdown() {
    dispose();
    return _closing!;
  }

  Future<void> _closeResources() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await Future.wait([serial.dispose(), jobs.dispose(), neovim.dispose()]);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _notifyTimer?.cancel();
    scanner.dispose();
    _closing = _closeResources();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
