# ═══════════════════════════════════════════════════════════════════════════
# Flutter engine — keep everything. R8 has a history of breaking Flutter's
# internal codec classes (JSONMessageCodec, StandardMessageCodec) because
# it incorrectly reshapes the exception hierarchy. The runtime ART verifier
# then rejects the class with VerifyError and the app crashes on launch.
#
# Don't minify these.
# ═══════════════════════════════════════════════════════════════════════════
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# org.json — referenced by Flutter's JSONMessageCodec. Keep its exception
# hierarchy intact so the verifier sees JSONException as a RuntimeException
# (which it actually is at runtime).
-keep class org.json.** { *; }
-keep class org.json.JSONException { *; }
-dontwarn org.json.**

# ═══════════════════════════════════════════════════════════════════════════
# MediaPipe / flutter_gemma
# ═══════════════════════════════════════════════════════════════════════════
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# ═══════════════════════════════════════════════════════════════════════════
# fllama (llama.cpp JNI) — keep JNI bindings so the native library can
# resolve its Java callbacks.
# ═══════════════════════════════════════════════════════════════════════════
-keep class com.peanut.fllama.** { *; }
-keepclassmembers class com.peanut.fllama.** {
    native <methods>;
}
-dontwarn com.peanut.fllama.**

# ═══════════════════════════════════════════════════════════════════════════
# Play Core (referenced by Flutter's deferred components even when unused)
# ═══════════════════════════════════════════════════════════════════════════
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# ═══════════════════════════════════════════════════════════════════════════
# Keep all @Keep-annotated classes (used by various JNI libraries)
# ═══════════════════════════════════════════════════════════════════════════
-keep class * {
    @androidx.annotation.Keep *;
}
-keep @androidx.annotation.Keep class * { *; }
