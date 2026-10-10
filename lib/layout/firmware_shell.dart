import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../core/byte_color.dart';
import '../screens/home_screen.dart';
import '../screens/project_page.dart';
import '../screens/firmware_pages.dart';
import '../screens/monitor_page.dart';
import '../screens/configuration_page.dart';
import '../screens/tool_pages.dart';
import '../screens/documentation_page.dart';
import '../screens/settings_page.dart';
import '../widgets/app_controls.dart';
import '../widgets/bytelab_logo.dart';

class FirmwareShell extends StatefulWidget {
  const FirmwareShell({super.key});
  @override
  State<FirmwareShell> createState() => _FirmwareShellState();
}

class _FirmwareShellState extends State<FirmwareShell> {
  late final AppLifecycleListener lifecycle;
  @override
  void initState() {
    super.initState();
    lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        final app = AppScope.of(context);
        try {
          await app.neovim.refreshModified();
        } catch (_) {
          // Unknown Neovim state is treated as potentially unsaved.
        }
        if (!mounted) return AppExitResponse.cancel;
        if (app.unsavedEditors.isNotEmpty || app.busy) {
          final leave =
              await showDialog<bool>(
                context: context,
                builder: (dialog) => AlertDialog(
                  title: const Text('Close ByteLab?'),
                  content: Text(
                    app.busy
                        ? 'A firmware command is running. Closing will cancel it. Stay in ByteLab to let it finish.'
                        : 'There are unsaved file edits. Closing will discard them.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Stay'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Close ByteLab'),
                    ),
                  ],
                ),
              ) ??
              false;
          if (!leave) return AppExitResponse.cancel;
        }
        await app.jobs.cancel();
        await app.serial.disconnect();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    lifecycle.dispose();
    super.dispose();
  }

  bool dock = false;
  final visited = <int>{0};
  static const labels = [
    'Overview',
    'Project',
    'Build',
    'Flash',
    'Monitor',
    'Configuration',
    'Diagnostics',
    'Protocol',
    'Documentation',
    'Settings',
  ];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.folder_open,
    Icons.build_circle_outlined,
    Icons.bolt,
    Icons.terminal,
    Icons.tune,
    Icons.memory,
    Icons.hub_outlined,
    Icons.menu_book_outlined,
    Icons.settings_outlined,
  ];
  static const pages = <Widget>[
    OverviewPage(),
    ProjectPage(),
    BuildPage(),
    FlashPage(),
    MonitorPage(),
    ConfigurationPage(),
    DiagnosticsPage(),
    ProtocolPage(),
    DocumentationPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    visited.add(app.selectedPage);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, size) {
          final wide = size.maxWidth >= 1150;
          return Row(
            children: [
              Container(
                width: wide ? 208 : 76,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: ByteColor.border)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 25),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const ByteLabLogo(),
                          if (wide)
                            const Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Text(
                                'BYTE LAB',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        children: [
                          for (var i = 0; i < labels.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Tooltip(
                                message: labels[i],
                                child: Material(
                                  color: app.selectedPage == i
                                      ? ByteColor.pink.withValues(alpha: 0.18)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    key: ValueKey('nav-$i'),
                                    onTap: () => app.navigate(i),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 14,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: wide
                                            ? MainAxisAlignment.start
                                            : MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            icons[i],
                                            size: 22,
                                            color: app.selectedPage == i
                                                ? ByteColor.cyan
                                                : ByteColor.secondsaryText,
                                          ),
                                          if (wide) ...[
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Text(
                                                labels[i],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: app.selectedPage == i
                                                      ? ByteColor.text
                                                      : ByteColor
                                                            .secondsaryText,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Tooltip(
                        message:
                            app.serial.connectedPort ?? 'No board connected',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 9,
                              color: app.serial.isConnected
                                  ? ByteColor.success
                                  : ByteColor.mutedText,
                            ),
                            if (wide) ...[
                              const SizedBox(width: 9),
                              Flexible(
                                child: Text(
                                  app.serial.isConnected
                                      ? 'BOARD CONNECTED'
                                      : 'DISCONNECTED',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 78,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: ByteColor.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.project.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  app.project.root ??
                                      'Open a project to get started',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: ByteColor.secondsaryText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: app.busy || !app.hasProject
                                ? null
                                : () {
                                    app.navigate(2);
                                    uiAction(context, app.build);
                                  },
                            icon: const Icon(Icons.build, size: 16),
                            label: const Text('Build'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => app.navigate(3),
                            icon: const Icon(Icons.bolt, size: 16),
                            label: const Text('Flash'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Serial monitor',
                            onPressed: () => app.navigate(4),
                            icon: const Icon(Icons.terminal),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 2,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ByteColor.glowCyan,
                            ByteColor.glowViolet,
                            ByteColor.pink,
                          ],
                        ),
                      ),
                    ),
                    if (app.notice != null)
                      MaterialBanner(
                        content: Text(app.notice!),
                        actions: [
                          TextButton(
                            onPressed: app.dismissNotice,
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    Expanded(
                      child: IndexedStack(
                        index: app.selectedPage,
                        children: [
                          for (var i = 0; i < pages.length; i++)
                            TickerMode(
                              enabled: app.selectedPage == i,
                              child: visited.contains(i)
                                  ? pages[i]
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                    if (app.selectedPage != 4) ...[
                      InkWell(
                        onTap: () => setState(() => dock = !dock),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 9,
                          ),
                          color: ByteColor.surface,
                          child: Row(
                            children: [
                              const Icon(Icons.terminal, size: 16),
                              const SizedBox(width: 10),
                              Text(
                                'Serial console · ${app.serial.history.length} lines',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const Spacer(),
                              Icon(
                                dock ? Icons.expand_more : Icons.expand_less,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (dock)
                        const SizedBox(
                          height: 215,
                          child: MonitorConsole(compact: true),
                        ),
                    ],
                    Container(
                      height: 28,
                      color: ByteColor.panel,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              app.serial.isConnected
                                  ? '${app.serial.connectedPort} · ${app.serial.baudRate} baud'
                                  : 'No serial connection',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: ByteColor.secondsaryText,
                              ),
                            ),
                          ),
                          Text(
                            app.busy
                                ? '${app.jobs.label} running'
                                : app.jobs.status.state.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: ByteColor.secondsaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
