import 'package:flutter/material.dart';

/// Underlight palette from dotfiles/.config/hypr/underlight/colors.conf,
/// Kitty's ANSI colors, and .config/underlight/widgets.css.
class ByteColor {
  static const background = Color(0xff1A1B26);
  static const surface = Color(0xff24283B);
  static const surfaceHover = Color(0xff2F354F);
  static const border = Color(0xff414868);
  static const text = Color(0xffC0CAF5);
  static const secondsaryText = Color(0xffA9B1D6);
  static const blue = Color(0xff7AA2F7);
  static const cyan = Color(0xff7DCFFF);
  static const purple = Color(0xffBB9AF7);
  static const pink = Color(0xffE052A0);
  static const glowCyan = Color(0xff48CAE4);
  static const glowViolet = Color(0xff7C4DFF);
  static const success = Color(0xff9ECE6A);
  static const warning = Color(0xffE0AF68);
  static const panel = Color(0xff161822);
  static const panelLight = surfaceHover;
  static const divider = border;
  // Use Underlight's brighter secondary tone for small labels and line numbers.
  static const mutedText = Color(0xffA9B1D6);
  static const error = Color(0xffF7768E);
  static const errorSurface = Color(0xff422835);
  static const info = blue;
  static const terminal = Color(0xff15161E);
  static const shadow = Color(0xff05060C);
}
