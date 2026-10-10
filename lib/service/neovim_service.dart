import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

/// One real Neovim process per workspace. ByteLab communicates over its private
/// local server socket; filenames and commands never pass through a shell.
class NeovimService {
  NeovimService({this.onChanged, this.environment});
  final Map<String, String>? environment;
  final void Function()? onChanged;
  Terminal terminal = Terminal(maxLines: 5000);
  Pty? _pty;
  StreamSubscription<String>? _output;
  Directory? _temporary;
  Timer? _poll;
  Future<void>? _starting;
  bool _checking = false;
  bool _closing = false;
  bool _disposed = false;
  bool modified = false;
  bool stateKnown = true;
  String? error, projectPath, currentFile;
  String _executable = 'nvim';
  String? _server;
  bool get running => _pty != null;
  bool get starting => _starting != null;
  bool get needsAttention => modified || (running && !stateKnown) || starting;

  static String? findExecutable({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final name = Platform.isWindows ? 'nvim.exe' : 'nvim';
    for (final dir in (env['PATH'] ?? '').split(
      Platform.isWindows ? ';' : ':',
    )) {
      if (dir.isEmpty) continue;
      final file = File('$dir${Platform.pathSeparator}$name');
      if (file.existsSync()) return file.absolute.path;
    }
    return null;
  }

  Future<void> start(String root, {bool clean = false}) async {
    if (_disposed) throw StateError('Editor has been disposed');
    if (_starting != null) return _starting;
    if (running) return;
    _starting = _start(root, clean: clean);
    onChanged?.call();
    try {
      await _starting;
    } finally {
      _starting = null;
      onChanged?.call();
    }
  }

  Future<void> _start(String root, {required bool clean}) async {
    try {
      _executable =
          findExecutable(environment: environment) ??
          (throw StateError(
            'Neovim was not found on PATH. Install Neovim 0.9 or newer, or choose the built-in editor in Settings.',
          ));
      if (_temporary != null) await close();
      projectPath = root;
      error = null;
      modified = false;
      stateKnown = false;
      _temporary = await Directory.systemTemp.createTemp('bl-nvim-');
      if (_disposed) {
        await close();
        throw StateError('Editor has been disposed');
      }
      _server = Platform.isWindows
          ? r'\\.\pipe\' +
                _temporary!.uri.pathSegments.where((s) => s.isNotEmpty).last
          : '${_temporary!.path}/rpc';
      terminal = Terminal(maxLines: 5000);
      final process = Pty.start(
        _executable,
        arguments: [if (clean) '--clean', '--listen', _server!],
        workingDirectory: root,
        environment: {
          ...(environment ?? Platform.environment),
          'TERM': 'xterm-256color',
          'COLORTERM': 'truecolor',
        },
      );
      _pty = process;
      terminal.onOutput = (data) {
        if (_pty == process) process.write(utf8.encode(data));
      };
      terminal.onResize = (width, height, _, _) {
        if (_pty == process && width > 0 && height > 0) {
          process.resize(height, width);
        }
      };
      _output = process.output
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(terminal.write);
      unawaited(
        process.exitCode.then((code) {
          if (_pty != process) return;
          _pty = null;
          _poll?.cancel();
          _poll = null;
          if (code == 0) {
            modified = false;
            stateKnown = true;
          }
          terminal.onOutput = null;
          terminal.onResize = null;
          if (!_closing && !_disposed) {
            error = code == 0
                ? 'Neovim closed. Start it again or select a file to continue.'
                : 'Neovim exited ($code). Restart to recover from any swap-file prompt.';
            onChanged?.call();
          }
        }),
      );
      // Plugin startup can take time. Keep its terminal visible during startup.
      onChanged?.call();
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (true) {
        if (_disposed || !running) {
          throw StateError('Neovim stopped during startup');
        }
        try {
          if (await evaluate('vim.v.vim_did_enter == 1') != true) {
            throw StateError('Neovim configuration is still loading');
          }
          await refreshModified();
          break;
        } catch (_) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError(
              'Neovim is not responding. Check the terminal for a plugin prompt, then select the file again, or Stop Neovim and choose clean mode in Settings.',
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
      error = null;
      _beginPolling();
    } catch (e) {
      if (running) _beginPolling();
      error = e.toString();
      onChanged?.call();
      rethrow;
    }
  }

  void _beginPolling() {
    _poll ??= Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_checking || _closing || !running) return;
      _checking = true;
      try {
        await refreshModified();
      } catch (_) {
        /* Keep the unknown-state guard. */
      } finally {
        _checking = false;
      }
    });
  }

  static String expression(String lua) =>
      'json_encode(luaeval(${jsonEncode(lua)}))';

  Future<Object?> evaluate(String lua) async {
    if (!running || _server == null) throw StateError('Neovim is not running');
    final process = await Process.start(
      _executable,
      [
        '--clean',
        '--headless',
        '--server',
        _server!,
        '--remote-expr',
        expression(lua),
      ],
      workingDirectory: _temporary!.path,
      environment: {
        ...(environment ?? Platform.environment),
        'NVIM_LOG_FILE': '${_temporary!.path}/client.log',
      },
    );
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.transform(utf8.decoder).join();
    try {
      final code = await process.exitCode.timeout(const Duration(seconds: 3));
      final output = await stdout;
      final errors = await stderr;
      if (code != 0) {
        throw StateError(
          errors.trim().isEmpty ? 'Neovim request failed' : errors.trim(),
        );
      }
      return jsonDecode(output.trim());
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
      await Future.wait([stdout, stderr]);
      throw StateError(
        'Neovim is busy or waiting for input. Return to its terminal and try again.',
      );
    }
  }

  Future<void> refreshModified() async {
    if (!running) return;
    final instance = _pty;
    try {
      final result = await evaluate(
        '#vim.tbl_filter(function(b) return vim.bo[b].modified end, vim.api.nvim_list_bufs())',
      );
      if (_pty != instance || _closing) return;
      if (result is! num) {
        throw StateError('Could not read Neovim buffer state');
      }
      final changed = modified != (result > 0) || !stateKnown;
      modified = result > 0;
      stateKnown = true;
      error = null;
      if (changed) onChanged?.call();
    } catch (_) {
      if (_pty != instance || _closing) return;
      stateKnown = false;
      onChanged?.call();
      rethrow;
    }
  }

  Future<void> ensureSaved() async {
    if (starting) throw StateError('Wait for Neovim to finish starting');
    await refreshModified();
    if (needsAttention) {
      throw StateError(
        'Save Neovim buffers with :wa, or discard them in Neovim, before continuing.',
      );
    }
  }

  Future<void> openFile(String root, String path, {bool clean = false}) async {
    await start(root, clean: clean);
    await evaluate(
      '(function() vim.cmd("edit " .. vim.fn.fnameescape(${jsonEncode(path)})); return true end)()',
    );
    currentFile = path;
    error = null;
    await refreshModified();
    onChanged?.call();
  }

  Future<void> saveAll() async {
    await evaluate('(function() vim.cmd("wall"); return true end)()');
    await refreshModified();
  }

  Future<void> showPlugins() async {
    final manager = await evaluate(
      '(function() if vim.fn.exists(":Lazy") == 2 then vim.cmd("Lazy"); return "Lazy" elseif vim.fn.exists(":PackerStatus") == 2 then vim.cmd("PackerStatus"); return "Packer" else return "none" end end)()',
    );
    if (manager == 'none') {
      throw StateError(
        'No Lazy or Packer manager found. Manage plugins in your Neovim configuration; clean mode does not load plugins.',
      );
    }
  }

  Future<void> close() async {
    _closing = true;
    _poll?.cancel();
    _poll = null;
    final process = _pty;
    if (process != null) {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
      }
      if (_pty == process) _pty = null;
    }
    await _output?.cancel();
    _output = null;
    terminal.onOutput = null;
    terminal.onResize = null;
    final temporary = _temporary;
    _temporary = null;
    if (temporary != null && await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
    modified = false;
    stateKnown = true;
    currentFile = null;
    error = null;
    _closing = false;
    if (!_disposed) onChanged?.call();
  }

  Future<void> dispose() async {
    _disposed = true;
    await close();
  }
}
