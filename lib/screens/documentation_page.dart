import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/app_controller.dart';
import '../core/byte_color.dart';
import '../service/documentation_service.dart';
import '../widgets/app_controls.dart';
import '../widgets/code_block.dart';
import '../widgets/user_manual.dart';

class DocumentationPage extends StatefulWidget {
  const DocumentationPage({super.key, this.service, this.openUrl});
  final DocumentationService? service;
  final Future<void> Function(String)? openUrl;
  @override
  State<DocumentationPage> createState() => _DocumentationPageState();
}

class _DocumentationPageState extends State<DocumentationPage> {
  final search = TextEditingController();
  Future<ToolchainDocs>? detection;
  Object? inputs;
  String? targetOverride, versionOverride;
  String category = 'All';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    final next = (
      app.project.root,
      app.settings.exportScript,
      app.selectedPage == 8,
      app.jobs.status.state,
    );
    if (inputs != next) {
      final previous = inputs;
      inputs = next;
      // Refresh on entry, project/SDK changes, and completed firmware operations.
      if (app.selectedPage == 8 || previous == null) _detect(app);
    }
  }

  void _detect(AppController app) {
    detection = (widget.service ?? DocumentationService()).detect(
      projectPath: app.project.root,
      exportScript: app.settings.exportScript,
    );
  }

  Future<void> _open(String url) => uiAction(
    context,
    () => (widget.openUrl ?? DocumentationService.openUrl)(url),
  );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(26),
      children: [
        PageTitle(
          'Documentation',
          'Offline user manual and official references for your firmware workspace.',
          actions: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _detect(app)),
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Refresh detection'),
            ),
          ],
        ),
        const UserManual(),
        const SizedBox(height: 20),
        FutureBuilder<ToolchainDocs>(
          future: detection,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const AppPanel(
                child: Text(
                  'Could not inspect toolchain metadata. Refresh to try again.',
                ),
              );
            }
            final detected = snapshot.data ?? const ToolchainDocs();
            final target = targetOverride ?? detected.target ?? 'esp32';
            final version = versionOverride ?? detected.docsVersion;
            final resources = DocumentationService.resources(
              detected,
              targetOverride: targetOverride,
              versionOverride: versionOverride,
            );
            final categories = [
              'All',
              ...resources.map((doc) => doc.category).toSet(),
            ];
            final effectiveCategory = categories.contains(category)
                ? category
                : 'All';
            final visible = resources
                .where(
                  (doc) =>
                      doc.matches(search.text.trim()) &&
                      (effectiveCategory == 'All' ||
                          doc.category == effectiveCategory),
                )
                .toList();
            final targets = {
              'esp32',
              'esp32s2',
              'esp32s3',
              'esp32c2',
              'esp32c3',
              'esp32c5',
              'esp32c6',
              'esp32h2',
              'esp32p4',
              ?detected.target,
              ?targetOverride,
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPanel(
                  title: 'Your toolchain',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          const Chip(
                            avatar: Icon(Icons.memory, size: 17),
                            label: Text('ESP-IDF workspace'),
                          ),
                          Chip(label: Text(target.toUpperCase())),
                          Chip(label: Text('Docs: $version')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        detected.target == null
                            ? 'Chip not detected. Showing ESP32 as a browsing default.'
                            : 'Chip: ${detected.target} · ${detected.targetSource}',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        detected.version == null
                            ? 'SDK version not detected. Showing stable documentation.'
                            : 'SDK: ${detected.version} · ${detected.versionSource}',
                      ),
                      if (!app.hasProject)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Open a project to detect its chip and build tools.',
                          ),
                        ),
                      for (final note in detected.notes)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            note,
                            style: const TextStyle(color: ByteColor.warning),
                          ),
                        ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              key: ValueKey(
                                'target-$targetOverride-${detected.target}',
                              ),
                              initialValue: targetOverride ?? 'auto',
                              decoration: const InputDecoration(
                                labelText: 'Documentation chip',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 'auto',
                                  child: Text('Auto-detect'),
                                ),
                                for (final chip in targets)
                                  DropdownMenuItem(
                                    value: chip,
                                    child: Text(chip.toUpperCase()),
                                  ),
                              ],
                              onChanged: (value) => setState(
                                () => targetOverride = value == 'auto'
                                    ? null
                                    : value,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: 'auto',
                              decoration: const InputDecoration(
                                labelText: 'Documentation version',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'auto',
                                  child: Text('Auto-detect'),
                                ),
                                DropdownMenuItem(
                                  value: 'stable',
                                  child: Text('Stable release'),
                                ),
                                DropdownMenuItem(
                                  value: 'latest',
                                  child: Text('Latest development'),
                                ),
                              ],
                              onChanged: (value) => setState(
                                () => versionOverride = value == 'auto'
                                    ? null
                                    : value,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'These choices only change documentation links. Development SDKs use their release-series docs. If a version or chip page is unavailable, try Stable release or the guide’s version selector.',
                        style: TextStyle(
                          color: ByteColor.secondsaryText,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search references, APIs, build tools…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(search.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in categories)
                      ChoiceChip(
                        label: Text(value),
                        selected: effectiveCategory == value,
                        onSelected: (_) => setState(() => category = value),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Full references open on the publisher’s website. Links and local examples remain available offline.',
                  style: TextStyle(color: ByteColor.secondsaryText),
                ),
                const SizedBox(height: 16),
                if (visible.isEmpty)
                  const AppPanel(
                    child: Text(
                      'No matching references. Try another search or category.',
                    ),
                  ),
                for (final doc in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.category.toUpperCase(),
                            style: const TextStyle(
                              color: ByteColor.cyan,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            doc.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            doc.description,
                            style: const TextStyle(
                              color: ByteColor.secondsaryText,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            doc.url,
                            style: const TextStyle(
                              fontSize: 12,
                              color: ByteColor.mutedText,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => _open(doc.url),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Read official docs'),
                              ),
                              TextButton.icon(
                                onPressed: () => uiAction(
                                  context,
                                  () => Clipboard.setData(
                                    ClipboardData(text: doc.url),
                                  ),
                                  success: 'Link copied',
                                ),
                                icon: const Icon(Icons.link, size: 16),
                                label: const Text('Copy link'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'ByteLab quick start',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Local examples · run commands in an activated ESP-IDF terminal.',
          style: TextStyle(color: ByteColor.secondsaryText),
        ),
        const SizedBox(height: 16),
        const AppPanel(
          title: 'Build, configure, and flash',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select export.sh in Settings, then open or create a project. Save your edits before building. Replace the example serial port with your board’s port.',
              ),
              SizedBox(height: 14),
              CodeBlock(
                language: 'bash',
                title: 'Terminal · project directory',
                code:
                    '# Check the activated SDK\nidf.py --version\n\n# Build and inspect firmware size\nidf.py build\nidf.py size\n\n# Flash your board\nidf.py -p /dev/ttyUSB0 flash',
              ),
              SizedBox(height: 14),
              Text(
                'Edit sdkconfig or sdkconfig.defaults in Configuration and run Reconfigure. For a different chip, use idf.py set-target <chip>; this regenerates configuration and clears the build directory.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const AppPanel(
          title: 'Register a firmware component',
          child: CodeBlock(
            language: 'cmake',
            title: 'main/CMakeLists.txt',
            code:
                'idf_component_register(\n    SRCS "main.c"\n    INCLUDE_DIRS "."\n    REQUIRES esp_system heap\n)',
          ),
        ),
        const SizedBox(height: 16),
        const AppPanel(
          title: 'Send telemetry to ByteLab',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'This example reports free heap in KiB every second. Monitor accepts any UTF-8 output; structured numeric telemetry also appears in charts.',
              ),
              SizedBox(height: 14),
              CodeBlock(
                language: 'c',
                title: 'main/main.c',
                code:
                    '#include <stdbool.h>\n#include "freertos/FreeRTOS.h"\n#include "freertos/task.h"\n#include "esp_log.h"\n#include "esp_system.h"\n\nvoid app_main(void)\n{\n    while (true) {\n        float free_kib = esp_get_free_heap_size() / 1024.0f;\n        ESP_LOGI("telemetry", "ram=%.1f", free_kib);\n        vTaskDelay(pdMS_TO_TICKS(1000));\n    }\n}',
              ),
              SizedBox(height: 14),
              Text(
                'The generated ByteLab starter also handles STATUS?, PING, and HELP. These commands require compatible firmware. Protocol can send text or raw hex bytes and preview the parser.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const AppPanel(
          title: 'Files, logs, and recovery',
          child: Text(
            'Ctrl+S saves the built-in editor; Neovim uses :w or :wa. The built-in editor checks for external edits and keeps previous file versions in .bytelab-backups. Serial history retains 5,000 lines and command output retains 10,000; export logs to keep them. If flashing fails because a port is busy, close other serial monitors. ByteLab releases its own monitor before flashing and reconnects afterward.',
            style: TextStyle(height: 1.6),
          ),
        ),
      ],
    );
  }
}
