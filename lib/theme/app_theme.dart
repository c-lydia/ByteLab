import 'package:flutter/material.dart';
import '../core/byte_color.dart';

class AppTheme {
  static const name = 'Underlight';
  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Ubuntu Sans',
      fontFamilyFallback: const ['Noto Sans', 'sans-serif'],
      useMaterial3: true,
      scaffoldBackgroundColor: ByteColor.background,
      colorScheme: const ColorScheme.dark(
        primary: ByteColor.blue,
        secondary: ByteColor.purple,
        surface: ByteColor.surface,
        onSurface: ByteColor.text,
        onSurfaceVariant: ByteColor.secondsaryText,
        onPrimary: ByteColor.background,
        primaryContainer: ByteColor.surfaceHover,
        onPrimaryContainer: ByteColor.blue,
        secondaryContainer: ByteColor.panelLight,
        onSecondaryContainer: ByteColor.purple,
        outline: ByteColor.border,
        error: ByteColor.error,
        onError: ByteColor.background,
        errorContainer: ByteColor.errorSurface,
        onErrorContainer: ByteColor.error,
        surfaceContainerLowest: ByteColor.terminal,
        surfaceContainerLow: ByteColor.panel,
        surfaceContainer: ByteColor.surface,
        surfaceContainerHigh: ByteColor.panelLight,
        surfaceContainerHighest: ByteColor.border,
      ),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    return base.copyWith(
      textTheme: base.textTheme
          .copyWith(
            headlineSmall: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.7,
              color: ByteColor.text,
            ),
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: ByteColor.text,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ByteColor.text,
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: ByteColor.text,
            ),
            bodySmall: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: ByteColor.secondsaryText,
            ),
          )
          .apply(
            fontFamily: 'Ubuntu Sans',
            fontFamilyFallback: const ['Noto Sans', 'sans-serif'],
          ),
      cardColor: ByteColor.surface,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ByteColor.panel,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        hintStyle: const TextStyle(color: ByteColor.mutedText, fontSize: 13),
        labelStyle: const TextStyle(color: ByteColor.secondsaryText),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ByteColor.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ByteColor.cyan, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ByteColor.text,
          side: const BorderSide(color: ByteColor.border),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: shape),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: ByteColor.panel,
        selectedColor: ByteColor.surfaceHover,
        side: const BorderSide(color: ByteColor.border),
        shape: shape,
        labelStyle: const TextStyle(fontSize: 12, color: ByteColor.text),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: ByteColor.text,
        selectionColor: ByteColor.blue.withValues(alpha: 0.30),
        selectionHandleColor: ByteColor.blue,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(ByteColor.border),
        radius: const Radius.circular(6),
        thickness: WidgetStateProperty.all(6),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ByteColor.panelLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ByteColor.border),
        ),
        textStyle: const TextStyle(color: ByteColor.text, fontSize: 12),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ByteColor.panelLight,
        contentTextStyle: TextStyle(color: ByteColor.text),
      ),
      dividerColor: ByteColor.border,
    );
  }
}
