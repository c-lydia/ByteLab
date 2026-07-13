import 'package:flutter/material.dart';

import '../widgets/nav_rail.dart';
import '../widgets/status_chip.dart';
import '../core/byte_color.dart';
import '../widgets/byte_topbar.dart';

class FirmwareShell extends StatefulWidget {
  final List<Widget> pages;
  final String project;
  final String path;

  const FirmwareShell({
    super.key, 
    required this.pages,
    this.project = "Untitled Project",
    this.path = "Workspace"
  });

  @override
  State<FirmwareShell> createState() => _FirmwareShellState();
}

class _FirmwareShellState extends State<FirmwareShell> {
  int selected = 0;

  void changePage(int index) {
    if (index < 0 || index >= widget.pages.length)
      return;

    setState(() {
      selected = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff080F17),
      body: Row(
        children: [
          FirmwareNavRail(
            selectedIndex: selected, 
            onChanged: changePage,
          ),
          Expanded(
            child: Column(
              children: [
                ByteTopbar(project: widget.project, path: widget.path, status: DeviceStatus.connected),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Duration(microseconds: 200),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(selected),
                      child: widget.pages[selected]
                    )
                  ),
                ),
                const _StatusBar(),
              ],
            )
          )
        ],
      )
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: ByteColor.surface,
        border: const Border(top: BorderSide(color: ByteColor.border))
      ),
      child: Row(
        children: [
          const Icon(Icons.usb, size: 13, color: ByteColor.success),
          const SizedBox(width: 8),
          const Text(
            "ESP32 CONNECTED",
            style: TextStyle(
              color: ByteColor.secondsaryText,
              fontSize: 11,
              letterSpacing: 1
            )
          ), 
          const Spacer(),
          const Text(
            "UART 115200",
            style: TextStyle(
              color: ByteColor.mutedText,
              fontSize: 11
            ),
          ), 
          const SizedBox(width: 20),
          const Text(
            "RAM 64KB",
            style: TextStyle(
              color: ByteColor.mutedText,
              fontSize: 11
            )
          )
        ],
      )
    );
  }
}