import 'package:flutter/material.dart';

import 'byte_color.dart';

class ByteTypography {
  static const title = TextStyle(
    color: ByteColor.text,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const section = TextStyle(
    color: ByteColor.secondsaryText,
    fontSize: 11,
    letterSpacing: 1.8,
    fontWeight: FontWeight.bold,
  );

  static const body = TextStyle(color: ByteColor.text, fontSize: 14);

  static const terminal = TextStyle(
    color: Colors.white70,
    fontSize: 13,
    fontFamily: "monospace",
  );
}
