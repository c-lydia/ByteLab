import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bytelab/service/serial_service.dart';
import 'package:bytelab/service/build_service.dart';
import 'package:bytelab/service/build_status.dart';
import 'package:bytelab/service/device_scanner.dart';
import 'fakes.dart';

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('idle services dispose cleanly and reject future work', () async {
    final serial = SerialService();
    final build = BuildService(projectPath: '/tmp');
    await serial.dispose();
    await serial.dispose();
    await build.dispose();
    await build.dispose();
    await expectLater(serial.connect('/fake'), throwsStateError);
    expect(() => build.start(), throwsStateError);
  });

  test(
    'serial opens configured port and handles split UTF-8, CRLF and telemetry',
    () async {
      final transport = FakeTransport();
      final service = SerialService(transportFactory: () => transport);
      addTearDown(service.dispose);
      await service.connect('/fake', baudRate: 9600);
      expect(transport.path, '/fake');
      expect(transport.baud, 9600);
      final bytes = utf8.encode('I (12) status: café\r\n');
      transport.inputController.add(bytes.sublist(0, bytes.length - 3));
      transport.inputController.add(bytes.sublist(bytes.length - 3));
      transport.emit(
        'I (13) telemetry: ram=84.5,temp=NaN,voltage=inf\nI (14) device: idf=v6,fw=2\n',
      );
      await tick();
      expect(service.history.first.message, 'café');
      expect(service.latestTelemetry.values, {'ram': 84.5});
      expect(service.latestDeviceInfo.firmwareVersion, '2');
      await service.write('é\n');
      expect(transport.writes.single, utf8.encode('é\n'));
    },
  );

  test(
    'status request succeeds, times out, and releases subscription when disconnected',
    () async {
      final transport = FakeTransport();
      final service = SerialService(transportFactory: () => transport);
      addTearDown(service.dispose);
      await expectLater(
        service.requestStatus(),
        throwsA(isA<SerialConnectionException>()),
      );
      await service.connect('/fake');
      transport.onWrite = (_) => transport.emit('I (0) status: ready\n');
      await service.requestStatus();
      transport.onWrite = null;
      await expectLater(
        service.requestStatus(timeout: const Duration(milliseconds: 25)),
        throwsA(isA<TimeoutException>()),
      );
      await service.disconnect();
      expect(service.isConnected, isFalse);
    },
  );

  test(
    'serial history is bounded and oversized frames cannot grow indefinitely',
    () async {
      final transport = FakeTransport();
      final service = SerialService(transportFactory: () => transport);
      addTearDown(service.dispose);
      await service.connect('/fake');
      transport.emit('${List.generate(5010, (i) => 'line $i').join('\n')}\n');
      transport.emit('x' * 70000);
      await tick();
      expect(service.history.length, SerialService.maxHistory);
      expect(service.rawHistory.length, SerialService.maxHistory);
      expect(service.history.last.message, contains('64 KiB'));
      transport.emit('\nI (1) telemetry: ram=10\n');
      await tick();
      expect(service.latestTelemetry.values['ram'], 10);
    },
  );

  test(
    'reconnecting resets device metadata and closes old transport',
    () async {
      final first = FakeTransport(), second = FakeTransport();
      var count = 0;
      final serial = SerialService(
        transportFactory: () => count++ == 0 ? first : second,
      );
      addTearDown(serial.dispose);
      await serial.connect('/one');
      first.emit('I (0) device: fw=old\nI (1) telemetry: ram=10\n');
      await tick();
      await serial.connect('/two');
      expect(first.closed, isTrue);
      expect(serial.latestDeviceInfo.firmwareVersion, isNull);
      expect(serial.latestTelemetry.values, isEmpty);
      expect(serial.history, isEmpty);
    },
  );

  test('scanner captures enumeration errors without crashing', () async {
    final serial = SerialService();
    final scanner = DeviceScanner(
      serialService: serial,
      provider: () => throw StateError('enumeration failed'),
    );
    scanner.refresh();
    expect(scanner.error, contains('enumeration failed'));
    expect(scanner.devices, isEmpty);
    scanner.dispose();
    await serial.dispose();
  });

  for (final line in ['[1/2] Compiling main.c', '[1/2/1] Compiling main.c']) {
    test('Ninja progress uses counters and description: $line', () async {
      final service = BuildService(
        projectPath: '/tmp',
        command: '/usr/bin/printf',
        args: ['$line\n'],
      );
      final states = <BuildStatus>[];
      final sub = service.statusStream.listen(states.add);
      await service.start();
      await sub.cancel();
      expect(
        states.any(
          (s) =>
              s.state == BuildState.running &&
              s.progress == .5 &&
              s.currentStep == 'Compiling main.c',
        ),
        isTrue,
      );
      expect(service.status.state, BuildState.success);
      expect(service.outputLines, contains(line));
      await service.dispose();
    });
  }

  test(
    'command failure retains stderr and an actionable exit status',
    () async {
      final service = BuildService(
        projectPath: '/tmp',
        command: '/bin/bash',
        args: ['-c', 'printf "broken\\n" >&2; exit 7'],
      );
      await service.start();
      expect(service.status.state, BuildState.failed);
      expect(service.status.currentStep, contains('exit 7'));
      expect(service.outputLines, contains('broken'));
      await service.dispose();
    },
  );

  test('cancel terminates subprocesses and permits another command', () async {
    final service = BuildService(
      projectPath: '/tmp',
      command: '/bin/bash',
      args: ['-c', 'sleep 30 & wait'],
    );
    final run = service.start();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await service.cancel().timeout(const Duration(seconds: 5));
    await run;
    expect(service.status.state, BuildState.cancelled);
    service.command = '/usr/bin/printf';
    await service.start(arguments: ['done\n']);
    expect(service.status.state, BuildState.success);
    await service.dispose();
  });

  test(
    'SDK script and command arguments remain literal shell arguments',
    () async {
      final dir = await Directory.systemTemp.createTemp('bytelab-args-');
      addTearDown(() => dir.delete(recursive: true));
      final script = File('${dir.path}/sdk export.sh');
      await script.writeAsString('export BYTELAB_TEST_ONLY=yes\n');
      final service = BuildService(
        projectPath: dir.path,
        exportScript: script.path,
        command: '/usr/bin/printf',
        args: ['%s\\n', r'$(touch should-not-exist)', 'space argument'],
      );
      await service.start();
      expect(service.status.state, BuildState.success);
      expect(service.outputLines, contains(r'$(touch should-not-exist)'));
      expect(service.outputLines, contains('space argument'));
      expect(await File('${dir.path}/should-not-exist').exists(), isFalse);
      await service.dispose();
    },
  );
}
