# ByteLab

<img src="assets/branding/bytelab-icon.png" alt="ByteLab cyan microchip logo" width="80" height="80">

ByteLab is a Flutter workspace for ESP-IDF firmware development, available as a **Linux desktop app** and a **browser app**. Edit source, browse official documentation matched to your project, and monitor serial logs and telemetry. The desktop app also runs your installed ESP-IDF toolchain to build and flash firmware.

**[Open ByteLab Web](https://bytelab-web.vercel.app)** · [Run on Linux](#run-on-linux) · [Editor setup](#editor-choice-and-in-app-manual) · [Development](#development)

## Desktop and web

| Capability | Linux desktop | Browser |
| --- | --- | --- |
| Source editing | Local project files, syntax highlighting, line numbers, Ctrl+S | Imported project copy, same highlighted editor, Ctrl+S, ZIP export |
| Editor choices | Built-in, embedded Neovim, external VS Code or Arduino IDE | Built-in |
| Vim motions and plugins | Your installed Neovim and its configuration | Not available |
| Documentation | Detects project metadata and selected local SDK | Detects imported project metadata |
| Serial monitor | Native serial ports, logs, commands, telemetry and charts | Web Serial in a supporting browser, logs, commands and telemetry values |
| Build and flash | Uses your installed ESP-IDF toolchain | Export the project and build/flash locally |
| Appearance | Underlight theme and adjustable Linux window opacity | Underlight theme and responsive layout |
| User manual | Bundled desktop workflow guide | Bundled browser workflow guide |

The editions currently use different layouts and navigation, with shared editor, documentation, starter-template, and serial-parsing code. The web app has no local helper or remote build service. Its imported files and drafts stay in the visitor's browser; they are not uploaded to Vercel.

Ubuntu is **not required by the app**. The desktop build has been validated on Ubuntu x86-64 and needs compatible Linux system libraries. Windows and macOS native support is not validated; Windows still needs platform-specific work described [below](#current-windows-limitations). Android and iOS runner folders and icons do not imply supported mobile apps. The browser edition provides access from other operating systems, subject to browser capabilities such as Web Serial.

## Underlight theme and branding

The app uses the **Underlight** palette adapted from the project's original dotfiles setup: Tokyo Night backgrounds and foregrounds, blue/violet controls, and cyan/pink panel accents. Editors, syntax highlighting, serial logs, and telemetry charts share the palette. Ubuntu Sans and Ubuntu Sans Mono are preferred when installed, with Noto and system font fallbacks. The theme is included in ByteLab; users do not need those dotfiles.

ByteLab's cyan microchip mark replaces the default Flutter branding in the app headers, web favicon, loading screen, installed web-app icons, and native launcher assets. Linux bundles include the window icon. Native icon assets are also provided for Windows, macOS, Android, and iOS; those builds still need validation.

The shared vector source is [`assets/branding/bytelab-icon.svg`](assets/branding/bytelab-icon.svg), with an opaque Underlight background. The full mark fits inside the maskable icon safe area. Web icons use branded filenames to avoid cached Flutter placeholders.

To regenerate the icons after editing the SVG, use Node.js with Puppeteer and Chromium installed:

```sh
node tool/generate_brand_icons.cjs
```

`BYTELAB_PUPPETEER_MODULE` and `BYTELAB_CHROME_PATH` can point to existing installations. Generated icons are included with the app; normal Flutter builds do not need Puppeteer. Rebuild the app after regeneration to include the updated assets.

## Browser edition

Live app: [bytelab-web.vercel.app](https://bytelab-web.vercel.app).

Choose **Import folder** for an existing ESP-IDF project or **Create starter** to begin. Edit files in **Project**, use **Documentation** for the manual and detected references, and download a project ZIP to keep a portable copy. Building, flashing, and opening your installed editors require the desktop workflow.

Build and preview locally:

```sh
flutter pub get
flutter build web
python3 -m http.server 8080 --bind 127.0.0.1 --directory build/web
```

Open `http://localhost:8080`. Serve the entire `build/web/` directory over HTTP(S); opening `index.html` as a local file is not supported. Use HTTPS for public hosting. CanvasKit is served from the deployment itself.

The browser edition includes the Underlight theme, highlighted source editor with line numbers and Ctrl+S, folder import, new files, starter generation, ZIP export, recoverable browser drafts, an in-app manual, detected toolchain references, serial logs, command sending, and telemetry values. The browser uses shared editor, documentation, template, and serial-parsing code; conditional imports keep native FFI dependencies out of the web build.

| Feature | Browser behavior |
| --- | --- |
| Project files | Imports an **independent copy** of an ESP-IDF folder. Original local files are never overwritten. Save updates the browser copy; Download project ZIP saves the current draft and exports source. |
| Limits | Up to 1,000 files / 16 MiB per project; UTF-8 editing up to 2 MiB per file. Binary files are retained in ZIP exports. `.git`, dependency folders, backups, and generated build files are omitted, except `build/project_description.json` for detection. |
| Persistence | Settings, source, and the active draft are stored for this site in browser local storage. Quota/private-mode failures display an in-memory warning. Download a ZIP regularly; clearing site data removes recovery. Extract a ZIP before reimporting its folder. |
| Serial | [Web Serial](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API) in supporting browsers such as Chrome/Edge, on HTTPS or localhost. Permission is requested by Choose serial device. Select the device again after reload. Physical board behavior still needs hardware validation. |
| Documentation | Detects chip/version from imported metadata; cannot inspect the host SDK or `IDF_PATH`. Explicit fallback and chip/version overrides are available. |
| Build / flash | Download and extract the project, then build/flash in ByteLab desktop or an activated ESP-IDF terminal. Disconnect the browser monitor before uploading externally. |
| Native editors / opacity | Neovim/plugins, VS Code and Arduino IDE launching, and native transparency remain desktop features. No local helper or build server is included. |

The in-app **Documentation → User manual · browser edition** explains the full workflow. Core editing and the bundled manual work without external references once the app is loaded; offline installation/reloading is not currently promised.

Browser validation:

```sh
flutter test test/browser_workspace_test.dart
flutter test --platform chrome test/browser/browser_app_test.dart
```

### Deploy to Vercel

The deployment uses the [Vercel Build Output API](https://vercel.com/docs/build-output-api), so Vercel does not need to install Flutter or receive the native build folders. With Flutter, Python 3, and the Vercel CLI installed and authenticated, link your own project once:

```sh
vercel link
```

Then build and deploy:

```sh
flutter build web
python3 tool/prepare_vercel.py
vercel deploy --prebuilt --prod
```

The packaging step replaces generated `.vercel/output/static/` assets and preserves the local project link. Only the compiled browser bundle is published. Vercel serves it over HTTPS with same-origin serial permission and revalidated assets to avoid stale app versions. Project imports and browser snapshots remain on the visitor’s computer.

The public deployment uses the `bytelab-web` project. Its current deployment workflow is manual; pushing to Git does not publish an update. `.vercel/` and `.env*` are ignored by Git and should remain local.

## Run on Linux

From source, install the [development prerequisites](#development), then run:

```sh
flutter pub get
flutter run -d linux
```

For a release build:

```sh
flutter build linux --release
./build/linux/x64/release/bundle/bytelab
```

### Packaged release

If you have a `ByteLab-linux-x64.tar.gz` archive, extract the entire archive, open the extracted folder, and run `./bytelab`. Keep the `lib/` and `data/` folders beside the executable. You do not need Flutter to run the bundle. Build from source for the current workspace changes; an existing archive is not automatically refreshed when the source changes.

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
- **Desktop integration:** documentation links use the platform browser launcher; automatic settings/toolchain discovery still uses Linux conventions. The launch command above only addresses the settings location.
- **Tests:** several process tests use `/tmp`, `/bin/bash`, and `/usr/bin/printf`; the current test suite has not been validated on Windows.

## Desktop workflow

1. **Project:** open an ESP-IDF folder containing `CMakeLists.txt`, or create a starter project. The file browser supports new files/folders. Neovim saves with `:w` or `:wa`; the built-in UTF-8 editor supports files up to 2 MiB and saves with Ctrl+S.
2. **Configuration:** edit `sdkconfig` (active configuration) or `sdkconfig.defaults` (defaults used when generating configuration). Save and reconfigure.
3. **Build:** build, reconfigure, inspect image size, or clean generated build output. Commands run in the open project; output and cancellation are available.
4. **Flash:** choose the correct serial device and upload. Flashing replaces that board's firmware. ByteLab releases its monitor and reconnects it after the command finishes.
5. **Monitor:** view/search/filter logs, send commands, and copy or export output. The console is also available as a dock.
6. **Overview / Diagnostics:** inspect actual reported metrics, device versions, port enumeration, and toolchain state.
7. **Protocol:** send text with your chosen line ending, send exact hex bytes, or preview structured log parsing.
8. **Documentation:** searchable official references matched to the project chip and SDK, plus local examples with syntax highlighting, line numbers, and copy controls. Detection reads `sdkconfig`, `sdkconfig.defaults`, last-build metadata, and the selected SDK (or `IDF_PATH`). Selected SDK metadata takes precedence over last-build versions; missing values fall back visibly to stable ESP32 docs. CMake, Ninja, and component-manager references appear when their metadata is present. Refresh detection after external changes; documentation chip/version overrides never modify project configuration. Full references open in your browser and require internet access.
9. **Settings:** persistent SDK/serial preferences.

The source and configuration editors highlight C/C++, CMake, configuration, JSON, YAML, and shell files. A scrolling line-number gutter, horizontal scrolling, and cursor position help navigate code; other files remain plain text.

The starter project uses ESP32 by default. For another chip, run `idf.py set-target <chip>` in an activated ESP-IDF terminal inside that project before building. Existing projects keep their configured chip target.

The SDK path is sourced as a shell script under your user account. Choose a trusted ESP-IDF installation.

## Keyboard shortcuts

| Context | Keys | Action |
| --- | --- | --- |
| Built-in source/configuration editor | `Ctrl+S` | Save the focused editor; in the browser, save the imported copy |
| Built-in editor | Standard platform text-editing shortcuts | Select, copy, paste, undo and redo |
| Embedded Neovim | `Esc`, `h j k l`, `i`, `/text`, `:w` | Modes, motions, search and save; see [Neovim editing and plugins](#neovim-editing-and-plugins) |
| External editor | That editor's configured shortcuts | Handled by VS Code or Arduino IDE |

ByteLab does not currently define global shortcuts for every page or firmware command. Ctrl+S is a built-in-editor binding; Neovim uses its own mappings and save commands. The bundled manual explains these controls in the app.

## Desktop files and persistence

Settings are saved to `$XDG_CONFIG_HOME/bytelab/settings.json` or `~/.config/bytelab/settings.json`. `BYTELAB_CONFIG_DIR` overrides the directory. The last project/port are restored; connections are opened explicitly.

Before saving, the built-in editor checks that the file has not changed externally and keeps a previous copy in the project's `.bytelab-backups/`. Save or reload unsaved edits before switching projects or running firmware commands. Closing the app prompts if files are dirty or a command is running.

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
flutter test --platform chrome test/browser/browser_app_test.dart
flutter build linux --release
flutter build web
```

Browser tests require Chrome/Chromium; set `CHROME_EXECUTABLE` if Flutter cannot locate it. The real-Neovim integration test is opt-in and requires an installed `nvim`:

```sh
BYTELAB_TEST_NEOVIM=1 flutter test test/neovim_test.dart
```

The runnable Linux bundle is `build/linux/x64/release/bundle/`; the web output is `build/web/`. Package or serve each whole directory. The embedded terminal uses `xterm` and `flutter_pty`; editor executables are installed separately.

The platform entry point is `lib/main.dart`, which selects `lib/app/desktop_app.dart` or `lib/web/web_app.dart`. Shared UI components live in `lib/widgets/`, and documentation detection and serial services live in `lib/service/`. The icon generator and Vercel packaging script live in `tool/`.

Tests cover project persistence and path boundaries, external-edit conflicts, serial framing/UTF-8/status/lifecycle, Ninja progress, command cancellation, literal shell arguments, navigation and serial controls. Firmware starter compilation is additionally checked with the local ESP-IDF installation. Physical flashing and board-specific sensor behavior require real hardware.

Official setup: [ESP-IDF getting started](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/get-started/).

## Editor choice and in-app manual

Open **Documentation → User manual → How to use ByteLab** for the bundled, offline manual. It covers first-time setup, every editor option, shortcuts, plugins, build/flash/monitor workflows, detected documentation, compatibility, transparency, and troubleshooting. Settings and editor panels link to it.

Choose **Settings → Editor and plugins → Preferred editor**, then **Save settings**:

| Editor | Where it runs | Requirement |
| --- | --- | --- |
| Built-in (default) | Inside ByteLab | No separate editor; syntax highlighting, line numbers, Ctrl+S |
| Neovim | Embedded terminal | Neovim 0.9+ on PATH; your own config/plugins |
| VS Code | Separate window | Installed `code` or `code-insiders`, or an executable override |
| Arduino IDE | Separate window | Installed `arduino-ide` or `arduino`, or an executable/AppImage override |

External executable paths are stored separately for VS Code and Arduino IDE. Enter a path without quotes or arguments, use **Browse executable**, or leave it empty for PATH detection. **Check executable** verifies location/execute permission; **Save and launch editor** opens it. Installed applications retain their own settings, shortcuts, extensions, boards, and libraries. ByteLab does not install any of these for you.

For VS Code, select a file in Project and click **Open file**, or use **Open project in VS Code**. See the [official VS Code command-line guide](https://code.visualstudio.com/docs/configure/command-line).

For Arduino IDE, select an `.ino`/`.pde` file and click **Open sketch**, or **Launch Arduino IDE** and use its File → Open menu. Arduino expects a [sketch structure](https://docs.arduino.cc/arduino-cli/sketch-specification/); ordinary ESP-IDF CMake projects are not Arduino sketches. Choosing an editor does **not** change ByteLab’s ESP-IDF build/flash toolchain. Use Arduino IDE’s board selection, Verify, and Upload for sketches, and its library/board managers. Disconnect ByteLab’s monitor before uploading externally, then reconnect at the sketch’s baud rate.

Save files in external editors before ByteLab builds or flashes: ByteLab cannot detect their unsaved buffers. Reload open built-in/configuration editors after external changes. External windows remain independent of ByteLab.

## Neovim editing and plugins

ByteLab embeds **real Neovim** in the Project page using `xterm` and `flutter_pty`. Install Neovim 0.9 or newer separately and check `nvim --version` from the environment used to launch ByteLab. These Flutter packages are bundled with the app; Neovim, plugins, language servers, and any tools required by your plugins are not bundled.

1. In **Settings → Editor and plugins**, choose **Neovim** under **Preferred editor**, leave **Clean Neovim configuration** off, and save settings. The built-in editor is the default; a saved Neovim preference is retained.
2. Open a firmware project and select a file, or click **Start Neovim**. The session stays alive when you navigate to other ByteLab pages.
3. Your normal configuration and plugin setup load. `NVIM_APPNAME`, `XDG_CONFIG_HOME`, and the rest of the launch environment are inherited. Use `:echo stdpath("config")` to find the active configuration folder.
4. **Plugins** opens `:Lazy` or `:PackerStatus` if available. Configure/install plugins with your existing manager; ByteLab does not install them or edit your dotfiles.
5. Use `:w` to save the current buffer, `:wa` or **Save all** for all buffers, and `:qa` to exit. To return to ByteLab’s original editor, save your changes, choose **Built-in** under **Preferred editor**, and save settings.

| Keys | Default Neovim action |
| --- | --- |
| `Esc`, `i`, `a` | Normal mode; insert before or after cursor |
| `h j k l` | Left, down, up, right |
| `w b e`, `0 ^ $`, `gg G` | Word motions; line motions; first/last line |
| `5j`, `3w` | Counted motions |
| `v`, `V` | Character or line selection |
| `dd`, `yy`, `p`, `ciw`, `dw` | Delete/yank/paste; change inner word; delete word |
| `u`, `Ctrl+R` | Undo, redo |
| `/text`, `n`, `N` | Search, next/previous match |
| `:w`, `:wa`, `:q`, `:qa` | Save current/all; quit window/all |
| `:qa!` | Discard all unsaved buffers and quit |
| `:Tutor`, `:help` | Interactive tutorial and built-in reference |

Your config may remap these keys. ByteLab passes editor keys through to Neovim, including Ctrl combinations; **Ctrl+S remains a built-in-editor shortcut**, not a Neovim save binding. Use `:set number relativenumber` to enable line numbers or configure those options in Neovim. See the [official quick reference](https://neovim.io/doc/user/quickref/) and [startup/configuration guide](https://neovim.io/doc/user/starting/).

Neovim writes files itself, using your Neovim backup and undo configuration. ByteLab’s `.bytelab-backups` is only used by the built-in editor. Before firmware operations or project/editor changes, ByteLab checks every Neovim buffer for unsaved changes; it blocks the operation when the editor state cannot be read. Terminal input is disabled during firmware operations. **Configuration → Edit in Neovim** opens the configuration file in Project; reload the configuration editor afterward to see disk changes. Other Neovim/plugin processes can still modify files independently.

If Neovim is missing, use **Editor settings** to choose the built-in editor. For plugin errors or a startup prompt, respond in Neovim or use **Stop Neovim**, then enable **Clean Neovim configuration**, save settings, and start again. Clean mode skips your config and third-party plugins. Unknown/unsaved buffers require confirmation before stopping. After an unexpected exit, restart and follow Neovim’s [swap recovery instructions](https://neovim.io/doc/user/recover/). Plugin-specific commands and mappings remain documented by your plugin manager, such as [lazy.nvim](https://lazy.folke.io/usage).

## Underlight transparency

**Settings → Underlight transparency** adjusts the native Linux window opacity between 70% and 100%; save settings to apply it. The default is 94%, and 100% restores full opacity. This affects the whole window, including text and the embedded terminal. It uses GTK directly, without an extra transparency package.

Desktop blur and additional opacity rules belong to your compositor. Underlight/Hyprland rules may combine with ByteLab’s setting; use 100% in ByteLab if you want the compositor to control opacity alone. On unsupported platforms the opacity control is disabled and the window keeps its normal appearance. The new editor/transparency integration is validated on Linux; Windows/macOS still need native build and runtime validation.
