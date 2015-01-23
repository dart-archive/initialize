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

        @DynamicInit('Bar')
        @DynamicInit('Bar2')
        class Bar {}

        @DynamicInit('bar()')
        @initMethod
        bar() {}
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
        import 'index.dart' as i0;
        import 'package:bar/bar.dart' as i1;
        import 'package:test_initializers/common.dart' as i2;
        import 'package:initialize/initialize.dart' as i3;
        import 'foo.dart' as i4;

        main() {
          initializers.addAll([
            new InitEntry(const i2.DynamicInit('bar'), #bar),
            new InitEntry(const i2.DynamicInit('bar2'), #bar),
            new InitEntry(const i2.DynamicInit('bar()'), i1.bar),
            new InitEntry(i3.initMethod, i1.bar),
            new InitEntry(const i2.DynamicInit('Bar'), i1.Bar),
            new InitEntry(const i2.DynamicInit('Bar2'), i1.Bar),
            new InitEntry(i2.constInit, #foo),
            new InitEntry(i3.initMethod, i4.foo),
            new InitEntry(i2.constInit, i4.Foo),
          ]);

          i0.main();
        }
        '''.replaceAll('        ', '')
  });

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
        import 'index.dart' as i0;
        import 'package:test_initializers/common.dart' as i1;
        import 'foo.dart' as i2;

        main() {
          initializers.addAll([
            new InitEntry(const i1.DynamicInit(i2.foo), #web_foo),
            new InitEntry(const i1.DynamicInit(i2.Foo.foo), #web_foo),
            new InitEntry(const i1.DynamicInit(const [i2.foo, i2.Foo.foo, 'foo']), #web_foo),
            new InitEntry(const i1.DynamicInit(const {'foo': i2.foo, 'Foo.foo': i2.Foo.foo, 'bar': 'bar'}), #web_foo),
            new InitEntry(const i1.DynamicInit('foo'), #web_foo),
            new InitEntry(const i1.DynamicInit(true), #web_foo),
            new InitEntry(const i1.DynamicInit(null), #web_foo),
            new InitEntry(const i1.DynamicInit(1), #web_foo),
            new InitEntry(const i1.DynamicInit(1.1), #web_foo),
            new InitEntry(const i1.NamedArgInit(1, name: 'Bill'), #web_foo),
          ]);

          i0.main();
        }
        '''.replaceAll('        ', '')
  });
}
