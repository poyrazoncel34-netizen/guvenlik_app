#!/bin/bash

# KoruBeni - Production Build Script (Play Store AAB)
# Kullanım: REVENUECAT_ANDROID_API_KEY=<redacted> ./scripts/build_production.sh
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

# RevenueCat Android API key kontrolü
if [ -z "${REVENUECAT_ANDROID_API_KEY:-}" ]; then
    printf '%s\n' "❌ REVENUECAT_ANDROID_API_KEY bulunamadı!"
    echo ""
    echo "Production abonelik akışı için RevenueCat Android API key gerekli:"
    printf '%s\n' "export REVENUECAT_ANDROID_API_KEY=<redacted>"
    echo ""
    exit 1
fi

echo "🐱 RevenueCat Android API key set (not logged for security)."
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
echo "   Sensitive dart defines are set; values are redacted."
AAB_PATH="build/app/outputs/bundle/playRelease/app-play-release.aab"
SYMBOLS_DIR="build/app/debug-symbols"
BUILD_LOG="$(mktemp /tmp/korubeni_android_build.XXXXXX.log)"

# Obfuscation + split debug info: Dart code is obfuscated for release,
# and the symbol files needed to deobfuscate crash stacks are written to
# $SYMBOLS_DIR. After upload, Play Console can be given these symbols
# (App bundle explorer → Native debug symbols) to symbolicate the
# Pre-launch and Production crash reports.
mkdir -p "$SYMBOLS_DIR"

set +e
flutter build appbundle --release \
  --flavor play \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR" \
  --dart-define=ENV=production \
  --dart-define=REVENUECAT_ANDROID_API_KEY="$REVENUECAT_ANDROID_API_KEY" 2>&1 | tee "$BUILD_LOG"
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
echo "📦 AAB: $AAB_PATH"
echo "🗂️  Debug symbols: $SYMBOLS_DIR (zip'leyip Play Console'a yükleyin)"
echo ""
rm -f "$BUILD_LOG"

# 16 KB page-size compatibility check (Play Store zorunluluğu Nov 1, 2025+)
if [ -x "./scripts/verify_16kb_alignment.sh" ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "🔍 16 KB page-size compatibility verification"
    echo "═══════════════════════════════════════════════════════════"
    if ./scripts/verify_16kb_alignment.sh "$AAB_PATH"; then
        :
    else
        echo ""
        echo "⚠️  16 KB alignment kontrolü uyarı verdi. Yukarıdaki çıktıyı"
        echo "    inceleyin. Play Store'a yüklemeden önce düzeltilmelidir."
    fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Build tamamlandı!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📋 Sonraki adımlar:"
echo "1. Android screenshot'larını al (store/screenshots/android/)"
echo "2. Privacy Policy'i canlıya al"
echo "3. Play Store Console'a git ve AAB'yi yükle"
echo "4. Symbol klasörünü zip'leyip Play Console → App bundle explorer →"
echo "   Native debug symbols altına yükleyin (crash deobfuscation için)"
echo ""
