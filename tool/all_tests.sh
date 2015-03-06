#!/bin/bash

# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Fast fail the script on failures.
set -e

# Run the command-line tests.
# TODO(jakemac): Add back once http://dartbug.com/22592 is fixed.
# dart test/deferred_library_test.dart
dart test/init_method_test.dart
dart test/initializer_custom_filter_test.dart
dart test/initializer_cycle_error_test.dart
dart test/initializer_test.dart
dart test/initializer_type_filter_test.dart
dart test/transformer_test.dart
