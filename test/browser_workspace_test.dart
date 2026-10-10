import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:bytelab/web/browser_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'starter edits survive snapshot and ZIP export including binary files',
    () {
      final workspace = BrowserWorkspace.starter('demo');
      workspace.createFile('main/sensor.c');
      workspace.save('main/sensor.c', '// sensor\n');
      workspace.files['asset.bin'] = Uint8List.fromList([0, 255, 128]);
      final restored = BrowserWorkspace.fromJson(
        jsonDecode(jsonEncode(workspace.toJson())) as Map<String, dynamic>,
      );
      expect(restored.read('main/sensor.c'), '// sensor\n');
      final archive = ZipDecoder().decodeBytes(restored.zip(), verify: true);
      expect(archive.findFile('demo/asset.bin')!.content, [0, 255, 128]);
      expect(
        utf8.decode(archive.findFile('demo/main/sensor.c')!.content),
        '// sensor\n',
      );
      expect(() => restored.read('asset.bin'), throwsFormatException);
    },
  );

  test('browser paths reject traversal and file-directory conflicts', () {
    final workspace = BrowserWorkspace.starter('demo');
    for (final path in [
      '/tmp/a',
      '../a',
      'main/../a',
      'main//a',
      r'main\a',
      'x:y',
      '.git/config',
      'build/output.o',
      'main/CMakeLists.txt/x',
    ]) {
      expect(
        () => workspace.createFile(path),
        throwsFormatException,
        reason: path,
      );
    }
    expect(() => workspace.createFile('main'), throwsFormatException);
    expect(
      () => BrowserWorkspace('../demo', workspace.files),
      throwsFormatException,
    );
    expect(() => BrowserWorkspace('empty', {}), throwsFormatException);
  });

  test('oversized edits fail without losing the existing contents', () {
    final workspace = BrowserWorkspace.starter('demo');
    final original = workspace.read('main/main.c');
    expect(
      () => workspace.save('main/main.c', 'x' * (2 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
    expect(workspace.read('main/main.c'), original);
    expect(
      BrowserWorkspace.includePath('build/project_description.json'),
      isTrue,
    );
    expect(BrowserWorkspace.includePath('build/firmware.bin'), isFalse);
  });

  test(
    'browser docs use imported metadata and track configuration edits',
    () async {
      final workspace = BrowserWorkspace.starter('demo');
      workspace.save('sdkconfig.defaults', 'CONFIG_IDF_TARGET="esp32s3"\n');
      workspace.createFile('sdkconfig');
      workspace.save(
        'sdkconfig',
        '# ESP-IDF v5.4.2\nCONFIG_IDF_TARGET="esp32c6"\n',
      );
      final docs = await workspace.detectDocs();
      expect(docs.target, 'esp32c6');
      expect(docs.docsVersion, 'v5.4.2');
      expect(docs.targetSource, 'sdkconfig');
      expect(docs.cmake, isTrue);
    },
  );
}
