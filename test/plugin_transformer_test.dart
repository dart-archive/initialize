// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.plugin_transformer_test;

import 'package:analyzer/analyzer.dart';
import 'package:initialize/plugin_transformer.dart';
import 'package:source_maps/refactor.dart';
import 'package:unittest/compact_vm_config.dart';
import 'common.dart';

// Simple plugin which just removes all initMethod initializers.
class DeleteInitMethodPlugin extends InitializePluginTransformer {
  DeleteInitMethodPlugin(String bootstrap) : super(bootstrap);

  initEntry(
      InstanceCreationExpression expression, TextEditTransaction transaction) {
    var firstArg = expression.argumentList.arguments[0];
    if (firstArg is PrefixedIdentifier &&
        firstArg.identifier.toString() == 'initMethod') {
      removeInitializer(expression, transaction);
    }
  }
}

main() {
  useCompactVMConfiguration();

  var transformer = new DeleteInitMethodPlugin('web/index.bootstrap.dart');

  testPhases('basic', [[transformer]], {
    'a|web/index.bootstrap.dart': '''
import 'package:initialize/src/static_loader.dart';
import 'package:initialize/initialize.dart';
import 'index.dart' as i0;

main() {
  initializers.addAll([
    new InitEntry(i0.initMethod, const LibraryIdentifier(#a, null, 'a.dart')),
    new InitEntry(i0.initMethod, const LibraryIdentifier(#a, 'a', 'a.dart')),
    new InitEntry(i0.initMethod, i0.a),
    new InitEntry(const i0.DynamicInit('a()'), i0.a),
  ]);

  i0.main();
}
'''
  }, {
    'a|web/index.bootstrap.dart': '''
import 'package:initialize/src/static_loader.dart';
import 'package:initialize/initialize.dart';
import 'index.dart' as i0;

main() {
  initializers.addAll([
    new InitEntry(const i0.DynamicInit('a()'), i0.a),
  ]);

  i0.main();
}
'''
  }, []);
}
