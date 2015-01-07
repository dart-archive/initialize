// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library static_init;

import 'dart:collection' show ListQueue;
import 'dart:mirrors';

part 'src/init_method.dart';
part 'src/static_initializer.dart';

/// The root library to start from.
final _root = currentMirrorSystem().isolate.rootLibrary;

/// Set of all visited annotations, keys are the declarations that were
/// annotated, values are the annotations that have been processed.
final _annotationsFound = new Map<DeclarationMirror, Set<InstanceMirror>>();

/// Queues for pending intialization functions to run.
final _libraryQueue = new ListQueue<Function>();
final _otherQueue = new ListQueue<Function>();

/// Top level function which crawls the dependency graph and runs initializers.
void run() {
  // Parse everything into the two queues.
  _readLibraryDeclarations(_root);

  // First empty the _libraryQueue, then the _otherQueue.
  while (_libraryQueue.isNotEmpty) _libraryQueue.removeFirst()();
  while (_otherQueue.isNotEmpty) _otherQueue.removeFirst()();
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

  // Second parse the library directive annotations.
  _readAnnotations(library, _libraryQueue);

  // Last, parse all class and method annotations.
   library
      .declarations
      .values
      .where((d) => d is ClassMirror || d is MethodMirror)
      .forEach((DeclarationMirror d) => _readAnnotations(d, _otherQueue));
}

void _readAnnotations(DeclarationMirror declaration,
                      ListQueue<Function> queue) {
  declaration
      .metadata
      .where((m) => m.reflectee is StaticInitializer)
      .forEach((meta) {
        if (!_annotationsFound.containsKey(declaration)) {
          _annotationsFound[declaration] = new Set<InstanceMirror>();
        }
        if (_annotationsFound[declaration].contains(meta)) return;
        _annotationsFound[declaration].add(meta);

        // Initialize super classes first, this is the only exception to the
        // post-order rule.
        if (declaration is ClassMirror && declaration.superclass != null) {
          _readAnnotations(declaration.superclass, queue);
        }

        queue.addLast(() => meta.reflectee.initialize(declaration));
      });
}
