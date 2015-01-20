// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
@initializeTracker
library initialize.initializer_test;

import 'foo.dart';
import 'bar.dart';
import 'initialize_tracker.dart';
import 'package:initialize/initialize.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/compact_vm_config.dart';

main() {
  useCompactVMConfiguration();

  // Run all initializers.
  run().then((_) {
    test('annotations are seen in post-order with superclasses first', () {
      var expectedNames = [
        #initialize.test.foo,
        foo,
        fooBar,
        Foo,
        #initialize.test.bar,
        bar,
        Bar,
        #initialize.initializer_test,
        zap,
        Zoop, // Zap extends Zoop, so Zoop comes first.
        Zap
      ];
      expect(InitializeTracker.seen, expectedNames);
    });

    test('annotations only run once', () {
      // Run the initializers again, should be a no-op.
      var originalSize = InitializeTracker.seen.length;
      return run().then((_) {
        expect(InitializeTracker.seen.length, originalSize);
      });
    });
  });
}

@initializeTracker
class Zoop {}

@initializeTracker
class Zap extends Zoop {}

@initializeTracker
zap() {}
