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
# flutter_gemma + MediaPipe removed from the app. Keep rules retired.
# protobuf keep retained in case a future plugin adds one.
# ═══════════════════════════════════════════════════════════════════════════
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# ═══════════════════════════════════════════════════════════════════════════
# llamadart (replaces fllama, 2026-05-13) — pure-Dart FFI plugin using
# native-assets bundling. No JNI classes to keep on the Java side, but
# the package writes through to ggml/llama.cpp internals, so we suppress
# any reflective-call warnings.
# ═══════════════════════════════════════════════════════════════════════════
-dontwarn dev.donato.llamadart.**

# ═══════════════════════════════════════════════════════════════════════════
# whisper_ggml + ffmpeg_kit_flutter_new_min (added 2026-05-13) — both ship
# native libraries that register JNI callbacks via JNI_OnLoad. Stripping
# their plugin classes breaks GeneratedPluginRegistrant and the app hangs
# on the Android splash before Flutter reaches runApp(). Keep the plugin
# registration surface + every native method declaration.
# ═══════════════════════════════════════════════════════════════════════════
-keep class com.devac.whisper_ggml.** { *; }
-keepclassmembers class com.devac.whisper_ggml.** {
    native <methods>;
}
-dontwarn com.devac.whisper_ggml.**

-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keepclassmembers class com.antonkarpenko.ffmpegkit.** {
    native <methods>;
}
-keep class com.arthenica.** { *; }
-keepclassmembers class com.arthenica.** {
    native <methods>;
}
-dontwarn com.antonkarpenko.ffmpegkit.**
-dontwarn com.arthenica.**

# ═══════════════════════════════════════════════════════════════════════════
# flutter_onnxruntime + Supertonic TTS (added 2026-05-13, v2.6.0). ONNX
# Runtime registers JNI methods on `ai.onnxruntime.*` classes — stripping
# them via R8 hangs the app on splash the same way whisper_ggml did.
# ═══════════════════════════════════════════════════════════════════════════
-keep class ai.onnxruntime.** { *; }
-keepclassmembers class ai.onnxruntime.** {
    native <methods>;
}
-dontwarn ai.onnxruntime.**

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
