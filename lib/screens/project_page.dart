import 'dart:io';
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/project_store.dart';
import '../core/byte_color.dart';
import '../widgets/app_controls.dart';
import '../widgets/source_editor.dart';

class ProjectPage extends StatefulWidget {
  const ProjectPage({super.key});
  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  final editor = TextEditingController();
  AppController? app;
  String? root, directory, file;
  String original = '';
  String? error;
  List<ProjectEntry> entries = [];
  bool loading = false;
  bool saving = false;
  int fileRequest = 0;
  int generation = 0;
  bool get dirty => file != null && editor.text != original;
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
      fileRequest++;
      root = app!.project.root;
      file = null;
      original = '';
      editor.clear();
      if (root != null) _list(root!);
    }
  }

  @override
  void dispose() {
    app?.unsavedEditors.remove(this);
    editor.dispose();
    super.dispose();
  }

  Future<void> _list(String path) async {
    final request = ++generation;
    setState(() => loading = true);
    try {
      final items = await app!.project.list(path);
      if (!mounted || request != generation) return;
      setState(() {
        entries = items;
        directory = path;
        error = null;
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> _openFile(String path) async {
    if (saving) throw StateError('Wait for the current file to finish saving');
    if (dirty && !await discardPrompt(context)) return;
    final request = ++fileRequest;
    final contents = await app!.project.read(path);
    if (!mounted || request != fileRequest) return;
    setState(() {
      file = path;
      original = contents;
      editor.text = contents;
    });
  }

  Future<void> _save() async {
    if (file == null) return;
    if (saving) return;
    if (app!.busy) throw StateError('Wait for the firmware command to finish');
    final contents = editor.text;
    final filename = file!;
    setState(() => saving = true);
    try {
      await app!.project.save(filename, contents, expectedContents: original);
      if (mounted && file == filename) {
        setState(() {
          original = contents;
          _edited();
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _openProject() async {
    final path = await choosePath(
      context,
      title: 'Open ESP-IDF project',
      initial: root,
    );
    if (path != null) await app!.openProject(path);
  }

  Future<void> _createProject() async {
    final parent = await choosePath(context, title: 'Choose a parent folder');
    if (parent == null || !mounted) return;
    final name = await textPrompt(
      context,
      'New ESP-IDF project',
      hint: 'my_board',
    );
    if (name != null && name.trim().isNotEmpty) {
      await app!.createProject(parent, name.trim());
    }
  }

  Future<void> _newEntry(bool folder) async {
    final name = await textPrompt(
      context,
      folder ? 'New folder' : 'New file',
      hint: folder ? 'components' : 'main.c',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final path = await app!.project.createEntry(
      directory!,
      name.trim(),
      folder: folder,
    );
    await _list(directory!);
    if (!folder && mounted) await _openFile(path);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTitle(
            'Project',
            'Browse and edit source files, or start a new ESP-IDF project.',
            actions: [
              OutlinedButton.icon(
                onPressed: controller.busy
                    ? null
                    : () => uiAction(context, _openProject),
                icon: const Icon(Icons.folder_open),
                label: const Text('Open project'),
              ),
              FilledButton.icon(
                onPressed: controller.busy
                    ? null
                    : () => uiAction(context, _createProject),
                icon: const Icon(Icons.add),
                label: const Text('Create starter'),
              ),
            ],
          ),
          if (root == null)
            const Expanded(
              child: EmptyMessage(
                'Choose your firmware project',
                'Open a folder containing CMakeLists.txt, or create a starter with serial commands and telemetry.',
              ),
            )
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 220,
                    child: AppPanel(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Parent folder',
                                onPressed:
                                    directory == root || directory == null
                                    ? null
                                    : () => _list(
                                        Directory(directory!).parent.path,
                                      ),
                                icon: const Icon(Icons.arrow_upward, size: 18),
                              ),
                              IconButton(
                                tooltip: 'Refresh files',
                                onPressed: () => _list(directory ?? root!),
                                icon: const Icon(Icons.refresh, size: 18),
                              ),
                              IconButton(
                                tooltip: 'New file',
                                onPressed: controller.busy
                                    ? null
                                    : () => uiAction(
                                        context,
                                        () => _newEntry(false),
                                      ),
                                icon: const Icon(
                                  Icons.note_add_outlined,
                                  size: 18,
                                ),
                              ),
                              IconButton(
                                tooltip: 'New folder',
                                onPressed: controller.busy
                                    ? null
                                    : () => uiAction(
                                        context,
                                        () => _newEntry(true),
                                      ),
                                icon: const Icon(
                                  Icons.create_new_folder_outlined,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              directory == root
                                  ? controller.project.name
                                  : directory?.substring(root!.length + 1) ??
                                        '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: ByteColor.secondsaryText,
                              ),
                            ),
                          ),
                          if (loading) const LinearProgressIndicator(),
                          if (error != null)
                            Text(
                              error!,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                              ),
                            ),
                          Expanded(
                            child: ListView(
                              children: [
                                for (final item in entries)
                                  ListTile(
                                    dense: true,
                                    selected: item.path == file,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    leading: Icon(
                                      item.isDirectory
                                          ? Icons.folder_outlined
                                          : Icons.description_outlined,
                                      size: 18,
                                    ),
                                    title: Text(
                                      item.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => item.isDirectory
                                        ? _list(item.path)
                                        : uiAction(
                                            context,
                                            () => _openFile(item.path),
                                          ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: file == null
                        ? const EmptyMessage(
                            'Select a file',
                            'Text files up to 2 MiB can be edited here.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${file!.substring(root!.length + 1)}${dirty ? ' • unsaved' : ''}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => uiAction(
                                      context,
                                      () => _openFile(file!),
                                    ),
                                    child: const Text('Reload'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: !dirty || controller.busy
                                        ? null
                                        : () => uiAction(
                                            context,
                                            _save,
                                            success: 'File saved',
                                          ),
                                    icon: const Icon(Icons.save, size: 16),
                                    label: const Text('Save'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: SourceEditor(
                                  controller: editor,
                                  readOnly: controller.busy,
                                  onSave: dirty && !controller.busy
                                      ? () => uiAction(
                                          context,
                                          _save,
                                          success: 'File saved',
                                        )
                                      : null,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Ctrl+S to save · Previous versions are kept in .bytelab-backups',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ByteColor.secondsaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
