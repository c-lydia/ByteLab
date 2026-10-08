import 'dart:io';
import 'package:bytelab/app/project_store.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    throw ArgumentError(
      'Usage: dart tool/create_starter.dart <existing-parent> <new-project-name>',
    );
  }
  final project = ProjectStore();
  await project.create(arguments[0], arguments[1]);
  stdout.writeln(project.root);
}
