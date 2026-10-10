import 'dart:convert';
import 'dart:io';
import 'package:bytelab/app/settings_store.dart';
import 'package:bytelab/service/neovim_service.dart';
import 'package:bytelab/service/window_appearance.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('editor and opacity settings migrate and round trip', () {
    final old = AppSettings.fromJson({'projectPath': '/tmp/project'});
    expect(old.editor, EditorChoice.builtin);
    expect(
      AppSettings.fromJson({'useNeovim': true}).editor,
      EditorChoice.neovim,
    );
    expect(old.neovimClean, isFalse);
    expect(old.windowOpacity, .94);
    final changed = old.copyWith(
      editor: EditorChoice.vscode,
      vscodePath: "/opt/VS Code/code",
      arduinoPath: "/opt/arduino.AppImage",
      neovimClean: true,
      windowOpacity: .8,
    );
    expect(AppSettings.fromJson(changed.toJson()).toJson(), changed.toJson());
    for (final invalid in [-1, 0, 2, 'bad', double.nan]) {
      expect(
        AppSettings.fromJson({'windowOpacity': invalid}).windowOpacity,
        .94,
      );
    }
  });

  test('opacity bridge validates and sends only supported values', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WindowAppearance.channel, (call) async {
          calls.add(call);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(WindowAppearance.channel, null),
    );
    final service = WindowAppearance();
    expect(await service.setOpacity(.85), Platform.isLinux);
    if (Platform.isLinux) {
      expect(calls.single.method, 'setOpacity');
      expect(calls.single.arguments, .85);
    }
    await expectLater(service.setOpacity(.2), throwsFormatException);
    await expectLater(service.setOpacity(double.nan), throwsFormatException);
  });

  test('remote expressions encode quotes, slashes, and newlines as data', () {
    const lua = '"quoted \\" text"\nreturn 1';
    expect(
      NeovimService.expression(lua),
      'json_encode(luaeval(${jsonEncode(lua)}))',
    );
    expect(
      NeovimService.findExecutable(environment: {'PATH': '/not/a/bin'}),
      isNull,
    );
  });

  // Opt in after the Linux build bundles libflutter_pty.so; never load the
  // developer's real config or install plugins while running tests.
  final integration = Platform.environment['BYTELAB_TEST_NEOVIM'] == '1';
  test(
    'real Neovim loads config, handles motions, preserves filenames, saves and exits',
    () async {
      final directory = await Directory.systemTemp.createTemp('bl-nvim-test-');
      final config = Directory('${directory.path}/config/bytelab-test');
      await config.create(recursive: true);
      await File('${config.path}/init.lua').writeAsString('''
vim.g.bytelab_test_config = true
vim.o.hidden = true
vim.api.nvim_create_user_command('Lazy', function() vim.g.bytelab_test_plugins = true end, {})
vim.keymap.set('n', 'Q', function() vim.g.bytelab_test_mapping = true end)
''');
      final file = File('${directory.path}/odd \' " | %.c');
      await file.writeAsString('first\nsecond\nthird\n');
      final editor = NeovimService(
        environment: {
          ...Platform.environment,
          'NVIM_APPNAME': 'bytelab-test',
          'XDG_CONFIG_HOME': '${directory.path}/config',
          'XDG_DATA_HOME': '${directory.path}/data',
          'XDG_STATE_HOME': '${directory.path}/state',
          'XDG_CACHE_HOME': '${directory.path}/cache',
        },
      );
      addTearDown(() async {
        await editor.dispose();
        await directory.delete(recursive: true);
      });
      await editor.openFile(directory.path, file.path);
      expect(
        await editor.evaluate('vim.g.bytelab_test_config'),
        isTrue,
        reason: (await editor.evaluate(
          '{vim.fn.stdpath("config"), vim.env.MYVIMRC or "none", vim.v.vim_did_enter}',
        )).toString(),
      );
      expect(await editor.evaluate('vim.api.nvim_buf_get_name(0)'), file.path);
      await editor.showPlugins();
      expect(await editor.evaluate('vim.g.bytelab_test_plugins'), isTrue);
      editor.terminal.onOutput!('Q');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await editor.evaluate('vim.g.bytelab_test_mapping'), isTrue);
      editor.terminal.onOutput!('ggj');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        (await editor.evaluate('vim.api.nvim_win_get_cursor(0)') as List).first,
        2,
      );
      editor.terminal.onOutput!('iEDITED\u001b');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await editor.refreshModified();
      expect(editor.modified, isTrue);
      await expectLater(editor.ensureSaved(), throwsStateError);
      await editor.saveAll();
      expect(await file.readAsString(), contains('EDITEDsecond'));
      expect(editor.modified, isFalse);
      await editor.ensureSaved();
      await editor.close();
      expect(editor.running, isFalse);
      await editor.start(directory.path, clean: true);
      expect(await editor.evaluate('vim.g.bytelab_test_config == nil'), isTrue);
      await expectLater(editor.showPlugins(), throwsStateError);
      editor.terminal.onOutput!(':qa!\r');
      for (var i = 0; i < 30 && editor.running; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(editor.running, isFalse);
      expect(editor.needsAttention, isFalse);
    },
    skip: !integration,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
