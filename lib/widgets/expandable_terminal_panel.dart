import 'package:flutter/material.dart';

import '../core/byte_color.dart';
import '../models/serial_log_entry.dart';
import '../service/serial_service.dart';
import 'terminal_panel.dart';

/// Collapsed by default — shows a compact bar with an error/warning badge
/// if something's wrong, so problems are still visible without opening it.
/// Expands in place to the full [TerminalPanel] on tap.
///
/// Pass [expanded] (a [ValueNotifier]) if something outside this widget
/// needs to open it too — e.g. an "Monitor" action tile, or auto-opening
/// when a build/flash fails.
class ExpandableTerminalPanel extends StatefulWidget {
  final SerialService serialService;
  final ValueNotifier<bool>? expanded;
  final double expandedHeight;

  const ExpandableTerminalPanel({
    super.key,
    required this.serialService,
    this.expanded,
    this.expandedHeight = 320,
  });

  @override
  State<ExpandableTerminalPanel> createState() =>
      _ExpandableTerminalPanelState();
}

class _ExpandableTerminalPanelState extends State<ExpandableTerminalPanel> {
  late final ValueNotifier<bool> _expanded;
  bool _ownsController = false;

  int _errorCount = 0;
  int _warnCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.expanded != null) {
      _expanded = widget.expanded!;
    } else {
      _expanded = ValueNotifier(false);
      _ownsController = true;
    }
    widget.serialService.logStream.listen(_onEntry);
  }

  @override
  void dispose() {
    if (_ownsController) _expanded.dispose();
    super.dispose();
  }

  void _onEntry(SerialLogEntry entry) {
    if (!mounted) return;
    if (entry.level == LogLevel.error) setState(() => _errorCount++);
    if (entry.level == LogLevel.warn) setState(() => _warnCount++);
  }

  void _toggle() => _expanded.value = !_expanded.value;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _expanded,
      builder: (context, isExpanded, child) {
        return Container(
          decoration: BoxDecoration(
            color: ByteColor.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ByteColor.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                isExpanded: isExpanded,
                errorCount: _errorCount,
                warnCount: _warnCount,
                onTap: _toggle,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: isExpanded
                    ? SizedBox(
                        height: widget.expandedHeight,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: TerminalPanel(
                            serialService: widget.serialService,
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatefulWidget {
  final bool isExpanded;
  final int errorCount;
  final int warnCount;
  final VoidCallback onTap;

  const _Header({
    required this.isExpanded,
    required this.errorCount,
    required this.warnCount,
    required this.onTap,
  });

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final hasIssues = widget.errorCount > 0 || widget.warnCount > 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hovering ? ByteColor.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.terminal,
                size: 16,
                color: ByteColor.mutedText,
              ),
              const SizedBox(width: 8),
              const Text(
                'Raw Output',
                style: TextStyle(
                  color: ByteColor.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasIssues) ...[
                const SizedBox(width: 10),
                if (widget.errorCount > 0)
                  _Badge(
                    count: widget.errorCount,
                    color: const Color(0xffFF5C5C),
                  ),
                if (widget.warnCount > 0) ...[
                  const SizedBox(width: 6),
                  _Badge(
                    count: widget.warnCount,
                    color: const Color(0xffFFC857),
                  ),
                ],
              ],
              const Spacer(),
              AnimatedRotation(
                turns: widget.isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: ByteColor.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final Color color;

  const _Badge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}