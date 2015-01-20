// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library static_init.transformer;

import 'dart:async';
import 'dart:collection' show Queue;
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:barback/barback.dart';
import 'package:code_transformers/resolver.dart';
import 'package:path/path.dart' as path;

/// Removes the mirror-based initialization logic and replaces it with static
/// logic.
class InitializeTransformer extends Transformer {
  final BarbackSettings _settings;
  final Resolvers _resolvers;

  InitializeTransformer.asPlugin(this._settings)
      : _resolvers = new Resolvers.fromMock({
        // The list of types below is derived from:
        //   * types that are used internally by the resolver (see
        //   _initializeFrom in resolver.dart).
        // TODO(jakemac): Move this into code_transformers so it can be shared.
        'dart:core': '''
            library dart.core;
            class Object {}
            class Function {}
            class StackTrace {}
            class Symbol {}
            class Type {}

            class String extends Object {}
            class bool extends Object {}
            class num extends Object {}
            class int extends num {}
            class double extends num {}
            class DateTime extends Object {}
            class Null extends Object {}

            class Deprecated extends Object {
              final String expires;
              const Deprecated(this.expires);
            }
            const Object deprecated = const Deprecated("next release");
            class _Override { const _Override(); }
            const Object override = const _Override();
            class _Proxy { const _Proxy(); }
            const Object proxy = const _Proxy();

            class List<V> extends Object {}
            class Map<K, V> extends Object {}
            ''',
        'dart:html': '''
            library dart.html;
            class HtmlElement {}
            ''',
      });

  String get _entryPoint => _settings.configuration['entryPoint'];
  String get _newEntryPoint {
    var val = _settings.configuration['newEntryPoint'];
    if (val == null) val = _entryPoint.replaceFirst('.dart', '.bootstrap.dart');
    return val;
  }

  bool isPrimary(AssetId id) => _entryPoint == id.path;

  Future apply(Transform transform) {
    var newEntryPointId =
        new AssetId(transform.primaryInput.id.package, _newEntryPoint);
    return transform.hasInput(newEntryPointId).then((exists) {
      if (exists) {
        transform.logger
            .error('New entry point file $newEntryPointId already exists.');
      } else {
        return _resolvers
            .get(transform)
            .then((resolver) => new _BootstrapFileBuilder(resolver, transform,
                transform.primaryInput.id, newEntryPointId).run());
      }
    });
  }
}

class _BootstrapFileBuilder {
  final Resolver _resolver;
  final Transform _transform;
  AssetId _entryPoint;
  AssetId _newEntryPoint;

  /// The resolved static_init library.
  LibraryElement _staticInitLibrary;
  /// The resolved StaticInitializer class from the static_init library.
  ClassElement _staticInitializer;

  /// Queue for intialization annotations.
  final _initQueue = new Queue<_InitializerData>();
  /// All the annotations we have seen for each element
  final _seenAnnotations = new Map<Element, Set<ElementAnnotation>>();

  TransformLogger _logger;

  _BootstrapFileBuilder(
      this._resolver, this._transform, this._entryPoint, this._newEntryPoint) {
    _logger = _transform.logger;
    _staticInitLibrary = _resolver
        .getLibrary(new AssetId('static_init', 'lib/static_init.dart'));
    _staticInitializer = _staticInitLibrary.getType('StaticInitializer');
  }

  /// Adds the new entry point file to the transform. Should only be ran once.
  void run() {
    var entryLib = _resolver.getLibrary(_entryPoint);
    _readLibraries(entryLib);

    _transform.addOutput(
        new Asset.fromString(_newEntryPoint, _buildNewEntryPoint(entryLib)));
  }

  /// Reads StaticInitializer annotations on this library and all
  /// its dependencies in post-order.
  void _readLibraries(LibraryElement library, [Set<LibraryElement> seen]) {
    if (seen == null) seen = new Set<LibraryElement>();
    seen.add(library);

    // Visit all our dependencies.
    for (var importedLibrary in _sortedLibraryImports(library)) {
      // Don't include anything from the sdk.
      if (importedLibrary.isInSdk) continue;
      if (seen.contains(importedLibrary)) continue;
      _readLibraries(importedLibrary, seen);
    }

    // Read annotations in this order: library, top level methods, classes.
    _readAnnotations(library);
    for (var method in _topLevelMethodsOfLibrary(library, seen)) {
      _readAnnotations(method);
    }
    for (var clazz in _classesOfLibrary(library, seen)) {
      var superClass = clazz.supertype;
      while (superClass != null) {
        if (_readAnnotations(superClass.element) &&
            superClass.element.library != clazz.library) {
          _logger.warning(
              'We have detected a cycle in your import graph when running '
              'static initializers on ${clazz.name}. This means the super '
              'class ${superClass.name} has a dependency on this library '
              '(possibly transitive).');
        }
        superClass = superClass.superclass;
      }
      _readAnnotations(clazz);
    }
  }

  bool _readAnnotations(Element element) {
    var found = false;
    element.metadata.where((ElementAnnotation meta) {
      // First filter out anything that is not a StaticInitializer.
      var e = meta.element;
      if (e is PropertyAccessorElement) {
        return _isStaticInitializer(e.variable.evaluationResult.value.type);
      } else if (e is ConstructorElement) {
        return _isStaticInitializer(e.returnType);
      }
      return false;
    }).where((ElementAnnotation meta) {
      _seenAnnotations.putIfAbsent(element, () => new Set<ElementAnnotation>());
      return !_seenAnnotations[element].contains(meta);
    }).forEach((ElementAnnotation meta) {
      _seenAnnotations[element].add(meta);
      _initQueue.addLast(new _InitializerData(element, meta));
      found = true;
    });
    return found;
  }

  String _buildNewEntryPoint(LibraryElement entryLib) {
    var importsBuffer = new StringBuffer();
    var initializersBuffer = new StringBuffer();
    var libraryPrefixes = new Map<LibraryElement, String>();

    // Import the static_loader and original entry point.
    importsBuffer.writeln(
        "import 'package:static_init/src/static_loader.dart';");
    _maybeWriteImport(entryLib, libraryPrefixes, importsBuffer);

    initializersBuffer.writeln('  initializers.addAll([');
    while (_initQueue.isNotEmpty) {
      var next = _initQueue.removeFirst();

      _maybeWriteImport(next.element.library, libraryPrefixes, importsBuffer);
      _maybeWriteImport(
          next.annotation.element.library, libraryPrefixes, importsBuffer);

      _writeInitializer(next, libraryPrefixes, initializersBuffer);
    }
    initializersBuffer.writeln('  ]);');

    // TODO(jakemac): copyright and library declaration
    return '''
$importsBuffer
main() {
$initializersBuffer
  i0.main();
}
''';
  }

  // Writes an import to library if it doesn't exist yet if libraries.
  _maybeWriteImport(LibraryElement library,
      Map<LibraryElement, String> libraries, StringBuffer buffer) {
    if (libraries.containsKey(library)) return;
    var prefix = 'i${libraries.length}';
    libraries[library] = prefix;
    _writeImport(library, prefix, buffer);
  }

  _writeImport(LibraryElement lib, String prefix, StringBuffer buffer) {
    AssetId id = (lib.source as dynamic).assetId;

    if (id.path.startsWith('lib/')) {
      var packagePath = id.path.replaceFirst('lib/', '');
      buffer.write("import 'package:${id.package}/${packagePath}'");
    } else if (id.package != _newEntryPoint.package) {
      _logger.error("Can't import `${id}` from `${_newEntryPoint}`");
    } else if (id.path.split(path.separator)[0] ==
        _newEntryPoint.path.split(path.separator)[0]) {
      var relativePath =
          path.relative(id.path, from: path.dirname(_newEntryPoint.path));
      buffer.write("import '${relativePath}'");
    } else {
      _logger.error("Can't import `${id}` from `${_newEntryPoint}`");
    }
    buffer.writeln(' as $prefix;');
  }

  _writeInitializer(_InitializerData data,
      Map<LibraryElement, String> libraryPrefixes, StringBuffer buffer) {
    final annotationElement = data.annotation.element;
    final element = data.element;

    final metaPrefix = libraryPrefixes[annotationElement.library];
    var elementString;
    if (element is LibraryElement) {
      elementString = '#${element.name}';
    } else if (element is ClassElement || element is FunctionElement) {
      elementString =
          '${libraryPrefixes[data.element.library]}.${element.name}';
    } else {
      _logger.error('StaticInitializers can only be applied to top level '
          'functions, libraries, and classes.');
    }

    if (annotationElement is ConstructorElement) {
      var node = data.element.node;
      List<Annotation> astMeta;
      if (node is SimpleIdentifier) {
        astMeta = node.parent.parent.metadata;
      } else if (node is ClassDeclaration || node is FunctionDeclaration) {
        astMeta = node.metadata;
      } else {
        _logger.error(
            'StaticInitializer annotations are only supported on libraries, '
            'classes, and top level methods. Found $node.');
      }
      final annotation =
          astMeta.firstWhere((m) => m.elementAnnotation == data.annotation);
      final clazz = annotation.name;
      final constructor = annotation.constructorName == null
          ? ''
          : '.${annotation.constructorName}';
      // TODO(jakemac): Support more than raw values here
      // https://github.com/dart-lang/static_init/issues/5
      final args = annotation.arguments;
      buffer.write('''
    new InitEntry(const $metaPrefix.${clazz}$constructor$args, $elementString),
''');
    } else if (annotationElement is PropertyAccessorElement) {
      buffer.write('''
    new InitEntry($metaPrefix.${annotationElement.name}, $elementString),
''');
    }
  }

  bool _isStaticInitializer(InterfaceType type) {
    if (type == null) return false;
    if (type.element.type == _staticInitializer.type) return true;
    if (_isStaticInitializer(type.superclass)) return true;
    for (var interface in type.interfaces) {
      if (_isStaticInitializer(interface)) return true;
    }
    return false;
  }

  /// Retrieves all top-level methods that are visible if you were to import
  /// [lib]. This includes exported methods from other libraries too.
  List<FunctionElement> _topLevelMethodsOfLibrary(
      LibraryElement library, Set<LibraryElement> seen) {
    var result = [];
    result.addAll(library.units.expand((u) => u.functions));
    for (var export in library.exports) {
      if (seen.contains(export.exportedLibrary)) continue;
      var exported = _topLevelMethodsOfLibrary(export.exportedLibrary, seen);
      _filter(exported, export.combinators);
      result.addAll(exported);
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  /// Retrieves all classes that are visible if you were to import [lib]. This
  /// includes exported classes from other libraries.
  List<ClassElement> _classesOfLibrary(
      LibraryElement library, Set<LibraryElement> seen) {
    var result = [];
    result.addAll(library.units.expand((u) => u.types));
    for (var export in library.exports) {
      if (seen.contains(export.exportedLibrary)) continue;
      var exported = _classesOfLibrary(export.exportedLibrary, seen);
      _filter(exported, export.combinators);
      result.addAll(exported);
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  /// Filters [elements] that come from an export, according to its show/hide
  /// combinators. This modifies [elements] in place.
  void _filter(List<Element> elements, List<NamespaceCombinator> combinators) {
    for (var c in combinators) {
      if (c is ShowElementCombinator) {
        var show = c.shownNames.toSet();
        elements.retainWhere((e) => show.contains(e.displayName));
      } else if (c is HideElementCombinator) {
        var hide = c.hiddenNames.toSet();
        elements.removeWhere((e) => hide.contains(e.displayName));
      }
    }
  }

  Iterable<LibraryElement> _sortedLibraryImports(LibraryElement library) =>
      (new List.from(library.imports)
    ..sort((ImportElement a, ImportElement b) {
      // dart: imports don't have a uri
      if (a.uri == null && b.uri != null) return -1;
      if (b.uri == null && a.uri != null) return 1;
      if (a.uri == null && b.uri == null) {
        return a.importedLibrary.name.compareTo(b.importedLibrary.name);
      }

      // package: imports next
      var aIsPackage = a.uri.startsWith('package:');
      var bIsPackage = b.uri.startsWith('package:');
      if (aIsPackage && !bIsPackage) {
        return -1;
      } else if (bIsPackage && !aIsPackage) {
        return 1;
      } else if (bIsPackage && aIsPackage) {
        return a.uri.compareTo(b.uri);
      }

      // And finally compare based on the relative uri if both are file paths.
      var aUri = path.relative(a.source.uri.path,
          from: path.dirname(library.source.uri.path));
      var bUri = path.relative(b.source.uri.path,
          from: path.dirname(library.source.uri.path));
      return aUri.compareTo(bUri);
    })).map((import) => import.importedLibrary);
}

// Element/ElementAnnotation pair.
class _InitializerData {
  final Element element;
  final ElementAnnotation annotation;

  _InitializerData(this.element, this.annotation);
}
