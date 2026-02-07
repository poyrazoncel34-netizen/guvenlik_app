#!/bin/bash

# KoruBeni - Production Build Script
# Kullanım: ./scripts/build_production.sh

set -e

echo "🏗️  KoruBeni Production Build Başlıyor..."
echo ""

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

echo "🔐 Encryption key kullanılıyor: ${ENCRYPTION_KEY:0:20}..."
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
