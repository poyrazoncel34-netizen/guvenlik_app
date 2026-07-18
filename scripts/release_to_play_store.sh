#!/usr/bin/env bash
# KoruBeni - Play Store release operator handoff
# Kullanım: ./scripts/release_to_play_store.sh v1.0.0
#
# This helper deliberately does NOT build or upload an AAB. Upload provenance
# comes only from the signed GitHub tag workflow. Local production builds are
# diagnostics and must never be submitted to Play.

set -euo pipefail

TAG="${1:-}"
if [[ ! "$TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "Kullanım: $0 vMAJOR.MINOR.PATCH"
    echo "Örnek: $0 v1.0.0"
    exit 2
fi

echo "═══════════════════════════════════════════════════════════"
echo "  KoruBeni - Play Store Release"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "Tag: $TAG"
echo ""
echo "Bu script yerel AAB DERLEMEZ ve YÜKLEMEZ."
echo "1. Temiz commit üzerinde $TAG etiketini oluşturup origin'e gönderin."
echo "2. GitHub Actions → 'Release Play AAB' çalışmasının yeşil olmasını bekleyin."
echo "3. Çalışmadan AAB + provenance + SHA256SUMS + debug symbols indirin."
echo "4. AAB yolu: build/app/outputs/bundle/playRelease/app-play-release.aab"
echo "5. Upload sertifikası, SHA-256 ve workflow run URL kanıtını kaydedin."
echo "6. Play Console → Testing → Internal testing bölümüne bu CI artifact'ını yükleyin."
echo "7. store/PRODUCTION_ROLLOUT_RUNBOOK.md kapıları geçmeden production'a çıkmayın."
