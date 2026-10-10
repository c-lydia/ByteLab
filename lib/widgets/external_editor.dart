import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/settings_store.dart';
import '../service/external_editor_service.dart';
import 'app_controls.dart';

class ExternalEditor extends StatelessWidget {
  const ExternalEditor({super.key, required this.root, this.file});
  final String root;
  final String? file;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final editor = app.settings.editor;
    final sketch =
        file != null &&
        RegExp(r'\.(ino|pde)$', caseSensitive: false).hasMatch(file!);
    void open(String? target) => uiAction(
      context,
      () => ExternalEditorService().open(app.settings, target: target),
      success: '${editor.label} launch requested',
    );
    return AppPanel(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              editor.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(editor.description),
            const SizedBox(height: 16),
            Text(
              file == null
                  ? 'Select a file in the project browser.'
                  : file!.substring(root.length + 1),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed:
                      app.busy ||
                          file == null ||
                          (editor == EditorChoice.arduino && !sketch)
                      ? null
                      : () => open(file),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(
                    editor == EditorChoice.arduino
                        ? 'Open sketch'
                        : 'Open file',
                  ),
                ),
                OutlinedButton(
                  onPressed: app.busy
                      ? null
                      : () => open(editor == EditorChoice.vscode ? root : null),
                  child: Text(
                    editor == EditorChoice.vscode
                        ? 'Open project in VS Code'
                        : 'Launch Arduino IDE',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (editor == EditorChoice.arduino) ...[
              const Text(
                'Arduino IDE opens .ino/.pde sketches. For a sketch outside this ESP-IDF project, launch the IDE and use File → Open. ByteLab’s Build and Flash commands still use ESP-IDF; use Arduino IDE’s own board selection, Verify, and Upload for Arduino sketches.',
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Save changes in the external editor before returning to Build or Flash. ByteLab reads files from disk and cannot detect unsaved edits in external windows. Use Reload in any built-in editor to see external changes.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: () => app.navigate(9),
                  child: const Text('Editor settings'),
                ),
                TextButton(
                  onPressed: () => app.navigate(8),
                  child: const Text('User manual'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
