import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'build_status.dart';

class BuildService {
  final String projectPath;
  final String command;
  final List<String> args;

  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  final _statusController = StreamController<BuildStatus>.broadcast();
  BuildStatus _status = const BuildStatus();

  final List<String> outputLines = [];
  final _outputController = StreamController<String>.broadcast();

  BuildService({
    required this.projectPath,
    this.command = 'idf.py',
    this.args = const ['build']
  });

  Stream<BuildStatus> get statusStream => _statusController.stream;
  Stream<String> get outputStream => _outputController.stream;
  BuildStatus get status => _status;
  bool get isRunning => _status.state == BuildState.running;

  static final RegExp _ninjaProgress = RegExp(r'^\[(\d+)/(\d+)/(\d+)\]\s+(.*)$');

  Future<void> start() async {
    if (isRunning) return;

    outputLines.clear();
    _setStatus(const BuildStatus(state: BuildState.running, progress: 0));

    try {
      _process = await Process.start(command, args, workingDirectory: projectPath, runInShell: true);
    } catch (e) {
      _setStatus(BuildStatus(state: BuildState.failed, currentStep: 'Failed to start: $e'));
      return;
    }

    _stdoutSub = _process!.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(_handleLine);

    _stderrSub = _process!.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(_handleLine);

    final exitCode = await _process!.exitCode;
    _setStatus(_status.copyWith(
      state: exitCode == 0? BuildState.success: BuildState.failed,
      progress: exitCode == 0? 1.0: _status.progress
    )); 
  }

  void _handleLine(String line) {
    outputLines.add(line);
    _outputController.add(line);

    final match = _ninjaProgress.firstMatch(line);

    if (match != null) {
      final current = int.parse(match.group(1)!);
      final total = int.parse(match.group(2)!);
      final step = match.group(3)!;

      _setStatus(_status.copyWith(
        progress: total > 0? current/total: _status.progress,
        currentStep: step
      ));
    }
  }

  void _setStatus(BuildStatus status) {
    _status = status;
    _statusController.add(status);
  }

  Future<void> cancel() async {
    _process?.kill();
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _setStatus(_status.copyWith(state: BuildState.idle));
  }

  void dispose() {
    cancel();
    _statusController.close();
    _outputController.close();
  }
}