# ============================================================================
# KORUBENI - PROGUARD RULES
# ============================================================================

# Flutter - Play Core split install (deferred components) kullanılmıyorsa R8 uyarısını kapat
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-keep class io.flutter.embedding.** { *; }

# Offline-first: No Firebase

# Gson / JSON
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class com.google.gson.stream.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Local Auth (Biometric)
-keep class androidx.biometric.** { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.** { *; }

# Audioplayers
-keep class xyz.luan.audioplayers.** { *; }

# Record (audio recording)
-keep class com.llfbandit.record.** { *; }

# Connectivity Plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# Sensors Plus
-keep class dev.fluttercommunity.plus.sensors.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# AndroidX
-keep class androidx.** { *; }
-dontwarn androidx.**

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.** { *; }

# KoruBeni custom platform channels - CRITICAL for emergency app
-keep class com.poyrazoncel.korubeni.** { *; }
-keepclassmembers class com.poyrazoncel.korubeni.** {
    public <methods>;
    public <fields>;
}

# MethodChannel handlers must not be obfuscated
-keep class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler {
    *;
}
-keep class * implements io.flutter.plugin.common.EventChannel$StreamHandler {
    *;
}

# ProGuard optimizations
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-allowaccessmodification
-repackageclasses ''

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
