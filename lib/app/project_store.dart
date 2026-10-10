import 'dart:convert';
import 'dart:io';
import 'firmware_template.dart' as firmware;

class ProjectEntry {
  final String path;
  final String name;
  final bool isDirectory;
  const ProjectEntry(this.path, this.name, this.isDirectory);
}

class ProjectStore {
  String? root;
  String get name => root?.split(Platform.pathSeparator).last ?? 'No project';
  static const ignored = {
    '.git',
    '.dart_tool',
    '.bytelab-backups',
    'build',
    'managed_components',
    '.venv',
    'node_modules',
  };

  Future<void> open(String path) async {
    final directory = Directory(path.trim());
    if (!await directory.exists()) {
      throw FileSystemException('Folder does not exist', path);
    }
    final canonical = await directory.resolveSymbolicLinks();
    if (!await File('$canonical/CMakeLists.txt').exists()) {
      throw const FormatException(
        'Choose an ESP-IDF project folder containing CMakeLists.txt',
      );
    }
    root = canonical;
  }

  Future<String> _inside(String path) async {
    final base = root;
    if (base == null) throw StateError('Open a project first');
    final resolved = await File(path).resolveSymbolicLinks();
    if (resolved != base &&
        !resolved.startsWith('$base${Platform.pathSeparator}')) {
      throw const FileSystemException('This path is outside the open project');
    }
    return resolved;
  }

  Future<List<ProjectEntry>> list([String? directory]) async {
    final location = directory ?? root;
    if (location == null) return [];
    final canonical = await _inside(location);
    final items = <ProjectEntry>[];
    await for (final entity in Directory(canonical).list(followLinks: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (ignored.contains(name) || entity is Link) continue;
      items.add(ProjectEntry(entity.path, name, entity is Directory));
    }
    items.sort(
      (a, b) => a.isDirectory != b.isDirectory
          ? (a.isDirectory ? -1 : 1)
          : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return items;
  }

  Future<String> read(String path) async {
    final file = File(await _inside(path));
    if (await file.length() > 2 * 1024 * 1024) {
      throw const FormatException('The editor supports text files up to 2 MiB');
    }
    return utf8.decode(await file.readAsBytes());
  }

  Future<void> save(
    String path,
    String text, {
    String? expectedContents,
  }) async {
    final canonical = await _inside(path);
    final file = File(canonical);
    if (expectedContents != null &&
        await file.readAsString() != expectedContents) {
      throw const FileSystemException(
        'This file changed outside ByteLab. Reload it before saving',
      );
    }
    final backup = Directory('${root!}/.bytelab-backups');
    await backup.create(recursive: true);
    final name = canonical.substring(root!.length + 1).replaceAll('/', '__');
    await file.copy(
      '${backup.path}/${DateTime.now().microsecondsSinceEpoch}-$name',
    );
    // Preserve permissions and the identity of existing files/symlink targets.
    await file.writeAsString(text, flush: true);
  }

  Future<String> configurationPath({
    bool defaults = false,
    bool create = false,
  }) async {
    final base = root;
    if (base == null) throw StateError('Open a project first');
    final path = '$base/${defaults ? 'sdkconfig.defaults' : 'sdkconfig'}';
    if (!await File(path).exists()) {
      if (!defaults) {
        throw const FileSystemException(
          'Build or reconfigure the project once to generate sdkconfig',
        );
      }
      if (!create) {
        throw const FileSystemException(
          'No sdkconfig.defaults yet. Create one to add project defaults',
        );
      }
      await File(path).writeAsString('# Project defaults\n');
    }
    return path;
  }

  Future<void> create(String parent, String name) async {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$').hasMatch(name)) {
      throw const FormatException(
        'Use letters, numbers, underscores, or hyphens for the project name',
      );
    }
    final parentDirectory = Directory(parent);
    if (!await parentDirectory.exists()) {
      throw const FileSystemException('Choose an existing parent folder');
    }
    final canonicalParent = await parentDirectory.resolveSymbolicLinks();
    final folder = Directory('$canonicalParent/$name');
    if (await folder.exists()) {
      throw const FileSystemException('A folder with that name already exists');
    }
    await Directory('${folder.path}/main').create(recursive: true);
    await File('${folder.path}/CMakeLists.txt').writeAsString(
      'cmake_minimum_required(VERSION 3.16)\ninclude(\$ENV{IDF_PATH}/tools/cmake/project.cmake)\nproject($name)\n',
    );
    await File('${folder.path}/main/CMakeLists.txt').writeAsString(
      'idf_component_register(SRCS "main.c" INCLUDE_DIRS "." REQUIRES esp_system heap spi_flash)\n',
    );
    await File(
      '${folder.path}/sdkconfig.defaults',
    ).writeAsString('# Defaults for this ESP-IDF project\n');
    await File('${folder.path}/main/main.c').writeAsString(starterFirmware);
    await File('${folder.path}/README.md').writeAsString(
      '# $name\n\nESP-IDF firmware created with ByteLab. Build and flash from the app, then connect the serial monitor at 115200 baud. Send `STATUS?`, `PING`, or `HELP`. Telemetry contains measured heap usage and flash capacity; board-specific sensors can be added in main/main.c.\n',
    );
    root = folder.path;
  }

  Future<String> createEntry(
    String directory,
    String name, {
    bool folder = false,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(name) ||
        name == '.' ||
        name == '..') {
      throw const FormatException(
        'Use a filename containing letters, numbers, dots, underscores, or hyphens',
      );
    }
    final parent = await _inside(directory);
    final path = '$parent/$name';
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const FileSystemException('An entry with that name already exists');
    }
    if (folder) {
      await Directory(path).create();
    } else {
      await File(path).writeAsString('');
    }
    return path;
  }

  static const starterFirmware = firmware.starterFirmware;
}
