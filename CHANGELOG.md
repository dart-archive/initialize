## 0.6.1+2

* Update analyzer to `<0.27.0` and dart_style to `<0.3.0`.

## 0.6.1+1

* Update to work with deferred loaded libararies in reflective mode, (but not
yet in the transformer).

## 0.6.1

* Update to analyzer `<0.26.0`.

## 0.6.0+5

* Fix bootstrap files to return the result of the original main.

## 0.6.0+4

* Switch `html5lib` package dependency to `html`.

## 0.6.0+3

* Make sure to always use the canonical libraries and super declarations in
development mode. This eliminates an uncommon issue where a single initializer
could be ran more than once.

## 0.6.0+2

* Private identifiers will now be evaluated and inlined into the bootstrap file
by the transformer, [29](https://github.com/dart-lang/initialize/issues/29).

## 0.6.0+1

* Fix for `LibraryIdentifier` paths when initializer starts from inline scripts
inside of subfolders.

## 0.6.0

* Added the `from` option to `run`. This should be a `Uri` pointing to a library
in the mirror system, and throws if not in mirrors mode. This can be used to
run initializers in a custom order at development time.
* This package no longer tries to handle initializing scripts found in html
imports. If you need this feature please use `initWebComponents` from the
`web_components` package.

## 0.5.1+8

* Make sure to crawl the entire supertype chain for annotations, and run them
in reverse order.

## 0.5.1+7

* Change to source order-crawling of directives instead of alphabetical. The one
exception is for `part` directives, those are still crawled in alphabetical
order since we can't currently get the original source order from the mirror
system.

## 0.5.1+6

* Fix some analyzer warnings.

## 0.5.1+5

* Fix an issue where for certain programs the transformer could fail,
  [33](https://github.com/dart-lang/polymer-dart/issues/33).


## 0.5.1+4

* Update to use mock dart sdk from `code_transformers` and update the `analyzer`
and `code_transformers` dependencies.

## 0.5.1+3

* Fix up mirror based import crawling so it detects dartium and only crawl all
libraries in the mirror system in that case.

## 0.5.1+2

* Fix handling of exported libraries. Specifically, annotations on exported
libraries will now be reached and imports in exported libraries will now be
reached.
* Add support for scripts living in html imports without adding an html
dependency by crawling all libraries in the mirror system in reverse order,
instead of just the root one.

## 0.5.1+1

* Make sure to always use `path.url` in the transformer.

## 0.5.1

* Added support for more types of expressions in constructor annotations. More
specifically, any const expressions that evaluate to a `String`, `int`,
`double`, or `bool` are now allowed. The evaluated value is what will be inlined
in the bootstrap file in this case.


## 0.5.0

* The `InitializePluginTransformer` is gone in favor of a new
`InitializerPlugin` class which you can pass a list of to the
`InitializeTransformer`. These plugins now have access to the fully resolved ast
nodes and can directly control what is output in the bootstrap file.

## 0.4.0

Lots of transformer updates:

* The `new_entry_point` option is gone. The bootstrapped file will now always
just be the original name but `.dart` will be replaced with `.initialize.dart`.
* The `html_entry_point` option is gone, and the file extension is now used to
detect if it is an html or dart file. You should no longer list the dart file
contained in the html file. Effectively resolves
[13](https://github.com/dart-lang/initialize/issues/13).
* The `entry_point` option has been renamed `entry_points` and now accepts
either a single file path or list of file paths. Additionally, it now supports
Glob syntax so many files can be selected at once. Resolves
[19](https://github.com/dart-lang/initialize/issues/19).

## 0.3.1

* Added `InitializePluginTransformer` class in `plugin_transformer.dart` which
provides a base transformer class which can be extended to perform custom
transformations for annotations. These transformers should be included after the
main `initialize` transformer and work by parsing the bootstrap file so the
program doesn't need to be re-analyzed.

## 0.3.0

* Library initializers now pass a `LibraryIdentifier` to `initialize` instead of
just a `Symbol`. This provides the package and path to the library in addition
to the symbol so that paths can be normalized.

## 0.2.0

* `entryPoint` and `newEntryPoint` transformer options were renamed to
`entry_point` and `new_entry_pont`.

* Added `html_entry_point` option to the transformer. This will search that file
for any script tag whose src is `entry_point` and rewrite it to point at the
bootstrapped file `new_entry_point`.

* Top level properties and static class properties are now supported in
initializer constructors, as well as List and Map literals,
[5](https://github.com/dart-lang/initialize/issues/5).

## 0.1.0+1

Quick fix for the transformer on windows.

## 0.1.0

Initial beta release. There is one notable missing feature in the release
regarding constructor arguments, see
[5](https://github.com/dart-lang/initialize/issues/5).
