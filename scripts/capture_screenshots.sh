#!/usr/bin/env bash
# KoruBeni - Android Screenshot Yakalama Script
# Plan Madde 4: Screenshots al
# Kullanım: Uygulama emülatörde/cihazda açıkken her ekranda ./scripts/capture_screenshots.sh 01_home
# veya: ./scripts/capture_screenshots.sh all (sonra her ekranda Enter'a bas)

set -e

OUT_DIR="store/screenshots/android"
DEVICE_PATH="/sdcard/korubeni_screenshot.png"

mkdir -p "$OUT_DIR"

capture() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "Kullanım: $0 <dosya_adı>"
        echo "Örnek: $0 01_home"
        echo ""
        echo "Yakalanacak ekranlar:"
        echo "  01_home   - Ana sayfa (panik butonu)"
        echo "  02_contacts - Acil kişiler"
        echo "  03_map    - Harita / Konum paylaşımı"
        echo "  04_safe_walk - Güvenli yürüyüş"
        echo "  05_fake_call - Sahte arama"
        echo "  06_settings - Ayarlar"
        exit 1
    fi

    echo "📸 Ekran yakalanıyor: $name"
    adb shell screencap -p "$DEVICE_PATH" || { echo "❌ adb hatası. Emülatör/cihaz bağlı mı?"; exit 1; }
    adb pull "$DEVICE_PATH" "$OUT_DIR/${name}.png" >/dev/null 2>&1
    adb shell rm -f "$DEVICE_PATH" 2>/dev/null || true
    echo "   ✅ $OUT_DIR/${name}.png"
}

if [ "$1" = "all" ]; then
    for label in 01_home 02_contacts 03_map 04_safe_walk 05_fake_call 06_settings; do
        echo ""
        read -p "Ekranı hazırla: $label — Enter'a bas" -r
        capture "$label"
    done
    echo ""
    echo "✅ Tüm screenshot'lar alındı: $OUT_DIR/"
else
    capture "$1"
fi
