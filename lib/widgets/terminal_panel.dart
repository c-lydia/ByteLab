import 'package:flutter/material.dart';

import '../service/serial_service.dart';
import '../models/serial_log_entry.dart';
import '../core/byte_color.dart';

class TerminalPanel extends StatefulWidget {
  final SerialService serialService;

  const TerminalPanel({super.key, required this.serialService});

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel> {
  final ScrollController _scrollContoller = ScrollController();
  final List<SerialLogEntry> _entries = [];
  bool _verbose = false;
  bool _autoScroll = true;

  @override 
  void initState() {
    super.initState();
    _entries.addAll(widget.serialService.history);
    widget.serialService.logStream.listen(_onEntry);
    _scrollContoller.addListener(_onScroll);
  }

  @override  
  void dispose() {
    _scrollContoller.dispose();
    super.dispose();
  }

  void _onEntry(SerialLogEntry entry) {
    if (!mounted) return;

    setState(() => _entries.add(entry));

    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollContoller.hasClients) return;
        _scrollContoller.jumpTo(_scrollContoller.position.maxScrollExtent);
      });
    }
  }

  void _onScroll() {
    if (!_scrollContoller.hasClients) return;

    final atBottom = _scrollContoller.position.pixels >= _scrollContoller.position.maxScrollExtent - 24;

    if (atBottom != _autoScroll) {
      setState(() => _autoScroll = atBottom);
    }
  }

  List<SerialLogEntry> get _visibleEntries => _verbose? _entries: _entries.where((e) => !e.level.isVerboseOnly).toList();

  @override
  Widget build(BuildContext context) {
    final visible = _visibleEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          verbose: _verbose,
          onVerboseChanged: (v) => setState(() => _verbose = v),
          onClear: () => setState(_entries.clear),
          autoScrollPaused: !_autoScroll,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ByteColor.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ByteColor.border)
            ),
            child: visible.isEmpty? const Center(
              child: Text(
                'Waiting for serial output...',
                style: TextStyle(color: ByteColor.mutedText)
              )
            ): ListView.builder(
              controller: _scrollContoller,
              itemCount: visible.length,
              itemBuilder: (context, i) => _LogLine(entry: visible[i])
            )
          )
        )
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  final bool verbose;
  final ValueChanged<bool> onVerboseChanged;
  final VoidCallback onClear;
  final bool autoScrollPaused;

  const _Toolbar({
    required this.verbose,
    required this.onVerboseChanged,
    required this.onClear,
    required this.autoScrollPaused
  });

  @override 
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'SERIAL MONITOR',
          style: TextStyle(
            color: ByteColor.secondsaryText,
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold
          )
        ),
        const Spacer(),
        if (autoScrollPaused)
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Text(
              'Scroll paused', 
              style: TextStyle(color: ByteColor.mutedText, fontSize: 11)
            )
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Verbose',
              style: TextStyle(color: ByteColor.mutedText, fontSize: 11)
            ),
            Switch (value:  verbose, onChanged: onVerboseChanged, activeColor: ByteColor.cyan)
          ],
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: ByteColor.mutedText,
          tooltip: 'Clear',
          onPressed: onClear
        )
      ]
    );
  }
}

class _LogLine extends StatelessWidget {
  final SerialLogEntry entry;

  const _LogLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    final ts = entry.deviceTimestampMs;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.4
          ),
          children: [
            if (ts != null)
              TextSpan(
                text: '(${ts.toString().padLeft(6)})',
                style: const TextStyle(color: ByteColor.mutedText)
              ),
            if (entry.tag != null)
              TextSpan(
                text: '${entry.tag}',
                style: TextStyle(color: entry.level.color, fontWeight: FontWeight.bold)
              ),
            TextSpan(
              text: entry.message,
              style: TextStyle(color: entry.level == LogLevel.unknown? ByteColor.text: entry.level.color)
            )
          ]
        )
      )
    );
  }
}