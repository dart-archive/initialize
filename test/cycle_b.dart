// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.test.cycle_b;

import 'initialize_tracker.dart';
import 'cycle_a.dart';

@initializeTracker
class CycleB extends CycleA {}
