#!/bin/bash

# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Fast fail the script on failures.
set -e

dartanalyzer --fatal-warnings lib/initialize.dart lib/transformer.dart

# Run the un-transformed command-line tests.
dart test/deferred_library_test.dart
dart test/init_method_test.dart
dart test/initializer_custom_filter_test.dart
dart test/initializer_cycle_error_test.dart
dart test/initializer_from_test.dart
dart test/initializer_parts_test.dart
dart test/initializer_super_test.dart
dart test/initializer_test.dart
dart test/initializer_type_filter_test.dart
dart test/transformer_test.dart

pub build test --mode=debug

# Run the transformed command-line tests.
# TODO(jakemac): Add back once initialize supports deferred libraries.
# dart test/deferred_library_test.dart
dart build/test/init_method_test.initialize.dart
dart build/test/initializer_custom_filter_test.initialize.dart
dart build/test/initializer_test.initialize.dart
dart build/test/initializer_parts_test.initialize.dart
dart build/test/initializer_super_test.initialize.dart
dart build/test/initializer_type_filter_test.initialize.dart
