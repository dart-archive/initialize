// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
@initializeTracker
library initialize.test.foo;

import 'initialize_tracker.dart';

@initializeTracker
class Foo {}

@initializeTracker
fooBar() {}

@initializeTracker
foo() {}
