// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library static_init;

import 'dart:collection' show ListQueue;
import 'dart:mirrors';

part 'src/init_method.dart';
part 'src/static_initializer.dart';

/// Typedef for a custom filter function.
typedef bool InitializerFilter(InstanceMirror meta);

/// Top level function which crawls the dependency graph and runs initializers.
/// If `typeFilter` is supplied then only those types of annotations will be
/// parsed.
void run({List<Type> typeFilter, InitializerFilter customFilter}) {
  new _StaticInitializationCrawler(typeFilter, customFilter).run();
}

// Crawls a library and all its dependencies for `StaticInitializer`
// annotations.
class _StaticInitializationCrawler {
  // Set of all visited annotations, keys are the declarations that were
  // annotated, values are the annotations that have been processed.
  static final _annotationsFound =
      new Map<DeclarationMirror, Set<InstanceMirror>>();

  // If non-null, then only these annotations should be processed.
  final List<Type> typeFilter;

  // If non-null, then only annotations which return true when passed to this
  // function will be processed.
  final InitializerFilter customFilter;

  // All the libraries we have seen so far.
  final Set<LibraryMirror> _librariesSeen = new Set<LibraryMirror>();

  // The root library that we start parsing from.
  LibraryMirror _root;

  /// Queues for pending intialization functions to run.
  final _libraryQueue = new ListQueue<Function>();
  final _otherQueue = new ListQueue<Function>();

  _StaticInitializationCrawler(
      this.typeFilter, this.customFilter, {LibraryMirror root}) {
    _root = root == null ? currentMirrorSystem().isolate.rootLibrary : root;
  }

  // The primary function in this class, invoke it to crawl and call all the
  // annotations.
  run() {
    // Parse everything into the two queues.
    _readLibraryDeclarations(_root);

    // First empty the _libraryQueue, then the _otherQueue.
    while (_libraryQueue.isNotEmpty) _libraryQueue.removeFirst()();
    while (_otherQueue.isNotEmpty) _otherQueue.removeFirst()();
  }

  /// Reads and executes StaticInitializer annotations on this library and all
  /// its dependencies in post-order.
  void _readLibraryDeclarations(LibraryMirror lib) {
    _librariesSeen.add(lib);

    // First visit all our dependencies.
    for (var dependency in lib.libraryDependencies) {
      if (_librariesSeen.contains(dependency.targetLibrary)) continue;
      _readLibraryDeclarations(dependency.targetLibrary);
    }

    // Second parse the library directive annotations.
    _readAnnotations(lib, _libraryQueue);

    // Last, parse all class and method annotations.
    lib .declarations
        .values
        .where((d) => d is ClassMirror || d is MethodMirror)
        .forEach((DeclarationMirror d) => _readAnnotations(d, _otherQueue));
  }

  void _readAnnotations(DeclarationMirror declaration,
                        ListQueue<Function> queue) {
    declaration
        .metadata
        .where((m) {
          if (m.reflectee is! StaticInitializer) return false;
          if (typeFilter != null &&
              !typeFilter.any((t) => m.reflectee.runtimeType == t)) {
            return false;
          }
          if (customFilter != null && !customFilter(m)) return false;
          return true;
        })
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
}
