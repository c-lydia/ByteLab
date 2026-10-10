import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import '../app/app_controller.dart';
import '../core/byte_color.dart';
import 'app_controls.dart';

class NeovimEditor extends StatelessWidget {
  const NeovimEditor({super.key});

  static const terminalTheme = TerminalTheme(
    cursor: ByteColor.text,
    selection: ByteColor.surfaceHover,
    foreground: ByteColor.text,
    background: ByteColor.terminal,
    black: ByteColor.terminal,
    white: ByteColor.secondsaryText,
    red: ByteColor.error,
    green: ByteColor.success,
    yellow: ByteColor.warning,
    blue: ByteColor.blue,
    magenta: ByteColor.purple,
    cyan: ByteColor.cyan,
    brightBlack: ByteColor.border,
    brightWhite: ByteColor.text,
    brightRed: ByteColor.error,
    brightGreen: ByteColor.success,
    brightYellow: ByteColor.warning,
    brightBlue: ByteColor.blue,
    brightMagenta: ByteColor.purple,
    brightCyan: ByteColor.cyan,
    searchHitBackground: ByteColor.surfaceHover,
    searchHitBackgroundCurrent: ByteColor.blue,
    searchHitForeground: ByteColor.text,
  );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final editor = app.neovim;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Chip(label: Text('NEOVIM')),
            Text(
              editor.starting
                  ? 'Starting…'
                  : editor.modified
                  ? 'Unsaved buffers'
                  : editor.running && !editor.stateKnown
                  ? 'Checking buffers…'
                  : app.settings.neovimClean
                  ? 'Clean configuration'
                  : 'Your configuration + plugins',
              style: TextStyle(
                color: editor.needsAttention
                    ? ByteColor.warning
                    : ByteColor.secondsaryText,
              ),
            ),
            if (editor.running) ...[
              TextButton.icon(
                onPressed: app.busy || editor.starting
                    ? null
                    : () => uiAction(
                        context,
                        editor.saveAll,
                        success: 'Neovim buffers saved',
                      ),
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Save all'),
              ),
              TextButton.icon(
                onPressed: editor.starting
                    ? null
                    : () => uiAction(context, editor.showPlugins),
                icon: const Icon(Icons.extension_outlined, size: 16),
                label: const Text('Plugins'),
              ),
              TextButton(
                onPressed: app.busy || editor.starting
                    ? null
                    : () => uiAction(context, () async {
                        try {
                          await editor.refreshModified();
                        } catch (_) {
                          /* Confirm unknown buffers too. */
                        }
                        if (!context.mounted) return;
                        if (editor.needsAttention &&
                            !await discardPrompt(context)) {
                          return;
                        }
                        await editor.close();
                      }),
                child: const Text('Stop Neovim'),
              ),
            ],
            TextButton(
              onPressed: () => app.navigate(9),
              child: const Text('Editor settings'),
            ),
            TextButton.icon(
              onPressed: () => app.navigate(8),
              icon: const Icon(Icons.help_outline, size: 16),
              label: const Text('Guide'),
            ),
          ],
        ),
        if (editor.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SelectableText(
              editor.error!,
              style: const TextStyle(color: ByteColor.warning),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: editor.running
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TerminalView(
                    editor.terminal,
                    key: ObjectKey(editor.terminal),
                    theme: terminalTheme,
                    textStyle: const TerminalStyle(
                      fontFamily: 'Ubuntu Sans Mono',
                      fontFamilyFallback: ['Noto Sans Mono', 'monospace'],
                    ),
                    readOnly: app.busy,
                    autofocus: true,
                    // Keep Ctrl+C, Ctrl+V, Ctrl+R, etc. available to Neovim.
                    shortcuts: const {},
                  ),
                )
              : EmptyMessage(
                  'Your Neovim workspace',
                  'Select a file, or start Neovim here. Your usual config and plugins load automatically.',
                  action: FilledButton.icon(
                    onPressed:
                        app.busy || editor.starting || app.project.root == null
                        ? null
                        : () => uiAction(
                            context,
                            () => editor.start(
                              app.project.root!,
                              clean: app.settings.neovimClean,
                            ),
                          ),
                    icon: const Icon(Icons.terminal),
                    label: const Text('Start Neovim'),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Esc → Normal · i → Insert · :wa → Save all · :qa → Quit · Configure plugins in your Neovim config',
          style: TextStyle(fontSize: 11, color: ByteColor.secondsaryText),
        ),
      ],
    );
  }
}
