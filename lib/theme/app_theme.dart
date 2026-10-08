import 'package:flutter/material.dart';
import '../core/byte_color.dart';

class AppTheme {
  static ThemeData dark() => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ByteColor.background,
    colorScheme: const ColorScheme.dark(
      primary: ByteColor.cyan,
      secondary: Color(0xffB388FF),
      surface: ByteColor.surface,
      onPrimary: ByteColor.background,
    ),
    cardColor: ByteColor.surface,
    useMaterial3: true,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ByteColor.panel,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ByteColor.border),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerColor: ByteColor.border,
  );
}
