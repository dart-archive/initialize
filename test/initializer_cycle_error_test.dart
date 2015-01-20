// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.initializer_cycle_error_test;

import 'cycle_a.dart'; // Causes a cycle.
import 'package:initialize/initialize.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/compact_vm_config.dart';

main() {
  useCompactVMConfiguration();

  test('super class cycles are not supported', () {
    expect(run, throwsUnsupportedError);
  });
}
