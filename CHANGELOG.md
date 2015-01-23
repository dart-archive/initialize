## 0.1.1-dev

Added `htmlEntryPoint` option to the transformer. This will search that file for
any script tag whose src is `entryPoint` and rewrite it to point at the
bootstrapped file `newEntryPoint`.

## 0.1.0+1

Quick fix for the transformer on windows.

## 0.1.0

Initial beta release. There is one notable missing feature in the release
regarding constructor arguments, see
[5](https://github.com/dart-lang/initialize/issues/5).
