import 'package:flutter/material.dart';

import '../core/byte_color.dart';
import 'surface_container.dart';

class ActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<ActionTile> {
  bool hovered = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          hovered = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            pressed = true;
          });
        },
        onTapUp: (_) {
          setState(() {
            pressed = false;
          });
          widget.onTap();
        },
        onTapCancel: () {
          setState(() {
            pressed = false;
          });
        },
        child: AnimatedScale(
          scale: pressed ? .96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, hovered ? -3.0 : 0.0, 0.0, 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: hovered
                  ? [
                      BoxShadow(
                        color: ByteColor.cyan.withValues(alpha: .15),
                        blurRadius: 18,
                      ),
                    ]
                  : [],
            ),
            child: SurfaceContainer(
              onTap: () {},
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: hovered
                          ? ByteColor.cyan.withValues(alpha: .15)
                          : ByteColor.surfaceHover,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AnimatedRotation(
                      turns: hovered ? .05 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(widget.icon, color: ByteColor.cyan),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: hovered ? ByteColor.cyan : ByteColor.text,
                            fontWeight: FontWeight.bold,
                          ),
                          child: Text(widget.title),
                        ),

                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: ByteColor.mutedText,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
