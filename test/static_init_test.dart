// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library static_init.static_init_test;

import 'foo.dart'; // For the annotations.
import 'initialize_tracker.dart';
import 'package:static_init/static_init.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/compact_vm_config.dart';

main() {
  useCompactVMConfiguration();

  // Run all static initializers.
  run();

  test('annotations are seen in post-order with superclasses first', () {
    // Foo comes first because its a superclass of Bar.
    var expectedNames = [#Foo, #Bar, #bar, #fooBar, #foo, #zap, #Zap];
    var actualNames = InitializeTracker.seen.map((d) => d.simpleName);
    expect(actualNames, expectedNames);
  });

  test('annotations only run once', () {
    // Run the static initializers again, should be a no-op.
    var originalSize = InitializeTracker.seen.length;
    run();
    expect(InitializeTracker.seen.length, originalSize);
  });
}

@initializeTracker
class Zap {}

@initializeTracker
zap() {}
