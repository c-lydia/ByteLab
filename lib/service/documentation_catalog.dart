class ToolchainDocs {
  const ToolchainDocs({
    this.target,
    this.targetSource,
    this.version,
    this.versionSource,
    this.versionBranch,
    this.cmake = false,
    this.ninja = false,
    this.components = false,
    this.notes = const [],
  });
  final String? target, targetSource, version, versionSource, versionBranch;
  final bool cmake, ninja, components;
  final List<String> notes;
  String get docsVersion =>
      versionBranch ?? DocumentationCatalog.versionPath(version) ?? 'stable';
}

class DocResource {
  const DocResource(this.title, this.description, this.category, this.url);
  final String title, description, category, url;
  bool matches(String query) => '$title $description $category'
      .toLowerCase()
      .contains(query.toLowerCase());
}

class DocumentationCatalog {
  static bool validTarget(String value) =>
      RegExp(r'^esp32[a-z0-9]*$').hasMatch(value);

  static String? versionPath(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^v?(\d+)\.(\d+)(?:\.(\d+))?((?:[-+][A-Za-z0-9.-]+)?)$',
    ).firstMatch(value.trim());
    if (match == null) return null;
    if (match.group(4)!.isNotEmpty) {
      return 'release-v${match.group(1)}.${match.group(2)}';
    }
    return 'v${match.group(1)}.${match.group(2)}${match.group(3) == null ? '' : '.${match.group(3)}'}';
  }

  static List<DocResource> resources(
    ToolchainDocs detected, {
    String? targetOverride,
    String? versionOverride,
  }) {
    final target = targetOverride ?? detected.target ?? 'esp32';
    final version = versionOverride ?? detected.docsVersion;
    if (!validTarget(target) ||
        !RegExp(
          r'^(stable|latest|v\d+\.\d+(?:\.\d+)?|release-v\d+\.\d+)$',
        ).hasMatch(version)) {
      throw const FormatException('Invalid documentation target or version');
    }
    final base =
        'https://docs.espressif.com/projects/esp-idf/en/$version/$target';
    return [
      DocResource(
        'ESP-IDF programming guide',
        'The official SDK reference for $target · $version.',
        'ESP-IDF',
        '$base/',
      ),
      DocResource(
        'Install and get started',
        'Install the SDK, connect a board, and build your first project.',
        'Setup',
        '$base/get-started/',
      ),
      DocResource(
        'Build system and components',
        'CMake project structure, component registration, and dependencies.',
        'Build',
        '$base/api-guides/build-system.html',
      ),
      DocResource(
        'Project configuration',
        'Look up sdkconfig options and configuration values.',
        'Configuration',
        '$base/api-reference/kconfig.html',
      ),
      DocResource(
        'API reference',
        'Drivers, FreeRTOS, networking, storage, and system APIs.',
        'Reference',
        '$base/api-reference/',
      ),
      DocResource(
        'esptool',
        'Official flashing and connection troubleshooting reference (latest).',
        'Flash',
        'https://docs.espressif.com/projects/esptool/en/latest/$target/',
      ),
      const DocResource(
        'VS Code command-line guide',
        'Open files and folders with your installed VS Code launcher.',
        'Editor',
        'https://code.visualstudio.com/docs/configure/command-line',
      ),
      const DocResource(
        'Arduino sketch specification',
        'Sketch folders, primary .ino files, and supported source files.',
        'Editor',
        'https://docs.arduino.cc/arduino-cli/sketch-specification/',
      ),
      const DocResource(
        'Neovim quick reference',
        'Normal, Insert, Visual mode, motions, operators, and editing commands.',
        'Editor',
        'https://neovim.io/doc/user/quickref/',
      ),
      const DocResource(
        'Neovim configuration and startup',
        'User configuration, runtime files, clean mode, and startup options.',
        'Editor',
        'https://neovim.io/doc/user/starting/',
      ),
      const DocResource(
        'lazy.nvim plugin manager',
        'Manage plugins with the Lazy interface when installed in your Neovim configuration.',
        'Editor',
        'https://lazy.folke.io/usage',
      ),
      if (detected.cmake)
        const DocResource(
          'CMake reference',
          'Commands, variables, and language reference (latest). Detected CMakeLists.txt.',
          'Build',
          'https://cmake.org/cmake/help/latest/',
        ),
      if (detected.ninja)
        const DocResource(
          'Ninja manual',
          'Build rules and command-line options. Detected build/build.ninja.',
          'Build',
          'https://ninja-build.org/manual.html',
        ),
      if (detected.components)
        const DocResource(
          'IDF Component Manager',
          'Dependency manifests, version constraints, and the component registry (latest).',
          'Dependencies',
          'https://docs.espressif.com/projects/idf-component-manager/en/latest/',
        ),
    ];
  }
}
