// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
@TestOn('vm')
library initialize.transformer_test;

import 'common.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:dart_style/dart_style.dart';
import 'package:initialize/transformer.dart';
import 'package:test/test.dart';

var formatter = new DartFormatter();

main() {
  group('Html entry points', htmlEntryPointTests);
  group('Dart entry points', dartEntryPointTests);
  group('InitializerPlugins', pluginTests);
}

void htmlEntryPointTests() {
  var phases = [
    [
      new InitializeTransformer(['web/*.html'])
    ]
  ];

  testPhases('basic', phases, {
    'a|web/index.html': '''
        <html><head></head><body>
          <script type="application/dart" src="index.dart"></script>
        </body></html>
        '''
        .replaceAll('        ', ''),
    'a|web/index.dart': '''
        library web_foo;

        import 'foo.dart';
        ''',
    'a|web/foo.dart': '''
        @constInit
        library foo;

        import 'package:initialize/initialize.dart';
        import 'package:test_initializers/common.dart';
        import 'package:bar/bar.dart';

        @constInit
        class Foo extends Bar {}

        @initMethod
        foo() {}
        ''',
    'bar|lib/bar.dart': '''
        @DynamicInit('bar')
        @DynamicInit('bar2')
        library bar;

        import 'package:initialize/initialize.dart';
        import 'package:test_initializers/common.dart';
        import 'baz.dart';

        @DynamicInit('Bar')
        @DynamicInit('Bar2')
        class Bar {}

        @DynamicInit('bar()')
        @initMethod
        bar() {}
        ''',
    'bar|lib/baz.dart': '''
        @constInit
        library baz;

        import 'package:test_initializers/common.dart';
        ''',
    // Mock out the Initialize package plus some initializers.
    'initialize|lib/initialize.dart': mockInitialize,
    'test_initializers|lib/common.dart': commonInitializers,
  }, {
    'a|web/index.html': '''
        <html><head></head><body>
          <script type="application/dart" src="index.initialize.dart"></script>

        </body></html>'''
        .replaceAll('        ', ''),
    'a|web/index.initialize.dart': formatter.format('''
        import 'package:initialize/src/static_loader.dart';
        import 'package:initialize/initialize.dart';
        import 'index.dart' as i0;
        import 'package:bar/baz.dart' as i1;
        import 'package:test_initializers/common.dart' as i2;
        import 'package:bar/bar.dart' as i3;
        import 'package:initialize/initialize.dart' as i4;
        import 'foo.dart' as i5;

        main() {
          initializers.addAll([
            new InitEntry(i2.constInit, const LibraryIdentifier(#baz, 'bar', 'baz.dart')),
            new InitEntry(const i2.DynamicInit('bar'), const LibraryIdentifier(#bar, 'bar', 'bar.dart')),
            new InitEntry(const i2.DynamicInit('bar2'), const LibraryIdentifier(#bar, 'bar', 'bar.dart')),
            new InitEntry(const i2.DynamicInit('bar()'), i3.bar),
            new InitEntry(i4.initMethod, i3.bar),
            new InitEntry(const i2.DynamicInit('Bar'), i3.Bar),
            new InitEntry(const i2.DynamicInit('Bar2'), i3.Bar),
            new InitEntry(i2.constInit, const LibraryIdentifier(#foo, null, 'foo.dart')),
            new InitEntry(i4.initMethod, i5.foo),
            new InitEntry(i2.constInit, i5.Foo),
          ]);

          return i0.main();
        }
        ''')
  }, []);
}

void dartEntryPointTests() {
  var phases = [
    [
      new InitializeTransformer(['web/index.dart'])
    ]
  ];

  testPhases('constructor arguments', phases, {
    'a|web/index.dart': '''
        @DynamicInit(foo)
        @DynamicInit(_foo)
        @DynamicInit(Foo.foo)
        @DynamicInit(bar.Foo.bar)
        @DynamicInit(bar.Foo.foo)
        @DynamicInit(const [foo, Foo.foo, 'foo'])
        @DynamicInit(const {'foo': foo, 'Foo.foo': Foo.foo, 'bar': 'bar'})
        @DynamicInit('foo')
        @DynamicInit(true)
        @DynamicInit(null)
        @DynamicInit(1)
        @DynamicInit(1.1)
        @DynamicInit('foo-\$x\${y}')
        @DynamicInit(1 + 2)
        @DynamicInit(1.0 + 0.2)
        @DynamicInit(1 == 1)
        @NamedArgInit(1, name: 'Bill')
        library web_foo;

        import 'package:test_initializers/common.dart';
        import 'foo.dart';
        import 'foo.dart' as bar;

        const x = 'x';
        const y = 'y';
        const _foo = '_foo';

        class MyConst {
          const MyConst;
        }
        ''',
    'a|web/foo.dart': '''
        library foo;

        const String foo = 'foo';

        class Bar {
          const Bar();
        }

        class Foo {
          static foo = 'Foo.foo';
          static bar = const Bar();
        }
        ''',
    // Mock out the Initialize package plus some initializers.
    'initialize|lib/initialize.dart': mockInitialize,
    'test_initializers|lib/common.dart': commonInitializers,
  }, {
    'a|web/index.initialize.dart': formatter.format('''
        import 'package:initialize/src/static_loader.dart';
        import 'package:initialize/initialize.dart';
        import 'index.dart' as i0;
        import 'package:test_initializers/common.dart' as i1;
        import 'foo.dart' as i2;

        main() {
          initializers.addAll([
            new InitEntry(const i1.DynamicInit(i2.foo), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit('_foo'), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(i2.Foo.foo), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(i2.Foo.bar), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(i2.Foo.foo), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(const [i2.foo, i2.Foo.foo, 'foo']), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(const {'foo': i2.foo, 'Foo.foo': i2.Foo.foo, 'bar': 'bar'}), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit('foo'), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(true), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(null), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(1), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(1.1), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit('foo-xy'), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(3), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(1.2), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(true), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.NamedArgInit(1, name: 'Bill'), const LibraryIdentifier(#web_foo, null, 'index.dart')),
          ]);

          return i0.main();
        }
        ''')
  }, []);

  testPhases('exported library annotations', phases, {
    'a|web/index.dart': '''
        library web_foo;

        export 'foo.dart';
        ''',
    'a|web/foo.dart': '''
        @constInit
        library foo;

        import 'package:test_initializers/common.dart';

        @constInit
        foo() {};

        @constInit
        class Foo {}
        ''',
    // Mock out the Initialize package plus some initializers.
    'initialize|lib/initialize.dart': mockInitialize,
    'test_initializers|lib/common.dart': commonInitializers,
  }, {
    'a|web/index.initialize.dart': formatter.format('''
        import 'package:initialize/src/static_loader.dart';
        import 'package:initialize/initialize.dart';
        import 'index.dart' as i0;
        import 'foo.dart' as i1;
        import 'package:test_initializers/common.dart' as i2;

        main() {
          initializers.addAll([
            new InitEntry(i2.constInit, const LibraryIdentifier(#foo, null, 'foo.dart')),
            new InitEntry(i2.constInit, i1.foo),
            new InitEntry(i2.constInit, i1.Foo),
          ]);

          return i0.main();
        }
        ''')
  }, []);

  testPhases('imports from exported libraries', phases, {
    'a|web/index.dart': '''
        library web_foo;

        export 'foo.dart';
        ''',
    'a|web/foo.dart': '''
        library foo;

        import 'foo/bar.dart';
        ''',
    'a|web/foo/bar.dart': '''
        @constInit
        library bar;

        import 'package:test_initializers/common.dart';

        @constInit
        bar() {};

        @constInit
        class Bar {}
        ''',
    // Mock out the Initialize package plus some initializers.
    'initialize|lib/initialize.dart': mockInitialize,
    'test_initializers|lib/common.dart': commonInitializers,
  }, {
    'a|web/index.initialize.dart': formatter.format('''
        import 'package:initialize/src/static_loader.dart';
        import 'package:initialize/initialize.dart';
        import 'index.dart' as i0;
        import 'foo/bar.dart' as i1;
        import 'package:test_initializers/common.dart' as i2;

        main() {
          initializers.addAll([
            new InitEntry(i2.constInit, const LibraryIdentifier(#bar, null, 'foo/bar.dart')),
            new InitEntry(i2.constInit, i1.bar),
            new InitEntry(i2.constInit, i1.Bar),
          ]);

          return i0.main();
        }
        ''')
  }, []);

  testPhases('library parts and exports', phases, {
    'a|web/index.dart': '''
        @constInit
        library index;

        import 'package:test_initializers/common.dart';
        export 'export.dart';

        part 'foo.dart';
        part 'bar.dart';

        @constInit
        index() {};

        @constInit
        class Index {};
        ''',
    'a|web/foo.dart': '''
        part of index;

        @constInit
        foo() {};

        @constInit
        class Foo {};
        ''',
    'a|web/bar.dart': '''
        part of index;

        @constInit
        bar() {};

        @constInit
        class Bar {};
        ''',
    'a|web/export.dart': '''
        @constInit
        library export;

        import 'package:test_initializers/common.dart';

        @constInit
        class Export {};
        ''',
    // Mock out the Initialize package plus some initializers.
    'initialize|lib/initialize.dart': mockInitialize,
    'test_initializers|lib/common.dart': commonInitializers,
  }, {
    'a|web/index.initialize.dart': formatter.format('''
        import 'package:initialize/src/static_loader.dart';
        import 'package:initialize/initialize.dart';
        import 'index.dart' as i0;
        import 'export.dart' as i1;
        import 'package:test_initializers/common.dart' as i2;

        main() {
          initializers.addAll([
            new InitEntry(i2.constInit, const LibraryIdentifier(#export, null, 'export.dart')),
            new InitEntry(i2.constInit, i1.Export),
            new InitEntry(i2.constInit, const LibraryIdentifier(#index, null, 'index.dart')),
            new InitEntry(i2.constInit, i0.bar),
            new InitEntry(i2.constInit, i0.foo),
            new InitEntry(i2.constInit, i0.index),
            new InitEntry(i2.constInit, i0.Bar),
            new InitEntry(i2.constInit, i0.Foo),
            new InitEntry(i2.constInit, i0.Index),
          ]);

          return i0.main();
        }
        ''')
  }, []);
}

class SkipConstructorsPlugin extends InitializerPlugin {
  bool shouldApply(InitializerPluginData data) {
    return data.initializer.annotationElement.element is ConstructorElement;
  }

  String apply(_) => null;
}

void pluginTests() {
  var phases = [
    [
      new InitializeTransformer(['web/index.dart'],
          plugins: [new SkipConstructorsPlugin()])
    ]
  ];

  testPhases('can omit statements', phases, {
    'a|web/index.dart': '''
        library index;

        import 'package:initialize/initialize.dart';
        import 'package:test_initializers/common.dart';
        import 'foo.dart';

        @initMethod
        @DynamicInit('index')
        index() {}
        ''',
    'a|web/foo.dart': '''
        library foo;

        import 'package:initialize/initialize.dart';
        import 'package:test_initializers/common.dart';

        @initMethod
        @DynamicInit('Foo')
        foo() {}
        ''',
    // Mock out the Initialize package plus some initializers.
    'initialize|lib/initialize.dart': mockInitialize,
    'test_initializers|lib/common.dart': commonInitializers,
  }, {
    'a|web/index.initialize.dart': formatter.format('''
        import 'package:initialize/src/static_loader.dart';
        import 'package:initialize/initialize.dart';
        import 'index.dart' as i0;
        import 'foo.dart' as i1;
        import 'package:initialize/initialize.dart' as i2;
        import 'package:test_initializers/common.dart' as i3;

        main() {
          initializers.addAll([
            new InitEntry(i2.initMethod, i1.foo),
            new InitEntry(i2.initMethod, i0.index),
          ]);

          return i0.main();
        }
        ''')
  }, []);
}
