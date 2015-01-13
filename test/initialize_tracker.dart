// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library static_init.test.initialize_tracker;

import 'dart:mirrors';
import 'package:static_init/static_init.dart';

// Static Initializer that just saves everything it sees.
class InitializeTracker implements StaticInitializer<dynamic> {
  static final List seen = [];

  const InitializeTracker();

  @override
  void initialize(value) => seen.add(value);
}

const initializeTracker = const InitializeTracker();
