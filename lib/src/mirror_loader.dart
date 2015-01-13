// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library static_init.mirror_loader;

import 'dart:async';
import 'dart:collection' show Queue;
import 'dart:mirrors';
import 'package:static_init/static_init.dart';

// Crawls a library and all its dependencies for `StaticInitializer`
// annotations using mirrors
class StaticInitializationCrawler {
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

  /// Queue for pending intialization functions to run.
  final _initQueue = new Queue<Function>();

  StaticInitializationCrawler(this.typeFilter, this.customFilter,
      {LibraryMirror root}) {
    _root = root == null ? currentMirrorSystem().isolate.rootLibrary : root;
  }

  // The primary function in this class, invoke it to crawl and call all the
  // annotations.
  Future run() {
    // Parse everything into the two queues.
    _readLibraryDeclarations(_root);

    // Empty the init queue.
    return _runInitQueue();
  }

  Future _runInitQueue() {
    if (_initQueue.isEmpty) return new Future.value(null);
    // Remove and invoke the next item.
    var val = _initQueue.removeFirst()();
    return (val is Future ? val : new Future.value(null))
        .then((_) => _runInitQueue());
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
    _readAnnotations(lib);

    // Last, parse all class and method annotations.
    lib.declarations.values
        .where((d) => d is ClassMirror || d is MethodMirror)
        .forEach((DeclarationMirror d) => _readAnnotations(d));
  }

  void _readAnnotations(DeclarationMirror declaration) {
    declaration.metadata.where((m) {
      if (m.reflectee is! StaticInitializer) return false;
      if (typeFilter != null &&
          !typeFilter.any((t) => m.reflectee.runtimeType == t)) {
        return false;
      }
      if (customFilter != null && !customFilter(m.reflectee)) return false;
      return true;
    }).forEach((meta) {
      if (!_annotationsFound.containsKey(declaration)) {
        _annotationsFound[declaration] = new Set<InstanceMirror>();
      }
      if (_annotationsFound[declaration].contains(meta)) return;
      _annotationsFound[declaration].add(meta);

      // Initialize super classes first, this is the only exception to the
      // post-order rule.
      if (declaration is ClassMirror && declaration.superclass != null) {
        _readAnnotations(declaration.superclass);
      }

      var annotatedValue;
      if (declaration is ClassMirror) {
        annotatedValue = declaration.reflectedType;
      } else if (declaration is MethodMirror) {
        if (!declaration.isStatic) {
          throw new UnsupportedError(
              'Only static methods are supported for StaticInitializers');
        }
        annotatedValue = (declaration.owner as ObjectMirror)
            .getField(declaration.simpleName).reflectee;
      } else {
        annotatedValue = declaration.qualifiedName;
      }
      _initQueue.addLast(() => meta.reflectee.initialize(annotatedValue));
    });
  }
}
