import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/byte_color.dart';
import 'code_block.dart';

class SourceEditor extends StatefulWidget {
  const SourceEditor({
    super.key,
    required this.controller,
    required this.onSave,
    this.readOnly = false,
  });
  final TextEditingController controller;
  final VoidCallback? onSave;
  final bool readOnly;
  @override
  State<SourceEditor> createState() => _SourceEditorState();
}

class _SourceEditorState extends State<SourceEditor> {
  final vertical = ScrollController();
  final horizontal = ScrollController();
  @override
  void dispose() {
    vertical.dispose();
    horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
          widget.onSave?.call(),
    },
    child: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final text = widget.controller.text;
        final lines = text.split('\n');
        final scaler = MediaQuery.textScalerOf(context);
        final measure = TextPainter(
          text: const TextSpan(text: 'M', style: codeStyle),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        final lineHeight = measure.height;
        final charWidth = measure.width;
        measure.dispose();
        final gutter = math.max(
          48.0,
          lines.length.toString().length * charWidth + 24,
        );
        final longest = lines.fold<int>(
          0,
          (value, line) => math.max(value, line.length),
        );
        final cursor = widget.controller.selection.extentOffset.clamp(
          0,
          text.length,
        );
        final line = '\n'.allMatches(text.substring(0, cursor)).length + 1;
        final column =
            cursor - text.lastIndexOf('\n', cursor == 0 ? 0 : cursor - 1);
        final controller = widget.controller;
        final language = controller is CodeEditingController
            ? controller.language
            : 'text';
        return Container(
          decoration: BoxDecoration(
            color: ByteColor.terminal,
            border: Border.all(color: ByteColor.border),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: gutter,
                      child: ClipRect(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _LineNumbers(
                            vertical,
                            lines.length,
                            lineHeight,
                            scaler,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => Scrollbar(
                          controller: horizontal,
                          child: SingleChildScrollView(
                            controller: horizontal,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: math.max(
                                constraints.maxWidth,
                                longest * charWidth + 48,
                              ),
                              height: constraints.maxHeight,
                              child: TextField(
                                controller: controller,
                                scrollController: vertical,
                                readOnly: widget.readOnly,
                                expands: true,
                                maxLines: null,
                                minLines: null,
                                keyboardType: TextInputType.multiline,
                                autocorrect: false,
                                enableSuggestions: false,
                                textAlignVertical: TextAlignVertical.top,
                                style: codeStyle,
                                strutStyle: StrutStyle.fromTextStyle(
                                  codeStyle,
                                  forceStrutHeight: true,
                                ),
                                decoration: const InputDecoration(
                                  filled: true,
                                  fillColor: ByteColor.terminal,
                                  contentPadding: EdgeInsets.fromLTRB(
                                    12,
                                    18,
                                    18,
                                    18,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: ByteColor.panel,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    Text(
                      language.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: ByteColor.cyan,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Ln $line, Col ${math.max(1, column)}  ·  ${lines.length} lines',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ByteColor.secondsaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _LineNumbers extends CustomPainter {
  _LineNumbers(this.scroll, this.count, this.lineHeight, this.scaler)
    : super(repaint: scroll);
  final ScrollController scroll;
  final int count;
  final double lineHeight;
  final TextScaler scaler;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ByteColor.panel);
    final offset = scroll.hasClients ? scroll.offset : 0.0;
    final first = math.max(0, ((offset - 18) / lineHeight).floor());
    final last = math.min(count, ((offset + size.height) / lineHeight).ceil());
    for (var i = first; i < last; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: codeStyle.copyWith(color: ByteColor.mutedText),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      painter.paint(
        canvas,
        Offset(size.width - painter.width - 12, 18 + i * lineHeight - offset),
      );
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(_LineNumbers old) =>
      old.count != count ||
      old.lineHeight != lineHeight ||
      old.scaler != scaler;
}
