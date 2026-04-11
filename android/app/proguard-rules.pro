# MediaPipe / flutter_gemma rules
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# fllama (llama.cpp JNI)
-keep class com.peanut.fllama.** { *; }
-dontwarn com.peanut.fllama.**

# Play Core (Flutter deferred components references)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
