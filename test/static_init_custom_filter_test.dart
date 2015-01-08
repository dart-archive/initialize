// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library static_init.static_init_custom_filter_test;

import 'dart:mirrors';
import 'package:static_init/static_init.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/compact_vm_config.dart';
import 'initialize_tracker.dart';

main() {
  useCompactVMConfiguration();

  test('filter option limits which types of annotations will be ran', () {
    runPhase(1);
    // Even though Baz extends Bar, only Baz should be run.
    expect(InitializeTracker.seen, [Baz]);
    runPhase(2);
    expect(InitializeTracker.seen, [Baz, 'foo']);
    runPhase(3);
    expect(InitializeTracker.seen, [Baz, 'foo', Foo]);
    runPhase(4);
    expect(InitializeTracker.seen, [Baz, 'foo', Foo, Bar]);

    // Sanity check, future calls should be no-ops
    var originalSize = InitializeTracker.seen.length;
    runPhase(1);
    runPhase(2);
    runPhase(3);
    runPhase(4);
    run();
    expect(InitializeTracker.seen.length, originalSize);
  });
}

runPhase(int phase) {
  run(customFilter: (StaticInitializer meta) =>
      meta is PhasedInitializer && meta.phase == phase);
}

@PhasedInitializer(3)
class Foo {}

@PhasedInitializer(2)
foo() => 'foo';

@PhasedInitializer(4)
class Bar {}

@PhasedInitializer(1)
class Baz extends Bar {}

// Static Initializer that has a phase associated with it, this can be used in
// combination with a custom filter to run intialization in phases.
class PhasedInitializer extends InitializeTracker {
  final int phase;

  const PhasedInitializer(this.phase);
}
