import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../app/firmware_template.dart';
import '../service/documentation_catalog.dart';
import '../service/documentation_detector.dart';

/// A browser-owned copy. No native paths or file handles are implied.
class BrowserWorkspace {
  BrowserWorkspace(this.name, Map<String, Uint8List> files)
    : files = Map.of(files) {
    validate();
  }
  final String name;
  final Map<String, Uint8List> files;
  static const maxBytes = 16 * 1024 * 1024;
  static const maxFiles = 1000;
  static const ignored = {
    '.git',
    '.dart_tool',
    '.bytelab-backups',
    'node_modules',
    '.venv',
    'managed_components',
  };

  static bool validPath(String path) =>
      path.isNotEmpty &&
      !path.startsWith('/') &&
      !path.contains('\\') &&
      !path.contains('\u0000') &&
      !path.contains(':') &&
      path.split('/').every((p) => p.isNotEmpty && p != '.' && p != '..');
  static bool includePath(String path) =>
      !path.split('/').any(ignored.contains) &&
      (!path.startsWith('build/') || path == 'build/project_description.json');

  void validate() {
    if (!validPath(name) || name.contains('/')) {
      throw const FormatException('Invalid project name');
    }
    if (files.length > maxFiles ||
        files.values.fold<int>(0, (sum, bytes) => sum + bytes.length) >
            maxBytes) {
      throw const FormatException(
        'Browser projects support up to 1,000 files and 16 MiB. Import source files without generated build output.',
      );
    }
    if (files.keys.any((path) => !validPath(path))) {
      throw const FormatException('Invalid project file path');
    }
    if (!files.containsKey('CMakeLists.txt')) {
      throw const FormatException(
        'Select an ESP-IDF folder containing CMakeLists.txt',
      );
    }
  }

  String read(String path) {
    final bytes = files[path];
    if (bytes == null) throw StateError('File does not exist');
    if (bytes.length > 2 * 1024 * 1024) {
      throw const FormatException('The editor supports text files up to 2 MiB');
    }
    if (bytes.contains(0)) {
      throw const FormatException(
        'Binary files are preserved for download but cannot be edited as text',
      );
    }
    return utf8.decode(bytes);
  }

  void save(String path, String text) {
    if (!files.containsKey(path)) throw StateError('File does not exist');
    final bytes = Uint8List.fromList(utf8.encode(text));
    if (bytes.length > 2 * 1024 * 1024) {
      throw const FormatException('The editor supports text files up to 2 MiB');
    }
    final previous = files[path]!;
    files[path] = bytes;
    try {
      validate();
    } catch (_) {
      files[path] = previous;
      rethrow;
    }
  }

  void createFile(String path) {
    if (!validPath(path) || !includePath(path)) {
      throw const FormatException(
        'Use a relative source-file path, for example main/new.c',
      );
    }
    if (files.containsKey(path) ||
        files.keys.any(
          (other) => other.startsWith('$path/') || path.startsWith('$other/'),
        )) {
      throw const FormatException('A file or folder already uses that path');
    }
    files[path] = Uint8List(0);
    try {
      validate();
    } catch (_) {
      files.remove(path);
      rethrow;
    }
  }

  Uint8List zip() {
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(
        ArchiveFile('$name/${entry.key}', entry.value.length, entry.value),
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Future<ToolchainDocs> detectDocs() => detectDocumentation(
    projectPath: name,
    read: (path) async {
      final relative = path.substring(name.length + 1);
      if (!files.containsKey(relative)) return '';
      try {
        return read(relative);
      } on FormatException {
        return '';
      }
    },
    exists: (path) async => files.containsKey(path.substring(name.length + 1)),
  );

  Map<String, Object> toJson() => {
    'name': name,
    'files': files.map((key, value) => MapEntry(key, base64Encode(value))),
  };
  factory BrowserWorkspace.fromJson(Map<String, dynamic> json) {
    if (json['name'] is! String || json['files'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid saved workspace');
    }
    final raw = json['files'] as Map<String, dynamic>;
    if (raw.length > maxFiles) {
      throw const FormatException('Too many saved files');
    }
    return BrowserWorkspace(
      json['name'] as String,
      raw.map((key, value) {
        if (value is! String || value.length > maxBytes * 2) {
          throw const FormatException('Invalid saved file');
        }
        return MapEntry(key, base64Decode(value));
      }),
    );
  }

  factory BrowserWorkspace.starter(String name) {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$').hasMatch(name)) {
      throw const FormatException(
        'Use letters, numbers, underscores, or hyphens for the project name',
      );
    }
    return BrowserWorkspace(name, {
      for (final entry in {
        'CMakeLists.txt':
            'cmake_minimum_required(VERSION 3.16)\ninclude(\$ENV{IDF_PATH}/tools/cmake/project.cmake)\nproject($name)\n',
        'main/CMakeLists.txt':
            'idf_component_register(SRCS "main.c" INCLUDE_DIRS "." REQUIRES esp_system heap spi_flash)\n',
        'main/main.c': starterFirmware,
        'sdkconfig.defaults':
            '# Defaults for this ESP-IDF project\nCONFIG_IDF_TARGET="esp32"\n',
      }.entries)
        entry.key: Uint8List.fromList(utf8.encode(entry.value)),
    });
  }
}
