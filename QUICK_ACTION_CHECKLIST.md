# KoruBeni Quick Action Checklist
## Immediate Tasks Before Production Release

**Priority:** 🔴 Critical | 🟡 High | 🟢 Medium | 🔵 Low

---

## 🔴 Critical (Must Do This Week)

### 1. Run 8 Critical Tests ⏱️ 4 hours
Test on 3 devices: Low-end (< 2GB RAM), Mid-range, High-end

- [ ] **Emergency Trigger Test**
  ```bash
  # Test all trigger methods
  1. Press panic button (hold 3s)
  2. Shake phone vigorously
  3. Press volume buttons 3x quickly
  # Expected: All should navigate to countdown screen
  ```

- [ ] **Offline Mode Test**
  ```bash
  1. Enable airplane mode
  2. Trigger emergency
  3. Check queue: adb shell run-as com.poyrazoncel.korubeni cat /data/data/com.poyrazoncel.korubeni/shared_prefs/FlutterSharedPreferences.xml | grep offline_event_queue
  4. Disable airplane mode
  5. Wait 10s
  # Expected: Event should sync automatically
  ```

- [ ] **GPS Fallback Test**
  ```bash
  1. Disable GPS in settings
  2. Trigger emergency
  3. Check logs for "Level 4: IP-based location"
  # Expected: Should use IP geolocation fallback
  ```

- [ ] **Low Battery Test**
  ```bash
  1. Drain battery to < 10%
  2. Trigger emergency
  3. Check logs for "CRITICAL BATTERY MODE"
  # Expected: Emergency-only mode activates
  ```

- [ ] **Background Survival Test**
  ```bash
  1. Start app
  2. Navigate to home
  3. Swipe app away from recent apps
  4. Check service: adb shell dumpsys activity services | grep BackgroundService
  # Expected: Service should still be running
  ```

- [ ] **Doze Mode Test**
  ```bash
  1. Force Doze: adb shell dumpsys deviceidle force-idle
  2. Trigger emergency (via adb or alarm)
  3. Check queue
  4. Exit Doze: adb shell dumpsys deviceidle unforce
  # Expected: Emergency queued and syncs after Doze exit
  ```

- [ ] **SMS Sending Test**
  ```bash
  1. Add emergency contact
  2. Trigger emergency
  3. Verify SMS sent
  4. Test with invalid number
  # Expected: Valid sends, invalid logs error gracefully
  ```

- [ ] **Contact Management Test**
  ```bash
  1. Add 5 contacts
  2. Edit contact
  3. Delete contact
  4. Trigger emergency
  # Expected: All operations work, emergency sends to remaining contacts
  ```

### 2. Add Skeleton Loaders ⏱️ 2 hours

**Files to modify:**

1. **contacts_page.dart** (line ~121)
```dart
// Add before ListView.builder
if (_isLoading) {
  return ListView.builder(
    itemCount: 5,
    itemBuilder: (context, index) => _ContactSkeletonCard(),
  );
}

// Add at bottom of file
class _ContactSkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

2. **map_page.dart** (line ~60)
3. **safety_timeline_screen.dart** (line ~88)
4. **activity_page.dart** (similar pattern)

### 3. Test Release APK ⏱️ 1 hour

```bash
# Build release APK with splits
flutter build apk --split-per-abi --release

# Install on device
adb install build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk

# Test critical flows
1. Launch app
2. Complete onboarding
3. Add contacts
4. Trigger emergency
5. Check logs for ProGuard issues

# Check for crashes
adb logcat | grep -i "fatal\|exception\|error"
```

### 4. Complete Data Safety Form ⏱️ 30 minutes

**Google Play Console → App content → Data safety**

Use this information:
```
Data collected:
✅ Location (precise) - For emergency response
✅ Contacts - For emergency contact list
✅ Personal info (name, email) - For user profile
✅ Device ID - For push notifications

Data shared:
✅ Location - With emergency contacts only
✅ Device info - With Firebase Crashlytics

Data encrypted:
✅ In transit (HTTPS)
✅ At rest (AES-256)

User can request deletion:
✅ Yes (via settings → delete account)
```

---

## 🟡 High Priority (Next 3 Days)

### 5. 24-Hour Battery Test ⏱️ 24 hours (passive)

```bash
# Setup
1. Fully charge device
2. Install app
3. Enable all features
4. Note battery level: ____%
5. Leave overnight

# Check after 24h
adb shell dumpsys battery
# Expected: < 5% drain in 24h idle
```

### 6. Add Timeout Guards ⏱️ 1 hour

**Files to modify:**

1. **firebase_service.dart** - Add timeout to all Firestore operations
2. **location_service.dart** - Add timeout to location requests
3. **sms_service.dart** - Add timeout to SMS sending

**Pattern:**
```dart
// BEFORE
await operation();

// AFTER
await operation().timeout(
  Duration(seconds: 10),
  onTimeout: () => throw TimeoutException('Operation timed out'),
);
```

### 7. Optimize Image Assets ⏱️ 30 minutes

```bash
# Install pngquant
brew install pngquant  # macOS
sudo apt install pngquant  # Linux

# Compress icons
cd assets/icon
pngquant --quality=80-90 --ext .png --force *.png

# Verify size reduction
du -sh .
# Expected: 40-50% size reduction
```

---

## 🟢 Medium Priority (Next Week)

### 8. Performance Profiling ⏱️ 2 hours

```bash
# Profile app startup
flutter run --profile --trace-startup

# Profile emergency trigger
flutter run --profile
# Trigger emergency, then:
# DevTools → Performance → Record

# Analyze results
# Look for:
# - Jank (frame time > 16ms)
# - Long-running operations
# - Memory leaks
```

### 9. Memory Leak Detection ⏱️ 1 hour

```bash
# Run app
flutter run --profile

# Perform actions 10x:
# - Open/close screens
# - Add/delete contacts
# - Trigger/cancel emergency

# Check memory
adb shell dumpsys meminfo com.poyrazoncel.korubeni

# Expected:
# - Memory stable after 10 iterations
# - No continuous growth
```

### 10. Accessibility Audit ⏱️ 2 hours

```bash
# Enable TalkBack (Android)
Settings → Accessibility → TalkBack

# Test:
- [ ] All buttons have semantic labels
- [ ] Screen reader announces correctly
- [ ] Navigation works with TalkBack
- [ ] Forms are accessible

# Enable VoiceOver (iOS)
Settings → Accessibility → VoiceOver
```

---

## 🔵 Low Priority (Future Releases)

### 11. Certificate Pinning ⏱️ 3 hours
### 12. Request Signing ⏱️ 2 hours
### 13. Code Splitting ⏱️ 4 hours
### 14. Advanced Analytics ⏱️ 3 hours

---

## Testing Devices Recommended

### Minimum 3 Devices:

1. **Low-End** (< 2GB RAM)
   - Samsung Galaxy A10
   - Xiaomi Redmi 9A
   - Android 8.0 (API 26)

2. **Mid-Range** (3-4GB RAM)
   - Samsung Galaxy A52
   - Xiaomi Redmi Note 10
   - Android 11 (API 30)

3. **High-End** (> 6GB RAM)
   - Samsung Galaxy S21
   - Google Pixel 6
   - Android 14 (API 34)

---

## Quick Commands Reference

### Build Commands
```bash
# Debug APK
flutter build apk --debug

# Release APK (single)
flutter build apk --release

# Release APK (split by ABI)
flutter build apk --split-per-abi --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

### Testing Commands
```bash
# Install APK
adb install app-release.apk

# Uninstall
adb uninstall com.poyrazoncel.korubeni

# View logs
adb logcat | grep -i "korubeni\|flutter"

# Check service status
adb shell dumpsys activity services | grep BackgroundService

# Force Doze Mode
adb shell dumpsys deviceidle force-idle

# Exit Doze Mode
adb shell dumpsys deviceidle unforce

# Check battery
adb shell dumpsys battery

# Check memory
adb shell dumpsys meminfo com.poyrazoncel.korubeni
```

### Firebase Commands
```bash
# Check Crashlytics
firebase crashlytics:reports

# Check Analytics
firebase analytics:events

# Deploy Firestore rules
firebase deploy --only firestore:rules
```

---

## Success Criteria

### Before Submitting to Play Store:
- ✅ All 8 critical tests pass on 3 devices
- ✅ No crashes in 24-hour test
- ✅ Battery drain < 5% in 24h idle
- ✅ Release APK tested and working
- ✅ Data safety form completed
- ✅ Privacy policy reviewed
- ✅ Store listing completed

### Performance Targets:
- ✅ Cold start < 3s
- ✅ Emergency trigger < 500ms
- ✅ Memory (idle) < 100MB
- ✅ Crash-free rate > 99.9%
- ✅ Battery drain < 10%/24h

---

## Timeline Estimate

**Week 1 (Critical):**
- Day 1-2: Run 8 critical tests (4h) + Add skeleton loaders (2h)
- Day 3: Test release APK (1h) + Complete data safety form (0.5h)
- Day 4-5: Fix any issues found

**Week 2 (High Priority):**
- Day 1: 24-hour battery test (setup)
- Day 2: Add timeout guards (1h) + Optimize images (0.5h)
- Day 3: Performance profiling (2h)
- Day 4-5: Fix any issues found

**Week 3 (Polish):**
- Day 1-2: Memory leak detection + Accessibility audit
- Day 3-4: Final testing on 3 devices
- Day 5: Submit to internal testing

**Week 4 (Beta):**
- Closed beta testing
- Collect feedback
- Fix critical issues

**Week 5-6 (Release):**
- Public release
- Monitor Crashlytics
- Respond to user feedback

---

## Contact for Issues

**Technical Issues:** destek@korubeni.com  
**Play Store Issues:** Google Play Console  
**Firebase Issues:** Firebase Console

---

**Created:** February 27, 2026  
**Last Updated:** February 27, 2026  
**Version:** 1.0

**Next Review:** After completing critical tasks
