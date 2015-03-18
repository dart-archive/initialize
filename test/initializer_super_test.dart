// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.initializer_super_test;

import 'package:initialize/src/initialize_tracker.dart';
import 'package:initialize/initialize.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/compact_vm_config.dart';

main() {
  useCompactVMConfiguration();

  // Run all initializers.
  run().then((_) {
    test('annotations are seen in post-order with superclasses first', () {
      var expectedNames = [A, C, B, E, D,];
      expect(InitializeTracker.seen, expectedNames);
    });
  });
}

@initializeTracker
class D extends E {}

@initializeTracker
class E extends B {}

@initializeTracker
class B extends C {}

@initializeTracker
class C extends A {}

@initializeTracker
class A {}
