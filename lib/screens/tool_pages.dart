import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../core/byte_color.dart';
import '../models/serial_log_entry.dart';
import '../service/device_info.dart';
import '../service/telemetry_sample.dart';
import '../widgets/app_controls.dart';

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final values = {
      'Project': app.project.root ?? 'No project open',
      'Serial connection': app.serial.connectedPort ?? 'Disconnected',
      'Monitor baud': '${app.serial.baudRate}',
      'Firmware version':
          app.serial.latestDeviceInfo.firmwareVersion ?? 'Not reported',
      'Device ESP-IDF version':
          app.serial.latestDeviceInfo.idfVersion ?? 'Not reported',
      'Last telemetry':
          app.lastTelemetryAt?.toLocal().toString() ?? 'Not received',
      'Retained serial lines': '${app.serial.history.length} / 5000',
      'Last command': '${app.jobs.label} · ${app.jobs.status.state.name}',
      'Toolchain script': app.settings.exportScript.isEmpty
          ? 'Uses process PATH'
          : app.settings.exportScript,
    };
    return ListView(
      padding: const EdgeInsets.all(26),
      children: [
        const PageTitle(
          'Diagnostics',
          'Inspect the actual device, project, and toolchain state.',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: app.scanner.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Rescan ports'),
            ),
            OutlinedButton(
              onPressed: app.serial.isConnected
                  ? () => uiAction(
                      context,
                      app.serial.requestStatus,
                      success: 'Status response received',
                    )
                  : null,
              child: const Text('Request device status'),
            ),
            FilledButton(
              onPressed: app.busy
                  ? null
                  : () {
                      app.navigate(2);
                      uiAction(context, app.checkToolchain);
                    },
              child: const Text('Verify ESP-IDF'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppPanel(
          title: 'Session',
          child: Column(
            children: [
              for (final value in values.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 190,
                        child: Text(
                          value.key,
                          style: const TextStyle(
                            color: ByteColor.secondsaryText,
                          ),
                        ),
                      ),
                      Expanded(child: SelectableText(value.value)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppPanel(
          title: 'Discovered serial devices',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (app.scanner.error != null)
                Text(
                  app.scanner.error!,
                  style: const TextStyle(color: ByteColor.warning),
                ),
              if (app.scanner.devices.isEmpty)
                const Text(
                  'No serial ports detected. Check the board connection and USB data cable.',
                ),
              for (final port in app.scanner.devices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.usb),
                  title: Text(port.path),
                  subtitle: Text(port.label),
                  trailing: TextButton(
                    onPressed: app.busy || app.serial.isConnecting
                        ? null
                        : () => uiAction(context, () => app.connect(port.path)),
                    child: const Text('Connect'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const AppPanel(
          title: 'Troubleshooting',
          child: SelectableText(
            'Permission denied: check access to the serial device and your Linux serial-device group (often dialout or uucp). Group changes require signing out and back in.\n\n'
            'Port busy: close other serial monitors. ByteLab releases its own monitor before flashing.\n\n'
            'No response to STATUS?: this command requires compatible firmware; ordinary serial output still works.\n\n'
            'Build failure: inspect the Build output and verify that the configured ESP-IDF installation supports your project and target.',
          ),
        ),
      ],
    );
  }
}

class ProtocolPage extends StatefulWidget {
  const ProtocolPage({super.key});
  @override
  State<ProtocolPage> createState() => _ProtocolPageState();
}

class _ProtocolPageState extends State<ProtocolPage> {
  final payload = TextEditingController();
  final sample = TextEditingController(
    text: 'I (1200) telemetry: ram=84.5,temp=28.2',
  );
  bool hex = false;
  @override
  void dispose() {
    payload.dispose();
    sample.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final entry = SerialLogEntry.parse(sample.text);
    final telemetry = TelemetrySample.tryParse(entry);
    final device = DeviceInfo.tryParse(entry);
    return ListView(
      padding: const EdgeInsets.all(26),
      children: [
        const PageTitle(
          'Protocol',
          'Send commands or raw bytes, and inspect the telemetry parser.',
        ),
        const AppPanel(child: ConnectionControls()),
        const SizedBox(height: 20),
        AppPanel(
          title: 'Send to board',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Text')),
                  ButtonSegment(value: true, label: Text('Hex bytes')),
                ],
                selected: {hex},
                onSelectionChanged: (values) =>
                    setState(() => hex = values.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: payload,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: hex
                      ? 'Bytes, e.g. 50 49 4E 47 0A'
                      : 'Command, e.g. PING',
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: app.serial.isConnected
                        ? () => uiAction(
                            context,
                            () => hex
                                ? app.sendHex(payload.text)
                                : app.send(payload.text),
                            success: 'Sent to board',
                          )
                        : null,
                    icon: const Icon(Icons.send, size: 17),
                    label: const Text('Send payload'),
                  ),
                  for (final command in ['STATUS?', 'PING', 'HELP'])
                    OutlinedButton(
                      onPressed: app.serial.isConnected
                          ? () => uiAction(
                              context,
                              () => app.send(command),
                              success: 'Sent $command',
                            )
                          : null,
                      child: Text(command),
                    ),
                  TextButton(
                    onPressed: () => app.navigate(4),
                    child: const Text('View responses in Monitor'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                hex
                    ? 'Hex sends exactly the entered bytes.'
                    : 'Text commands use the ${app.settings.lineEnding} line ending.',
                style: const TextStyle(color: ByteColor.secondsaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppPanel(
          title: 'Parser preview',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: sample,
                minLines: 1,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'ESP-IDF log line',
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              SelectableText(
                'Level: ${entry.level.name}\nTag: ${entry.tag ?? 'unstructured'}\nMessage: ${entry.message ?? ''}\n'
                'Telemetry: ${telemetry?.values ?? {}}\nFirmware: ${device?.firmwareVersion ?? '—'}\nESP-IDF: ${device?.idfVersion ?? '—'}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
