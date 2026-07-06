#!/usr/bin/env bash
# KoruBeni - Play Store Release Akışı
# Plan Madde 6-7: AAB build → Internal Testing → İncelemeye gönder
# Kullanım: REVENUECAT_ANDROID_API_KEY=<redacted> ./scripts/release_to_play_store.sh

set -e

echo "═══════════════════════════════════════════════════════════"
echo "  KoruBeni - Play Store Release"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. İlk kez mi? Önce setup çalıştır: ./scripts/setup_play_release.sh

if [ -z "${REVENUECAT_ANDROID_API_KEY:-}" ]; then
    printf '%s\n' "REVENUECAT_ANDROID_API_KEY gerekli:"
    printf '%s\n' "  REVENUECAT_ANDROID_API_KEY=<redacted> $0"
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
