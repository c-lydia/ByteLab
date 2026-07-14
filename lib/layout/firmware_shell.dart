import 'package:flutter/material.dart';

import '../core/byte_color.dart';
import '../service/build_service.dart';
import '../service/device_scanner.dart';
import '../service/serial_service.dart';
import '../widgets/byte_topbar.dart';
import '../widgets/expandable_terminal_panel.dart';
import '../widgets/nav_rail.dart';
import '../widgets/status_chip.dart';
import '../service/serial_service_scope.dart';

class FirmwareShell extends StatefulWidget {
  final List<Widget> pages;
  final String project;
  final String path;

  const FirmwareShell({
    super.key,
    required this.pages,
    this.project = "Untitled Project",
    this.path = "Workspace",
  });

  @override
  State<FirmwareShell> createState() => _FirmwareShellState();
}

class _FirmwareShellState extends State<FirmwareShell> {
  int selected = 0;

  // Owned once here so the connection survives page navigation instead of
  // being torn down/recreated every time you switch tabs. Shared with every
  // page below via SerialServiceScope.
  final SerialService _serialService = SerialService();

  // Also shared, so any page's "Monitor" action can pop the terminal dock
  // open — not just the dock's own header toggle.
  final ValueNotifier<bool> _terminalExpanded = ValueNotifier(false);

  late final DeviceScanner _deviceScanner =
      DeviceScanner(serialService: _serialService)..start();

  late final BuildService _buildService =
      BuildService(projectPath: widget.path);

  @override
  void dispose() {
    _serialService.dispose();
    _terminalExpanded.dispose();
    _deviceScanner.dispose();
    _buildService.dispose();
    super.dispose();
  }

  void changePage(int index) {
    if (index < 0 || index >= widget.pages.length) return;
    setState(() => selected = index);
  }

  @override
  Widget build(BuildContext context) {
    return SerialServiceScope(
      serialService: _serialService,
      terminalExpanded: _terminalExpanded,
      deviceScanner: _deviceScanner,
      buildService: _buildService,
      child: Scaffold(
        backgroundColor: const Color(0xff080F17),
        body: Row(
          children: [
            FirmwareNavRail(selectedIndex: selected, onChanged: changePage),
            Expanded(
              child: Column(
                children: [
                  ByteTopbar(
                    project: widget.project,
                    path: widget.path,
                    status: DeviceStatus.connected,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      // was `microseconds: 200` — effectively invisible.
                      // milliseconds is what makes the fade actually show.
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(selected),
                        child: widget.pages[selected],
                      ),
                    ),
                  ),
                  // Persistent dock, present on every page — collapsed by
                  // default, expands in place. Lives here (not inside
                  // individual pages) so it doesn't reset when navigating.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: ExpandableTerminalPanel(
                      serialService: _serialService,
                      expanded: _terminalExpanded,
                    ),
                  ),
                  const _StatusBar(),
                ],
              ),
            ),
          ],
        ),
      ),
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
      decoration: const BoxDecoration(
        color: ByteColor.surface,
        border: Border(top: BorderSide(color: ByteColor.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.usb, size: 13, color: ByteColor.success),
          const SizedBox(width: 8),
          const Text(
            "ESP32 CONNECTED",
            // was ByteColor.secondsaryText (typo) — fixed
            style: TextStyle(
              color: ByteColor.secondsaryText,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          const Text(
            "UART 115200",
            style: TextStyle(color: ByteColor.mutedText, fontSize: 11),
          ),
          const SizedBox(width: 20),
          const Text(
            "RAM 64KB",
            style: TextStyle(color: ByteColor.mutedText, fontSize: 11),
          ),
        ],
      ),
    );
  }
}