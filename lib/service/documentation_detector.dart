import 'dart:convert';
import 'documentation_catalog.dart';

Future<ToolchainDocs> detectDocumentation({
  String? projectPath,
  String? sdkRoot,
  bool selectedSDK = false,
  required Future<String> Function(String) read,
  required Future<bool> Function(String) exists,
  List<String>? notes,
}) async {
  notes ??= [];
  String? target, targetSource, version, versionSource, versionBranch;
  var cmake = false, ninja = false, components = false;
  Map<String, dynamic> build = {};
  if (projectPath != null) {
    final raw = await read('$projectPath/build/project_description.json');
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) throw const FormatException();
        build = decoded;
      } on FormatException {
        notes.add('Build metadata is invalid; using other detection sources.');
      }
    }
    for (final name in ['sdkconfig', 'sdkconfig.defaults']) {
      final config = await read('$projectPath/$name');
      final match = RegExp(
        r'^\s*CONFIG_IDF_TARGET="(esp32[a-z0-9]*)"\s*$',
        multiLine: true,
      ).firstMatch(config);
      if (match != null) {
        target ??= match.group(1);
        targetSource ??= name;
      }
      // Generated sdkconfig records the SDK which generated it.
      final sdk = RegExp(
        r'ESP-IDF\s+(v?\d+\.\d+(?:\.\d+)?[^\s]*)',
      ).firstMatch(config)?.group(1);
      if (DocumentationCatalog.versionPath(sdk) != null &&
          name == 'sdkconfig') {
        version = sdk;
        versionSource = 'sdkconfig (generated configuration)';
      }
    }
    final buildTarget = build['target'];
    if (buildTarget is String &&
        DocumentationCatalog.validTarget(buildTarget)) {
      if (target == null || targetSource == 'sdkconfig.defaults') {
        target = buildTarget;
        targetSource = 'build/project_description.json';
      }
      if (target != buildTarget) {
        notes.add(
          'Build target differs from configuration. Reconfigure to update build metadata.',
        );
      }
    }
    final buildVersion = build['idf_ver'];
    if (buildVersion is String &&
        DocumentationCatalog.versionPath(buildVersion) != null) {
      version = buildVersion;
      versionSource = 'build/project_description.json (last build)';
    }
    cmake = (await read('$projectPath/CMakeLists.txt')).isNotEmpty;
    ninja = await exists('$projectPath/build/build.ninja');
    components =
        await exists('$projectPath/dependencies.lock') ||
        await exists('$projectPath/main/idf_component.yml') ||
        await exists('$projectPath/idf_component.yml');
  }
  if (sdkRoot != null && sdkRoot.isNotEmpty) {
    var installed = (await read('$sdkRoot/version.txt')).trim();
    if (DocumentationCatalog.versionPath(installed) == null) {
      final cmakeVersion = await read('$sdkRoot/tools/cmake/version.cmake');
      String? part(String name) => RegExp(
        'set\\(IDF_VERSION_$name\\s+"?(\\d+)"?\\s*\\)',
        caseSensitive: false,
      ).firstMatch(cmakeVersion)?.group(1);
      final major = part('MAJOR'), minor = part('MINOR'), patch = part('PATCH');
      installed = major != null && minor != null
          ? '$major.$minor.${patch ?? '0'}'
          : '';
      // version.cmake gives a release series, not necessarily a release tag.
      if (installed.isNotEmpty) versionBranch = 'release-v$major.$minor';
    }
    if (DocumentationCatalog.versionPath(installed) != null) {
      if (version != null &&
          DocumentationCatalog.versionPath(version) !=
              DocumentationCatalog.versionPath(installed)) {
        notes.add(
          'Installed SDK differs from the last generated project metadata. Docs follow the selected SDK.',
        );
      }
      version = installed;
      versionSource = selectedSDK ? 'SDK selected in Settings' : 'IDF_PATH';
    } else {
      notes.add(
        'SDK version could not be read; choose a docs version below if needed.',
      );
    }
  }
  return ToolchainDocs(
    target: target,
    targetSource: targetSource,
    version: version,
    versionSource: versionSource,
    versionBranch: versionBranch,
    cmake: cmake,
    ninja: ninja,
    components: components,
    notes: notes,
  );
}
