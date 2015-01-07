// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library static_init.init_method_test;

import 'package:static_init/static_init.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/compact_vm_config.dart';

int calledFoo = 0;
int calledBar = 0;

main() {
  useCompactVMConfiguration();

  // Run all static initializers.
  run();

  test('initMethod annotation invokes functions once', () {
    expect(calledFoo, 1);
    expect(calledBar, 1);
    // Re-run all static initializers, should be a no-op.
    run();
    expect(calledFoo, 1);
    expect(calledBar, 1);
  });
}

@initMethod
foo() => calledFoo++;

@initMethod
bar() => calledBar++;
