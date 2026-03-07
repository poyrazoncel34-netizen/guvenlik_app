#!/usr/bin/env bash
# KoruBeni - Play Store Release Hazırlık Script
# Plan: İkon ve key.properties hazırlığı
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
    echo "   → 1024x1024 PNG tasarım oluşturup assets/icon/app_icon.png olarak kaydet"
    echo "   → Sonra: dart run flutter_launcher_icons"
    exit 1
fi

# 2. key.properties
echo ""
echo "2. key.properties..."
if [ -f "$KEY_PROPS" ]; then
    echo "   ✅ android/key.properties mevcut"
else
    echo "   ⚠️  key.properties yok. Örnekten oluşturuluyor..."
    cp "$KEY_EXAMPLE" "$KEY_PROPS"
    echo "   ✅ $KEY_PROPS oluşturuldu"
    echo ""
    echo "   ⚠️  DÜZENLEMEN GEREKİYOR: nano $KEY_PROPS"
    echo "   - storePassword, keyPassword gerçek değerlerini gir"
    echo "   - storeFile=korubeni-release-key.jks (keystore android/ içinde olmalı)"
    echo ""
    echo "   Keystore yoksa:"
    echo "   cd android && keytool -genkey -v -keystore korubeni-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias korubeni"
fi

# 3. Launcher icons üret
echo ""
echo "3. Launcher icons üretiliyor..."
dart run flutter_launcher_icons
echo "   ✅ Android ve iOS ikonları oluşturuldu"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Hazırlık tamamlandı!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Sonraki: ENCRYPTION_KEY='...' ./scripts/build_production.sh"
echo ""
