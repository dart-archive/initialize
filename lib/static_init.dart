// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library static_init;

import 'dart:mirrors';

part 'src/init_method.dart';
part 'src/static_initializer.dart';

/// The root library to start from.
final _root = currentMirrorSystem().isolate.rootLibrary;

/// Set of all visited annotations, keys are the declarations that were
/// annotated, values are the annotations that have been processed.
final _annotationsFound = new Map<DeclarationMirror, Set<InstanceMirror>>();

/// Top level function which crawls the dependency graph and runs initializers.
void run() {
  _readLibraryDeclarations(_root);
}

/// Reads and executes StaticInitializer annotations on this library and all its
/// dependencies in post-order.
void _readLibraryDeclarations(
    LibraryMirror library, [Set<LibraryMirror> librariesSeen]) {
  if (librariesSeen == null) librariesSeen = new Set<LibraryMirror>();
  librariesSeen.add(library);

  // First visit all our dependencies.
  for (var dependency in library.libraryDependencies) {
    if (librariesSeen.contains(dependency.targetLibrary)) continue;
    _readLibraryDeclarations(dependency.targetLibrary, librariesSeen);
  }

  // Then parse all class and method annotations in this library.
  library
      .declarations
      .values
      .where((d) => d is ClassMirror || d is MethodMirror)
      .forEach((DeclarationMirror d) => _readAnnotations(d));
}

void _readAnnotations(DeclarationMirror declaration) {
  for (var meta in declaration.metadata) {
    if (meta.reflectee is! StaticInitializer) continue;
    if (!_annotationsFound.containsKey(declaration)) {
      _annotationsFound[declaration] = new Set<InstanceMirror>();
    }
    if (_annotationsFound[declaration].contains(meta)) continue;

    _annotationsFound[declaration].add(meta);

    // Initialize super classes first, this is the only exception to the
    // post-order rule.
    if (declaration is ClassMirror && declaration.superclass != null) {
      _readAnnotations(declaration.superclass);
    }

    meta.reflectee.initialize(declaration);
  }
}
