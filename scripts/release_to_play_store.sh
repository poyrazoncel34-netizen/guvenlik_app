#!/usr/bin/env bash
# KoruBeni - Play Store Release Akışı
# Plan Madde 6-7: AAB build → Internal Testing → İncelemeye gönder
# Kullanım: ENCRYPTION_KEY='...' REVENUECAT_ANDROID_API_KEY='goog_...' ./scripts/release_to_play_store.sh

set -e

echo "═══════════════════════════════════════════════════════════"
echo "  KoruBeni - Play Store Release"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. İlk kez mi? Önce setup çalıştır: ./scripts/setup_play_release.sh

# 2. Encryption key
if [ -z "$ENCRYPTION_KEY" ]; then
    if [ -n "$1" ]; then
        ENCRYPTION_KEY="$1"
    else
        echo "ENCRYPTION_KEY gerekli:"
        echo "  ENCRYPTION_KEY='...' REVENUECAT_ANDROID_API_KEY='goog_...' $0"
        echo ""
        echo "Key üretmek için: openssl rand -base64 32"
        exit 1
    fi
fi

export ENCRYPTION_KEY

if [ -z "${REVENUECAT_ANDROID_API_KEY:-}" ]; then
    echo "REVENUECAT_ANDROID_API_KEY gerekli:"
    echo "  REVENUECAT_ANDROID_API_KEY='goog_...' ENCRYPTION_KEY='...' $0"
    exit 1
fi

# 3. AAB build
./scripts/build_production.sh

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Sonraki Adımlar (Play Console)"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "1. Play Console → Release → Testing → Internal testing"
echo "2. Create new release → AAB yükle: build/app/outputs/bundle/playRelease/app-play-release.aab"
echo "3. Release notları yaz"
echo "4. Save → Review release → Start rollout to Internal testing"
echo "5. İncelemeye gönder (Send for review)"
echo ""
