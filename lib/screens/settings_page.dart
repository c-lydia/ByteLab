import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../core/byte_color.dart';
import '../widgets/app_controls.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final sdk = TextEditingController();
  final baud = TextEditingController();
  final flashBaud = TextEditingController();
  String ending = 'LF';
  bool initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      final settings = AppScope.of(context).settings;
      sdk.text = settings.exportScript;
      baud.text = '${settings.baudRate}';
      flashBaud.text = '${settings.flashBaudRate}';
      ending = settings.lineEnding;
      initialized = true;
    }
  }

  @override
  void dispose() {
    sdk.dispose();
    baud.dispose();
    flashBaud.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = AppScope.of(context);
    final rate = int.tryParse(baud.text), upload = int.tryParse(flashBaud.text);
    if (rate == null || upload == null) {
      throw const FormatException('Baud rates must be whole numbers');
    }
    await app.saveSettings(
      app.settings.copyWith(
        exportScript: sdk.text.trim(),
        baudRate: rate,
        flashBaudRate: upload,
        lineEnding: ending,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(26),
      children: [
        const PageTitle(
          'Settings',
          'Toolchain and serial preferences are saved on this computer.',
        ),
        AppPanel(
          title: 'ESP-IDF toolchain',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: sdk,
                      decoration: const InputDecoration(
                        labelText: 'Path to ESP-IDF export.sh',
                        hintText: '/home/you/esp/esp-idf/export.sh',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () async {
                      final path = await choosePath(
                        context,
                        title: 'Choose ESP-IDF export.sh',
                        initial: sdk.text,
                        file: true,
                      );
                      if (path != null && mounted) {
                        setState(() => sdk.text = path);
                      }
                    },
                    child: const Text('Browse'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'ByteLab sources this script before running idf.py. Leave it empty if ESP-IDF is already on the launch environment’s PATH.',
                style: TextStyle(color: ByteColor.secondsaryText),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: app.busy
                    ? null
                    : () => uiAction(context, () async {
                        await _save();
                        app.navigate(2);
                        await app.checkToolchain();
                      }),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Save and check toolchain'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppPanel(
          title: 'Serial communication',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: baud,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monitor baud rate',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: flashBaud,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Flash baud rate',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: ending,
                      decoration: const InputDecoration(
                        labelText: 'Command line ending',
                      ),
                      items: ['LF', 'CRLF', 'None']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => ending = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Monitor baud changes take effect on the next connection. Hex sends always use the exact bytes you enter.',
                style: TextStyle(color: ByteColor.secondsaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: app.busy || app.serial.isConnecting
                ? null
                : () => uiAction(context, _save, success: 'Settings saved'),
            icon: const Icon(Icons.save),
            label: const Text('Save settings'),
          ),
        ),
        const SizedBox(height: 18),
        SelectableText(
          'Settings file: ${app.store.file.path}',
          style: const TextStyle(fontSize: 12, color: ByteColor.secondsaryText),
        ),
      ],
    );
  }
}
