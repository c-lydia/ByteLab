import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/settings_store.dart';
import '../service/external_editor_service.dart';
import '../core/byte_color.dart';
import '../widgets/app_controls.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final sdk = TextEditingController();
  final vscodePath = TextEditingController();
  final arduinoPath = TextEditingController();
  final baud = TextEditingController();
  final flashBaud = TextEditingController();
  String ending = 'LF';
  double opacity = 0.94;
  EditorChoice editor = EditorChoice.builtin;
  bool neovimClean = false;
  bool initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      final settings = AppScope.of(context).settings;
      sdk.text = settings.exportScript;
      baud.text = '${settings.baudRate}';
      flashBaud.text = '${settings.flashBaudRate}';
      ending = settings.lineEnding;
      opacity = settings.windowOpacity;
      editor = settings.editor;
      vscodePath.text = settings.vscodePath;
      arduinoPath.text = settings.arduinoPath;
      neovimClean = settings.neovimClean;
      initialized = true;
    }
  }

  @override
  void dispose() {
    sdk.dispose();
    vscodePath.dispose();
    arduinoPath.dispose();
    baud.dispose();
    flashBaud.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = AppScope.of(context);
    final rate = int.tryParse(baud.text), upload = int.tryParse(flashBaud.text);
    if (rate == null || upload == null) {
      throw const FormatException('Baud rates must be whole numbers');
    }
    await app.saveSettings(
      app.settings.copyWith(
        exportScript: sdk.text.trim(),
        baudRate: rate,
        flashBaudRate: upload,
        lineEnding: ending,
        windowOpacity: opacity,
        editor: editor,
        vscodePath: vscodePath.text.trim(),
        arduinoPath: arduinoPath.text.trim(),
        neovimClean: neovimClean,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(26),
      children: [
        const PageTitle(
          'Settings',
          'Toolchain and serial preferences are saved on this computer.',
        ),
        AppPanel(
          title: 'Editor and plugins',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<EditorChoice>(
                initialValue: editor,
                decoration: const InputDecoration(
                  labelText: 'Preferred editor',
                ),
                items: [
                  for (final choice in EditorChoice.values)
                    DropdownMenuItem(value: choice, child: Text(choice.label)),
                ],
                onChanged: app.busy
                    ? null
                    : (value) => setState(() => editor = value!),
              ),
              const SizedBox(height: 12),
              Text(editor.description),
              if (editor.external) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: editor == EditorChoice.vscode
                      ? vscodePath
                      : arduinoPath,
                  decoration: const InputDecoration(
                    labelText: 'Executable path (optional)',
                    hintText: 'Leave empty to detect from PATH',
                    helperText:
                        'Choose the executable or AppImage, without quotes or arguments.',
                    helperMaxLines: 2,
                  ),
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Browse executable'),
                      onPressed: () async {
                        final field = editor == EditorChoice.vscode
                            ? vscodePath
                            : arduinoPath;
                        final path = await choosePath(
                          context,
                          title: 'Choose editor executable',
                          initial: field.text,
                          file: true,
                        );
                        if (path != null && mounted) {
                          setState(() => field.text = path);
                        }
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Check executable'),
                      onPressed: () => uiAction(context, () async {
                        final path = await ExternalEditorService().resolve(
                          editor,
                          editor == EditorChoice.vscode
                              ? vscodePath.text
                              : arduinoPath.text,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Found: $path')),
                          );
                        }
                      }),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Save and launch editor'),
                  onPressed: app.busy
                      ? null
                      : () => uiAction(context, () async {
                          await _save();
                          await ExternalEditorService().open(app.settings);
                        }),
                ),
                const Text(
                  'Save files in the external editor before building. ByteLab cannot check its unsaved buffers. Arduino IDE uses its own boards and libraries; this selection does not change ByteLab’s ESP-IDF toolchain.',
                ),
              ],
              if (editor == EditorChoice.neovim)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Clean Neovim configuration'),
                  subtitle: const Text(
                    'Start without your configuration or plugins for troubleshooting. Save buffers before changing this setting.',
                  ),
                  value: neovimClean,
                  onChanged: !app.busy
                      ? (value) => setState(() => neovimClean = value)
                      : null,
                ),
              TextButton.icon(
                onPressed: () => app.navigate(8),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Open user manual'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppPanel(
          title: 'Underlight transparency',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Window opacity · ${(opacity * 100).round()}%'),
              Slider(
                value: opacity,
                min: 0.7,
                max: 1,
                divisions: 30,
                label: '${(opacity * 100).round()}%',
                onChanged: app.windowOpacitySupported
                    ? (value) => setState(() => opacity = value)
                    : null,
              ),
              const Text(
                'Save settings to apply. 100% is opaque. This affects the whole window, including text; desktop blur is controlled by your compositor.',
              ),
              if (!app.windowOpacitySupported)
                const Text(
                  'Native opacity is available in the Linux desktop build.',
                  style: TextStyle(color: ByteColor.secondsaryText),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppPanel(
          title: 'ESP-IDF toolchain',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: sdk,
                      decoration: const InputDecoration(
                        labelText: 'Path to ESP-IDF export.sh',
                        hintText: '/home/you/esp/esp-idf/export.sh',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () async {
                      final path = await choosePath(
                        context,
                        title: 'Choose ESP-IDF export.sh',
                        initial: sdk.text,
                        file: true,
                      );
                      if (path != null && mounted) {
                        setState(() => sdk.text = path);
                      }
                    },
                    child: const Text('Browse'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'ByteLab sources this script before running idf.py. Leave it empty if ESP-IDF is already on the launch environment’s PATH.',
                style: TextStyle(color: ByteColor.secondsaryText),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: app.busy
                    ? null
                    : () => uiAction(context, () async {
                        await _save();
                        app.navigate(2);
                        await app.checkToolchain();
                      }),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Save and check toolchain'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppPanel(
          title: 'Serial communication',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: baud,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monitor baud rate',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: flashBaud,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Flash baud rate',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: ending,
                      decoration: const InputDecoration(
                        labelText: 'Command line ending',
                      ),
                      items: ['LF', 'CRLF', 'None']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => ending = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Monitor baud changes take effect on the next connection. Hex sends always use the exact bytes you enter.',
                style: TextStyle(color: ByteColor.secondsaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: app.busy || app.serial.isConnecting
                ? null
                : () => uiAction(context, _save, success: 'Settings saved'),
            icon: const Icon(Icons.save),
            label: const Text('Save settings'),
          ),
        ),
        const SizedBox(height: 18),
        SelectableText(
          'Settings file: ${app.store.file.path}',
          style: const TextStyle(fontSize: 12, color: ByteColor.secondsaryText),
        ),
      ],
    );
  }
}
