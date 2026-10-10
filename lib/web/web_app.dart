import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/byte_color.dart';
import '../service/documentation_catalog.dart';
import '../service/serial_service.dart';
import '../theme/app_theme.dart';
import '../widgets/code_block.dart';
import '../widgets/bytelab_logo.dart';
import '../widgets/log_console.dart';
import '../widgets/source_editor.dart';
import 'browser_io.dart' as browser;
import 'browser_workspace.dart';
import 'serial_transport_web.dart';

class ByteLabApp extends StatelessWidget {
  const ByteLabApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ByteLab Web',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    home: const BrowserShell(),
  );
}

class BrowserShell extends StatefulWidget {
  const BrowserShell({super.key});
  @override
  State<BrowserShell> createState() => _BrowserShellState();
}

class _BrowserShellState extends State<BrowserShell> {
  final editor = CodeEditingController();
  final command = TextEditingController();
  final serial = SerialService();
  final subscriptions = <StreamSubscription<dynamic>>[];
  late final browser.BrowserExitGuard exitGuard;
  BrowserWorkspace? workspace;
  ToolchainDocs detected = const ToolchainDocs();
  String? file, storageError, notice, port;
  String original = '', docsSearch = '', fileSearch = '', logSearch = '';
  String? docsTarget, docsVersion;
  String ending = 'LF';
  int page = 0, baud = 115200, detectionGeneration = 0;
  bool working = false, persisted = true, follow = true;
  Timer? persistTimer, serialTimer;
  bool get dirty => file != null && editor.text != original;
  static const labels = [
    'Overview',
    'Project',
    'Monitor',
    'Documentation',
    'Build & flash',
    'Settings',
  ];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.folder_open,
    Icons.terminal,
    Icons.menu_book_outlined,
    Icons.build_circle_outlined,
    Icons.settings_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _restore();
    editor.addListener(_edited);
    exitGuard = browser.BrowserExitGuard(() => dirty || !persisted);
    subscriptions.addAll([
      serial.logStream.listen((_) => _serialChanged()),
      serial.telemetryStream.listen((_) => _serialChanged()),
      serial.connectionStream.listen((_) {
        if (mounted) setState(() {});
      }),
    ]);
    unawaited(_detect());
  }

  void _restore() {
    try {
      final saved = browser.readSnapshot();
      if (saved == null) return;
      final data = jsonDecode(saved) as Map<String, dynamic>;
      if (data['version'] != 1) {
        throw const FormatException('Unsupported browser workspace version');
      }
      if (data['workspace'] != null) {
        workspace = BrowserWorkspace.fromJson(
          data['workspace'] as Map<String, dynamic>,
        );
      }
      final restoredBaud = data['baud'];
      if (restoredBaud is int && restoredBaud > 0 && restoredBaud <= 4000000) {
        baud = restoredBaud;
      }
      if (['LF', 'CRLF', 'None'].contains(data['ending'])) {
        ending = data['ending'] as String;
      }
      final path = data['file'];
      if (path is String && workspace?.files.containsKey(path) == true) {
        file = path;
        original = workspace!.read(path);
        editor.language = codeLanguage(path);
        editor.text = data['draft'] is String
            ? data['draft'] as String
            : original;
      }
      notice =
          'Restored your browser workspace. Download a ZIP to keep a portable backup.';
    } catch (_) {
      storageError =
          'The saved browser workspace could not be loaded. Existing storage is kept until you make a change. Import your source folder or create a starter to continue.';
    }
  }

  void _edited() {
    persisted = false;
    persistTimer?.cancel();
    persistTimer = Timer(const Duration(milliseconds: 500), _persist);
    if (mounted) setState(() {});
  }

  void _persist() {
    persistTimer?.cancel();
    try {
      browser.writeSnapshot(
        jsonEncode({
          'version': 1,
          'workspace': workspace?.toJson(),
          'file': file,
          'draft': dirty ? editor.text : null,
          'baud': baud,
          'ending': ending,
        }),
      );
      persisted = true;
      storageError = null;
    } catch (_) {
      persisted = false;
      storageError =
          'Browser storage is full or unavailable. This workspace is only in memory. Download the project ZIP before closing this tab.';
    }
    if (mounted) setState(() {});
  }

  void _serialChanged() {
    serialTimer ??= Timer(const Duration(milliseconds: 80), () {
      serialTimer = null;
      if (mounted) setState(() {});
    });
  }

  Future<void> _detect() async {
    final request = ++detectionGeneration;
    final result = await workspace?.detectDocs() ?? const ToolchainDocs();
    if (mounted && request == detectionGeneration) {
      setState(() => detected = result);
    }
  }

  Future<void> _action(FutureOr<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: ByteColor.errorSurface,
          ),
        );
      }
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;

  Future<String?> _name(String title, String initial) async {
    final field = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: field,
          autofocus: true,
          onSubmitted: (text) => Navigator.pop(dialog, text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, field.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    // The dialog's exit animation still owns its text field for a frame.
    Timer(const Duration(seconds: 1), field.dispose);
    return result;
  }

  Future<void> _replace(Future<BrowserWorkspace?> Function() load) async {
    if (workspace != null &&
        !await _confirm(
          'Replace browser workspace?',
          'Download the current project first if you need a backup. Continuing replaces its browser copy and any unsaved draft.',
        )) {
      return;
    }
    setState(() => working = true);
    try {
      final next = await load();
      if (next == null || !mounted) return;
      editor.removeListener(_edited);
      setState(() {
        workspace = next;
        file = null;
        original = '';
        editor.clear();
        fileSearch = '';
        docsTarget = null;
        docsVersion = null;
        page = 1;
        notice =
            'Editing a browser copy. Original files on your computer are unchanged.';
      });
      editor.addListener(_edited);
      _persist();
      await _detect();
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _create() => _replace(() async {
    final name = await _name('Create ESP-IDF starter', 'web_firmware');
    return name == null ? null : BrowserWorkspace.starter(name.trim());
  });

  Future<void> _open(String path) async {
    if (path == file) return;
    if (dirty &&
        !await _confirm(
          'Discard unsaved draft?',
          'Save this file first to keep the changes in your project.',
        )) {
      return;
    }
    final contents = workspace!.read(path);
    editor.removeListener(_edited);
    setState(() {
      file = path;
      original = contents;
      editor.language = codeLanguage(path);
      editor.text = contents;
    });
    editor.addListener(_edited);
    _persist();
  }

  void _save() {
    if (file == null) return;
    workspace!.save(file!, editor.text);
    setState(() => original = editor.text);
    _persist();
    unawaited(_detect());
  }

  void _downloadProject() {
    if (workspace == null) return;
    if (dirty) _save();
    browser.download(
      '${workspace!.name}.zip',
      workspace!.zip(),
      type: 'application/zip',
    );
    setState(
      () => notice =
          'Project ZIP download requested. Extract it before opening in ByteLab desktop or your ESP-IDF terminal.',
    );
  }

  Future<void> _newFile() async {
    final path = await _name('New relative file path', 'main/new.c');
    if (path == null || workspace == null) return;
    if (dirty &&
        !await _confirm(
          'Discard unsaved draft?',
          'Save this file first if you want to keep the changes.',
        )) {
      return;
    }
    workspace!.createFile(path.trim());
    // The preceding confirmation already resolved the current draft.
    original = editor.text;
    await _open(path.trim());
    _persist();
  }

  Future<void> _connect() async {
    // Invoke the permission picker directly from this click, before any I/O.
    final selected = await BrowserSerialTransport.requestPort();
    setState(() => port = selected);
    final connection = serial.connect(selected, baudRate: baud);
    setState(() {});
    try {
      await connection;
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _send() async {
    final text = command.text;
    if (text.isEmpty) return;
    await serial.write(
      '$text${ending == 'LF'
          ? '\n'
          : ending == 'CRLF'
          ? '\r\n'
          : ''}',
    );
    command.clear();
  }

  @override
  void dispose() {
    persistTimer?.cancel();
    serialTimer?.cancel();
    exitGuard.dispose();
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(serial.dispose());
    editor.dispose();
    command.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: MediaQuery.sizeOf(context).width < 700
        ? AppBar(
            title: const Row(
              children: [
                ByteLabLogo(size: 32),
                SizedBox(width: 10),
                Text('ByteLab Web'),
              ],
            ),
            leading: PopupMenuButton<int>(
              tooltip: 'Pages',
              icon: const Icon(Icons.menu),
              onSelected: (value) => setState(() => page = value),
              itemBuilder: (_) => [
                for (var i = 0; i < labels.length; i++)
                  PopupMenuItem(value: i, child: Text(labels[i])),
              ],
            ),
          )
        : null,
    body: LayoutBuilder(
      builder: (context, bounds) {
        final wide = bounds.maxWidth >= 1000;
        return Row(
          children: [
            if (bounds.maxWidth >= 700)
              NavigationRail(
                extended: wide,
                selectedIndex: page,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ByteLabLogo(),
                      if (wide) ...[
                        const SizedBox(width: 10),
                        const Text(
                          'BYTE LAB  /  WEB',
                          style: TextStyle(
                            color: ByteColor.cyan,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                onDestinationSelected: (value) => setState(() => page = value),
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    NavigationRailDestination(
                      icon: Icon(icons[i]),
                      label: Text(labels[i]),
                    ),
                ],
              ),
            if (bounds.maxWidth >= 700) const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          labels[page],
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          '${workspace?.name ?? 'No project'} · ${dirty
                              ? 'Unsaved draft'
                              : persisted
                              ? 'Browser workspace'
                              : 'In memory'}',
                          style: const TextStyle(
                            color: ByteColor.secondsaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (storageError != null)
                    _banner(storageError!, warning: true),
                  if (notice != null) _banner(notice!),
                  Expanded(
                    child: switch (page) {
                      0 => _overview(),
                      1 => _project(),
                      2 => _monitor(),
                      3 => _docs(),
                      4 => _buildHelp(),
                      _ => _settings(),
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _banner(String text, {bool warning = false}) => Container(
    margin: const EdgeInsets.fromLTRB(22, 0, 22, 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: (warning ? ByteColor.warning : ByteColor.cyan).withValues(
        alpha: .09,
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        if (!warning)
          IconButton(
            tooltip: 'Dismiss notice',
            onPressed: () => setState(() => notice = null),
            icon: const Icon(Icons.close, size: 16),
          ),
      ],
    ),
  );

  Widget _panel(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Material(
      color: ByteColor.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: ByteColor.glowViolet.withValues(alpha: .4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    ),
  );
  Widget _text(String value) =>
      Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(value));
  Widget _list(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(22), children: children);

  Widget _projectActions() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      FilledButton.icon(
        onPressed: working
            ? null
            : () => _action(() => _replace(browser.importFolder)),
        icon: const Icon(Icons.file_upload_outlined),
        label: const Text('Import folder'),
      ),
      OutlinedButton.icon(
        onPressed: working ? null : () => _action(_create),
        icon: const Icon(Icons.add),
        label: const Text('Create starter'),
      ),
      OutlinedButton.icon(
        onPressed: workspace == null || working
            ? null
            : () => _action(_downloadProject),
        icon: const Icon(Icons.download),
        label: const Text('Download project ZIP'),
      ),
    ],
  );

  Widget _overview() => _list([
    _panel('Your firmware workspace, in the browser', [
      _text(
        'Browse and edit ESP-IDF source, read matched toolchain documentation, and monitor serial devices in supporting browsers. Everything stays on this computer; no project upload or account is required.',
      ),
      _projectActions(),
      const SizedBox(height: 14),
      _text(
        'Import creates a browser copy. Save updates that copy; Download project ZIP exports your changes. Your original folder is never modified.',
      ),
    ]),
    _panel('Continue your workflow', [
      ListTile(
        leading: const Icon(Icons.code),
        title: const Text('Project editor'),
        subtitle: const Text(
          'Underlight syntax colors, line numbers, Ctrl+S, and browser draft recovery.',
        ),
        onTap: () => setState(() => page = 1),
      ),
      ListTile(
        leading: const Icon(Icons.terminal),
        title: const Text('Serial monitor'),
        subtitle: Text(
          BrowserSerialTransport.supported
              ? 'Web Serial is available. Choose a device to grant access.'
              : 'Web Serial needs a supported browser on HTTPS or localhost.',
        ),
        onTap: () => setState(() => page = 2),
      ),
      ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: const Text('User manual and toolchain docs'),
        subtitle: const Text(
          'Browser instructions plus references detected from imported metadata.',
        ),
        onTap: () => setState(() => page = 3),
      ),
    ]),
    _panel('Build locally', [
      _text(
        'The browser edition does not run ESP-IDF, flash firmware, launch native editors, or embed Neovim. Download your project and use ByteLab desktop or an activated ESP-IDF terminal for those steps.',
      ),
      TextButton(
        onPressed: () => setState(() => page = 4),
        child: const Text('Build and flash instructions'),
      ),
    ]),
  ]);

  Widget _project() {
    if (workspace == null) {
      return _list([
        _panel('Open your source', [
          _projectActions(),
          const SizedBox(height: 16),
          _text(
            'Choose a folder containing CMakeLists.txt, or create a starter. Browser projects support 1,000 files and 16 MiB; generated build output, dependencies, and version-control folders are omitted. The editor supports UTF-8 text up to 2 MiB per file.',
          ),
        ]),
      ]);
    }
    final paths =
        workspace!.files.keys
            .where(
              (path) => path.toLowerCase().contains(fileSearch.toLowerCase()),
            )
            .toList()
          ..sort();
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _projectActions(),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final browser = SizedBox(
                  width: constraints.maxWidth < 700 ? 165 : 240,
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: fileSearch,
                        decoration: const InputDecoration(
                          labelText: 'Find file',
                        ),
                        onChanged: (text) => setState(() => fileSearch = text),
                      ),
                      TextButton.icon(
                        onPressed: working ? null : () => _action(_newFile),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New file'),
                      ),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final path in paths)
                              ListTile(
                                dense: true,
                                selected: path == file,
                                title: Text(
                                  path,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _action(() => _open(path)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(file),
                              initialValue: file,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Project file',
                              ),
                              items: [
                                for (final path in workspace!.files.keys)
                                  DropdownMenuItem(
                                    value: path,
                                    child: Text(
                                      path,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (path) {
                                if (path != null) _action(() => _open(path));
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: 'New file',
                            onPressed: () => _action(_newFile),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(child: _editorPane()),
                    ],
                  );
                }
                return Row(
                  children: [
                    browser,
                    const VerticalDivider(width: 22),
                    Expanded(child: _editorPane()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _editorPane() => file == null
      ? const Center(child: Text('Select a source file to edit.'))
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$file${dirty ? ' • unsaved' : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.icon(
                  onPressed: dirty ? () => _action(_save) : null,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SourceEditor(
                controller: editor,
                onSave: () => _action(_save),
              ),
            ),
          ],
        );

  Widget _monitor() => Padding(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed:
                  !BrowserSerialTransport.supported ||
                      serial.isConnected ||
                      serial.isConnecting
                  ? null
                  : () => _action(_connect),
              icon: const Icon(Icons.usb),
              label: Text(
                serial.isConnecting ? 'Connecting…' : 'Choose serial device',
              ),
            ),
            OutlinedButton(
              onPressed: serial.isConnected
                  ? () => _action(serial.disconnect)
                  : null,
              child: const Text('Disconnect'),
            ),
            Text(
              serial.isConnected
                  ? '$port · ${serial.baudRate} baud'
                  : 'Disconnected · $baud baud',
            ),
            TextButton(
              onPressed: () => setState(() => page = 5),
              child: const Text('Serial settings'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!BrowserSerialTransport.supported)
          _text(
            'Web Serial is unavailable. Use a supporting browser such as Chrome or Edge over HTTPS or localhost, or use the desktop app.',
          ),
        if (serial.latestTelemetry.values.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 12,
              children: [
                for (final entry in serial.latestTelemetry.values.entries)
                  Chip(label: Text('${entry.key}: ${entry.value}')),
              ],
            ),
          ),
        TextFormField(
          initialValue: logSearch,
          decoration: const InputDecoration(
            labelText: 'Filter serial output',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (text) => setState(() => logSearch = text),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LogConsole(
            lines: [
              for (var i = 0; i < serial.history.length; i++)
                if (serial.rawHistory[i].toLowerCase().contains(
                  logSearch.toLowerCase(),
                ))
                  ConsoleLine(
                    serial.rawHistory[i],
                    serial.history[i].level.color,
                  ),
            ],
            follow: follow,
            empty:
                'Connect a serial device to receive logs. No simulated data.',
          ),
        ),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              label: const Text('Follow output'),
              selected: follow,
              onSelected: (value) => setState(() => follow = value),
            ),
            TextButton(
              onPressed: () {
                serial.clearHistory();
                setState(() {});
              },
              child: const Text('Clear logs'),
            ),
            TextButton(
              onPressed: serial.rawHistory.isEmpty
                  ? null
                  : () => browser.download(
                      'bytelab-serial.log',
                      Uint8List.fromList(
                        utf8.encode('${serial.rawHistory.join('\n')}\n'),
                      ),
                      type: 'text/plain',
                    ),
              child: const Text('Download logs'),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: command,
                enabled: serial.isConnected,
                decoration: const InputDecoration(
                  labelText: 'Serial command',
                  hintText: 'STATUS?',
                ),
                onSubmitted: (_) => _action(_send),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: serial.isConnected ? () => _action(_send) : null,
              child: const Text('Send'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _docs() {
    final resources = DocumentationCatalog.resources(
      detected,
      targetOverride: docsTarget,
      versionOverride: docsVersion,
    ).where((item) => item.matches(docsSearch));
    return _list([
      _panel('User manual · browser edition', [
        _text(
          'These instructions are bundled with the app. Full official references open in a new tab and need internet.',
        ),
        for (final topic in browserManual)
          ExpansionTile(
            title: Text(topic.$1),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SelectableText(topic.$2),
              ),
            ],
          ),
      ]),
      _panel('Detected toolchain', [
        _text(
          'Chip: ${detected.target ?? 'ESP32 (fallback)'} · ${detected.targetSource ?? 'No project target found'}\nSDK: ${detected.version ?? 'stable (fallback)'} · ${detected.versionSource ?? 'The browser cannot inspect an installed SDK'}',
        ),
        for (final note in detected.notes) _text(note),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: docsTarget ?? 'auto',
                decoration: const InputDecoration(labelText: 'Docs chip'),
                items: [
                  const DropdownMenuItem(
                    value: 'auto',
                    child: Text('Detected / default'),
                  ),
                  for (final chip in [
                    'esp32',
                    'esp32s2',
                    'esp32s3',
                    'esp32c2',
                    'esp32c3',
                    'esp32c5',
                    'esp32c6',
                    'esp32h2',
                    'esp32p4',
                  ])
                    DropdownMenuItem(value: chip, child: Text(chip)),
                ],
                onChanged: (value) =>
                    setState(() => docsTarget = value == 'auto' ? null : value),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: docsVersion ?? 'auto',
                decoration: const InputDecoration(labelText: 'Docs version'),
                items: const [
                  DropdownMenuItem(
                    value: 'auto',
                    child: Text('Detected / default'),
                  ),
                  DropdownMenuItem(
                    value: 'stable',
                    child: Text('Stable release'),
                  ),
                  DropdownMenuItem(
                    value: 'latest',
                    child: Text('Latest development'),
                  ),
                ],
                onChanged: (value) => setState(
                  () => docsVersion = value == 'auto' ? null : value,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _action(_detect),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh detection'),
            ),
          ],
        ),
      ]),
      TextFormField(
        initialValue: docsSearch,
        decoration: const InputDecoration(
          labelText: 'Search official docs',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (text) => setState(() => docsSearch = text),
      ),
      const SizedBox(height: 16),
      if (resources.isEmpty) _text('No matching references.'),
      for (final doc in resources)
        _panel(doc.title, [
          _text(doc.description),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _action(() => browser.openDocs(doc.url)),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Read official docs'),
            ),
          ),
        ]),
    ]);
  }

  Widget _buildHelp() => _list([
    _panel('Build and flash with your local toolchain', [
      _text(
        'This web edition cannot run idf.py or upload firmware. Download your project ZIP, extract it, and open the extracted folder in ByteLab desktop or an activated ESP-IDF terminal.',
      ),
      _projectActions(),
      const SizedBox(height: 16),
      const CodeBlock(
        title: 'Inside the extracted project · activated ESP-IDF terminal',
        language: 'shell',
        code:
            'idf.py build\n# Replace PORT with the board’s serial port\nidf.py -p PORT flash',
      ),
      const SizedBox(height: 16),
      _text(
        'Disconnect the browser serial monitor before flashing from another application. After uploading, reconnect here with the firmware’s baud rate. Flashing replaces the selected board’s firmware.',
      ),
      _text(
        'Real Neovim, VS Code/Arduino IDE launching, and native window transparency are available in the desktop workflow. A local helper or remote build server is not included in this web version.',
      ),
    ]),
  ]);

  Widget _settings() => _list([
    _panel('Browser settings', [
      _text(
        'The web editor uses the Underlight theme, syntax highlighting, and line numbers. Ctrl+S saves into the browser workspace while the editor has focus. Settings and recoverable drafts are stored in this browser for this site.',
      ),
      const ListTile(
        leading: Icon(Icons.code),
        title: Text('Built-in editor'),
        subtitle: Text('Available in the browser'),
      ),
      const ListTile(
        leading: Icon(Icons.desktop_windows),
        title: Text('Neovim, VS Code, and Arduino IDE'),
        subtitle: Text(
          'Select these in ByteLab desktop. Browsers cannot start your installed editors or load your Neovim plugins.',
        ),
      ),
      _text(
        'Native window transparency is desktop-only. The browser uses the same opaque Underlight palette.',
      ),
    ]),
    _panel('Serial connection', [
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          SizedBox(
            width: 220,
            child: TextFormField(
              initialValue: '$baud',
              decoration: const InputDecoration(labelText: 'Monitor baud rate'),
              keyboardType: TextInputType.number,
              onChanged: (text) {
                final value = int.tryParse(text);
                if (value != null && value > 0 && value <= 4000000) {
                  setState(() => baud = value);
                  _persist();
                }
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (text) {
                final value = int.tryParse(text ?? '');
                return value == null || value < 1 || value > 4000000
                    ? 'Enter 1–4,000,000'
                    : null;
              },
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: ending,
              decoration: const InputDecoration(
                labelText: 'Command line ending',
              ),
              items: [
                for (final value in ['LF', 'CRLF', 'None'])
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: (value) {
                setState(() => ending = value!);
                _persist();
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _text(
        'Valid values save automatically. Baud changes apply on the next connection. Device permission is granted through the browser’s picker, and must be chosen again after a page reload.',
      ),
    ]),
    _panel('Project copies and backups', [
      _text(
        'Browser storage is limited and may be cleared by private browsing, site-data removal, or browser policies. Download project ZIP regularly. Large projects can be edited in memory when storage is full; a banner will explain when recovery is unavailable.',
      ),
      _projectActions(),
    ]),
  ]);
}

const browserManual = <(String, String)>[
  (
    'First project and editing',
    'Choose Import folder and select an ESP-IDF source folder containing CMakeLists.txt, or Create starter. Import makes a browser copy and omits .git, dependencies, backups, and generated build files (except project_description.json for documentation detection). Up to 1,000 files / 16 MiB are supported. Choose a UTF-8 file to edit; binary files are retained for ZIP export. Use Save or Ctrl+S with editor focus. New file accepts a relative path such as main/sensor.c. Download project ZIP saves the current draft first, then exports source for your desktop toolchain. Original files on your computer are never overwritten.',
  ),
  (
    'Saving, recovery, and shortcuts',
    'Save updates the browser project copy. Ctrl+S saves when the source editor is focused; normal copy, paste, selection, undo, and redo controls work there. Drafts are also backed up to browser storage after a short pause, where space allows, and restored on reload. A dirty draft prompts before switching files; replacing a workspace asks for confirmation. A storage warning means your latest work is only in memory: download the ZIP before closing. Download regularly even when browser recovery works, since clearing site data removes it. To reimport, extract the ZIP and choose its project folder.',
  ),
  (
    'Serial monitor and telemetry',
    'Use a Web Serial browser such as Chrome or Edge, with HTTPS or localhost. Set baud and line ending in Settings, then Choose serial device in Monitor and grant access to the correct board. Connect uses real hardware; no readings are simulated. Send text commands, filter logs, follow output, or download logs. Firmware controls which commands exist. The starter accepts STATUS?, PING, and HELP and emits heap/flash measurements. Structured telemetry is shown above the console. Disconnect before flashing from another application. Browser/device permissions and occupied ports can prevent connection; close other monitors and choose the device again. Device permission is requested again after reload.',
  ),
  (
    'Documentation detection',
    'The app reads imported sdkconfig, sdkconfig.defaults, CMakeLists.txt, component manifests, and build/project_description.json when present. It cannot inspect your computer’s IDF_PATH or installed SDK. When metadata is missing, stable ESP32 references are shown with a fallback label. Chip/version controls change documentation links only. Save a changed configuration and refresh detection. Official links open in a new browser tab.',
  ),
  (
    'Build, flash, native editors, and plugins',
    'Download the project ZIP, extract it, and use ByteLab desktop or an activated ESP-IDF terminal to build and flash. The web edition does not run native tools or include a build server. Neovim with your own config/plugins, VS Code, Arduino IDE launching, and native window opacity remain desktop features. Arduino IDE expects Arduino sketches; selecting an editor never converts an ESP-IDF project into a sketch.',
  ),
];
