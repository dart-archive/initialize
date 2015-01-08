// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
@initializeTracker
library static_init.test.bar;

import 'foo.dart';  // Make sure cycles are ok.
import 'initialize_tracker.dart';

// Foo should be initialized first.
@initializeTracker
class Bar extends Foo {}

@initializeTracker
bar() => 'bar';
