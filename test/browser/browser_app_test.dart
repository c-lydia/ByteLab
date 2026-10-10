@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'package:bytelab/main.dart';
import 'package:bytelab/service/serial_service.dart';
import 'package:bytelab/web/browser_io.dart' as browser;
import 'package:bytelab/web/browser_workspace.dart';
import 'package:bytelab/web/serial_transport_web.dart';
import 'package:bytelab/widgets/source_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

@JS('eval')
external JSAny? evaluate(JSString code);

void main() {
  setUp(() {
    web.window.localStorage.removeItem(browser.storageKey);
    BrowserSerialTransport.ports.clear();
  });
  tearDown(() => web.window.localStorage.removeItem(browser.storageKey));

  testWidgets(
    'web app edits, saves with Ctrl+S, recovers a draft, and renders all pages',
    (tester) async {
      final originalErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        // Forward browser framework failures to the command-line test reporter.
        // ignore: avoid_print
        print('BROWSER_ERROR: ${details.toString()}');
        originalErrorHandler!(details);
      };
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      browser.writeSnapshot(
        jsonEncode({
          'version': 1,
          'workspace': BrowserWorkspace.starter('demo').toJson(),
          'file': 'main/main.c',
          'draft': '// recovered draft',
          'baud': 115200,
          'ending': 'LF',
        }),
      );
      await tester.pumpWidget(const ByteLabApp());
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Project'),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(SourceEditor),
        matching: find.byType(TextField),
      );
      expect(find.textContaining('main/main.c • unsaved'), findsOneWidget);
      await tester.enterText(field, '// saved from browser');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      final saved = jsonDecode(browser.readSnapshot()!) as Map<String, dynamic>;
      expect(
        BrowserWorkspace.fromJson(
          saved['workspace'] as Map<String, dynamic>,
        ).read('main/main.c'),
        '// saved from browser',
      );
      expect(saved['draft'], isNull);
      await tester.enterText(field, '// unsaved but recoverable');
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        (jsonDecode(browser.readSnapshot()!) as Map<String, dynamic>)['draft'],
        '// unsaved but recoverable',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      for (final label in [
        'Monitor',
        'Documentation',
        'Build & flash',
        'Settings',
        'Overview',
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const ByteLabApp());
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Project'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('// unsaved but recoverable'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('browser pages fit a narrow phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    browser.writeSnapshot(
      jsonEncode({
        'version': 1,
        'workspace': BrowserWorkspace.starter('demo').toJson(),
        'file': 'main/main.c',
      }),
    );
    await tester.pumpWidget(const ByteLabApp());
    await tester.pumpAndSettle();
    for (final label in [
      'Project',
      'Monitor',
      'Documentation',
      'Build & flash',
      'Settings',
      'Overview',
    ]) {
      await tester.tap(find.byTooltip('Pages'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PopupMenuItem<int>, label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  test(
    'Web Serial adapter handles real stream semantics, UTF-8, writes, and cancellation',
    () async {
      evaluate(
        r'''
      globalThis.bytelabWrites = [];
      globalThis.bytelabPort = {
        async open(options) {
          globalThis.bytelabBaud = options.baudRate;
          this.readable = new ReadableStream({start(c) { globalThis.bytelabReader = c; }});
          this.writable = new WritableStream({write(bytes) { globalThis.bytelabWrites.push(...bytes); }});
        },
        async close() { globalThis.bytelabClosed = true; }
      };
      Object.defineProperty(navigator, 'serial', {configurable: true, value: {requestPort: async () => globalThis.bytelabPort}});
    '''
            .toJS,
      );
      final serial = SerialService();
      final path = await BrowserSerialTransport.requestPort();
      await serial.connect(path, baudRate: 9600);
      final received = serial.logStream.first;
      evaluate(
        'bytelabReader.enqueue(new TextEncoder().encode("I (1) telemetry: ram=12.5\\n"));'
            .toJS,
      );
      await received;
      expect(serial.latestTelemetry['ram'], 12.5);
      await serial.write('PING\n');
      expect(evaluate('bytelabBaud'.toJS).dartify(), 9600);
      expect(evaluate('bytelabWrites'.toJS).dartify(), utf8.encode('PING\n'));
      await serial.disconnect();
      expect(evaluate('bytelabClosed'.toJS).dartify(), isTrue);
      await serial.dispose();
      evaluate('delete navigator.serial;'.toJS);
    },
  );
}
