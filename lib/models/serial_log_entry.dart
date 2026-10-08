import 'package:flutter/material.dart';

import '../core/byte_color.dart';

enum LogLevel {
  error,
  warn,
  info,
  debug,
  verbose,
  unknown;

  static LogLevel? fromPrefix(String letter) {
    switch (letter) {
      case 'E':
        return LogLevel.error;
      case 'W':
        return LogLevel.warn;
      case 'I':
        return LogLevel.info;
      case 'D':
        return LogLevel.debug;
      case 'V':
        return LogLevel.verbose;
      default:
        return LogLevel.unknown;
    }
  }

  Color get color {
    switch (this) {
      case LogLevel.error:
        return const Color(0xffFF5C5C);
      case LogLevel.warn:
        return const Color(0xffFFC857);
      case LogLevel.info:
        return ByteColor.cyan;
      case LogLevel.debug:
        return const Color(0xff8A8FA3);
      case LogLevel.verbose:
        return ByteColor.mutedText;
      case LogLevel.unknown:
        return ByteColor.mutedText;
    }
  }

  bool get isVerboseOnly => this == LogLevel.debug || this == LogLevel.verbose;
}

@immutable
class SerialLogEntry {
  final LogLevel level;
  final int? deviceTimestampMs;
  final String? tag;
  final String? message;
  final DateTime receivedAt;

  SerialLogEntry({
    required this.level,
    required this.message,
    this.deviceTimestampMs,
    this.tag,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory SerialLogEntry.parse(String rawline) {
    rawline = rawline.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
    final match = _pattern.firstMatch(rawline);

    if (match == null) {
      return SerialLogEntry(level: LogLevel.unknown, message: rawline);
    }

    final level = LogLevel.fromPrefix(match.group(1)!) ?? LogLevel.unknown;
    return SerialLogEntry(
      level: level,
      deviceTimestampMs: int.tryParse(match.group(2)!),
      tag: match.group(3),
      message: match.group(4)!,
    );
  }

  static final RegExp _pattern = RegExp(
    r'^([EWIDV])\s*\((\d+)\)\s*([^:]+):\s*(.*)$',
  );
}
