// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.initializer_custom_filter_test;

import 'dart:async';
import 'package:initialize/initialize.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/compact_vm_config.dart';
import 'initialize_tracker.dart';

main() {
  useCompactVMConfiguration();

  test('filter option limits which types of annotations will be ran', () {
    var originalSize;
    return runPhase(1).then((_) {
      // Even though Baz extends Bar, only Baz should be run.
      expect(InitializeTracker.seen, [Baz]);
    }).then((_) => runPhase(2)).then((_) {
      expect(InitializeTracker.seen, [Baz, foo]);
    }).then((_) => runPhase(3)).then((_) {
      expect(InitializeTracker.seen, [Baz, foo, Foo]);
    }).then((_) => runPhase(4)).then((_) {
      expect(InitializeTracker.seen, [Baz, foo, Foo, Bar]);
    }).then((_) {
      originalSize = InitializeTracker.seen.length;
    })
        .then((_) => runPhase(1))
        .then((_) => runPhase(2))
        .then((_) => runPhase(3))
        .then((_) => runPhase(4))
        .then((_) => run())
        .then((_) {
      expect(InitializeTracker.seen.length, originalSize);
    });
  });
}

Future runPhase(int phase) => run(
    customFilter: (Initializer meta) =>
        meta is PhasedInitializer && meta.phase == phase);

@PhasedInitializer(3)
class Foo {}

@PhasedInitializer(2)
foo() {}

@PhasedInitializer(4)
class Bar {}

@PhasedInitializer(1)
class Baz extends Bar {}

// Initializer that has a phase associated with it, this can be used in
// combination with a custom filter to run intialization in phases.
class PhasedInitializer extends InitializeTracker {
  final int phase;

  const PhasedInitializer(this.phase);
}
