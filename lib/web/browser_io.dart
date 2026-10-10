import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'browser_workspace.dart';

const storageKey = 'bytelab.web.workspace.v1';
String? readSnapshot() => web.window.localStorage.getItem(storageKey);
void writeSnapshot(String json) =>
    web.window.localStorage.setItem(storageKey, json);

Future<BrowserWorkspace?> importFolder() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = true;
  input.setAttribute('webkitdirectory', '');
  input.style.display = 'none';
  web.document.body!.appendChild(input);
  final result = Completer<BrowserWorkspace?>();
  late final JSFunction changed, cancelled;
  void cleanup() {
    input.removeEventListener('change', changed);
    input.removeEventListener('cancel', cancelled);
    input.remove();
  }

  changed = ((web.Event event) {
    unawaited(() async {
      try {
        final selected = input.files;
        if (selected == null || selected.length == 0) {
          result.complete(null);
          return;
        }
        final files = <String, Uint8List>{};
        String? name;
        var size = 0;
        for (var i = 0; i < selected.length; i++) {
          final file = selected.item(i)!;
          final fullPath = file.webkitRelativePath;
          final split = fullPath.indexOf('/');
          if (split < 1) {
            throw const FormatException(
              'Choose a project folder, not individual files',
            );
          }
          name ??= fullPath.substring(0, split);
          if (!fullPath.startsWith('$name/')) {
            throw const FormatException('Choose one project folder');
          }
          final path = fullPath.substring(split + 1);
          if (!BrowserWorkspace.validPath(path)) {
            throw const FormatException('Invalid project path');
          }
          if (!BrowserWorkspace.includePath(path)) continue;
          size += file.size;
          if (size > BrowserWorkspace.maxBytes ||
              files.length >= BrowserWorkspace.maxFiles) {
            throw const FormatException(
              'Project exceeds 1,000 files or 16 MiB. Choose a smaller source folder.',
            );
          }
          files[path] = (await file.arrayBuffer().toDart).toDart.asUint8List();
        }
        result.complete(BrowserWorkspace(name!, files));
      } catch (e, stack) {
        result.completeError(e, stack);
      } finally {
        cleanup();
      }
    }());
  }).toJS;
  cancelled = ((web.Event event) {
    cleanup();
    result.complete(null);
  }).toJS;
  input.addEventListener('change', changed);
  input.addEventListener('cancel', cancelled);
  input.click();
  return result.future;
}

void download(
  String name,
  Uint8List bytes, {
  String type = 'application/octet-stream',
}) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: type));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.appendChild(link);
  link.click();
  link.remove();
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}

void openDocs(String url) {
  final uri = Uri.parse(url);
  if (uri.scheme != 'https' ||
      !{
        'docs.espressif.com',
        'code.visualstudio.com',
        'docs.arduino.cc',
        'neovim.io',
        'lazy.folke.io',
        'cmake.org',
        'ninja-build.org',
      }.contains(uri.host)) {
    throw const FormatException('Unsupported documentation URL');
  }
  web.window.open(url, '_blank', 'noopener,noreferrer');
}

/// Browser-level close protection supplements the app's file-switch prompt.
class BrowserExitGuard {
  BrowserExitGuard(bool Function() needsWarning) {
    listener = ((web.Event event) {
      if (!needsWarning()) return;
      event.preventDefault();
      (event as web.BeforeUnloadEvent).returnValue = '';
    }).toJS;
    web.window.addEventListener('beforeunload', listener);
  }
  late final JSFunction listener;
  void dispose() => web.window.removeEventListener('beforeunload', listener);
}
