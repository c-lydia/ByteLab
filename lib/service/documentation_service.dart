import 'dart:async';
import 'dart:io';
import 'documentation_catalog.dart';
import 'documentation_detector.dart';
export 'documentation_catalog.dart';

class DocumentationService {
  // Read metadata only: visiting Documentation never sources or runs project code.
  Future<ToolchainDocs> detect({
    String? projectPath,
    String exportScript = '',
    Map<String, String>? environment,
  }) async {
    final notes = <String>[];
    Future<String> read(String path) async {
      try {
        final file = File(path);
        if (!await file.exists()) return '';
        if (await file.length() > 2 * 1024 * 1024) {
          notes.add(
            'Skipped oversized metadata: ${file.uri.pathSegments.last}',
          );
          return '';
        }
        return await file.readAsString();
      } on FileSystemException {
        notes.add('Could not read ${File(path).uri.pathSegments.last}.');
        return '';
      } on FormatException {
        notes.add('Invalid text in ${File(path).uri.pathSegments.last}.');
        return '';
      }
    }

    return detectDocumentation(
      projectPath: projectPath,
      sdkRoot: exportScript.isNotEmpty
          ? File(exportScript).parent.path
          : (environment ?? Platform.environment)['IDF_PATH'],
      selectedSDK: exportScript.isNotEmpty,
      read: read,
      exists: (path) => File(path).exists(),
      notes: notes,
    );
  }

  static bool validTarget(String value) =>
      DocumentationCatalog.validTarget(value);
  static String? versionPath(String? value) =>
      DocumentationCatalog.versionPath(value);
  static List<DocResource> resources(
    ToolchainDocs detected, {
    String? targetOverride,
    String? versionOverride,
  }) => DocumentationCatalog.resources(
    detected,
    targetOverride: targetOverride,
    versionOverride: versionOverride,
  );

  static Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' ||
        !{
          'docs.espressif.com',
          'cmake.org',
          'ninja-build.org',
          'neovim.io',
          'lazy.folke.io',
          'code.visualstudio.com',
          'docs.arduino.cc',
        }.contains(uri.host)) {
      throw const FormatException('Unsupported documentation URL');
    }
    final command = Platform.isMacOS
        ? 'open'
        : Platform.isWindows
        ? 'rundll32'
        : 'xdg-open';
    final args = Platform.isWindows
        ? ['url.dll,FileProtocolHandler', url]
        : [url];
    final process = await Process.start(command, args);
    final output = process.stdout.drain<void>();
    final errors = process.stderr.drain<void>();
    try {
      final code = await process.exitCode.timeout(const Duration(seconds: 10));
      await Future.wait([output, errors]).timeout(const Duration(seconds: 2));
      if (code != 0) {
        throw StateError(
          'Could not open browser. Copy the documentation link instead.',
        );
      }
    } on TimeoutException {
      process.kill();
      throw StateError(
        'Browser launch timed out. Copy the documentation link instead.',
      );
    }
  }
}
