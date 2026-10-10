import 'dart:io';
import '../app/settings_store.dart';

class ExternalEditorService {
  ExternalEditorService({Map<String, String>? environment})
    : environment = environment ?? Platform.environment;
  final Map<String, String> environment;

  Future<String> resolve(EditorChoice editor, String override) async {
    if (!editor.external) throw ArgumentError('Choose an external editor');
    final candidates = override.trim().isNotEmpty
        ? [override.trim()]
        : editor == EditorChoice.vscode
        ? ['code', 'code-insiders']
        : ['arduino-ide', 'arduino'];
    for (final candidate in candidates) {
      final paths = candidate.contains('/') || candidate.contains('\\')
          ? [candidate]
          : [
              for (final dir in (environment['PATH'] ?? '').split(
                Platform.isWindows ? ';' : ':',
              ))
                if (dir.isNotEmpty) '$dir${Platform.pathSeparator}$candidate',
            ];
      for (final path in paths) {
        final stat = await File(path).stat();
        if (stat.type == FileSystemEntityType.file &&
            (Platform.isWindows || stat.mode & 0x49 != 0)) {
          return File(path).absolute.path;
        }
      }
    }
    throw StateError(
      '${editor.label} was not found. Install it and add its command to PATH, or choose its executable in Settings.',
    );
  }

  static List<String> arguments(EditorChoice editor, String? target) {
    if (!editor.external) throw ArgumentError('Choose an external editor');
    if (target == null) return const [];
    final path = File(target).absolute.path;
    if (editor == EditorChoice.arduino &&
        !path.toLowerCase().endsWith('.ino') &&
        !path.toLowerCase().endsWith('.pde')) {
      throw const FormatException(
        'Arduino IDE opens sketches (.ino or .pde). Use VS Code or the built-in editor for ESP-IDF source files.',
      );
    }
    return editor == EditorChoice.vscode
        ? ['--reuse-window', '--', path]
        : [path];
  }

  Future<void> open(AppSettings settings, {String? target}) async {
    final args = arguments(settings.editor, target);
    final executable = await resolve(
      settings.editor,
      settings.editor == EditorChoice.vscode
          ? settings.vscodePath
          : settings.arduinoPath,
    );
    // Pass paths as individual arguments; never interpret them as shell commands.
    await Process.start(executable, args, mode: ProcessStartMode.detached);
  }
}
