# KoruBeni: Zero-Fault Integration Guide

## 🚀 Quick Start

This guide shows how to integrate the new zero-fault services into your existing code.

---

## 1️⃣ Emergency Trigger Integration

### ❌ Old Way (Fragile)

```dart
Future<void> triggerPanic() async {
  await FirebaseService.instance.createEmergencyEvent(
    title: 'Panic',
    message: 'Help needed',
  );
}
```

### ✅ New Way (Zero-Fault)

```dart
import 'package:guvenlik_app/core/services/emergency_core_service.dart';
import 'package:guvenlik_app/core/services/breadcrumb_service.dart';

Future<void> triggerPanic() async {
  BreadcrumbService.instance.addButtonTap('panic_button');
  
  final result = await EmergencyCoreService.instance.triggerEmergency(
    title: 'panic_alert'.tr(),
    message: 'emergency_help_needed'.tr(),
  );
  
  if (result.success) {
    // Show success feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.success,
        ),
      );
    }
  } else {
    // Show error feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('emergency_failed'.tr()),
          backgroundColor: AppColors.emergency,
        ),
      );
    }
  }
}
```

---

## 2️⃣ Network Operations Integration

### ❌ Old Way (No Retry)

```dart
Future<void> updateUserProfile() async {
  await FirebaseService.instance.upsertUserProfile();
}
```

### ✅ New Way (With Retry)

```dart
import 'package:guvenlik_app/core/services/network_retry_service.dart';
import 'package:guvenlik_app/core/services/breadcrumb_service.dart';

Future<void> updateUserProfile() async {
  BreadcrumbService.instance.addApiCall('/users', method: 'PUT');
  
  final result = await NetworkRetryService.instance.executeWithRetry(
    operation: () => FirebaseService.instance.upsertUserProfile(),
    operationName: 'updateUserProfile',
    maxAttempts: 3,
    timeout: Duration(seconds: 10),
  );
  
  if (result.success) {
    BreadcrumbService.instance.addSuccess('Profile updated');
  } else {
    BreadcrumbService.instance.addError('Profile update failed: ${result.errorMessage}');
  }
}
```

---

## 3️⃣ Data Storage Integration

### ❌ Old Way (Direct Write)

```dart
Future<void> saveSettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('settings', jsonEncode(settings));
}
```

### ✅ New Way (Atomic Write)

```dart
import 'package:guvenlik_app/core/services/atomic_storage_service.dart';

Future<void> saveSettings() async {
  final success = await AtomicStorageService.instance.writeJson(
    'settings',
    settings.toMap(),
  );
  
  if (!success) {
    debugPrint('Failed to save settings');
    // Handle failure
  }
}

Future<Map<String, dynamic>?> loadSettings() async {
  return await AtomicStorageService.instance.readJson('settings');
}
```

---

## 4️⃣ Screen Navigation Integration

### Add Breadcrumbs

```dart
import 'package:guvenlik_app/core/services/breadcrumb_service.dart';

class HomePage extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    BreadcrumbService.instance.addScreenView('HomePage');
  }
}

class SettingsPage extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    BreadcrumbService.instance.addScreenView('SettingsPage');
  }
}
```

---

## 5️⃣ Button Tap Integration

### Add Breadcrumbs for User Actions

```dart
import 'package:guvenlik_app/core/services/breadcrumb_service.dart';

ElevatedButton(
  onPressed: () {
    BreadcrumbService.instance.addButtonTap('save_settings');
    _saveSettings();
  },
  child: Text('save'.tr()),
)
```

---

## 6️⃣ Error Handling Integration

### Report Errors with Context

```dart
import 'package:guvenlik_app/core/services/breadcrumb_service.dart';

try {
  await riskyOperation();
} catch (e, stack) {
  await BreadcrumbService.instance.reportWithTrail(
    e,
    stack,
    reason: 'riskyOperation failed',
  );
  
  // Show user-friendly error
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('operation_failed'.tr())),
    );
  }
}
```

---

## 7️⃣ Location Services Integration

### Use EmergencyCoreService

```dart
import 'package:guvenlik_app/core/services/emergency_core_service.dart';

// Don't use LocationService directly for emergencies
// Use EmergencyCoreService which has 5-level fallback

final result = await EmergencyCoreService.instance.triggerEmergency(
  title: 'Emergency',
  message: 'Help needed',
);

// Location is automatically obtained with fallback:
// 1. Real-time GPS (10s timeout)
// 2. Cached location (< 30 min)
// 3. System last known
// 4. IP-based geolocation
// 5. null (graceful)
```

---

## 8️⃣ Health Check Integration

### Check System Status

```dart
import 'package:guvenlik_app/core/services/health_check_service.dart';

Future<void> checkSystemHealth() async {
  final health = await HealthCheckService.instance.performHealthCheck();
  
  if (!health.isHealthy) {
    // Show warnings to user
    if (!health.networkHealthy) {
      _showWarning('offline_mode_warning'.tr());
    }
    if (!health.gpsHealthy) {
      _showWarning('gps_disabled_warning'.tr());
    }
    if (!health.batteryHealthy) {
      _showWarning('low_battery_warning'.tr());
    }
  }
}
```

---

## 9️⃣ Battery Optimization Wizard

### Show on First Launch

```dart
import 'package:guvenlik_app/core/services/battery_optimization_service.dart';
import 'package:guvenlik_app/core/services/doze_mode_service.dart';

Future<void> showOptimizationWizardIfNeeded(BuildContext context) async {
  // Check battery optimization
  final shouldShowBattery = 
      await BatteryOptimizationService.instance.shouldShowRequest();
  
  if (shouldShowBattery) {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('battery_optimization_title'.tr()),
        content: Text('battery_optimization_desc'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('not_now'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('continue'.tr()),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await BatteryOptimizationService.instance.requestDisableOptimization();
    }
  }
  
  // Check Doze Mode
  final shouldShowDoze = await DozeModeService.instance.shouldShowRequest();
  
  if (shouldShowDoze) {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('doze_mode_title'.tr()),
        content: Text('doze_mode_desc'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('not_now'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('continue'.tr()),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await DozeModeService.instance.requestWhitelist();
    }
  }
}
```

---

## 🔟 Foreground Service Integration

### Start on Emergency Mode

```dart
import 'package:guvenlik_app/core/services/foreground_service.dart';

Future<void> startEmergencyMode() async {
  // Start foreground service
  await KoruBeniForegroundService.start();
  
  // Update notification
  KoruBeniForegroundService.updateNotification(
    'emergency_active'.tr(),
    'tracking_location'.tr(),
  );
}

Future<void> stopEmergencyMode() async {
  // Stop foreground service
  await KoruBeniForegroundService.stop();
}
```

---

## 📋 Translation Keys to Add

Add these keys to your translation files:

### English (en-US.json)

```json
{
  "battery_optimization_title": "Battery Optimization",
  "battery_optimization_desc": "To ensure KoruBeni can send emergency alerts even when your phone is locked, please disable battery optimization for this app.",
  "doze_mode_title": "Background Operation",
  "doze_mode_desc": "To ensure KoruBeni works during deep sleep, please whitelist this app from Doze Mode restrictions.",
  "not_now": "Not Now",
  "continue": "Continue",
  "offline_mode_warning": "You are offline. Emergency alerts will be sent when connection is restored.",
  "gps_disabled_warning": "GPS is disabled. Location accuracy may be reduced.",
  "low_battery_warning": "Low battery. Emergency-only mode activated.",
  "emergency_failed": "Failed to send emergency alert. It has been queued for retry.",
  "operation_failed": "Operation failed. Please try again."
}
```

### Turkish (tr-TR.json)

```json
{
  "battery_optimization_title": "Pil Optimizasyonu",
  "battery_optimization_desc": "KoruBeni'nin telefonunuz kilitliyken bile acil durum sinyali gönderebilmesi için lütfen bu uygulama için pil optimizasyonunu devre dışı bırakın.",
  "doze_mode_title": "Arka Plan Çalışması",
  "doze_mode_desc": "KoruBeni'nin derin uyku modunda çalışabilmesi için lütfen bu uygulamayı Doze Mode kısıtlamalarından muaf tutun.",
  "not_now": "Şimdi Değil",
  "continue": "Devam Et",
  "offline_mode_warning": "Çevrimdışısınız. Acil durum uyarıları bağlantı sağlandığında gönderilecek.",
  "gps_disabled_warning": "GPS kapalı. Konum doğruluğu azalabilir.",
  "low_battery_warning": "Düşük pil. Sadece acil durum modu etkinleştirildi.",
  "emergency_failed": "Acil durum uyarısı gönderilemedi. Yeniden deneme için kuyruğa alındı.",
  "operation_failed": "İşlem başarısız. Lütfen tekrar deneyin."
}
```

---

## ✅ Migration Checklist

### Phase 1: Core Services (Already Done)

- [x] BatteryOptimizationService
- [x] DozeModeService
- [x] NetworkRetryService
- [x] AtomicStorageService
- [x] BreadcrumbService
- [x] HealthCheckService
- [x] StartupDiagnosticsService
- [x] ResourceMonitorService

### Phase 2: Integration (Your Tasks)

- [ ] Add breadcrumbs to all screens
- [ ] Add breadcrumbs to all button taps
- [ ] Replace direct Firebase calls with NetworkRetryService
- [ ] Replace direct SharedPreferences with AtomicStorageService
- [ ] Add battery optimization wizard to onboarding
- [ ] Add Doze Mode wizard to onboarding
- [ ] Add translation keys
- [ ] Test on low-end Android device
- [ ] Test with airplane mode
- [ ] Test with GPS disabled

### Phase 3: Testing

- [ ] Test emergency trigger offline
- [ ] Test emergency trigger with GPS off
- [ ] Test app kill in background
- [ ] Test Doze Mode
- [ ] Test low battery mode
- [ ] Verify Crashlytics reporting
- [ ] Verify breadcrumb trails

---

## 🐛 Common Issues

### Issue: Services not initialized

**Symptom**: `instance` is null

**Fix**: Ensure main.dart initialization completed:

```dart
await StartupDiagnosticsService.instance.run();
```

### Issue: Breadcrumbs not appearing in Crashlytics

**Symptom**: No breadcrumb trail in crash reports

**Fix**: Ensure Firebase is initialized before breadcrumbs:

```dart
if (kFirebaseReady) {
  BreadcrumbService.instance.add('...');
}
```

### Issue: Atomic storage not working

**Symptom**: Data still corrupted

**Fix**: Ensure integrity check runs on startup:

```dart
await AtomicStorageService.instance.checkIntegrity();
```

---

## 📞 Support

For questions or issues with the zero-fault implementation:

1. Check the `ZERO_FAULT_IMPLEMENTATION.md` documentation
2. Review the Cursor rules in `.cursor/rules/`
3. Use the `android-hardening-expert` subagent
4. Check Crashlytics for error patterns

---

## 🎯 Success Metrics

Track these metrics to verify zero-fault implementation:

- **Crash-free rate**: Should be > 99.5%
- **Emergency signal success rate**: Should be > 99%
- **GPS fallback distribution**: Track which level is used most
- **Offline queue size**: Should stay < 10 events
- **Battery optimization bypass rate**: Target > 80%
- **Doze whitelist rate**: Target > 70%

---

**Last Updated**: 2026-02-27  
**Version**: 1.0.0
