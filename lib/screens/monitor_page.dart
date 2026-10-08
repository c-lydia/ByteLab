import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/app_controller.dart';
import '../models/serial_log_entry.dart';
import '../widgets/app_controls.dart';
import '../widgets/log_console.dart';

Future<void> exportConsole(
  BuildContext context, {
  bool firmware = false,
}) async {
  final app = AppScope.of(context);
  final folder = await choosePath(context, title: 'Export log to folder');
  if (folder == null) return;
  final filename =
      '${firmware ? 'firmware' : 'serial'}-${DateTime.now().toIso8601String().replaceAll(':', '-')}.log';
  await app.exportLog('$folder/$filename', firmware: firmware);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved $filename')));
  }
}

class MonitorPage extends StatelessWidget {
  const MonitorPage({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTitle(
          'Serial monitor',
          'Live UART output with search, filtering, and command input.',
        ),
        ConnectionControls(),
        SizedBox(height: 14),
        Expanded(child: MonitorConsole()),
      ],
    ),
  );
}

class MonitorConsole extends StatefulWidget {
  const MonitorConsole({super.key, this.compact = false});
  final bool compact;
  @override
  State<MonitorConsole> createState() => _MonitorConsoleState();
}

class _MonitorConsoleState extends State<MonitorConsole> {
  final command = TextEditingController();
  final search = TextEditingController();
  String level = 'all';
  bool follow = true;
  bool sending = false;
  @override
  void dispose() {
    command.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = command.text;
    if (value.isEmpty || sending) return;
    final app = AppScope.of(context);
    setState(() => sending = true);
    try {
      await app.send(value);
      if (mounted && command.text == value) command.clear();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final query = search.text.toLowerCase();
    final lines = <ConsoleLine>[];
    for (var i = 0; i < app.serial.history.length; i++) {
      final entry = app.serial.history[i];
      final raw = app.serial.rawHistory[i];
      if ((level == 'all' || entry.level.name == level) &&
          raw.toLowerCase().contains(query)) {
        lines.add(ConsoleLine(raw, entry.level.color));
      }
    }
    return Column(
      children: [
        if (!widget.compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 230,
                  child: TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      labelText: 'Search logs',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: level,
                    decoration: const InputDecoration(labelText: 'Log level'),
                    items: ['all', ...LogLevel.values.map((e) => e.name)]
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (value) => setState(() => level = value!),
                  ),
                ),
                FilterChip(
                  label: const Text('Follow'),
                  selected: follow,
                  onSelected: (value) => setState(() => follow = value),
                ),
                IconButton(
                  tooltip: 'Copy visible logs',
                  onPressed: () => uiAction(
                    context,
                    () => Clipboard.setData(
                      ClipboardData(text: lines.map((e) => e.text).join('\n')),
                    ),
                    success: 'Logs copied',
                  ),
                  icon: const Icon(Icons.copy, size: 19),
                ),
                IconButton(
                  tooltip: 'Export serial log',
                  onPressed: () =>
                      uiAction(context, () => exportConsole(context)),
                  icon: const Icon(Icons.file_download_outlined, size: 19),
                ),
                TextButton(
                  onPressed: app.clearLogs,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        Expanded(
          child: LogConsole(
            lines: lines,
            follow: follow,
            empty: app.serial.isConnected
                ? 'Connected. Waiting for serial output…'
                : 'Connect a board to receive serial output.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: command,
                  enabled: app.serial.isConnected && !sending,
                  decoration: InputDecoration(
                    labelText: 'Command · ${app.settings.lineEnding}',
                    hintText: 'STATUS?',
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  onSubmitted: (_) => uiAction(context, _send),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: app.serial.isConnected && !sending
                    ? () => uiAction(context, _send)
                    : null,
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
