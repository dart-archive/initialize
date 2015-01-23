// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.transformer;

import 'dart:async';
import 'dart:collection' show Queue;
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:barback/barback.dart';
import 'package:code_transformers/resolver.dart';
import 'package:html5lib/dom.dart' as dom;
import 'package:html5lib/parser.dart' show parse;
import 'package:path/path.dart' as path;

/// Removes the mirror-based initialization logic and replaces it with static
/// logic.
class InitializeTransformer extends Transformer {
  final Resolvers _resolvers;
  final String _entryPoint;
  final String _newEntryPoint;
  final String _htmlEntryPoint;

  InitializeTransformer(
      this._entryPoint, this._newEntryPoint, this._htmlEntryPoint)
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

  factory InitializeTransformer.asPlugin(BarbackSettings settings) {
    var entryPoint = settings.configuration['entry_point'];
    var newEntryPoint = settings.configuration['new_entry_point'];
    if (newEntryPoint == null) {
      newEntryPoint = entryPoint.replaceFirst('.dart', '.bootstrap.dart');
    }
    var htmlEntryPoint = settings.configuration['html_entry_point'];
    return new InitializeTransformer(entryPoint, newEntryPoint, htmlEntryPoint);
  }

  bool isPrimary(AssetId id) =>
      _entryPoint == id.path || _htmlEntryPoint == id.path;

  Future apply(Transform transform) {
    if (transform.primaryInput.id.path == _entryPoint) {
      return _buildBootstrapFile(transform);
    } else if (transform.primaryInput.id.path == _htmlEntryPoint) {
      return _replaceEntryWithBootstrap(transform);
    }
    return null;
  }

  Future _buildBootstrapFile(Transform transform) {
    var newEntryPointId =
        new AssetId(transform.primaryInput.id.package, _newEntryPoint);
    return transform.hasInput(newEntryPointId).then((exists) {
      if (exists) {
        transform.logger
            .error('New entry point file $newEntryPointId already exists.');
      } else {
        return _resolvers.get(transform).then((resolver) {
          new _BootstrapFileBuilder(resolver, transform,
              transform.primaryInput.id, newEntryPointId).run();
          resolver.release();
        });
      }
    });
  }

  Future _replaceEntryWithBootstrap(Transform transform) {
    // For now at least, _htmlEntryPoint, _entryPoint, and _newEntryPoint need
    // to be in the same folder.
    // TODO(jakemac): support package urls with _entryPoint or _newEntryPoint
    // in `lib`, and _htmlEntryPoint in another directory.
    var _expectedDir = path.split(_htmlEntryPoint)[0];
    if (_expectedDir != path.split(_entryPoint)[0] ||
        _expectedDir != path.split(_newEntryPoint)[0]) {
      transform.logger.error(
          'htmlEntryPoint, entryPoint, and newEntryPoint(if supplied) all must '
          'be in the same top level directory.');
    }

    return transform.primaryInput.readAsString().then((String html) {
      var found = false;
      var doc = parse(html);
      var scripts = doc.querySelectorAll('script[type="application/dart"]');
      for (dom.Element script in scripts) {
        if (!_isEntryPointScript(script)) continue;
        script.attributes['src'] = _relativeDartEntryPath(_newEntryPoint);
        found = true;
      }
      if (!found) {
        transform.logger.error(
            'Unable to find script for $_entryPoint in $_htmlEntryPoint.');
      }
      return transform.addOutput(
          new Asset.fromString(transform.primaryInput.id, doc.outerHtml));
    });
  }

  // Checks if the src of this script tag is pointing at `_entryPoint`.
  bool _isEntryPointScript(dom.Element script) =>
      path.normalize(script.attributes['src']) ==
          _relativeDartEntryPath(_entryPoint);

  // The relative path from `_htmlEntryPoint` to `dartEntry`. You must ensure
  // that neither of these is null before calling this function.
  String _relativeDartEntryPath(String dartEntry) =>
      path.relative(dartEntry, from: path.dirname(_htmlEntryPoint));
}

class _BootstrapFileBuilder {
  final Resolver _resolver;
  final Transform _transform;
  AssetId _entryPoint;
  AssetId _newEntryPoint;

  /// The resolved initialize library.
  LibraryElement _initializeLibrary;
  /// The resolved Initializer class from the initialize library.
  ClassElement _initializer;

  /// Queue for intialization annotations.
  final _initQueue = new Queue<_InitializerData>();
  /// All the annotations we have seen for each element
  final _seenAnnotations = new Map<Element, Set<ElementAnnotation>>();

  TransformLogger _logger;

  _BootstrapFileBuilder(
      this._resolver, this._transform, this._entryPoint, this._newEntryPoint) {
    _logger = _transform.logger;
    _initializeLibrary =
        _resolver.getLibrary(new AssetId('initialize', 'lib/initialize.dart'));
    _initializer = _initializeLibrary.getType('Initializer');
  }

  /// Adds the new entry point file to the transform. Should only be ran once.
  void run() {
    var entryLib = _resolver.getLibrary(_entryPoint);
    _readLibraries(entryLib);

    _transform.addOutput(
        new Asset.fromString(_newEntryPoint, _buildNewEntryPoint(entryLib)));
  }

  /// Reads Initializer annotations on this library and all its dependencies in
  /// post-order.
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
              'initializers on ${clazz.name}. This means the super class '
              '${superClass.name} has a dependency on this library '
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
      // First filter out anything that is not a Initializer.
      var e = meta.element;
      if (e is PropertyAccessorElement) {
        return _isInitializer(e.variable.evaluationResult.value.type);
      } else if (e is ConstructorElement) {
        return _isInitializer(e.returnType);
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
    importsBuffer
        .writeln("import 'package:initialize/src/static_loader.dart';");
    libraryPrefixes[entryLib] = 'i0';

    initializersBuffer.writeln('  initializers.addAll([');
    while (_initQueue.isNotEmpty) {
      var next = _initQueue.removeFirst();

      libraryPrefixes.putIfAbsent(
          next.element.library, () => 'i${libraryPrefixes.length}');
      libraryPrefixes.putIfAbsent(
          next.annotation.element.library, () => 'i${libraryPrefixes.length}');

      _writeInitializer(next, libraryPrefixes, initializersBuffer);
    }
    initializersBuffer.writeln('  ]);');

    libraryPrefixes
        .forEach((lib, prefix) => _writeImport(lib, prefix, importsBuffer));

    // TODO(jakemac): copyright and library declaration
    return '''
$importsBuffer
main() {
$initializersBuffer
  i0.main();
}
''';
  }

  _writeImport(LibraryElement lib, String prefix, StringBuffer buffer) {
    AssetId id = (lib.source as dynamic).assetId;

    if (id.path.startsWith('lib/')) {
      var packagePath = id.path.replaceFirst('lib/', '');
      buffer.write("import 'package:${id.package}/${packagePath}'");
    } else if (id.package != _newEntryPoint.package) {
      _logger.error("Can't import `${id}` from `${_newEntryPoint}`");
    } else if (path.url.split(id.path)[0] ==
        path.url.split(_newEntryPoint.path)[0]) {
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
      _logger.error('Initializers can only be applied to top level functins, '
          'libraries, and classes.');
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
            'Initializer annotations are only supported on libraries, classes, '
            'and top level methods. Found $node.');
      }
      final annotation =
          astMeta.firstWhere((m) => m.elementAnnotation == data.annotation);
      final clazz = annotation.name;
      final constructor = annotation.constructorName == null
          ? ''
          : '.${annotation.constructorName}';
      // TODO(jakemac): Support more than raw values here
      // https://github.com/dart-lang/static_init/issues/5
      final args = _buildArgsString(annotation.arguments, libraryPrefixes);
      buffer.write('''
    new InitEntry(const $metaPrefix.${clazz}$constructor$args, $elementString),
''');
    } else if (annotationElement is PropertyAccessorElement) {
      buffer.write('''
    new InitEntry($metaPrefix.${annotationElement.name}, $elementString),
''');
    } else {
      _logger.error('Unsupported annotation type. Only constructors and '
          'properties are supported as initializers.');
    }
  }

  String _buildArgsString(
      ArgumentList args, Map<LibraryElement, String> libraryPrefixes) {
    var buffer = new StringBuffer();
    buffer.write('(');
    var first = true;
    for (var arg in args.arguments) {
      if (!first) buffer.write(', ');
      first = false;

      Expression expression;
      if (arg is NamedExpression) {
        buffer.write('${arg.name.label.name}: ');
        expression = arg.expression;
      } else {
        expression = arg;
      }

      buffer.write(_expressionString(expression, libraryPrefixes));
    }
    buffer.write(')');
    return buffer.toString();
  }

  String _expressionString(
      Expression expression, Map<LibraryElement, String> libraryPrefixes) {
    var buffer = new StringBuffer();
    if (expression is StringLiteral) {
      var value = expression.stringValue;
      if (value == null) {
        _logger.error('Only const strings are allowed in initializer '
            'expressions, found $expression');
      }
      value = value.replaceAll(r'\', r'\\').replaceAll(r"'", r"\'");
      buffer.write("'$value'");
    } else if (expression is BooleanLiteral ||
        expression is DoubleLiteral ||
        expression is IntegerLiteral ||
        expression is NullLiteral) {
      buffer.write('${expression}');
    } else if (expression is ListLiteral) {
      buffer.write('const [');
      var first = true;
      for (Expression listExpression in expression.elements) {
        if (!first) buffer.write(', ');
        first = false;
        buffer.write(_expressionString(listExpression, libraryPrefixes));
      }
      buffer.write(']');
    } else if (expression is MapLiteral) {
      buffer.write('const {');
      var first = true;
      for (MapLiteralEntry entry in expression.entries) {
        if (!first) buffer.write(', ');
        first = false;
        buffer.write(_expressionString(entry.key, libraryPrefixes));
        buffer.write(': ');
        buffer.write(_expressionString(entry.value, libraryPrefixes));
      }
      buffer.write('}');
    } else if (expression is Identifier) {
      var element = expression.bestElement;
      if (element == null || !element.isPublic) {
        _logger.error('Private constants are not supported in intializer '
            'constructors, found $element.');
      }
      libraryPrefixes.putIfAbsent(
          element.library, () => 'i${libraryPrefixes.length}');

      buffer.write('${libraryPrefixes[element.library]}.');
      if (element is ClassElement) {
        buffer.write(element.name);
      } else if (element is PropertyAccessorElement) {
        var variable = element.variable;
        if (variable is FieldElement) {
          buffer.write('${variable.enclosingElement.name}.');
        }
        buffer.write('${variable.name}');
      } else {
        _logger.error('Unsupported argument to initializer constructor.');
      }
    } else {
      _logger.error('Only literals and identifiers are allowed for initializer '
          'expressions, found $expression.');
    }
    return buffer.toString();
  }

  bool _isInitializer(InterfaceType type) {
    if (type == null) return false;
    if (type.element.type == _initializer.type) return true;
    if (_isInitializer(type.superclass)) return true;
    for (var interface in type.interfaces) {
      if (_isInitializer(interface)) return true;
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
