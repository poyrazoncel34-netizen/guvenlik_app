#!/bin/bash

# KoruBeni - Production Build Script (Play Store AAB + optional iOS)
# Kullanım: ENCRYPTION_KEY='base64key' ./scripts/build_production.sh
# Key üretmek: openssl rand -base64 32

set -e

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

# Pre-flight: google-services.json (Firebase)
if [ ! -f "android/app/google-services.json" ]; then
    echo "❌ android/app/google-services.json bulunamadı!"
    echo "   Firebase Console > Project Settings > Android app > indir, bu yola koy."
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
if [ ! -z "$1" ]; then
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
flutter build appbundle --release \
  --dart-define=ENV=production \
  --dart-define=ENCRYPTION_KEY="$ENCRYPTION_KEY"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Android AAB build başarılı!"
    echo "📦 Dosya: build/app/outputs/bundle/release/app-release.aab"
    echo ""
else
    echo ""
    echo "❌ Android build başarısız!"
    exit 1
fi

# iOS Build (opsiyonel - sadece Mac'te)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ ! -f "ios/Runner/GoogleService-Info.plist" ]; then
        echo "⚠️  ios/Runner/GoogleService-Info.plist bulunamadı!"
        echo "   iOS'ta Firebase kullanmak için Firebase Console > Project Settings > iOS app > indir, ios/Runner/ altına koy."
        echo "   Devam ediliyor (Firebase olmadan build alınacak)..."
        echo ""
    fi
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
