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
