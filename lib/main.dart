import 'package:flutter/material.dart';

import 'layout/firmware_shell.dart';
import 'package:bytelab/screens/test.dart';
import 'package:bytelab/screens/home_screen.dart';

void main() {
  runApp(const ByteLabApp());
}

class ByteLabApp extends StatelessWidget {
  const ByteLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FirmwareShell(
        pages: [
          const OverviewPage(),
          const TestPage(),
          const TestPage(),
          const TestPage(),
          const TestPage(),
          const TestPage(),
          const TestPage(),
          const TestPage(),
          const TestPage(),
          const TestPage(),
        ],
      ),
    );
  }
}
