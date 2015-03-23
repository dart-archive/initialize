// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
@initializeTracker
library initialize.test.initializer_from_test;

import 'package:initialize/src/initialize_tracker.dart';
import 'package:initialize/initialize.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/compact_vm_config.dart';
import 'package:test_package/bar.dart'; // Used for annotations

main() {
  useCompactVMConfiguration();

  test('The `from` option', () {
    var expectedNames = [];
    return run(from: Uri.parse('package:test_package/bar.dart')).then((_) {
      // First just run on the test packages bar.dart file.
      expectedNames.add(const LibraryIdentifier(
          #test_package.bar, 'test_package', 'bar.dart'));
      expect(InitializeTracker.seen, expectedNames);
    }).then((_) => run()).then((_) {
      // Now we run on the rest (just this file).
      expectedNames.add(const LibraryIdentifier(
          #initialize.test.initializer_from_test, null,
          'initializer_from_test.dart'));
      expect(InitializeTracker.seen, expectedNames);
    });
  });
}
