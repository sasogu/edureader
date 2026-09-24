# Local patches

This directory vendors `flutter_readium` 0.3.3 from
[pub.dev](https://pub.dev/packages/flutter_readium/versions/0.3.3).

## Android selection actions on first mount

`android/src/main/kotlin/dk/nota/flutterreadium/ReadiumReaderWidget.kt`
initializes `ReadiumReader.selectionActions` from the platform view's creation
parameters before the reader is initialized. Without this, the first Android
reader instance can miss the configured text-selection actions. Keep this
patch when updating the vendored package, and remove the fork once an upstream
release with the fix is compatible with this app's Flutter SDK.
