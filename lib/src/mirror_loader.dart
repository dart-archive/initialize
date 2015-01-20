// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.mirror_loader;

import 'dart:collection' show Queue;
import 'dart:mirrors';
import 'package:path/path.dart' as path;
import 'package:initialize/initialize.dart';

Queue<Function> loadInitializers(
    {List<Type> typeFilter, InitializerFilter customFilter}) {
  return new InitializationCrawler(typeFilter, customFilter).run();
}

// Crawls a library and all its dependencies for `Initializer` annotations using
// mirrors
class InitializationCrawler {
  // Set of all visited annotations, keys are the declarations that were
  // annotated, values are the annotations that have been processed.
  static final _annotationsFound =
      new Map<DeclarationMirror, Set<InstanceMirror>>();

  // If non-null, then only these annotations should be processed.
  final List<Type> typeFilter;

  // If non-null, then only annotations which return true when passed to this
  // function will be processed.
  final InitializerFilter customFilter;

  // The root library that we start parsing from.
  LibraryMirror _root;

  InitializationCrawler(this.typeFilter, this.customFilter,
      {LibraryMirror root}) {
    _root = root == null ? currentMirrorSystem().isolate.rootLibrary : root;
  }

  // The primary function in this class, invoke it to crawl and collect all the
  // annotations into a queue of init functions.
  Queue<Function> run() => _readLibraryDeclarations(_root);

  // Reads Initializer annotations on this library and all its dependencies in
  // post-order.
  Queue<Function> _readLibraryDeclarations(LibraryMirror lib,
      [Set<LibraryMirror> librariesSeen, Queue<Function> queue]) {
    if (librariesSeen == null) librariesSeen = new Set<LibraryMirror>();
    if (queue == null) queue = new Queue<Function>();
    librariesSeen.add(lib);

    // First visit all our dependencies.
    for (var dependency in _sortedLibraryDependencies(lib)) {
      // Skip dart: imports, they never use this package.
      if (dependency.targetLibrary.uri.toString().startsWith('dart:')) continue;
      if (librariesSeen.contains(dependency.targetLibrary)) continue;

      _readLibraryDeclarations(dependency.targetLibrary, librariesSeen, queue);
    }

    // Second parse the library directive annotations.
    _readAnnotations(lib, queue);

    // Last, parse all class and method annotations.
    for (var declaration in _sortedLibraryDeclarations(lib)) {
      _readAnnotations(declaration, queue);
      // Check classes for static annotations which are not supported
      if (declaration is ClassMirror) {
        for (var classDeclaration in declaration.declarations.values) {
          _readAnnotations(classDeclaration, queue);
        }
      }
    }

    return queue;
  }

  Iterable<LibraryDependencyMirror> _sortedLibraryDependencies(
      LibraryMirror lib) => new List.from(lib.libraryDependencies)
    ..sort((a, b) {
      var aScheme = a.targetLibrary.uri.scheme;
      var bScheme = b.targetLibrary.uri.scheme;
      if (aScheme != 'file' && bScheme == 'file') return -1;
      if (bScheme != 'file' && aScheme == 'file') return 1;
      return _relativeLibraryUri(a).compareTo(_relativeLibraryUri(b));
    });

  String _relativeLibraryUri(LibraryDependencyMirror lib) {
    if (lib.targetLibrary.uri.scheme == 'file' &&
        lib.sourceLibrary.uri.scheme == 'file') {
      return path.relative(lib.targetLibrary.uri.path,
          from: path.dirname(lib.sourceLibrary.uri.path));
    }
    return lib.targetLibrary.uri.toString();
  }

  Iterable<DeclarationMirror> _sortedLibraryDeclarations(LibraryMirror lib) =>
      lib.declarations.values
          .where((d) => d is ClassMirror || d is MethodMirror)
          .toList()
    ..sort((a, b) {
      if (a is MethodMirror && b is ClassMirror) return -1;
      if (a is ClassMirror && b is MethodMirror) return 1;
      return _declarationName(a).compareTo(_declarationName(b));
    });

  String _declarationName(DeclarationMirror declaration) =>
      MirrorSystem.getName(declaration.qualifiedName);

  // Reads annotations on declarations and adds them to `_initQueue` if they are
  // initializers.
  void _readAnnotations(DeclarationMirror declaration, Queue<Function> queue) {
    var annotations =
        declaration.metadata.where((m) => _filterMetadata(declaration, m));
    for (var meta in annotations) {
      _annotationsFound[declaration].add(meta);

      // Initialize super classes first, if they are in the same library,
      // otherwise we throw an error. This can only be the case if there are
      // cycles in the imports.
      if (declaration is ClassMirror && declaration.superclass != null) {
        if (declaration.superclass.owner == declaration.owner) {
          _readAnnotations(declaration.superclass, queue);
        } else {
          var superMetas = declaration.superclass.metadata
              .where((m) => _filterMetadata(declaration.superclass, m))
              .toList();
          if (superMetas.isNotEmpty) {
            throw new UnsupportedError(
                'We have detected a cycle in your import graph when running '
                'initializers on ${declaration.qualifiedName}. This means the '
                'super class ${declaration.superclass.qualifiedName} has a '
                'dependency on this library (possibly transitive).');
          }
        }
      }

      var annotatedValue;
      if (declaration is ClassMirror) {
        annotatedValue = declaration.reflectedType;
      } else if (declaration is MethodMirror) {
        if (declaration.owner is! LibraryMirror) {
          // TODO(jakemac): Support static class methods.
          throw _TOP_LEVEL_FUNCTIONS_ONLY;
        }
        annotatedValue = (declaration.owner as ObjectMirror)
            .getField(declaration.simpleName).reflectee;
      } else if (declaration is LibraryMirror) {
        annotatedValue = declaration.qualifiedName;
      } else {
        throw _UNSUPPORTED_DECLARATION;
      }
      queue.addLast(() => meta.reflectee.initialize(annotatedValue));
    }
  }

  // Filter function that returns true only if `meta` is an `Initializer`,
  // it passes the `typeFilter` and `customFilter` if they exist, and it has not
  // yet been seen.
  bool _filterMetadata(DeclarationMirror declaration, InstanceMirror meta) {
    if (meta.reflectee is! Initializer) return false;
    if (typeFilter != null &&
        !typeFilter.any((t) => meta.reflectee.runtimeType == t)) {
      return false;
    }
    if (customFilter != null && !customFilter(meta.reflectee)) return false;
    if (!_annotationsFound.containsKey(declaration)) {
      _annotationsFound[declaration] = new Set<InstanceMirror>();
    }
    if (_annotationsFound[declaration].contains(meta)) return false;
    return true;
  }
}

final _TOP_LEVEL_FUNCTIONS_ONLY = new UnsupportedError(
    'Only top level methods are supported for initializers');

final _UNSUPPORTED_DECLARATION = new UnsupportedError(
    'Initializers are only supported on libraries, classes, and top level '
    'methods');
