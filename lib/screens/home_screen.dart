import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../core/byte_color.dart';
import '../models/serial_log_entry.dart';
import '../service/metric_registry.dart';
import '../widgets/app_controls.dart';
import '../widgets/metric_card.dart';
import '../widgets/telemetry_chart.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final info = app.serial.latestDeviceInfo;
    final metrics = app.serial.latestTelemetry.values;
    final events = app.serial.history
        .where((e) => e.level == LogLevel.warn || e.level == LogLevel.error)
        .toList()
        .reversed
        .take(6);
    return ListView(
      padding: const EdgeInsets.all(26),
      children: [
        PageTitle(
          'Workspace overview',
          'Your firmware, connected board, and live telemetry.',
          actions: [
            OutlinedButton.icon(
              onPressed: app.serial.isConnected
                  ? () => uiAction(
                      context,
                      app.serial.requestStatus,
                      success: 'Board replied',
                    )
                  : null,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Request status'),
            ),
          ],
        ),
        const AppPanel(child: ConnectionControls()),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 230,
              child: MetricCard(
                title: 'Connection',
                value: app.serial.isConnected ? 'Connected' : 'Offline',
                subtitle: app.serial.connectedPort ?? 'Choose a port above',
                icon: Icons.usb,
              ),
            ),
            SizedBox(
              width: 230,
              child: MetricCard(
                title: 'Firmware',
                value: info.firmwareVersion ?? '—',
                subtitle: info.idfVersion == null
                    ? 'Waiting for device metadata'
                    : 'ESP-IDF ${info.idfVersion}',
                icon: Icons.memory,
              ),
            ),
            for (final entry in metrics.entries)
              SizedBox(
                width: 190,
                child: MetricCard(
                  title: MetricRegistry.forId(entry.key).label,
                  value: MetricRegistry.forId(entry.key).format(entry.value),
                  subtitle: app.serial.isConnected
                      ? 'Last reported by board'
                      : 'Last session',
                  icon: MetricRegistry.forId(entry.key).icon,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        AppPanel(
          title: 'Live telemetry',
          child: SizedBox(
            height: 240,
            child: app.series.isEmpty
                ? const EmptyMessage(
                    'Waiting for telemetry',
                    'Connect a board that emits telemetry lines. The starter project includes this protocol.',
                    icon: Icons.show_chart,
                  )
                : TelemetryChart(
                    series: {
                      for (final entry in app.series.entries)
                        entry.key: List.of(entry.value),
                    },
                    markers: List.of(app.markers),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Each chart line is scaled independently; values and units appear in the cards above.',
          style: TextStyle(fontSize: 11, color: ByteColor.secondsaryText),
        ),
        const SizedBox(height: 20),
        AppPanel(
          title: 'Quick actions',
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => app.navigate(1),
                icon: const Icon(Icons.folder_open),
                label: const Text('Open or create project'),
              ),
              OutlinedButton.icon(
                onPressed: app.busy || !app.hasProject
                    ? null
                    : () {
                        app.navigate(2);
                        uiAction(context, app.build);
                      },
                icon: const Icon(Icons.build),
                label: const Text('Build firmware'),
              ),
              OutlinedButton.icon(
                onPressed: () => app.navigate(3),
                icon: const Icon(Icons.bolt),
                label: const Text('Flash board'),
              ),
              OutlinedButton.icon(
                onPressed: () => app.navigate(4),
                icon: const Icon(Icons.terminal),
                label: const Text('Open monitor'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppPanel(
          title: 'Recent warnings and errors',
          child: events.isEmpty
              ? const Text(
                  'No warnings or errors in this session.',
                  style: TextStyle(color: ByteColor.secondsaryText),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in events)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Text(
                          '${entry.tag ?? entry.level.name}: ${entry.message}',
                          style: TextStyle(color: entry.level.color),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
