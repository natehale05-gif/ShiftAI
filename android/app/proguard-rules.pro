# Flutter's own engine classes are reached by JNI, so R8 must not touch
# them. Everything else in the app is Dart and is not affected by this.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_secure_storage reaches its Android side reflectively, and R8
# strips it under `isMinifyEnabled`. The build succeeds either way — the
# failure is at runtime, in release only, the first time a token is read.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# The Keystore-backed cipher it uses comes from androidx.security, which
# R8 also prunes because nothing references it directly in Java.
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# file_picker's platform channel, same story: stripped by R8, fails when
# somebody taps the "+" in a release build rather than at compile time.
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-dontwarn com.mr.flutter.plugin.filepicker.**

# Play Core is referenced by Flutter's deferred-components support even
# when the app uses none. Without this, R8 warns and can fail the build.
-dontwarn com.google.android.play.core.**
