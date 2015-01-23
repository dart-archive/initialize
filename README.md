Initialize
==========

This package provides a common interface for initialization annotations on top
level methods, classes, and libraries. The interface looks like this:

    abstract class Initializer<T> {
      dynamic initialize(T target);
    }

The `initialize` method will be called once for each annotation. The type `T` is
determined by what was annotated. For libraries it will be the Symbol
representing that library, for a class it will be the Type representing that
class, and for a top level method it will be the Function object representing
that method.

If a future is returned from the initialize method, it will wait until the future
completes before running the next initializer.

## Usage

### @initMethod

Ther is one initializer which comes with this package, `@initMethod`. Annotate
any top level function with this and it will be invoked automatically. For
example, the program below will print `hello`:

    import 'package:initialize/initialize.dart';
    
    @initMethod
    printHello() => print('hello');
    
    main() => run();

### Running the initializers

In order to run all the initializers, you need to import
`package:initialize/initialize.dart` and invoke the `run` method. This should
typically be the first thing to happen in your main. That method returns a Future,
so you should put the remainder of your program inside the chained then call.

    import 'package:initialize/initialize.dart';
    
    main() {
      run().then((_) {
        print('hello world!');
      });
    }

## Transformer

During development a mirror based system is used to find and run the initializers,
but for deployment there is a transformer which can replace that with a static list
of initializers to be ran. 

This will create a new entry point which bootstraps your existing app. If you
supply an `htmlEntryPoint` then any script tags whose src is the same as
`entryPoint` will be rewritten to the bootstrapped file `newEntryPoint`.

Below is an example pubspec with the transformer:

    name: my_app
    dependencies:
      initialize: any
    transformers:
    - initialize:
        entryPoint: web/index.dart
        newEntryPoint: web/index.bootstrap.dart
        htmlEntryPoint: web/index.html

## Creating your own initializer

Lets look at a slightly simplified version of the `@initMethod` class:

    class InitMethod implements Initializer<Function> {
      const InitMethod();
    
      @override
      initialize(Function method) => method();
    }

You would now be able to add `@InitMethod()` in front of any function and it
will be automatically invoked when the user calls `run()`.

For classes which are stateless, you can usually just have a single const
instance, and that is how the actual InitMethod implementation works. Simply add
something like the following:

    const initMethod = const InitMethod();

Now when people use the annotation, it just looks like `@initMethod` without any
parenthesis, and its a bit more efficient since there is a single instance. You
can also make your class private to force users into using the static instance.
