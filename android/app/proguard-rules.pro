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

# ── Android framework component subclasses ──────────────────────────────────
# Services and BroadcastReceivers are instantiated by the OS using their
# fully-qualified class names stored in the manifest and in PendingIntents.
# These rules are belt-and-suspenders: the korubeni.** wildcard above already
# covers current classes, but these ensure any future class outside that prefix
# (e.g. added by a plugin update) is also protected.
-keep public class * extends android.app.Service {
    public int onStartCommand(android.content.Intent, int, int);
    public android.os.IBinder onBind(android.content.Intent);
    public void onDestroy();
}
-keep public class * extends android.content.BroadcastReceiver {
    public void onReceive(android.content.Context, android.content.Intent);
}

# ── AlarmManager / PendingIntent receiver class names ────────────────────────
# CheckInAlarmReceiver's class name is baked into the PendingIntent at
# scheduling time and must match exactly when the alarm fires after reboot.
# Already covered by the korubeni.** wildcard, but called out explicitly
# so this critical class is never accidentally removed by future rule changes.
-keep class com.poyrazoncel.korubeni.emergency.CheckInAlarmReceiver { *; }
-keep class com.poyrazoncel.korubeni.emergency.BootCompletedReceiver { *; }
-keep class com.poyrazoncel.korubeni.emergency.CheckInScheduler { *; }

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
