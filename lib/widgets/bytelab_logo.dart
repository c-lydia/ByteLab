import 'package:flutter/material.dart';

/// The same mark is used by the web favicon and native launcher icons.
class ByteLabLogo extends StatelessWidget {
  const ByteLabLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .2),
    child: Image.asset(
      'assets/branding/bytelab-icon.png',
      width: size,
      height: size,
      semanticLabel: 'ByteLab logo',
      filterQuality: FilterQuality.high,
    ),
  );
}
