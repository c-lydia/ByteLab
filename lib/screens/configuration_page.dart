import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../core/byte_color.dart';
import '../widgets/app_controls.dart';
import '../widgets/source_editor.dart';
import '../widgets/code_block.dart';

class ConfigurationPage extends StatefulWidget {
  const ConfigurationPage({super.key});
  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  final editor = CodeEditingController(language: 'config');
  AppController? app;
  String? root, path, error;
  String original = '';
  bool defaults = true;
  bool loading = false;
  bool saving = false;
  int generation = 0;
  bool get dirty => path != null && editor.text != original;
  @override
  void initState() {
    super.initState();
    editor.addListener(_edited);
  }

  void _edited() {
    if (dirty) {
      app?.unsavedEditors.add(this);
    } else {
      app?.unsavedEditors.remove(this);
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    app = AppScope.of(context);
    if (root != app!.project.root) {
      root = app!.project.root;
      if (root != null) _load();
    }
  }

  @override
  void dispose() {
    app?.unsavedEditors.remove(this);
    editor.dispose();
    super.dispose();
  }

  Future<void> _load({bool create = false, bool? useDefaults}) async {
    if (saving) return;
    if (dirty && !await discardPrompt(context)) return;
    if (useDefaults != null) defaults = useDefaults;
    final request = ++generation;
    setState(() {
      loading = true;
      path = null;
      original = '';
      editor.clear();
      error = null;
    });
    try {
      final filename = await app!.project.configurationPath(
        defaults: defaults,
        create: create,
      );
      final text = await app!.project.read(filename);
      if (!mounted || request != generation) return;
      setState(() {
        path = filename;
        original = text;
        editor.text = text;
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    if (saving || path == null) return;
    if (app!.busy) throw StateError('Wait for the firmware command to finish');
    final text = editor.text;
    final filename = path!;
    setState(() => saving = true);
    try {
      await app!.project.save(filename, text, expectedContents: original);
      if (mounted && path == filename) {
        setState(() {
          original = text;
          _edited();
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageTitle(
            'Configuration',
            'Edit the SDK configuration used by your firmware project.',
          ),
          if (!controller.hasProject)
            Expanded(
              child: EmptyMessage(
                'Open a project first',
                'Configuration files belong to an ESP-IDF project.',
                action: FilledButton(
                  onPressed: () => controller.navigate(1),
                  child: const Text('Open project'),
                ),
              ),
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('sdkconfig.defaults'),
                    ),
                    ButtonSegment(value: false, label: Text('sdkconfig')),
                  ],
                  selected: {defaults},
                  onSelectionChanged: loading || controller.busy
                      ? null
                      : (values) => _load(useDefaults: values.first),
                ),
                OutlinedButton(
                  onPressed: loading || controller.busy ? null : _load,
                  child: const Text('Reload'),
                ),
                FilledButton.icon(
                  onPressed: dirty && !controller.busy
                      ? () => uiAction(
                          context,
                          _save,
                          success: 'Configuration saved',
                        )
                      : null,
                  icon: const Icon(Icons.save, size: 17),
                  label: Text(dirty ? 'Save changes •' : 'Saved'),
                ),
                if (controller.settings.useNeovim)
                  OutlinedButton.icon(
                    onPressed:
                        path == null || loading || dirty || controller.busy
                        ? null
                        : () => uiAction(context, () async {
                            await controller.neovim.openFile(
                              controller.project.root!,
                              path!,
                              clean: controller.settings.neovimClean,
                            );
                            controller.navigate(1);
                          }),
                    icon: const Icon(Icons.terminal, size: 16),
                    label: const Text('Edit in Neovim'),
                  ),
                OutlinedButton(
                  onPressed: controller.busy
                      ? null
                      : () {
                          controller.navigate(2);
                          uiAction(
                            context,
                            () => controller.runFirmware([
                              'reconfigure',
                            ], 'Reconfigure'),
                          );
                        },
                  child: const Text('Reconfigure'),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'sdkconfig contains active values. sdkconfig.defaults supplies values when generating a configuration; it does not override existing sdkconfig values. Save, then reconfigure or build to apply changes.',
                style: TextStyle(fontSize: 12, color: ByteColor.secondsaryText),
              ),
            ),
            if (loading) const LinearProgressIndicator(),
            if (error != null)
              Expanded(
                child: EmptyMessage(
                  'Configuration unavailable',
                  error!,
                  action: defaults
                      ? FilledButton(
                          onPressed: controller.busy
                              ? null
                              : () => _load(create: true),
                          child: const Text('Create defaults'),
                        )
                      : null,
                ),
              )
            else
              Expanded(
                child: SourceEditor(
                  controller: editor,
                  readOnly: loading || controller.busy || path == null,
                  onSave: dirty && !controller.busy
                      ? () => uiAction(
                          context,
                          _save,
                          success: 'Configuration saved',
                        )
                      : null,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
