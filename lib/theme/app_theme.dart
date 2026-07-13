import 'package:flutter/material.dart';

class AppTheme {
  static const purple = Color(0xffB026FF);
  static const blue = Color(0xff00F5FF);

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xff080812),
      colorScheme: const ColorScheme.dark(
        primary: purple,
        secondary: blue
      ),
      cardColor: Color(0xff121225),
      useMaterial3: true
    );
  }
}