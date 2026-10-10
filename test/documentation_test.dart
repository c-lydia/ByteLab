import 'dart:io';
import 'package:bytelab/service/documentation_service.dart';
import 'package:bytelab/widgets/code_block.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(() => directory = Directory.systemTemp.createTempSync('bytelab-docs-'));
  tearDown(() => directory.deleteSync(recursive: true));
  Future<void> write(String path, String data) async {
    final file = File('${directory.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsString(data);
  }

  test(
    'missing toolchain uses explicit stable ESP32 browsing defaults',
    () async {
      final docs = await DocumentationService().detect(environment: {});
      expect(docs.target, isNull);
      expect(docs.version, isNull);
      expect(
        DocumentationService.resources(docs).first.url,
        'https://docs.espressif.com/projects/esp-idf/en/stable/esp32/',
      );
    },
  );

  test(
    'active configuration and selected SDK win over defaults and old build',
    () async {
      await write('sdkconfig', 'CONFIG_IDF_TARGET="esp32s3"\n');
      await write('sdkconfig.defaults', 'CONFIG_IDF_TARGET="esp32c3"\n');
      await write(
        'build/project_description.json',
        '{"target":"esp32","idf_ver":"v5.2.1"}',
      );
      await write('sdk/version.txt', 'v5.4.2\n');
      await write('CMakeLists.txt', 'project(test)');
      await write('build/build.ninja', '');
      await write('main/idf_component.yml', 'dependencies: {}');
      final docs = await DocumentationService().detect(
        projectPath: directory.path,
        exportScript: '${directory.path}/sdk/export.sh',
        environment: {},
      );
      expect(docs.target, 'esp32s3');
      expect(docs.targetSource, 'sdkconfig');
      expect(docs.version, 'v5.4.2');
      expect(docs.notes, hasLength(2));
      final resources = DocumentationService.resources(docs);
      expect(resources.first.url, endsWith('/v5.4.2/esp32s3/'));
      expect(
        resources.map((doc) => doc.title),
        containsAll([
          'CMake reference',
          'Ninja manual',
          'IDF Component Manager',
        ]),
      );
      expect(
        DocumentationService.resources(
          docs,
          targetOverride: 'esp32c6',
          versionOverride: 'stable',
        ).first.url,
        endsWith('/stable/esp32c6/'),
      );
    },
  );

  test(
    'malformed build metadata still allows defaults and environment SDK',
    () async {
      await write('build/project_description.json', '[]');
      await write('sdkconfig.defaults', 'CONFIG_IDF_TARGET="esp32c6"\n');
      await write(
        'sdk/tools/cmake/version.cmake',
        'set(IDF_VERSION_MAJOR 5)\nset(IDF_VERSION_MINOR 4)\nset(IDF_VERSION_PATCH 1)',
      );
      final docs = await DocumentationService().detect(
        projectPath: directory.path,
        environment: {'IDF_PATH': '${directory.path}/sdk'},
      );
      expect(docs.target, 'esp32c6');
      expect(docs.docsVersion, 'release-v5.4');
      expect(docs.notes.single, contains('invalid'));
    },
  );

  test(
    'last build supplies version and target when SDK is unavailable',
    () async {
      await write(
        'build/project_description.json',
        '{"target":"esp32h2","idf_ver":"v5.3.2"}',
      );
      final docs = await DocumentationService().detect(
        projectPath: directory.path,
        environment: {},
      );
      expect(docs.target, 'esp32h2');
      expect(docs.docsVersion, 'v5.3.2');
      expect(docs.versionSource, contains('last build'));
      await write(
        'build/project_description.json',
        '{"target":"../../evil","idf_ver":"<script>"}',
      );
      final invalid = await DocumentationService().detect(
        projectPath: directory.path,
        environment: {},
      );
      expect(invalid.target, isNull);
      expect(invalid.docsVersion, 'stable');
    },
  );

  test('version paths distinguish releases and development metadata', () {
    expect(DocumentationService.versionPath('v5.4.1'), 'v5.4.1');
    expect(DocumentationService.versionPath('v5.4'), 'v5.4');
    expect(
      DocumentationService.versionPath('v5.4.1-23-gabc-dirty'),
      'release-v5.4',
    );
    expect(DocumentationService.versionPath('v6.0-dev'), 'release-v6.0');
    expect(DocumentationService.versionPath('../../elsewhere'), isNull);
    expect(
      () => DocumentationService.resources(
        const ToolchainDocs(),
        targetOverride: '../../elsewhere',
      ),
      throwsFormatException,
    );
  });

  test(
    'highlighter preserves code, multiline comments, and string contents',
    () {
      const source =
          '/* first\nsecond */\nconst char *s = "if // text";\nreturn 42;\n';
      final spans = highlightCode(source, 'cpp');
      expect(spans.map((span) => span.text).join(), source);
      expect(spans.first.text, '/* first\nsecond */');
      expect(spans.first.style?.color, isNotNull);
      expect(spans.where((span) => span.text == '"if // text"'), hasLength(1));
      expect(codeLanguage('/project/main/CMakeLists.txt'), 'cmake');
      expect(codeLanguage('/project/sdkconfig.defaults'), 'config');
      expect(codeLanguage('main.cpp'), 'cpp');
      expect(highlightCode(source, 'text').single.text, source);
    },
  );
}
