import 'package:flutter/material.dart';

import '../core/byte_color.dart';

class EventTile extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String time;
  final VoidCallback? onTap;

  const EventTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.time,
    this.onTap,
  });

  @override
  State<EventTile> createState() => _EventTileState();
}

class _EventTileState extends State<EventTile>
    with SingleTickerProviderStateMixin {
  bool hovering = false;
  late AnimationController pulseController;

  @override
  void initState() {
    super.initState();

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    pulseController.forward();
  }

  @override
  void dispose() {
    pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (interactive) {
          setState(() {
            hovering = true;
          });
        }
      },

      onExit: (_) {
        if (interactive) {
          setState(() {
            hovering = false;
          });
        }
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.identity()
          ..translateByDouble(0.0, hovering ? -2.0 : 0.0, 0.0, 1.0),
        decoration: BoxDecoration(
          color: hovering ? ByteColor.surfaceHover : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: hovering
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: .18),
                    blurRadius: 12,
                  ),
                ]
              : [],
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: hovering ? 1.15 : 1,
                  child: Icon(widget.icon, color: widget.color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ByteColor.text),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    widget.time,
                    key: ValueKey(widget.time),
                    style: const TextStyle(color: ByteColor.text, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
