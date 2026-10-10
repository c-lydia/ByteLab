import 'dart:convert';
import 'dart:io';

enum EditorChoice {
  builtin(
    'Built-in',
    'Highlighting and line numbers, with no separate editor to install.',
  ),
  neovim(
    'Neovim',
    'Embedded Neovim with your own configuration and plugins. Requires nvim on PATH.',
  ),
  vscode(
    'VS Code',
    'Open files or the project in your installed VS Code, in a separate window.',
  ),
  arduino(
    'Arduino IDE',
    'Launch your installed Arduino IDE for sketches. ByteLab builds remain ESP-IDF.',
  );

  const EditorChoice(this.label, this.description);
  final String label;
  final String description;
  bool get external => this == vscode || this == arduino;
}

class AppSettings {
  final String projectPath;
  final String exportScript;
  final String port;
  final int baudRate;
  final int flashBaudRate;
  final String lineEnding;
  final double windowOpacity;
  final EditorChoice editor;
  final String vscodePath;
  final String arduinoPath;
  bool get useNeovim => editor == EditorChoice.neovim;
  final bool neovimClean;
  const AppSettings({
    this.projectPath = '',
    this.exportScript = '',
    this.port = '',
    this.baudRate = 115200,
    this.flashBaudRate = 460800,
    this.lineEnding = 'LF',
    this.windowOpacity = 0.94,
    this.editor = EditorChoice.builtin,
    this.vscodePath = '',
    this.arduinoPath = '',
    this.neovimClean = false,
  });

  AppSettings copyWith({
    String? projectPath,
    String? exportScript,
    String? port,
    int? baudRate,
    int? flashBaudRate,
    String? lineEnding,
    double? windowOpacity,
    EditorChoice? editor,
    String? vscodePath,
    String? arduinoPath,
    bool? neovimClean,
  }) => AppSettings(
    projectPath: projectPath ?? this.projectPath,
    exportScript: exportScript ?? this.exportScript,
    port: port ?? this.port,
    baudRate: baudRate ?? this.baudRate,
    flashBaudRate: flashBaudRate ?? this.flashBaudRate,
    lineEnding: lineEnding ?? this.lineEnding,
    windowOpacity: windowOpacity ?? this.windowOpacity,
    editor: editor ?? this.editor,
    vscodePath: vscodePath ?? this.vscodePath,
    arduinoPath: arduinoPath ?? this.arduinoPath,
    neovimClean: neovimClean ?? this.neovimClean,
  );

  Map<String, Object> toJson() => {
    'version': 2,
    'projectPath': projectPath,
    'exportScript': exportScript,
    'port': port,
    'baudRate': baudRate,
    'flashBaudRate': flashBaudRate,
    'lineEnding': lineEnding,
    'windowOpacity': windowOpacity,
    'editor': editor.name,
    'vscodePath': vscodePath,
    'arduinoPath': arduinoPath,
    'neovimClean': neovimClean,
  };

  factory AppSettings.fromJson(Map<String, dynamic> data) {
    String string(String key) => data[key] is String ? data[key] as String : '';
    int rate(String key, int fallback) =>
        data[key] is int && data[key] > 0 && data[key] <= 4000000
        ? data[key] as int
        : fallback;
    final ending = string('lineEnding');
    final opacity = data['windowOpacity'];
    return AppSettings(
      projectPath: string('projectPath'),
      exportScript: string('exportScript'),
      port: string('port'),
      baudRate: rate('baudRate', 115200),
      flashBaudRate: rate('flashBaudRate', 460800),
      lineEnding: ['LF', 'CRLF', 'None'].contains(ending) ? ending : 'LF',
      windowOpacity:
          opacity is num && opacity.isFinite && opacity >= 0.7 && opacity <= 1
          ? opacity.toDouble()
          : 0.94,
      editor:
          EditorChoice.values
              .where((value) => value.name == data['editor'])
              .firstOrNull ??
          (data['editor'] == null && data['useNeovim'] == true
              ? EditorChoice.neovim
              : EditorChoice.builtin),
      vscodePath: string('vscodePath'),
      arduinoPath: string('arduinoPath'),
      neovimClean: data['neovimClean'] == true,
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
