// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
@initializeTracker
library initialize.deferred_library_test;

import 'foo.dart' deferred as foo;
import 'package:initialize/src/initialize_tracker.dart';
import 'package:initialize/initialize.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/compact_vm_config.dart';

main() {
  useCompactVMConfiguration();

  test('annotations can be loaded lazily', () {
    // Initialize everything not in deferred imports.
    return run().then((_) {
      expect(InitializeTracker.seen.length, 1);

      // Now load the foo library and re-run initializers.
      return foo.loadLibrary().then((_) => run()).then((_) {
        expect(InitializeTracker.seen.length, 5);
      });
    });
  });
}
