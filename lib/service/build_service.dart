import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'build_status.dart';

class BuildService {
  BuildService({
    required this.projectPath,
    this.command = 'idf.py',
    this.args = const ['build'],
    this.exportScript = '',
  });
  String projectPath;
  String command;
  List<String> args;
  String exportScript;
  String label = 'Build';
  Process? _process;
  Future<void>? _activeRun;
  bool _cancelRequested = false;
  bool _disposed = false;
  bool _processGroup = false;
  Timer? _killTimer;
  final _statuses = StreamController<BuildStatus>.broadcast();
  final _output = StreamController<String>.broadcast();
  BuildStatus _status = const BuildStatus();
  final List<String> outputLines = [];
  Stream<BuildStatus> get statusStream => _statuses.stream;
  Stream<String> get outputStream => _output.stream;
  BuildStatus get status => _status;
  bool get isRunning => _activeRun != null;
  static final _progress = RegExp(r'^\[(\d+)/(\d+)(?:/\d+)?\]\s+(.*)$');

  Future<void> start({List<String>? arguments, String? title}) {
    if (_disposed) throw StateError('Build service has been disposed');
    if (_activeRun != null) {
      throw StateError('Another firmware operation is running');
    }
    if (arguments != null) args = List.of(arguments);
    label = title ?? 'Build';
    _cancelRequested = false;
    outputLines.clear();
    _activeRun = _run().whenComplete(() {
      _activeRun = null;
    });
    return _activeRun!;
  }

  Future<void> _run() async {
    _setStatus(
      BuildStatus(state: BuildState.running, currentStep: 'Starting $label…'),
    );
    try {
      if (!await Directory(projectPath).exists()) {
        throw FileSystemException(
          'Project directory does not exist',
          projectPath,
        );
      }
      var executable = command;
      var parameters = List<String>.of(args);
      if (exportScript.isNotEmpty) {
        if (!await File(exportScript).exists()) {
          throw FileSystemException(
            'ESP-IDF export script does not exist',
            exportScript,
          );
        }
        executable = '/bin/bash';
        parameters = [
          '-c',
          r'set -e; source "$1" >/dev/null; shift; exec "$@"',
          'bytelab',
          exportScript,
          command,
          ...args,
        ];
      }
      _processGroup = Platform.isLinux && File('/usr/bin/setsid').existsSync();
      if (_processGroup) {
        parameters = [executable, ...parameters];
        executable = '/usr/bin/setsid';
      }
      _handleLine('> $command ${args.join(' ')}');
      _process = await Process.start(
        executable,
        parameters,
        workingDirectory: projectPath,
      );
      if (_cancelRequested || _disposed) _signal(ProcessSignal.sigterm);
      final stdoutDone = _process!.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .forEach(_handleLine);
      final stderrDone = _process!.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .forEach(_handleLine);
      final code = await _process!.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      _setStatus(
        _status.copyWith(
          state: _cancelRequested
              ? BuildState.cancelled
              : code == 0
              ? BuildState.success
              : BuildState.failed,
          progress: code == 0 && !_cancelRequested ? 1 : _status.progress,
          currentStep: _cancelRequested
              ? '$label cancelled'
              : code == 0
              ? '$label complete'
              : '$label failed (exit $code)',
        ),
      );
    } catch (error) {
      _handleLine('ERROR: $error');
      _setStatus(
        BuildStatus(
          state: _cancelRequested ? BuildState.cancelled : BuildState.failed,
          currentStep: error.toString(),
        ),
      );
    } finally {
      _killTimer?.cancel();
      _killTimer = null;
      _process = null;
    }
  }

  void _handleLine(String line) {
    if (_disposed) return;
    final clean = line.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
    outputLines.add(clean);
    if (outputLines.length > 10000) {
      outputLines.removeRange(0, outputLines.length - 10000);
    }
    _output.add(clean);
    final match = _progress.firstMatch(clean);
    if (match != null) {
      final total = int.parse(match.group(2)!);
      _setStatus(
        _status.copyWith(
          progress: total == 0
              ? _status.progress
              : (int.parse(match.group(1)!) / total).clamp(0.0, 1.0),
          currentStep: match.group(3)!,
        ),
      );
    }
  }

  void _setStatus(BuildStatus status) {
    _status = status;
    if (!_disposed) _statuses.add(status);
  }

  void _signal(ProcessSignal signal) {
    final process = _process;
    if (process == null) return;
    if (_processGroup) {
      if (!Process.killPid(-process.pid, signal)) process.kill(signal);
    } else {
      process.kill(signal);
    }
  }

  Future<void> cancel() async {
    if (_activeRun == null) return;
    _cancelRequested = true;
    _signal(ProcessSignal.sigterm);
    _killTimer ??= Timer(
      const Duration(seconds: 2),
      () => _signal(ProcessSignal.sigkill),
    );
    await _activeRun;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await cancel();
    await Future.wait([_statuses.close(), _output.close()]);
  }
}
