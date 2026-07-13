import 'package:flutter/material.dart';

import '../core/byte_color.dart';

class SurfaceContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const SurfaceContainer({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 12,
  });

  @override
  State<SurfaceContainer> createState() => _SurfaceContainerState();
}

class _SurfaceContainerState extends State<SurfaceContainer> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;

    return MouseRegion(
      cursor: interactive
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: interactive ? (_) => setState(() => _hovering = true) : null,
      onExit: interactive ? (_) => setState(() => _hovering = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _hovering ? ByteColor.surfaceHover : ByteColor.surface,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: _hovering ? ByteColor.cyan : ByteColor.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          onTap: widget.onTap,
          hoverColor: Colors.transparent, // hover handled above, avoid double-tint
          child: Padding(
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}