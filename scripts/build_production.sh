#!/bin/bash

# KoruBeni - Production Build Script (Play Store AAB + optional iOS)
# Kullanım: ENCRYPTION_KEY='base64key' ./scripts/build_production.sh
# Key üretmek: openssl rand -base64 32

set -euo pipefail

echo "🏗️  KoruBeni Production Build Başlıyor..."
echo ""

# Pre-flight: android/key.properties (release signing)
# Dosya MUTLAKA android/key.properties olmali (proje kokune kopyalamayin)
if [ ! -f "android/key.properties" ]; then
    echo "❌ android/key.properties bulunamadı!"
    echo "   cp android/key.properties.example android/key.properties"
    echo "   Sonra storePassword, keyPassword, keyAlias, storeFile düzenle."
    echo "   (Dosya android/ klasöründe olmalı; kökteki key.properties kullanılmaz.)"
    exit 1
fi

# Encryption key kontrolü
if [ -z "$ENCRYPTION_KEY" ]; then
    echo "⚠️  ENCRYPTION_KEY bulunamadı!"
    echo ""
    echo "Lütfen encryption key'i belirle:"
    echo "export ENCRYPTION_KEY='senin-key-buraya'"
    echo ""
    echo "Veya script'e parametre olarak ver:"
    echo "./scripts/build_production.sh 'senin-key-buraya'"
    echo ""
    exit 1
fi

# İlk parametre encryption key olabilir
if [ -n "${1:-}" ]; then
    ENCRYPTION_KEY="$1"
fi

echo "🔐 Encryption key set (not logged for security)."
echo ""

# Flutter clean
echo "🧹 Flutter clean..."
flutter clean
echo ""

# Pub get
echo "📦 Dependencies yükleniyor..."
flutter pub get
echo ""

# Android AAB Build
echo "🤖 Android AAB build başlıyor..."
AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
BUILD_LOG="$(mktemp /tmp/korubeni_android_build.XXXXXX.log)"

set +e
flutter build appbundle --release \
  --dart-define=ENV=production \
  --dart-define=ENCRYPTION_KEY="$ENCRYPTION_KEY" 2>&1 | tee "$BUILD_LOG"
ANDROID_BUILD_EXIT=$?
set -e

if [ $ANDROID_BUILD_EXIT -ne 0 ]; then
    if [ -f "$AAB_PATH" ] && grep -q "failed to strip debug symbols from native libraries" "$BUILD_LOG"; then
        echo ""
        echo "⚠️  Flutter native symbol stripping uyarısı verdi, ancak AAB üretildi."
        echo "   Paket bütünlüğü yine de doğrulanıyor..."
        unzip -tq "$AAB_PATH" >/dev/null
    else
        echo ""
        echo "❌ Android build başarısız!"
        rm -f "$BUILD_LOG"
        exit 1
    fi
fi

echo ""
echo "✅ Android AAB build başarılı!"
echo "📦 Dosya: $AAB_PATH"
echo ""
rm -f "$BUILD_LOG"

# iOS Build (opsiyonel - sadece Mac'te)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 iOS build başlıyor..."
    flutter build ios --release \
      --dart-define=ENV=production \
      --dart-define=ENCRYPTION_KEY="$ENCRYPTION_KEY"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ iOS build başarılı!"
        echo "📦 Xcode'da Archive yapabilirsin: ios/Runner.xcworkspace"
        echo ""
    else
        echo ""
        echo "⚠️  iOS build başarısız (devam ediyoruz...)"
    fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Build tamamlandı!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📋 Sonraki adımlar:"
echo "1. Screenshot'ları al (store/screenshots/)"
echo "2. Privacy Policy'i canlıya al"
echo "3. Play Store Console'a git ve AAB'yi yükle"
echo "4. App Store Connect'e git ve iOS build'i yükle"
echo ""
