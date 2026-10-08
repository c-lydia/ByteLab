import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bytelab/app/project_store.dart';
import 'package:bytelab/app/settings_store.dart';
import 'package:bytelab/app/app_controller.dart';

void main() {
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('bytelab-project-');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test(
    'starter has valid project structure; saving backs up and rejects external edits',
    () async {
      final store = ProjectStore();
      await store.create(temp.path, 'demo');
      expect(await File('${store.root}/main/main.c').exists(), isTrue);
      final file = '${store.root}/main/main.c';
      final original = await store.read(file);
      await store.save(file, '$original\n// saved', expectedContents: original);
      final backups = await Directory(
        '${store.root}/.bytelab-backups',
      ).list().toList();
      expect(backups, hasLength(1));
      expect(await File(backups.single.path).readAsString(), original);
      await File(file).writeAsString('external edit');
      await expectLater(
        store.save(file, 'overwrite', expectedContents: '$original\n// saved'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(file).readAsString(), 'external edit');
      expect(
        (await store.list()).map((e) => e.name),
        isNot(contains('.bytelab-backups')),
      );
      await expectLater(
        store.create(temp.path, 'demo'),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test(
    'project editor rejects traversal, symlink escapes, and duplicate files',
    () async {
      final store = ProjectStore();
      await store.create(temp.path, 'demo');
      final outside = File('${temp.path}/outside');
      await outside.writeAsString('private');
      await Link('${store.root}/escape').create(outside.path);
      await expectLater(
        store.read('${store.root}/escape'),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        store.list(temp.path),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        store.createEntry(store.root!, '../bad'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        store.createEntry(store.root!, 'CMakeLists.txt'),
        throwsA(isA<FileSystemException>()),
      );
      final fresh = await store.createEntry(store.root!, 'notes.txt');
      expect(await store.read(fresh), '');
    },
  );

  test('settings round trip preserves SDK, project, port and rates', () async {
    final store = SettingsStore(
      file: File('${temp.path}/config/settings.json'),
    );
    const settings = AppSettings(
      projectPath: '/tmp/demo',
      exportScript: '/tmp/esp/export.sh',
      port: '/dev/fake',
      baudRate: 9600,
      flashBaudRate: 115200,
      lineEnding: 'CRLF',
    );
    await store.save(settings);
    expect((await store.load()).toJson(), settings.toJson());
    await store.file.writeAsString('invalid');
    await expectLater(store.load(), throwsFormatException);
  });

  test(
    'controller blocks project switching and builds with unsaved edits',
    () async {
      final app = AppController(
        settingsStore: SettingsStore(file: File('${temp.path}/settings.json')),
        portProvider: () => [],
      );
      await app.initialize();
      await app.createProject(temp.path, 'demo');
      app.unsavedEditors.add('editor');
      await expectLater(
        app.createProject(temp.path, 'other'),
        throwsStateError,
      );
      await expectLater(app.build(), throwsStateError);
      await app.shutdown();
    },
  );
}
