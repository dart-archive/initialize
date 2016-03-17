// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(jakemac): swap this to @TestOn('pub-serve') once
// https://github.com/dart-lang/test/issues/388 is completed.
@TestOn('!js')
library initialize.initializer_super_test;

import 'package:initialize/src/initialize_tracker.dart';
import 'package:initialize/initialize.dart';
import 'package:test/test.dart';

main() {
  // Run all initializers.
  return run().then((_) {
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
