// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library static_init.build.transformer_test;

import 'common.dart';
import 'package:barback/barback.dart';
import 'package:static_init/transformer.dart';
import 'package:unittest/compact_vm_config.dart';

main() {
  useCompactVMConfiguration();

  var transformer = new InitializeTransformer.asPlugin(
      new BarbackSettings({'entryPoint': 'web/index.dart'}, BarbackMode.DEBUG));

  testPhases('transformer', [[transformer]], {
    'a|web/index.dart': '''
          library web_foo;

          import 'foo.dart';
          ''',
    'a|web/foo.dart': '''
          @constInit
          library foo;

          import 'package:static_init/static_init.dart';
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

          import 'package:static_init/static_init.dart';

          @DynamicInit('Bar')
          @DynamicInit('Bar2')
          class Bar {}

          @DynamicInit('bar()')
          @initMethod
          bar() {}
          ''',
    // Mock out the StaticInitializer package plus some initializers.
    'static_init|lib/static_init.dart': '''
          library static_init;

          abstract class StaticInitializer<T> {}

          class _ConstInit extends StaticInitializer<dynamic> {
            const ConstInit();
          }
          const _ConstInit constInit = const _ConstInit();

          class DynamicInit extends StaticInitializer<dynamic> {
            final String _name;
            const DynamicInit(this._name);
          }

          class _InitMethod implements StaticInitializer<Function> {
            const _InitMethod();
          }
          const _InitMethod initMethod = const _InitMethod();
          '''
  }, {
    'a|web/index.bootstrap.dart': '''
          import 'package:static_init/src/static_loader.dart';
          import 'index.dart' as i0;
          import 'package:bar/bar.dart' as i1;
          import 'package:static_init/static_init.dart' as i2;
          import 'foo.dart' as i3;

          main() {
            initializers.addAll([
              new InitEntry(const i2.DynamicInit('bar'), #bar),
              new InitEntry(const i2.DynamicInit('bar2'), #bar),
              new InitEntry(const i2.DynamicInit('bar()'), i1.bar),
              new InitEntry(i2.initMethod, i1.bar),
              new InitEntry(const i2.DynamicInit('Bar'), i1.Bar),
              new InitEntry(const i2.DynamicInit('Bar2'), i1.Bar),
              new InitEntry(i2.constInit, #foo),
              new InitEntry(i2.initMethod, i3.foo),
              new InitEntry(i2.constInit, i3.Foo),
            ]);

            i0.main();
          }
          '''.replaceAll('          ', '')
  });
}
