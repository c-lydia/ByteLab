import 'package:flutter/material.dart';
import '../core/byte_color.dart';

class ByteCard extends StatefulWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;
  final Widget? footer;

  const ByteCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.icon,
    this.footer,
  });

  @override
  State<ByteCard> createState() => _ByteCardState();
}

class _ByteCardState extends State<ByteCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => hovered = true);
      },

      onExit: (_) {
        setState(() => hovered = false);
      },

      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),

        curve: Curves.easeOutCubic,

        scale: hovered ? 1.015 : 1.0,

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),

          curve: Curves.easeOutCubic,

          transform: Matrix4.identity()
            ..translateByDouble(0.0, hovered ? -5.0 : 0.0, 0.0, 1.0),

          decoration: BoxDecoration(
            color: ByteColor.surface,

            borderRadius: BorderRadius.circular(14),

            border: Border.all(
              color: hovered
                  ? Colors.cyanAccent.withValues(alpha: .7)
                  : ByteColor.border,

              width: hovered ? 1.2 : 1,
            ),

            boxShadow: hovered
                ? [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: .20),

                      blurRadius: 25,

                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),

          child: Padding(
            padding: const EdgeInsets.all(18),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    if (widget.icon != null) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),

                        padding: const EdgeInsets.all(7),

                        decoration: BoxDecoration(
                          color: hovered
                              ? const Color(0xff16354A)
                              : const Color(0xff132738),

                          borderRadius: BorderRadius.circular(8),
                        ),

                        child: Icon(
                          widget.icon,

                          size: 16,

                          color: Colors.cyanAccent,
                        ),
                      ),

                      const SizedBox(width: 10),
                    ],

                    Text(
                      widget.title.toUpperCase(),

                      style: const TextStyle(
                        color: ByteColor.secondsaryText,

                        fontSize: 11,

                        letterSpacing: 1.5,

                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                    if (widget.trailing != null) widget.trailing!,
                  ],
                ),

                const SizedBox(height: 18),

                widget.child,

                if (widget.footer != null) ...[
                  const SizedBox(height: 14),

                  widget.footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
