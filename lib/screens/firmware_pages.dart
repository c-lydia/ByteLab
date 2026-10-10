import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/app_controller.dart';
import '../core/byte_color.dart';
import '../service/build_status.dart';
import '../widgets/app_controls.dart';
import '../widgets/log_console.dart';
import 'monitor_page.dart';

class BuildPage extends StatelessWidget {
  const BuildPage({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageTitle(
            'Build firmware',
            'Compile your ESP-IDF project and inspect the full command output.',
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: app.busy || !app.hasProject
                    ? null
                    : () => uiAction(context, app.build),
                icon: const Icon(Icons.build, size: 18),
                label: const Text('Build project'),
              ),
              for (final task in [
                ('reconfigure', 'Reconfigure'),
                ('size', 'Memory usage'),
                ('clean', 'Clean build'),
              ])
                OutlinedButton(
                  onPressed: app.busy || !app.hasProject
                      ? null
                      : () => uiAction(
                          context,
                          () => app.runFirmware([task.$1], task.$2),
                        ),
                  child: Text(task.$2),
                ),
              TextButton(
                onPressed: app.busy
                    ? null
                    : () => uiAction(context, app.checkToolchain),
                child: const Text('Check toolchain'),
              ),
            ],
          ),
          if (!app.hasProject)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Text('No project open.'),
                  TextButton(
                    onPressed: () => app.navigate(1),
                    child: const Text('Choose project'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          const Expanded(child: FirmwareOutput()),
        ],
      ),
    );
  }
}

class FlashPage extends StatelessWidget {
  const FlashPage({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageTitle(
            'Flash board',
            'Build and upload this project to the selected board.',
          ),
          const ConnectionControls(),
          const SizedBox(height: 16),
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Project: ${app.project.name}    ·    Upload: ${app.settings.flashBaudRate} baud',
                ),
                const SizedBox(height: 10),
                const Text(
                  'Flashing replaces firmware on the selected board. The serial monitor is released during upload and reconnected afterward.',
                  style: TextStyle(color: ByteColor.secondsaryText),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed:
                      app.busy ||
                          app.serial.isConnecting ||
                          !app.hasProject ||
                          app.settings.port.isEmpty
                      ? null
                      : () => uiAction(context, app.flash),
                  icon: const Icon(Icons.bolt),
                  label: Text(
                    app.settings.port.isEmpty
                        ? 'Select a board port'
                        : 'Flash ${app.settings.port}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Expanded(child: FirmwareOutput()),
        ],
      ),
    );
  }
}

class FirmwareOutput extends StatelessWidget {
  const FirmwareOutput({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final status = app.jobs.status;
    final color = switch (status.state) {
      BuildState.failed => ByteColor.error,
      BuildState.success => ByteColor.success,
      BuildState.cancelled => ByteColor.warning,
      _ => ByteColor.cyan,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              status.state == BuildState.failed
                  ? Icons.error_outline
                  : Icons.terminal,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                status.currentStep.isEmpty
                    ? 'Ready to run'
                    : status.currentStep,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (app.busy)
              TextButton.icon(
                onPressed: () => uiAction(context, app.jobs.cancel),
                icon: const Icon(Icons.stop),
                label: const Text('Cancel'),
              ),
            IconButton(
              tooltip: 'Copy command output',
              onPressed: () => uiAction(
                context,
                () => Clipboard.setData(
                  ClipboardData(text: app.jobs.outputLines.join('\n')),
                ),
                success: 'Output copied',
              ),
              icon: const Icon(Icons.copy, size: 18),
            ),
            IconButton(
              tooltip: 'Export command output',
              onPressed: () => uiAction(
                context,
                () => exportConsole(context, firmware: true),
              ),
              icon: const Icon(Icons.file_download_outlined, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: app.busy && status.progress == 0 ? null : status.progress,
          color: color,
          minHeight: 3,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LogConsole(
            lines: app.jobs.outputLines
                .map(
                  (line) => ConsoleLine(
                    line,
                    line.startsWith('ERROR:') || line.contains('error:')
                        ? ByteColor.error
                        : ByteColor.text,
                  ),
                )
                .toList(),
            empty: 'Build, flash, and toolchain output appears here.',
          ),
        ),
      ],
    );
  }
}
