# ByteLab

ByteLab is a Linux desktop workspace for ESP-IDF firmware development, built with Flutter. It opens and edits projects, runs the installed ESP-IDF toolchain, flashes a selected board, and monitors serial output and telemetry.

## Run the Linux release

Extract the entire `ByteLab-linux-x64.tar.gz` archive, open the extracted folder, and run `./bytelab`. Keep the `lib/` and `data/` folders beside the executable. You do not need Flutter to run the bundle.

The release is built for x86-64 Linux on this Ubuntu system. It requires compatible system GTK 3, GLib, C++ runtime, and OpenGL libraries. It is not a Windows/macOS binary. Run `ldd ./bytelab` to diagnose missing system libraries.

ESP-IDF is needed for firmware commands; ordinary serial monitoring works independently. In **Settings**, select your ESP-IDF `export.sh`, then **Save and check toolchain**. If you launched ByteLab from an already activated ESP-IDF terminal, the script path can be empty.

## Build on Windows

ByteLab includes a Windows runner, but the app has only been built and tested on Linux so far. Run these steps in native Windows PowerShell on a Windows PC or VM; Flutter requires Windows to build the Windows desktop target. [Flutter platform requirements](https://docs.flutter.dev/platform-integration).

### Requirements

- Install the Windows Flutter SDK matching the version listed under [Development](#development), and add its `bin` directory to `PATH`.
- Install Visual Studio with the **Desktop development with C++** workload, including its default MSVC, Windows SDK, and CMake components.
- Enable Windows **Developer Mode** if Flutter reports that plugins require symlink support. Open the setting with `Start-Process 'ms-settings:developers'`.

Check the installation before building, and resolve any issues reported for Windows or Visual Studio. [Flutter Windows setup](https://docs.flutter.dev/platform-integration/windows/setup).

```powershell
flutter doctor -v
flutter devices
```

### Compile and launch

Copy the ByteLab **source project** to Windows, for example `C:\src\ByteLab\bytelab`. Keep `pubspec.yaml`, `pubspec.lock`, `lib/`, and `windows/`. The Linux release archive contains compiled Linux binaries; use the source folder for this build.

From that folder, regenerate local build files and dependencies:

```powershell
Set-Location C:\src\ByteLab\bytelab
flutter config --enable-windows-desktop
flutter clean
flutter pub get
flutter analyze
flutter build windows --release
```

For an x64 build, launch the resulting executable:

```powershell
$env:BYTELAB_CONFIG_DIR = Join-Path $env:APPDATA "ByteLab"
.\build\windows\x64\runner\Release\bytelab.exe
```

The environment variable directs ByteLab's settings to your Windows user profile for this launch.

To share the build, package the **whole Release folder**, including all DLLs and `data/`. Other computers also need the Visual C++ runtime described in [Flutter's Windows distribution guide](https://docs.flutter.dev/platform-integration/windows/building#building-your-own-zip-file-for-windows).

```powershell
Compress-Archive -Path .\build\windows\x64\runner\Release\* -DestinationPath .\ByteLab-windows-x64.zip
```

### Current Windows limitations

Compiling the executable does not establish full Windows support. These parts still need porting and testing:

- **Firmware commands:** the SDK launcher uses `/bin/bash` and `export.sh`. Windows ESP-IDF activation and child-process cancellation need platform-specific handling before build/flash workflows can be considered supported.
- **Project paths and backups:** new-project paths and nested-file backup names currently assume Unix-style separators, so Windows project creation and nested-file saves need fixes.
- **Desktop integration:** the documentation link uses `xdg-open`, and automatic settings/toolchain discovery uses Linux conventions. The launch command above only addresses the settings location.
- **Tests:** several process tests use `/tmp`, `/bin/bash`, and `/usr/bin/printf`; the current test suite has not been validated on Windows.

## Workflow

1. **Project:** open an ESP-IDF folder containing `CMakeLists.txt`, or create a starter project. The file browser supports new files/folders and editing UTF-8 files up to 2 MiB. Use Ctrl+S to save.
2. **Configuration:** edit `sdkconfig` (active configuration) or `sdkconfig.defaults` (defaults used when generating configuration). Save and reconfigure.
3. **Build:** build, reconfigure, inspect image size, or clean generated build output. Commands run in the open project; output and cancellation are available.
4. **Flash:** choose the correct serial device and upload. Flashing replaces that board's firmware. ByteLab releases its monitor and reconnects it after the command finishes.
5. **Monitor:** view/search/filter logs, send commands, and copy or export output. The console is also available as a dock.
6. **Overview / Diagnostics:** inspect actual reported metrics, device versions, port enumeration, and toolchain state.
7. **Protocol:** send text with your chosen line ending, send exact hex bytes, or preview structured log parsing.
8. **Documentation / Settings:** in-app setup instructions and persistent SDK/serial preferences.

The starter project uses ESP32 by default. For another chip, run `idf.py set-target <chip>` in an activated ESP-IDF terminal inside that project before building. Existing projects keep their configured chip target.

The SDK path is sourced as a shell script under your user account. Choose a trusted ESP-IDF installation.

## Files and persistence

Settings are saved to `$XDG_CONFIG_HOME/bytelab/settings.json` or `~/.config/bytelab/settings.json`. `BYTELAB_CONFIG_DIR` overrides the directory. The last project/port are restored; connections are opened explicitly.

Before saving, the editor checks that the file has not changed externally and keeps a previous copy in the project's `.bytelab-backups/`. Save or reload unsaved edits before switching projects or running firmware commands. Closing the app prompts if files are dirty or a command is running.

Serial history retains 5,000 lines and command history retains 10,000. Export to retain a session. Export refuses to overwrite an existing file.

## Board protocol

Plain UTF-8 output works with any serial firmware. The dashboard additionally understands ESP-IDF log lines:

```text
I (1200) telemetry: ram=84.5,temp=28.2,voltage=3.30
I (1200) device: idf=v6.0,fw=1.0.0
I (1200) status: ready
```

Numeric telemetry must be finite. Units: CPU percent; RAM/flash KiB; temperature °C; voltage V; current mA; RSSI dBm. Other numeric keys are displayed with their key as the label. Chart lines are scaled independently.

The starter implements `STATUS?`, `PING`, and `HELP`, and emits measured heap usage and flash capacity. Custom firmware must implement these commands itself. The app does not infer CPU load or sensor readings from an ordinary serial connection.

## Development

Use Flutter 3.44.5 / Dart 3.12.2 or a compatible SDK. Linux builds require clang, CMake, Ninja, pkg-config, GTK 3 development headers and a C++ toolchain.

```sh
flutter pub get
flutter analyze
flutter test
flutter build linux --release
```

The runnable bundle is `build/linux/x64/release/bundle/`. Package that whole folder, not just its executable. No extra Dart packages were added for the desktop workflows.

Tests cover project persistence and path boundaries, external-edit conflicts, serial framing/UTF-8/status/lifecycle, Ninja progress, command cancellation, literal shell arguments, navigation and serial controls. Firmware starter compilation is additionally checked with the local ESP-IDF installation. Physical flashing and board-specific sensor behavior require real hardware.

Official setup: [ESP-IDF getting started](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/get-started/).
