// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(jakemac): swap this to @TestOn('pub-serve') once
// https://github.com/dart-lang/test/issues/388 is completed.
@TestOn('!js')
library initialize.initializer_cycle_error_test;

import 'cycle_a.dart' as cycle_a; // Causes a cycle.
import 'package:initialize/initialize.dart';
import 'package:test/test.dart';

/// Uses [cycle_a].
main() {
  test('super class cycles are not supported', () {
    expect(run, throwsUnsupportedError);
  },
      skip: 'Should be skipped only in pub-serve mode, blocked on  '
          'https://github.com/dart-lang/test/issues/388.');
}
