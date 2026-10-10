import 'package:flutter/material.dart';
import '../core/byte_color.dart';

class ConsoleLine {
  const ConsoleLine(this.text, [this.color = ByteColor.text]);
  final String text;
  final Color color;
}

class LogConsole extends StatefulWidget {
  const LogConsole({
    super.key,
    required this.lines,
    this.follow = true,
    this.empty = 'No output yet.',
  });
  final List<ConsoleLine> lines;
  final bool follow;
  final String empty;
  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  final scroll = ScrollController();
  @override
  void didUpdateWidget(LogConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.follow &&
        (oldWidget.lines.length != widget.lines.length ||
            (widget.lines.isNotEmpty &&
                oldWidget.lines.lastOrNull?.text != widget.lines.last.text) ||
            !oldWidget.follow)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) {
          scroll.jumpTo(scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    color: ByteColor.terminal,
    child: widget.lines.isEmpty
        ? Center(
            child: Text(
              widget.empty,
              style: const TextStyle(color: ByteColor.secondsaryText),
            ),
          )
        : Scrollbar(
            controller: scroll,
            thumbVisibility: true,
            child: SelectionArea(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(14),
                itemCount: widget.lines.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    widget.lines[index].text,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.5,
                      color: widget.lines[index].color,
                    ),
                  ),
                ),
              ),
            ),
          ),
  );
}
