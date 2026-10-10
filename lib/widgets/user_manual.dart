import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import 'app_controls.dart';
import 'neovim_guide.dart';

/// Bundled help stays usable without an SDK, project, or network connection.
class UserManual extends StatelessWidget {
  const UserManual({super.key});

  @override
  Widget build(BuildContext context) => AppPanel(
    title: 'User manual',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'New to ByteLab? This manual is included with the app and works offline. Choose a topic below for setup, editing, and your first build.',
        ),
        ExpansionTile(
          key: const ValueKey('user-manual'),
          tilePadding: EdgeInsets.zero,
          title: const Text('How to use ByteLab'),
          children: [
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: () => AppScope.of(context).navigate(9),
                  child: const Text('Go to settings'),
                ),
                TextButton(
                  onPressed: () => AppScope.of(context).navigate(1),
                  child: const Text('Go to project'),
                ),
              ],
            ),
            const _Topic('Start here · first project to serial output', [
              '1. Install ESP-IDF for your board. In Settings, choose its export.sh and select Save and check toolchain. If you launched ByteLab from an activated ESP-IDF terminal, you can leave this path empty. Serial monitoring alone does not require ESP-IDF.',
              '2. In Project, use Open project for a folder containing CMakeLists.txt, or Create starter to make a new ESP-IDF project. The starter targets ESP32. To change chips, run idf.py set-target <chip> in an activated SDK terminal inside that project.',
              '3. Choose your preferred editor in Settings and Save settings. Select a file in Project, edit, then save. The built-in editor is the default and needs no separate editor installation.',
              '4. Open Build and select Build project. Read the command output for errors; cancellation is available while a command runs. Save all files first: builds use the files on disk.',
              '5. Connect the board, select the correct serial port on Flash, and upload. Flashing replaces the selected board’s firmware. ByteLab releases its monitor while flashing and reconnects afterward.',
              '6. In Monitor, connect with the firmware’s baud rate to view logs and send commands. Dashboard telemetry appears only when firmware emits supported metrics. The starter understands STATUS?, PING, and HELP; other firmware may use different commands.',
            ]),
            const _Topic('Built-in editor · files, saving, and shortcuts', [
              'Select Built-in in Settings → Preferred editor and save. In Project, choose a text file (up to 2 MiB). Syntax colors, line numbers, horizontal scrolling, and cursor position are provided. Configuration has a built-in editor too.',
              'Ctrl+S saves while the built-in editor has focus. Use the standard text selection, copy, paste, undo, and redo controls. Save is also available as a button. Reload reads the file from disk and asks before discarding an edited draft.',
              'Save or reload your drafts before changing projects, editor modes, or running firmware commands. Built-in saves check for external changes and keep the previous file in .bytelab-backups. If another editor changed the file, reload it before retrying; preserve any draft you still need first.',
              'Vim motions and plugins require selecting Neovim. ByteLab does not currently provide global keyboard shortcuts for every page or firmware command.',
            ]),
            const _Topic('VS Code · external editing and extensions', [
              'Install VS Code separately. In Settings choose VS Code. Leave Executable path empty to detect code or code-insiders from PATH, or Browse executable to select the launcher. Enter only the executable path, without quotes or command arguments. Check executable confirms it can be located; Save settings retains your selection.',
              'In Project, select a file and click Open file, or click Open project in VS Code. It opens a separate editor window. Your installed VS Code settings, keyboard shortcuts, and extensions apply; manage extensions inside VS Code.',
              'Save all changes in VS Code before Build or Flash in ByteLab. ByteLab cannot inspect external unsaved buffers or close that editor for you. Reload any open built-in/configuration editor after external changes. ByteLab firmware commands continue using the ESP-IDF SDK configured in its Settings.',
            ]),
            const _Topic('Arduino IDE · sketches, boards, and libraries', [
              'Install Arduino IDE separately. Choose Arduino IDE in Settings. Detection looks for arduino-ide or arduino on PATH; for an extracted installation or AppImage, browse to its executable and ensure it has execute permission. Check executable, then Save settings. Save and launch editor can open it before you have a ByteLab project.',
              'Arduino IDE runs in a separate window. In Project, Open sketch is available for .ino or .pde files; Launch Arduino IDE opens the application without a file. Use its File → Open menu for a sketch elsewhere. A normal Arduino sketch has a primary .ino file matching its folder name.',
              'An ESP-IDF CMake project is not an Arduino sketch. Selecting Arduino IDE does not convert a project or add Arduino support to ByteLab’s build system. For Arduino sketches, select the board and port in Arduino IDE and use its Verify and Upload commands. Manage board packages and libraries there.',
              'ByteLab can still monitor an Arduino board’s serial output. Disconnect the ByteLab monitor before uploading from Arduino IDE so the serial port is available. Reconnect afterward using the sketch’s baud rate. Save externally before using any ByteLab command that reads the same files.',
            ]),
            const NeovimGuide(),
            const _Topic('Toolchain docs · detection and online references', [
              'Below this manual, ByteLab detects the ESP-IDF chip and version from project configuration, build metadata, and your selected SDK. Detection sources and fallback values are shown. Refresh detection after changing the SDK or files outside ByteLab.',
              'Search or filter the official references, then use Read official docs to open your browser. Chip/version overrides affect documentation links only. Full online references require internet; this manual and the code examples are bundled with ByteLab.',
            ]),
            const _Topic('Compatibility and troubleshooting', [
              'ByteLab is currently built and tested on Linux. Ubuntu is not a requirement in the app, but the release needs compatible GTK 3, GLib, C++ runtime, and OpenGL libraries. Windows has a runner but still needs firmware/serial integration work and validation; a Linux bundle cannot run directly on Windows or macOS.',
              'Editor not found: check its installation and PATH in the environment that launches ByteLab, or set the external executable path in Settings. A desktop shortcut can have a different PATH from your terminal. An AppImage may also need distribution-specific runtime support.',
              'Toolchain errors: check export.sh, run Save and check toolchain, and inspect Build output. No serial port: check the USB data cable, device permissions, and whether another program owns the port. Unexpected text: check baud rate and line endings in Settings.',
              'For appearance, Settings → Underlight transparency changes Linux whole-window opacity from 70% to 100%. Save to apply; 100% is opaque. Text also becomes translucent. Desktop blur belongs to the compositor, and its rules may combine with this setting.',
            ]),
          ],
        ),
      ],
    ),
  );
}

class _Topic extends StatelessWidget {
  const _Topic(this.title, this.paragraphs);
  final String title;
  final List<String> paragraphs;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: ValueKey(title),
    tilePadding: EdgeInsets.zero,
    title: Text(title),
    children: [
      for (final paragraph in paragraphs)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(paragraph),
          ),
        ),
    ],
  );
}
