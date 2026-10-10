import 'package:bytelab/app/app_controller.dart';
import 'package:bytelab/screens/documentation_page.dart';
import 'package:bytelab/service/documentation_service.dart';
import 'package:bytelab/theme/app_theme.dart';
import 'package:bytelab/widgets/code_block.dart';
import 'package:bytelab/widgets/source_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDocs extends DocumentationService {
  int calls = 0;
  @override
  Future<ToolchainDocs> detect({
    String? projectPath,
    String exportScript = '',
    Map<String, String>? environment,
  }) async {
    calls++;
    return const ToolchainDocs(
      target: 'esp32s3',
      targetSource: 'sdkconfig',
      version: 'v5.4.2',
      versionSource: 'SDK selected in Settings',
      cmake: true,
    );
  }
}

void main() {
  testWidgets(
    'docs detect, search, open matched URL, override, refresh, and handle empty results',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = AppController(portProvider: () => [])..navigate(8);
      final service = FakeDocs();
      String? opened;
      await tester.pumpWidget(
        AppScope(
          controller: app,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: DocumentationPage(
                service: service,
                openUrl: (url) async => opened = url,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('SDK: v5.4.2 · SDK selected in Settings'),
        findsOneWidget,
      );
      final search = find.byType(TextField);
      await tester.enterText(search, 'programming guide');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Read official docs'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read official docs'));
      await tester.pumpAndSettle();
      expect(opened, endsWith('/v5.4.2/esp32s3/'));
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stable release').last);
      await tester.pumpAndSettle();
      expect(find.text('Docs: stable'), findsOneWidget);
      await tester.enterText(search, 'no-such-reference');
      await tester.pumpAndSettle();
      expect(
        find.text('No matching references. Try another search or category.'),
        findsOneWidget,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Refresh detection'),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh detection'));
      await tester.pumpAndSettle();
      expect(service.calls, 2);
      expect(tester.takeException(), isNull);
      await tester.runAsync(app.shutdown);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'code block copies code without gutter and editor retains editing shortcuts',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      const code = 'int main() {\n  return 42;\n}';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: CodeBlock(code: code, language: 'cpp'),
          ),
        ),
      );
      expect(find.text('1\n2\n3'), findsOneWidget);
      await tester.tap(find.text('Copy code'));
      await tester.pump();
      expect(copied, code);
      final editor = CodeEditingController(language: 'cpp')..text = code;
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SourceEditor(controller: editor, onSave: () => saves++),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '$code\n// edited');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(editor.text, endsWith('// edited'));
      expect(find.textContaining('4 lines'), findsOneWidget);
      expect(saves, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      editor.dispose();
    },
  );
}
