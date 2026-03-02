# KoruBeni - Asset Generation Commands

## 📱 Generate App Icons and Splash Screens

After updating `pubspec.yaml` with the icon and splash screen configurations, run these commands in your terminal:

### Step 1: Install Dependencies
```bash
flutter pub get
```

### Step 2: Generate Launcher Icons
```bash
dart run flutter_launcher_icons
```

This will generate:
- **Android**: App icons for all densities (mipmap folders)
- **Android**: Adaptive icons with the dark blue background (#0A1B2A)
- **iOS**: App icons for all sizes in Assets.xcassets

### Step 3: Generate Native Splash Screens
```bash
dart run flutter_native_splash:create
```

This will generate:
- **Android**: Native splash screen with dark blue background (#0A1B2A)
- **Android 12+**: Splash screen compatible with Android 12's new splash API
- **iOS**: LaunchScreen.storyboard with your app icon centered on dark blue background

---

## 🎨 Configuration Summary

### App Icon
- **Source**: `assets/icon/app_icon.png`
- **Background Color**: `#0A1B2A` (Dark Blue)
- **Platforms**: Android (including adaptive icons) + iOS

### Splash Screen
- **Background Color**: `#0A1B2A` (Dark Blue)
- **Image**: `assets/icon/app_icon.png` (centered)
- **Mode**: Fullscreen (no status bar during splash)
- **Platforms**: Android (including Android 12+) + iOS

---

## ✅ Verification Steps

After running the commands:

### Android
1. Check `android/app/src/main/res/mipmap-*` folders for app icons
2. Check `android/app/src/main/res/drawable*/launch_background.xml` for splash screen
3. Check `android/app/src/main/res/values/colors.xml` for splash background color
4. For Android 12+: Check `android/app/src/main/res/values-v31/styles.xml`

### iOS
1. Check `ios/Runner/Assets.xcassets/AppIcon.appiconset/` for app icons
2. Check `ios/Runner/Base.lproj/LaunchScreen.storyboard` for splash screen
3. Open Xcode and verify the launch screen looks correct

### Testing
1. **Android**: `flutter run` on Android device/emulator
2. **iOS**: `flutter run` on iOS device/simulator
3. Close and reopen the app to see the splash screen
4. Verify the app icon appears correctly on the home screen

---

## 🔧 Troubleshooting

### If icons don't appear:
```bash
# Clean and rebuild
flutter clean
flutter pub get
dart run flutter_launcher_icons
flutter run
```

### If splash screen doesn't appear:
```bash
# Regenerate splash screen
dart run flutter_native_splash:create
flutter clean
flutter run
```

### For iOS specifically:
```bash
# Clean iOS build
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter run
```

---

## 📝 Notes

- The splash screen will automatically be removed when your app is ready (when `runApp()` is called)
- The dark blue color `#0A1B2A` matches your app's theme for a seamless transition
- Android 12+ uses a new splash screen API - the configuration handles both old and new APIs
- iOS splash screens are displayed from the LaunchScreen.storyboard
- Make sure `assets/icon/app_icon.png` exists and is at least 1024x1024px for best results

---

## 🚀 Ready for Store Submission

After generating the assets:
1. ✅ App icons will be ready for both stores
2. ✅ Splash screens will provide a professional first impression
3. ✅ Android 12+ compatibility is ensured
4. ✅ iOS App Store requirements are met

Your app will have a polished, professional appearance from the moment users tap the icon!
