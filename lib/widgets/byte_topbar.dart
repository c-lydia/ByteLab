import 'package:flutter/material.dart';

import '../core/byte_color.dart';
import '../core/byte_typography.dart';
import 'status_chip.dart';

class ByteTopbar extends StatefulWidget {
  final String project;
  final String path;
  final DeviceStatus status;

  final VoidCallback? onBuild;
  final VoidCallback? onFlash;
  final VoidCallback? onDebug;

  const ByteTopbar({
    super.key,
    required this.project,
    required this.path,
    required this.status,
    this.onBuild,
    this.onFlash,
    this.onDebug,
  });

  @override
  State<ByteTopbar> createState() => _ByteTopbarState();
}

class _ByteTopbarState extends State<ByteTopbar> {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: 0,
        end: 1,
      ),
      duration: const Duration(
        milliseconds:400,
      ),
      curve: Curves.easeOutCubic,
      builder:(context,value,child){
        return Transform.translate(
          offset: Offset(
            0,
            -20 * (1-value),
          ),
          child: Opacity(
            opacity:value,
            child:child,
          ),
        );
      },
      child: Container(
        height:80,
        padding:
            const EdgeInsets.symmetric(
              horizontal:24,
            ),
        decoration:BoxDecoration(
          color:
              ByteColor.background,
          border:Border(
            bottom:BorderSide(
              color:
                  ByteColor.border,
            ),
          ),
        ),
        child:Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children:[
            Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children:[
                Text(
                  "BYTE LAB",
                  style:
                      ByteTypography.section,
                ),
                const SizedBox(height:8),
                Row(
                  children:[
                    Text(
                      widget.project,
                      style:
                          ByteTypography.body,
                    ),
                    const SizedBox(width:8),
                    const Text(
                      "/",
                      style:TextStyle(
                        color:
                            ByteColor.mutedText,
                      ),
                    ),
                    const SizedBox(width:8),
                    Text(
                      widget.path,
                      style:const TextStyle(
                        color:
                            ByteColor.secondsaryText,
                        fontSize:13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children:[
                StatusChip(
                  status:
                      widget.status,
                ),
                const SizedBox(width:20),
                _ActionButton(
                  text:"BUILD",
                  icon:Icons.build,
                  onTap:
                      widget.onBuild,
                ),
                const SizedBox(width:8),
                _ActionButton(
                  text:"FLASH",
                  icon:Icons.memory,
                  onTap:
                      widget.onFlash,
                ),
                const SizedBox(width:8),
                _ActionButton(
                  text:"DEBUG",
                  icon:Icons.bug_report,
                  onTap:
                      widget.onDebug,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionButton({
    super.key,
    required this.text,
    required this.icon,
    this.onTap,
  });

  @override
  State<_ActionButton> createState()
      => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool hovering = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context){
    return MouseRegion(
      cursor:
          SystemMouseCursors.click,
      onEnter:(_){
        setState((){
          hovering=true;
        });
      },
      onExit:(_){
        setState((){
          hovering=false;
        });
      },
      child:GestureDetector(
        onTapDown:(_){
          setState((){
            pressed=true;
          });
        },
        onTapUp:(_){
          setState((){
            pressed=false;
          });
          widget.onTap?.call();
        },
        onTapCancel:(){
          setState((){
            pressed=false;
          });
        },
        child:AnimatedScale(
          scale:
              pressed ? .94 : 1,
          duration:
              const Duration(
                milliseconds:100,
              ),
          child:AnimatedContainer(
            duration:
                const Duration(
                  milliseconds:180,
                ),
            curve:
                Curves.easeOut,
            padding:
                const EdgeInsets.symmetric(
                  horizontal:12,
                  vertical:8,
                ),
            decoration:BoxDecoration(
              color:
                  hovering
                  ? ByteColor.surfaceHover
                  : ByteColor.surface,
              border:
                  Border.all(
                    color:
                    hovering
                    ? ByteColor.cyan
                    : ByteColor.border,
                  ),
              borderRadius:
                  BorderRadius.circular(6),
              boxShadow:
                  hovering
                  ?
                  [
                    BoxShadow(
                      color:
                          ByteColor.cyan
                          .withOpacity(.15),
                      blurRadius:12,
                    ),
                  ]
                  :
                  [],
            ),
            child:Row(
              children:[
                AnimatedRotation(
                  turns:
                    hovering
                    ? .05
                    : 0,
                  duration:
                    const Duration(
                      milliseconds:200,
                    ),
                  child:Icon(
                    widget.icon,
                    size:14,
                    color:
                        ByteColor.cyan,
                  ),
                ),
                const SizedBox(width:6),
                AnimatedDefaultTextStyle(
                  duration:
                    const Duration(
                      milliseconds:180,
                    ),
                  style:TextStyle(
                    color:
                    hovering
                    ? ByteColor.cyan
                    : Colors.white,
                    fontSize:11,
                    letterSpacing:1,
                    fontWeight:
                        FontWeight.bold,
                  ),
                  child:Text(
                    widget.text,
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