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
    _readLibraryDeclarations(_root);
    return _runInitQueue();
  }

  Future _runInitQueue() {
    if (_initQueue.isEmpty) return new Future.value(null);

    var initializer = _initQueue.removeFirst();
    var val = initializer();
    if (val is! Future) val = new Future.value(val);

    return val.then((_) => _runInitQueue());
  }

  // Reads StaticInitializer annotations on this library and all its
  // dependencies in post-order.
  void _readLibraryDeclarations(LibraryMirror lib) {
    _librariesSeen.add(lib);

    // First visit all our dependencies.
    for (var dependency in _sortedLibraryDependencies(lib)) {
      if (_librariesSeen.contains(dependency.targetLibrary)) continue;
      _readLibraryDeclarations(dependency.targetLibrary);
    }

    // Second parse the library directive annotations.
    _readAnnotations(lib);

    // Last, parse all class and method annotations.
    for (var declaration in _sortedLibraryDeclarations(lib)) {
      _readAnnotations(declaration);
      // Check classes for static annotations which are not supported
      if (declaration is ClassMirror) {
        for (var classDeclaration in declaration.declarations.values) {
          _readAnnotations(classDeclaration);
        }
      }
    }
  }

  Iterable<LibraryDependencyMirror>
      _sortedLibraryDependencies(LibraryMirror lib) =>
    lib.libraryDependencies
      ..sort((a, b) => _targetLibraryName(a).compareTo(_targetLibraryName(b)));

  String _targetLibraryName(LibraryDependencyMirror lib) =>
      MirrorSystem.getName(lib.targetLibrary.qualifiedName);

  Iterable<DeclarationMirror> _sortedLibraryDeclarations(LibraryMirror lib) =>
      lib.declarations.values
          .where((d) => d is ClassMirror || d is MethodMirror)
          .toList()
          ..sort((a, b) {
            if (a.runtimeType == b.runtimeType) {
              return _declarationName(a).compareTo(_declarationName(b));
            }
            if (a is MethodMirror && b is ClassMirror) return -1;
            if (a is ClassMirror && b is MethodMirror) return 1;
            return 0;
          });

  String _declarationName(DeclarationMirror declaration) =>
      MirrorSystem.getName(declaration.qualifiedName);

  // Reads annotations on declarations and adds them to `_initQueue` if they are
  // static initializers.
  void _readAnnotations(DeclarationMirror declaration) {
    var annotations =
        declaration.metadata.where((m) => _filterMetadata(declaration, m));
    for (var meta in annotations) {
      _annotationsFound[declaration].add(meta);

      // Initialize super classes first, if they are in the same library,
      // otherwise we throw an error. This can only be the case if there are
      // cycles in the imports.
      if (declaration is ClassMirror && declaration.superclass != null) {
        if (declaration.superclass.owner == declaration.owner) {
          _readAnnotations(declaration.superclass);
        } else {
          var superMetas = declaration.superclass.metadata
              .where((m) => _filterMetadata(declaration.superclass, m))
              .toList();
          if (superMetas.isNotEmpty) {
            throw new UnsupportedError(
                'We have detected a cycle in your import graph when running '
                'static initializers on ${declaration.qualifiedName}. This means '
                'the super class ${declaration.superclass.qualifiedName} has a '
                'dependency on this library (possibly transitive).');
          }
        }
      }

      var annotatedValue;
      if (declaration is ClassMirror) {
        annotatedValue = declaration.reflectedType;
      } else if (declaration is MethodMirror) {
        if (declaration.owner is! LibraryMirror) {
          throw _TOP_LEVEL_FUNCTIONS_ONLY;
        }
        annotatedValue = (declaration.owner as ObjectMirror)
            .getField(declaration.simpleName).reflectee;
      } else if (declaration is LibraryMirror) {
        annotatedValue = declaration.qualifiedName;
      } else {
        throw _UNSUPPORTED_DECLARATION;
      }
      _initQueue.addLast(() => meta.reflectee.initialize(annotatedValue));
    }
    ;
  }

  bool _filterMetadata(DeclarationMirror declaration, InstanceMirror meta) {
    // We only care about StaticInitializer annotations
    if (meta.reflectee is! StaticInitializer) return false;
    // Respect the typeFilter
    if (typeFilter != null &&
        !typeFilter.any((t) => meta.reflectee.runtimeType == t)) {
      return false;
    }
    // Respect the customFilter
    if (customFilter != null && !customFilter(meta.reflectee)) return false;
    // Filter out already seen annotations
    if (!_annotationsFound.containsKey(declaration)) {
      _annotationsFound[declaration] = new Set<InstanceMirror>();
    }
    if (_annotationsFound[declaration].contains(meta)) return false;
    return true;
  }
}

final _TOP_LEVEL_FUNCTIONS_ONLY = new UnsupportedError(
    'Only top level methods are supported for StaticInitializers');

final _UNSUPPORTED_DECLARATION = new UnsupportedError(
    'StaticInitializers are only supported on libraries, classes, and top '
    'level methods');
