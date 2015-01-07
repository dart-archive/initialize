// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
part of static_init;

/// Metadata used to label static or top-level methods that are called
/// automatically when calling static_init.run(). This class is private because
/// it shouldn't be used directly in annotations, instead use the `initMethod`
/// singleton below.
class _InitMethod implements StaticInitializer<MethodMirror> {
  const _InitMethod();

  @override
  initialize(MethodMirror method) {
    if (!method.isStatic) {
      throw 'Methods marked with @initMethod should be static, '
            '${method.simpleName} is not.';
    }
    if (method.parameters.any((p) => !p.isOptional)) {
      throw 'Methods marked with @initMethod should take no arguments, '
            '${method.simpleName} expects some.';
    }
    (method.owner as ObjectMirror).invoke(method.simpleName, const []);
  }
}

/// We only ever need one instance of the `_InitMethod` class, this is it.
const initMethod = const _InitMethod();
