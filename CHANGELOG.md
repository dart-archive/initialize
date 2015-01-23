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
