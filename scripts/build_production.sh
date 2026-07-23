#!/bin/bash

# KoruBeni - Production Build Script (Play Store AAB)
# Kullanım: REVENUECAT_ANDROID_API_KEY=<redacted> ./scripts/build_production.sh
# Anahtar RevenueCat dashboard'undaki Android PUBLIC SDK key olmalıdır.
# `sk_` ile başlayan secret key istemci uygulamasına asla gömülmez.

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

RC_KEY_LOWER="$(printf '%s' "$REVENUECAT_ANDROID_API_KEY" | tr '[:upper:]' '[:lower:]')"
if [[ "$REVENUECAT_ANDROID_API_KEY" =~ [[:space:]] ]] ||
   [[ "$RC_KEY_LOWER" != goog_* ]] ||
   [[ "$RC_KEY_LOWER" == sk_* ]] ||
   [[ "$RC_KEY_LOWER" == *placeholder* ]] ||
   [[ "$RC_KEY_LOWER" == *dummy* ]] ||
   [[ "$RC_KEY_LOWER" == *non_release_smoke* ]]; then
    echo "❌ RevenueCat anahtarı production public SDK key değil."
    echo "   Yalnız goog_ Android public SDK key kabul edilir; test_/sk_/placeholder reddedilir."
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
MERGED_MANIFEST="build/app/intermediates/merged_manifest/playRelease/processPlayReleaseMainManifest/AndroidManifest.xml"
ANDROID_SURFACE_REPORT="build/release-evidence/android-release-surface.json"
SYMBOLS_DIR="build/app/debug-symbols"

# Obfuscation + split debug info: Dart code is obfuscated for release,
# and the symbol files needed to deobfuscate crash stacks are written to
# $SYMBOLS_DIR. These are Flutter/Dart symbols for `flutter symbolize`.
# They are not R8 mapping files and not Play native debug symbols.
mkdir -p "$SYMBOLS_DIR"

flutter build appbundle --release \
  --flavor play \
  --target-platform android-arm64 \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR" \
  --dart-define=ENV=production \
  --dart-define=REVENUECAT_ANDROID_API_KEY="$REVENUECAT_ANDROID_API_KEY"

[ -s "$AAB_PATH" ] || { echo "❌ Beklenen AAB üretilmedi: $AAB_PATH"; exit 1; }
[ -s "$MERGED_MANIFEST" ] || { echo "❌ Birleşik Play manifesti bulunamadı."; exit 1; }
unzip -tq "$AAB_PATH" >/dev/null || { echo "❌ AAB ZIP bütünlüğü bozuk."; exit 1; }
if unzip -Z1 "$AAB_PATH" | awk -F/ \
    '/^base\/lib\/[^/]+\// && $3 != "arm64-v8a" { unexpected = 1 } END { exit !unexpected }'; then
    echo "❌ Production AAB arm64-v8a dışında native ABI içeriyor; yayın durduruldu."
    exit 1
fi
grep -q 'package="com.poyrazoncel.korubeni"' "$MERGED_MANIFEST" || {
    echo "❌ Birleşik manifest beklenen Play paket kimliğini taşımıyor."
    exit 1
}
python3 scripts/audit_android_release_surface.py \
    --manifest "$MERGED_MANIFEST" \
    --network-security-config android/app/src/main/res/xml/network_security_config.xml \
    --data-extraction-rules android/app/src/main/res/xml/data_extraction_rules.xml \
    --expected-package com.poyrazoncel.korubeni \
    --output "$ANDROID_SURFACE_REPORT" || {
        echo "❌ Birleşik Android release yüzeyi güvenlik denetimini geçemedi."
        exit 1
    }

SIGNATURE_LOG="$(mktemp /tmp/korubeni_aab_signature.XXXXXX)"
trap 'rm -f "$SIGNATURE_LOG"' EXIT
if LC_ALL=C jarsigner -verify -strict "$AAB_PATH" >"$SIGNATURE_LOG" 2>&1; then
    SIGNATURE_STATUS=0
else
    # Keep errexit enabled globally while still capturing jarsigner's strict
    # bitmask (4 is the expected self-signed upload-certificate warning).
    SIGNATURE_STATUS=$?
fi
# Android upload keys are commonly self-signed. jarsigner strict bit 4 means
# only "certificate chain not trusted"; every other bit (especially 16 for an
# unsigned entry) is a hard failure.
if [[ "$SIGNATURE_STATUS" -ne 0 && "$SIGNATURE_STATUS" -ne 4 ]]; then
    echo "❌ AAB JAR imza doğrulaması başarısız."
    sed -n '1,80p' "$SIGNATURE_LOG"
    exit 1
fi
if ! grep -Eq '^jar verified([,.]|$)' "$SIGNATURE_LOG"; then
    echo "❌ AAB imzalı olarak doğrulanamadı."
    sed -n '1,80p' "$SIGNATURE_LOG"
    exit 1
fi

echo ""
echo "✅ Android AAB build başarılı!"
echo "📦 AAB: $AAB_PATH"
echo "🗂️  Flutter/Dart symbols: $SYMBOLS_DIR (flutter symbolize için saklayın)"
echo "🔏 AAB JAR imzası doğrulandı."
echo ""

# 16 KB page-size compatibility check (Play Store zorunluluğu Nov 1, 2025+)
if [ -x "./scripts/verify_16kb_alignment.sh" ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "🔍 16 KB page-size compatibility verification"
    echo "═══════════════════════════════════════════════════════════"
    ./scripts/verify_16kb_alignment.sh "$AAB_PATH" || {
        echo "❌ 16 KB alignment kontrolü başarısız; yayın durduruldu."
        exit 1
    }
else
    echo "❌ scripts/verify_16kb_alignment.sh yok veya çalıştırılabilir değil."
    exit 1
fi

SHA256_FILE="$AAB_PATH.sha256"
shasum -a 256 "$AAB_PATH" | tee "$SHA256_FILE"
echo "🧾 SHA-256 kanıtı: $SHA256_FILE"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Build tamamlandı!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📋 Sonraki adımlar:"
echo "1. Android screenshot'larını al (store/screenshots/android/)"
echo "2. Privacy Policy'i canlıya al"
echo "3. Play Store Console'a git ve AAB'yi yükle"
echo "4. Dart symbol klasörünü release evidence ile saklayın; R8 mapping ve"
echo "   varsa NDK native symbols ayrı artifact'lerdir."
echo ""
