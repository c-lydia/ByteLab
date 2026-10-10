import 'dart:io';
import 'package:bytelab/widgets/source_editor.dart';
import 'package:flutter/material.dart';
import 'package:bytelab/service/window_appearance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bytelab/main.dart';
import 'package:bytelab/app/app_controller.dart';
import 'package:bytelab/app/settings_store.dart';
import 'package:bytelab/service/serial_service.dart';
import 'package:bytelab/service/device_scanner.dart';
import 'fakes.dart';

class MemorySettingsStore extends SettingsStore {
  AppSettings settings = const AppSettings();
  @override
  Future<AppSettings> load() async => settings;
  @override
  Future<void> save(AppSettings next) async {
    settings = next;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          WindowAppearance.channel,
          (call) async => true,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WindowAppearance.channel, null);
  });
  for (final size in [const Size(1360, 900), const Size(1000, 720)]) {
    testWidgets('all ten sections render and navigate at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = AppController(
        settingsStore: MemorySettingsStore(),
        portProvider: () => [],
      );
      await tester.pumpWidget(ByteLabApp(controller: app));
      await tester.pumpAndSettle();
      expect(find.text('Workspace overview'), findsOneWidget);
      for (var i = 1; i < 10; i++) {
        await tester.ensureVisible(find.byKey(ValueKey('nav-$i')));
        await tester.tap(find.byKey(ValueKey('nav-$i')));
        await tester.pumpAndSettle();
        expect(app.selectedPage, i);
        expect(tester.takeException(), isNull, reason: 'page $i at $size');
      }
      await tester.runAsync(app.shutdown);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('connect, receive telemetry, send command, and disconnect', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = FakeTransport();
    final store = MemorySettingsStore();
    await store.save(const AppSettings(port: '/fake'));
    final app = AppController(
      serialService: SerialService(transportFactory: () => transport),
      settingsStore: store,
      portProvider: () => [
        const DiscoveredDevice(path: '/fake', label: 'Test board'),
      ],
    );
    await tester.pumpWidget(ByteLabApp(controller: app));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(app.serial.isConnected, isTrue);
    transport.emit('I (1) telemetry: ram=84\nI (1) device: fw=2.0,idf=v6\n');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('84 KB'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-4')));
    await tester.pumpAndSettle();
    final command = find.widgetWithText(TextField, 'Command · LF');
    await tester.enterText(command, 'PING');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(transport.writes.last, [80, 73, 78, 71, 10]);
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(app.serial.isConnected, isFalse);
    await tester.runAsync(app.shutdown);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'project editor preserves drafts across navigation and saves with a backup',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory.systemTemp.createTempSync(
        'bytelab-editor-ui-',
      );
      final app = AppController(
        settingsStore: MemorySettingsStore(),
        portProvider: () => [],
      );
      await tester.runAsync(() async {
        await app.initialize();
        await app.createProject(directory.path, 'editor_demo');
      });
      await tester.pumpWidget(ByteLabApp(controller: app));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      Future<void> flushFiles([bool Function()? done]) async {
        for (var i = 0; i < (done == null ? 20 : 200); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 20));
          if (done?.call() == true) return;
        }
      }

      await flushFiles();
      await tester.tap(find.text('CMakeLists.txt'));
      await flushFiles();
      final source = find.descendant(
        of: find.byType(SourceEditor),
        matching: find.byType(TextField),
      );
      expect(source, findsOneWidget);
      final text = (tester.widget<TextField>(source).controller!.text);
      await tester.enterText(source, '$text\n# Saved in UI test\n');
      expect(app.unsavedEditors, hasLength(1));
      await tester.tap(find.byKey(const ValueKey('nav-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(source).controller!.text,
        contains('# Saved in UI test'),
      );
      await tester.tap(find.text('Save'));
      await flushFiles(() => app.unsavedEditors.isEmpty);
      expect(app.unsavedEditors, isEmpty);
      expect(
        File('${app.project.root}/CMakeLists.txt').readAsStringSync(),
        contains('# Saved in UI test'),
      );
      expect(
        Directory('${app.project.root}/.bytelab-backups').listSync(),
        hasLength(1),
      );
      await tester.tap(find.byKey(const ValueKey('nav-5')));
      await flushFiles();
      expect(tester.takeException(), isNull);
      expect(find.byType(SourceEditor), findsOneWidget);
      await tester.runAsync(app.shutdown);
      await tester.pumpWidget(const SizedBox.shrink());
      directory.deleteSync(recursive: true);
    },
  );
}
