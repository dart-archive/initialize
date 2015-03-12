library initialize.tool.rename_build_outputs;

import 'dart:io';

import 'package:path/path.dart';

main() {
  var scriptPath = Platform.script.path;
  if (context.style.name == 'windows') scriptPath = scriptPath.substring(1);
  var dir = join(dirname(dirname(scriptPath)), 'build', 'test');
  for (var file in new Directory(dir).listSync()) {
    var filepath = file.path;
    var name = basename(filepath);
    if (name.endsWith('.initialize.dart')) {
      var newPath = join(dirname(filepath),
          name.replaceFirst('.initialize.dart', '.initialize_test.dart'));
      print('Copying $filepath to $newPath');
      new File(filepath).copySync(newPath);
    }
  }
}
