import 'package:flutter/material.dart';

import '../core/byte_color.dart';

class DeviceTile extends StatefulWidget {
  final String name;
  final String status;
  final bool isOnline;
  final VoidCallback? onTap;

  const DeviceTile({
    super.key,
    required this.name,
    required this.status,
    this.isOnline = true,
    this.onTap,
  });

  @override
  State<DeviceTile> createState() => _DeviceTileState();
}

class _DeviceTileState extends State<DeviceTile>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    if (widget.isOnline) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(DeviceTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isOnline != oldWidget.isOnline) {
      if (widget.isOnline) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: interactive ? (_) => setState(() => _hovering = true) : null,
      onExit: interactive ? (_) => setState(() => _hovering = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.identity()
          ..translateByDouble(0.0, _hovering ? -3.0 : 0.0, 0.0, 1.0),
        decoration: BoxDecoration(
          color: _hovering ? ByteColor.surfaceHover : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: ByteColor.cyan.withValues(alpha: .12),
                    blurRadius: 15,
                  ),
                ]
              : [],
        ),
        child: ListTile(
          onTap: widget.onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          hoverColor: Colors.transparent,
          leading: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isOnline ? 1 + (_pulseController.value * .08) : 1,
                child: Icon(
                  Icons.memory,
                  color: widget.isOnline ? ByteColor.cyan : ByteColor.mutedText,
                ),
              );
            },
          ),
          title: Text(
            widget.name,
            style: const TextStyle(color: ByteColor.text),
          ),
          subtitle: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isOnline ? Colors.greenAccent : Colors.grey,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  widget.status,
                  key: ValueKey(widget.status),
                  style: const TextStyle(color: ByteColor.mutedText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
