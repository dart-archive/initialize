// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(jakemac): swap this to @TestOn('pub-serve') once
// https://github.com/dart-lang/test/issues/388 is completed.
@TestOn('!js')
@initializeTracker
library initialize.test.initializer_from_test;

import 'package:initialize/src/initialize_tracker.dart';
import 'package:initialize/initialize.dart';
import 'package:test/test.dart';
import 'package:test_package/bar.dart' as bar;

/// Uses [bar]
main() {
  test('The `from` option', () async {
    final expectedNames = <LibraryIdentifier>[];

    // First just run on the test packages bar.dart file.
    await run(from: Uri.parse('package:test_package/bar.dart'));
    expectedNames.add(
        const LibraryIdentifier(#test_package.bar, 'test_package', 'bar.dart'));
    expect(InitializeTracker.seen, expectedNames);

    // Now we run on the rest (just this file).
    await run();
    expect(InitializeTracker.seen.length, 2);
    // Don't know what the path will be, so have to explicitly check fields
    // and use an [endsWith] matcher for the path.
    expect(InitializeTracker.seen[1].name,
        #initialize.test.initializer_from_test);
    expect(InitializeTracker.seen[1].package, isNull);
    expect(
        InitializeTracker.seen[1].path, endsWith('initializer_from_test.dart'));
  }, skip: 'Should be skipped only in pub-serve mode, blocked on  '
      'https://github.com/dart-lang/test/issues/388.');
}
