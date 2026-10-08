import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/byte_color.dart';

class SourceEditor extends StatelessWidget {
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
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
          onSave?.call(),
    },
    child: TextField(
      controller: controller,
      readOnly: readOnly,
      expands: true,
      maxLines: null,
      minLines: null,
      keyboardType: TextInputType.multiline,
      autocorrect: false,
      enableSuggestions: false,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.6,
        color: Color(0xffD0DEE8),
      ),
      decoration: const InputDecoration(
        filled: true,
        fillColor: ByteColor.terminal,
        contentPadding: EdgeInsets.all(18),
        border: OutlineInputBorder(),
      ),
    ),
  );
}
