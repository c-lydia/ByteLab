import 'package:flutter/material.dart';
import 'app_controller.dart';
import '../layout/firmware_shell.dart';
import '../theme/app_theme.dart';

class ByteLabApp extends StatefulWidget {
  const ByteLabApp({super.key, this.controller});
  final AppController? controller;
  @override
  State<ByteLabApp> createState() => _ByteLabAppState();
}

class _ByteLabAppState extends State<ByteLabApp> {
  late final AppController app = widget.controller ?? AppController();
  @override
  void initState() {
    super.initState();
    app.initialize();
  }

  @override
  void dispose() {
    app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    controller: app,
    child: MaterialApp(
      title: 'ByteLab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) => app.ready
            ? const FirmwareShell()
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    ),
  );
}
