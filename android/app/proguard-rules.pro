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

# Connectivity Plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# AndroidX
-keep class androidx.** { *; }
-dontwarn androidx.**

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.** { *; }

# ── KoruBeni app code ───────────────────────────────────────────────────────
# There is deliberately NO blanket `-keep class com.poyrazoncel.korubeni.** { *; }`
# here any more (audit F-05). That rule kept every class, method and field name
# in the app, so `isMinifyEnabled = true` shrank and obfuscated the libraries and
# left this app's own code fully readable. Obfuscation is NOT a security boundary
# and removing the rule fixes no vulnerability; what it does is stop advertising
# the exact shape of the entitlement gate, which is client-side by design and
# therefore the one thing whose bypass cost is set purely by how easy the code is
# to read.
#
# What replaces it, and why each piece is load-bearing:
#
# 1. AGP already emits `-keep class <component> { <init>(); }` for EVERY component
#    declared in the merged manifest. Verified, not assumed -- see
#    build/app/intermediates/aapt_proguard_file/<variant>/.../aapt_rules.txt, which
#    lists all eleven: MainActivity, the six emergency receivers,
#    EmergencyFallbackDialActivity, QuickPanicTrampolineActivity,
#    PanicTileService and PanicWidgetProvider. Their NAMES therefore survive R8
#    without any rule in this file.
# 2. The framework-subclass and explicit component rules below keep the METHODS
#    the OS calls on them, which AGP's `<init>()`-only rule does not cover.
# 3. The MethodChannel/EventChannel handler rules below keep the Flutter bridge.
#
# Why the receiver names matter beyond ordinary reflection: a PendingIntent bakes
# the target class name in at SCHEDULING time. An alarm armed by one build and
# fired after an app update must still resolve that name, and R8's renaming is not
# stable across builds. That is why the receivers are kept explicitly below rather
# than left to AGP alone.
#
# Nothing in this app loads a class by name: there is no Class.forName, no
# `javaClass.name` lookup, and the only ComponentName values built at runtime
# address OEM system apps (Xiaomi, Huawei), not our own classes. Checked before
# narrowing this rule; re-check before widening the obfuscated surface further.

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
# Only classes that actually exist are listed: a keep rule for a deleted class
# reads as protection that is not there.
# Already covered by the korubeni.** wildcard, but called out explicitly
# so this critical class is never accidentally removed by future rule changes.
-keep class com.poyrazoncel.korubeni.emergency.CheckInAlarmReceiver { *; }
-keep class com.poyrazoncel.korubeni.emergency.BootCompletedReceiver { *; }
# Quick-access surfaces: the widget provider's name is baked into its
# PendingIntent and its manifest meta-data, and SystemUI binds the tile service
# by the name in the manifest. Covered by the korubeni.** wildcard and by the
# Service/BroadcastReceiver rules above; listed explicitly for the same reason
# the alarm receivers are.
-keep class com.poyrazoncel.korubeni.quickaccess.PanicWidgetProvider { *; }
-keep class com.poyrazoncel.korubeni.quickaccess.PanicTileService { *; }
# The remaining PendingIntent targets. The generic Service/BroadcastReceiver
# rules above and AGP's manifest rules already cover these, but every class whose
# name is baked into a PendingIntent is listed here by name on purpose: this is
# the failure mode with the worst consequence (an alarm armed before an app
# update firing afterwards against a name that no longer resolves), and it is
# silent -- nothing fails at build time, the alarm simply never arrives.
-keep class com.poyrazoncel.korubeni.emergency.CountdownAlarmReceiver { *; }
-keep class com.poyrazoncel.korubeni.emergency.EmergencyFallbackCleanupReceiver { *; }
-keep class com.poyrazoncel.korubeni.emergency.EmergencyFallbackDialActivity { *; }
-keep class com.poyrazoncel.korubeni.quickaccess.QuickPanicTrampolineActivity { *; }
# Manifest-declared, not a PendingIntent target; kept so the receiver set in this
# file matches the receiver set in the manifest and a reader can check one list.
-keep class com.poyrazoncel.korubeni.emergency.ClockChangeReceiver { *; }
-keep class com.poyrazoncel.korubeni.emergency.ExactAlarmPermissionReceiver { *; }
-keep class com.poyrazoncel.korubeni.MainActivity { *; }

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
