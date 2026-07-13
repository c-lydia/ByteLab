import 'package:flutter/material.dart';

import '../core/byte_color.dart';
import 'surface_container.dart';

class MetricChip extends StatefulWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  const MetricChip({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  State<MetricChip> createState() => _MetricChipState();
}

class _MetricChipState extends State<MetricChip> {
  bool hovering = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,

      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },

      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },

      child: GestureDetector(
        onTapDown: widget.onTap != null
            ? (_) {
                setState(() {
                  pressed = true;
                });
              }
            : null,

        onTapUp: widget.onTap != null
            ? (_) {
                setState(() {
                  pressed = false;
                });
                widget.onTap!();
              }
            : null,

        onTapCancel: () {
          setState(() {
            pressed = false;
          });
        },

        child: AnimatedScale(
          duration:
              const Duration(milliseconds:120),
          scale: pressed
              ? .95
              : hovering
                  ? 1.05
                  : 1,
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds:200),
            transform: Matrix4.identity()
              ..translate(
                0.0,
                hovering ? -3.0 : 0.0,
              ),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(12),
              boxShadow: hovering
                  ? [
                      BoxShadow(
                        color:
                            ByteColor.cyan.withOpacity(.18),
                        blurRadius:18,
                      ),
                    ]
                  : [],
            ),

            child: SurfaceContainer(
              onTap: widget.onTap,
              padding:
                  const EdgeInsets.symmetric(
                    horizontal:16,
                    vertical:12,
                  ),
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children:[
                  AnimatedRotation(
                    turns: hovering ? .05 : 0,
                    duration:
                        const Duration(milliseconds:200),
                    child: AnimatedScale(
                      duration:
                          const Duration(milliseconds:200),
                      scale: hovering ? 1.15 : 1,
                      child: Icon(
                        widget.icon,
                        size:18,
                        color:
                            ByteColor.cyan,
                      ),
                    ),
                  ),
                  const SizedBox(width:10),
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children:[
                      Text(
                        widget.title,
                        style:const TextStyle(
                          color:
                              ByteColor.mutedText,
                          fontSize:10,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration:
                            const Duration(milliseconds:300),
                        transitionBuilder:
                            (child, animation){
                          return FadeTransition(
                            opacity:animation,
                            child:
                                SlideTransition(
                                  position:
                                    Tween<Offset>(
                                      begin:
                                          const Offset(0,.3),
                                      end:
                                          Offset.zero,
                                    ).animate(animation),
                                  child:child,
                                ),
                          );
                        },
                        child:Text(
                          widget.value,
                          key:
                              ValueKey(widget.value),
                          style:const TextStyle(
                            color:
                                ByteColor.text,
                            fontSize:14,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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