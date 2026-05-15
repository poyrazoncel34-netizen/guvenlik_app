#!/usr/bin/env bash
# KoruBeni - Play Store Release Hazırlık Script
# Plan: Operator checklist only; do not create signing files.
# Kullanım: ./scripts/setup_play_release.sh

set -e

ANDROID_DIR="android"
KEY_PROPS="$ANDROID_DIR/key.properties"
KEY_EXAMPLE="$ANDROID_DIR/key.properties.example"
ICON_PATH="assets/icon/app_icon.png"

echo "═══════════════════════════════════════════════════════════"
echo "  KoruBeni Play Store Release Hazırlık"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. App Icon kontrolü
echo "1. App icon..."
if [ -f "$ICON_PATH" ]; then
    echo "   ✅ assets/icon/app_icon.png mevcut"
else
    echo "   ❌ $ICON_PATH bulunamadı!"
    echo "   → Launcher kaynak PNG'sini assets/icon/app_icon.png olarak kaydet"
    echo "   → Play listing için 512x512 PNG: store/assets/play_icon_512.png"
    echo "   → Sonra: dart run flutter_launcher_icons"
    exit 1
fi

# 2. key.properties
echo ""
echo "2. key.properties..."
if [ -f "$KEY_PROPS" ]; then
    echo "   ✅ android/key.properties mevcut"
else
    echo "   ⚠️  key.properties yok. Bu script dosya oluşturmaz veya signing materyali üretmez."
    echo ""
    echo "   Operator güvenli release-signing prosedürüyle oluşturmalı: $KEY_PROPS"
    echo "   - storePassword, keyPassword gerçek değerlerini gir"
    echo "   - storeFile=korubeni-release-key.jks (keystore android/ içinde olmalı)"
    echo ""
    echo "   Keystore yoksa:"
    echo "   cd android && keytool -genkey -v -keystore korubeni-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias korubeni"
fi

# 3. Launcher icons
echo ""
echo "3. Launcher icons..."
echo "   Bu script repo-tracked icon dosyalarını yeniden üretmez."
echo "   Gerekirse ayrı operator adımı olarak çalıştır: dart run flutter_launcher_icons"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Hazırlık tamamlandı!"
echo "═══════════════════════════════════════════════════════════"
echo ""
printf '%s\n' "Sonraki: ENCRYPTION_KEY=<redacted> REVENUECAT_ANDROID_API_KEY=<redacted> ./scripts/build_production.sh"
echo ""
