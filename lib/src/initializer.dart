// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
part of initialize;

/// Implement this class to create your own initializer.
///
/// Hello world example:
///
///   class Print implements Initializer<Type> {
///     final String message;
///     const Print(this.message);
///
///     @override
///     initialize(Type t) => print('$t says `$message`');
///   }
///
///   @Print('hello world!')
///   class Foo {}
///
/// Call [run] from your main and this will print 'Foo says `hello world!`'
///
abstract class Initializer<T> {
  dynamic initialize(T target);
}

/// Typedef for a custom filter function.
typedef bool InitializerFilter(Initializer initializer);
