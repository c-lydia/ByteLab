import 'dart:io';
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../core/byte_color.dart';

Future<void> uiAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (context.mounted && success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
  } catch (error) {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: ByteColor.errorSurface,
        ),
      );
    }
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle(
    this.title,
    this.subtitle, {
    super.key,
    this.actions = const [],
  });
  final String title;
  final String subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 18,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: ByteColor.secondsaryText),
            ),
          ],
        ),
        if (actions.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    ),
  );
}

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final String? title;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(1),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          ByteColor.glowCyan.withValues(alpha: 0.55),
          ByteColor.glowViolet.withValues(alpha: 0.35),
          ByteColor.pink.withValues(alpha: 0.45),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: ByteColor.shadow.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Material(
      color: ByteColor.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                ByteColor.glowCyan.withValues(alpha: 0.05),
                ByteColor.surface,
              ),
              ByteColor.surface,
              Color.alphaBlend(
                ByteColor.pink.withValues(alpha: 0.04),
                ByteColor.surface,
              ),
            ],
          ),
        ),
        child: Padding(
          padding: padding,
          child: title == null
              ? child
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    child,
                  ],
                ),
        ),
      ),
    ),
  );
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.folder_open,
    this.action,
  });
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: ByteColor.cyan),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ByteColor.secondsaryText),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class ConnectionControls extends StatelessWidget {
  const ConnectionControls({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final paths = {
      for (final port in app.scanner.devices) port.path: port.label,
    };
    if (app.settings.port.isNotEmpty) {
      paths.putIfAbsent(app.settings.port, () => 'Saved port');
    }
    final disabled = app.busy || app.serial.isConnecting;
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<String>(
            key: ValueKey('port-${app.settings.port}-${paths.keys.join()}'),
            initialValue: paths.containsKey(app.settings.port)
                ? app.settings.port
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Serial port'),
            items: paths.entries
                .map(
                  (p) => DropdownMenuItem(
                    value: p.key,
                    child: Text(
                      '${p.key} — ${p.value}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: disabled || app.serial.isConnected
                ? null
                : (port) {
                    if (port != null) {
                      uiAction(context, () => app.selectPort(port));
                    }
                  },
          ),
        ),
        Text(
          '${app.settings.baudRate} baud',
          style: const TextStyle(color: ByteColor.secondsaryText),
        ),
        FilledButton.icon(
          onPressed: disabled
              ? null
              : () => uiAction(
                  context,
                  app.serial.isConnected ? app.disconnect : () => app.connect(),
                ),
          icon: Icon(app.serial.isConnected ? Icons.link_off : Icons.usb),
          label: Text(
            app.serial.isConnecting
                ? 'Connecting…'
                : app.serial.isConnected
                ? 'Disconnect'
                : 'Connect',
          ),
        ),
        IconButton(
          tooltip: 'Refresh ports',
          onPressed: disabled ? null : app.scanner.refresh,
          icon: const Icon(Icons.refresh),
        ),
        TextButton(
          onPressed: disabled || app.serial.isConnected
              ? null
              : () async {
                  final path = await textPrompt(
                    context,
                    'Serial port path',
                    initial: app.settings.port,
                    hint: '/dev/ttyUSB0',
                  );
                  if (path != null && context.mounted) {
                    await uiAction(context, () => app.selectPort(path.trim()));
                  }
                },
          child: const Text('Enter port'),
        ),
      ],
    );
  }
}

Future<String?> textPrompt(
  BuildContext context,
  String title, {
  String initial = '',
  String? hint,
}) async {
  final field = TextEditingController(text: initial);
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: field,
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
            onSubmitted: (value) => Navigator.pop(dialog, value),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, field.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  } finally {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    field.dispose();
  }
}

Future<bool> discardPrompt(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Discard unsaved edits?'),
        content: const Text(
          'Save the current file first to keep your changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Discard edits'),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> choosePath(
  BuildContext context, {
  required String title,
  String? initial,
  bool file = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _PathDialog(title: title, initial: initial, file: file),
);

class _PathDialog extends StatefulWidget {
  const _PathDialog({required this.title, this.initial, required this.file});
  final String title;
  final String? initial;
  final bool file;
  @override
  State<_PathDialog> createState() => _PathDialogState();
}

class _PathDialogState extends State<_PathDialog> {
  late final TextEditingController path;
  List<FileSystemEntity> entries = [];
  String? error;
  String directory = '';
  int generation = 0;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial?.isNotEmpty == true
        ? widget.initial!
        : Platform.environment['HOME'] ?? Directory.current.path;
    path = TextEditingController(text: initial);
    _list(
      FileSystemEntity.isDirectorySync(initial)
          ? initial
          : File(initial).parent.path,
    );
  }

  Future<void> _list(String folder) async {
    final request = ++generation;
    try {
      final canonical = await Directory(folder).resolveSymbolicLinks();
      final children = await Directory(canonical)
          .list(followLinks: false)
          .where((e) => e is Directory || widget.file && e is File)
          .toList();
      children.sort(
        (a, b) => (a is Directory) != (b is Directory)
            ? (a is Directory ? -1 : 1)
            : a.path.toLowerCase().compareTo(b.path.toLowerCase()),
      );
      if (!mounted || request != generation) return;
      setState(() {
        directory = canonical;
        entries = children;
        error = null;
        path.text = canonical;
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(() => error = e.toString());
      }
    }
  }

  @override
  void dispose() {
    path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 650,
      height: 400,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Parent folder',
                onPressed: directory.isEmpty
                    ? null
                    : () => _list(Directory(directory).parent.path),
                icon: const Icon(Icons.arrow_upward),
              ),
              Expanded(
                child: TextField(
                  controller: path,
                  decoration: const InputDecoration(labelText: 'Path'),
                  onSubmitted: (value) => _list(value),
                ),
              ),
              IconButton(
                tooltip: 'Browse this folder',
                onPressed: () => _list(path.text),
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                error!,
                style: const TextStyle(color: ByteColor.warning),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    entry is Directory
                        ? Icons.folder_outlined
                        : Icons.description_outlined,
                  ),
                  title: Text(
                    entry.path.split(Platform.pathSeparator).last,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    if (entry is Directory) {
                      _list(entry.path);
                    } else {
                      Navigator.pop(context, entry.path);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, path.text),
        child: Text(widget.file ? 'Select file' : 'Select folder'),
      ),
    ],
  );
}
