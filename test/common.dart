// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.test.build.common;

import 'package:barback/barback.dart';
import 'package:code_transformers/src/test_harness.dart';
import 'package:unittest/unittest.dart';

testPhases(String testName, List<List<Transformer>> phases,
    Map<String, String> inputFiles, Map<String, String> expectedFiles,
    [List<String> expectedMessages]) {
  test(testName, () {
    var helper = new TestHelper(phases, inputFiles, expectedMessages)..run();
    return helper.checkAll(expectedFiles).whenComplete(() => helper.tearDown());
  });
}

// Simple mock of initialize.
const mockInitialize = '''
    library initialize;

    abstract class Initializer<T> {}

    class _InitMethod implements Initializer<Function> {
      const _InitMethod();
    }
    const _InitMethod initMethod = const _InitMethod();''';

// Some simple initializers for use in tests.
const commonInitializers = '''
    library test_initializers;

    import 'package:initialize/initialize.dart';

    class _ConstInit extends Initializer<dynamic> {
      const ConstInit();
    }
    const _ConstInit constInit = const _ConstInit();

    class DynamicInit extends Initializer<dynamic> {
      final dynamic _value;
      const DynamicInit(this._value);
    }

    class NamedArgInit extends Initializer<dynamic> {
      final dynamic _first;
      final dynamic name;
      const NamedArgInit(this._first, {this.name});
    }
    ''';
