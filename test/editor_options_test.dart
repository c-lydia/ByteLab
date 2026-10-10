import 'dart:io';
import 'package:bytelab/app/app_controller.dart';
import 'package:bytelab/app/settings_store.dart';
import 'package:bytelab/screens/settings_page.dart';
import 'package:bytelab/service/external_editor_service.dart';
import 'package:bytelab/service/window_appearance.dart';
import 'package:bytelab/theme/app_theme.dart';
import 'package:bytelab/widgets/user_manual.dart';
import 'package:bytelab/widgets/external_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'widget_test.dart' show MemorySettingsStore;

void main() {
  test(
    'editor migration preserves explicit choices and rejects unknown modes',
    () {
      expect(const AppSettings().editor, EditorChoice.builtin);
      expect(
        AppSettings.fromJson({'useNeovim': true}).editor,
        EditorChoice.neovim,
      );
      expect(
        AppSettings.fromJson({'useNeovim': false}).editor,
        EditorChoice.builtin,
      );
      expect(
        AppSettings.fromJson({'editor': 'invalid', 'useNeovim': true}).editor,
        EditorChoice.builtin,
      );
      for (final editor in EditorChoice.values) {
        final settings = AppSettings(
          editor: editor,
          vscodePath: '/opt/code',
          arduinoPath: '/opt/Arduino IDE',
        );
        expect(
          AppSettings.fromJson(settings.toJson()).toJson(),
          settings.toJson(),
        );
      }
    },
  );

  test(
    'external targets stay literal and Arduino rejects ESP-IDF source files',
    () {
      const path = '/tmp/a project/odd " \$() ;.c';
      expect(ExternalEditorService.arguments(EditorChoice.vscode, path), [
        '--reuse-window',
        '--',
        path,
      ]);
      expect(
        () => ExternalEditorService.arguments(EditorChoice.arduino, path),
        throwsFormatException,
      );
      expect(
        ExternalEditorService.arguments(
          EditorChoice.arduino,
          '/tmp/Blink/Blink.ino',
        ),
        ['/tmp/Blink/Blink.ino'],
      );
      expect(
        ExternalEditorService.arguments(EditorChoice.arduino, null),
        isEmpty,
      );
    },
  );

  test(
    'finds installed executables and respects an explicit override',
    () async {
      final temp = await Directory.systemTemp.createTemp('bytelab-editors-');
      addTearDown(() => temp.delete(recursive: true));
      final code = await File(
        '${temp.path}/code',
      ).writeAsString('#!/bin/sh\nexit 0\n');
      final appImage = await File(
        '${temp.path}/Arduino IDE.AppImage',
      ).writeAsString('#!/bin/sh\nexit 0\n');
      if (!Platform.isWindows) {
        expect(
          (await Process.run('chmod', [
            '+x',
            code.path,
            appImage.path,
          ])).exitCode,
          0,
        );
      }
      final service = ExternalEditorService(environment: {'PATH': temp.path});
      expect(await service.resolve(EditorChoice.vscode, ''), code.path);
      expect(
        await service.resolve(EditorChoice.arduino, appImage.path),
        appImage.path,
      );
      await expectLater(
        service.resolve(EditorChoice.vscode, '${temp.path}/missing'),
        throwsStateError,
      );
      await expectLater(
        service.resolve(EditorChoice.arduino, ''),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'editor selection persists separate paths and guards dirty drafts',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        WindowAppearance.channel,
        (_) async => true,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          WindowAppearance.channel,
          null,
        ),
      );
      final store = MemorySettingsStore();
      final app = AppController(settingsStore: store, portProvider: () => []);
      await tester.pumpWidget(
        AppScope(
          controller: app,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(body: SettingsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dropdown = find.byType(DropdownButtonFormField<EditorChoice>);
      Future<void> choose(String label) async {
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await choose('VS Code');
      await tester.enterText(
        find.widgetWithText(TextField, 'Executable path (optional)'),
        '/opt/code',
      );
      await choose('Arduino IDE');
      await tester.enterText(
        find.widgetWithText(TextField, 'Executable path (optional)'),
        '/opt/arduino',
      );
      await choose('VS Code');
      expect(find.text('/opt/code'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.scrollUntilVisible(
        find.text('Save settings'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save settings'));
      await tester.pumpAndSettle();
      expect(store.settings.editor, EditorChoice.vscode);
      expect(store.settings.vscodePath, '/opt/code');
      expect(store.settings.arduinoPath, '/opt/arduino');
      app.unsavedEditors.add(Object());
      await expectLater(
        app.saveSettings(app.settings.copyWith(editor: EditorChoice.builtin)),
        throwsStateError,
      );
      expect(app.settings.editor, EditorChoice.vscode);
      expect(tester.takeException(), isNull);
      await tester.runAsync(app.shutdown);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'external editor panel scrolls in a small workspace and rejects non-sketch launch',
    (tester) async {
      final app = AppController(portProvider: () => [])
        ..settings = const AppSettings(editor: EditorChoice.arduino);
      await tester.pumpWidget(
        AppScope(
          controller: app,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 350,
                  height: 300,
                  child: ExternalEditor(
                    root: '/tmp/project',
                    file: '/tmp/project/main.c',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Open sketch'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('User manual'));
      await tester.tap(find.text('User manual'));
      await tester.pumpAndSettle();
      expect(app.selectedPage, 8);
      expect(tester.takeException(), isNull);
      await tester.runAsync(app.shutdown);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('offline manual expands editor instructions without a project', (
    tester,
  ) async {
    final app = AppController(portProvider: () => []);
    await tester.pumpWidget(
      AppScope(
        controller: app,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: ListView(children: const [UserManual()])),
        ),
      ),
    );
    expect(find.text('User manual'), findsOneWidget);
    await tester.tap(find.text('How to use ByteLab'));
    await tester.pumpAndSettle();
    final topic = find.text('Arduino IDE · sketches, boards, and libraries');
    await tester.ensureVisible(topic);
    await tester.tap(topic);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Selecting Arduino IDE does not convert'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Disconnect the ByteLab monitor'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(app.shutdown);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
