// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(jakemac): swap this to @TestOn('pub-serve') once
// https://github.com/dart-lang/test/issues/388 is completed.
@TestOn('!js')
@initializeTracker
library initialize.initializer_parts_test;

import 'package:initialize/src/initialize_tracker.dart';
import 'package:initialize/initialize.dart';
import 'package:test/test.dart';

part 'parts/foo.dart';
part 'parts/bar.dart';

main() {
  // Run all initializers.
  return run().then((_) {
    test('parts', () {
      var expectedNames = [
        const LibraryIdentifier(#initialize.initializer_parts_test, null,
            'initializer_parts_test.dart'),
        bar2,
        bar,
        foo,
        baz,
        Bar2,
        Bar,
        Foo,
        Baz,
      ];
      expect(InitializeTracker.seen, expectedNames);
    });
  });
}

@initializeTracker
class Baz {}

@initializeTracker
baz() {}
