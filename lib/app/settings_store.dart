import 'dart:convert';
import 'dart:io';

class AppSettings {
  final String projectPath;
  final String exportScript;
  final String port;
  final int baudRate;
  final int flashBaudRate;
  final String lineEnding;
  const AppSettings({
    this.projectPath = '',
    this.exportScript = '',
    this.port = '',
    this.baudRate = 115200,
    this.flashBaudRate = 460800,
    this.lineEnding = 'LF',
  });

  AppSettings copyWith({
    String? projectPath,
    String? exportScript,
    String? port,
    int? baudRate,
    int? flashBaudRate,
    String? lineEnding,
  }) => AppSettings(
    projectPath: projectPath ?? this.projectPath,
    exportScript: exportScript ?? this.exportScript,
    port: port ?? this.port,
    baudRate: baudRate ?? this.baudRate,
    flashBaudRate: flashBaudRate ?? this.flashBaudRate,
    lineEnding: lineEnding ?? this.lineEnding,
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'projectPath': projectPath,
    'exportScript': exportScript,
    'port': port,
    'baudRate': baudRate,
    'flashBaudRate': flashBaudRate,
    'lineEnding': lineEnding,
  };

  factory AppSettings.fromJson(Map<String, dynamic> data) {
    String string(String key) => data[key] is String ? data[key] as String : '';
    int rate(String key, int fallback) =>
        data[key] is int && data[key] > 0 && data[key] <= 4000000
        ? data[key] as int
        : fallback;
    final ending = string('lineEnding');
    return AppSettings(
      projectPath: string('projectPath'),
      exportScript: string('exportScript'),
      port: string('port'),
      baudRate: rate('baudRate', 115200),
      flashBaudRate: rate('flashBaudRate', 460800),
      lineEnding: ['LF', 'CRLF', 'None'].contains(ending) ? ending : 'LF',
    );
  }
}

class SettingsStore {
  SettingsStore({File? file})
    : file = file ?? File('${configDirectory()}/settings.json');
  final File file;
  Future<void> _writes = Future<void>.value();

  static String configDirectory() {
    final env = Platform.environment;
    return env['BYTELAB_CONFIG_DIR'] ??
        '${env['XDG_CONFIG_HOME'] ?? '${env['HOME'] ?? Directory.current.path}/.config'}/bytelab';
  }

  Future<AppSettings> load() async {
    if (!await file.exists()) {
      return AppSettings(exportScript: detectExportScript());
    }
    final data = jsonDecode(await file.readAsString());
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Settings must be a JSON object');
    }
    return AppSettings.fromJson(data);
  }

  static String detectExportScript() {
    final idf = Platform.environment['IDF_PATH'];
    final home = Platform.environment['HOME'];
    for (final path in [
      if (idf != null) '$idf/export.sh',
      if (home != null) '$home/esp/esp-idf/export.sh',
    ]) {
      if (File(path).existsSync()) return path;
    }
    return '';
  }

  Future<void> save(AppSettings settings) {
    final next = _writes.then((_) async {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(settings.toJson())}\n',
        flush: true,
      );
      await temporary.rename(file.path);
    });
    _writes = next.catchError((Object _) {});
    return next;
  }
}
