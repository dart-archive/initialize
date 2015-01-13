// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
@initializeTracker
library static_init.static_init_test;

import 'bar.dart';
import 'foo.dart';
import 'initialize_tracker.dart';
import 'package:static_init/static_init.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/compact_vm_config.dart';

main() {
  useCompactVMConfiguration();

  // Run all static initializers.
  run().then((_) {
    test('annotations are seen in post-order with superclasses first', () {
      var expectedNames = [
        #static_init.test.foo,
        foo,
        fooBar,
        Foo,
        #static_init.test.bar,
        bar,
        Bar,
        #static_init.static_init_test,
        zap,
        Zoop, // Zap extends Zoop, so Zoop comes first.
        Zap
      ];
      expect(InitializeTracker.seen, expectedNames);
    });

    test('annotations only run once', () {
      // Run the static initializers again, should be a no-op.
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
