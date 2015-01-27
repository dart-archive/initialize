// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library initialize.transformer_test;

import 'common.dart';
import 'package:initialize/transformer.dart';
import 'package:unittest/compact_vm_config.dart';

main() {
  useCompactVMConfiguration();

  var transformer = new InitializeTransformer(
      'web/index.dart', 'web/index.bootstrap.dart', 'web/index.html');

  testPhases('basic', [[transformer]], {
    'a|web/index.html': '''
        <html><head></head><body>
          <script type="application/dart" src="index.dart"></script>
        </body></html>
        '''.replaceAll('        ', ''),
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
          <script type="application/dart" src="index.bootstrap.dart"></script>

        </body></html>'''.replaceAll('        ', ''),
    'a|web/index.bootstrap.dart': '''
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

          i0.main();
        }
        '''.replaceAll('        ', '')
  }, []);

  testPhases('constructor arguments', [[transformer]], {
    'a|web/index.dart': '''
        @DynamicInit(foo)
        @DynamicInit(Foo.foo)
        @DynamicInit(const [foo, Foo.foo, 'foo'])
        @DynamicInit(const {'foo': foo, 'Foo.foo': Foo.foo, 'bar': 'bar'})
        @DynamicInit('foo')
        @DynamicInit(true)
        @DynamicInit(null)
        @DynamicInit(1)
        @DynamicInit(1.1)
        @NamedArgInit(1, name: 'Bill')
        library web_foo;

        import 'package:test_initializers/common.dart';
        import 'foo.dart';
        ''',
    'a|web/foo.dart': '''
        library foo;

        const String foo = 'foo';

        class Foo {
          static foo = 'Foo.foo';
        }
        ''',
    // Mock out the Initialize package plus some initializers.
    'initialize|lib/initialize.dart': mockInitialize,
    'test_initializers|lib/common.dart': commonInitializers,
  }, {
    'a|web/index.bootstrap.dart': '''
        import 'package:initialize/src/static_loader.dart';
        import 'package:initialize/initialize.dart';
        import 'index.dart' as i0;
        import 'package:test_initializers/common.dart' as i1;
        import 'foo.dart' as i2;

        main() {
          initializers.addAll([
            new InitEntry(const i1.DynamicInit(i2.foo), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(i2.Foo.foo), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(const [i2.foo, i2.Foo.foo, 'foo']), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(const {'foo': i2.foo, 'Foo.foo': i2.Foo.foo, 'bar': 'bar'}), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit('foo'), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(true), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(null), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(1), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.DynamicInit(1.1), const LibraryIdentifier(#web_foo, null, 'index.dart')),
            new InitEntry(const i1.NamedArgInit(1, name: 'Bill'), const LibraryIdentifier(#web_foo, null, 'index.dart')),
          ]);

          i0.main();
        }
        '''.replaceAll('        ', '')
  }, []);
}
