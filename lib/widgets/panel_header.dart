import 'package:flutter/material.dart';

import '../core/byte_color.dart';

class PanelHeaderAction extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const PanelHeaderAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  State<PanelHeaderAction> createState() => _PanelHeaderActionState();
}

class _PanelHeaderActionState extends State<PanelHeaderAction> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _hovering ? ByteColor.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color: _hovering ? ByteColor.cyan : ByteColor.mutedText,
          ),
        ),
      ),
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}