#!/bin/bash
# KoruBeni - Privacy Policy Yayınlama
# GitHub Pages veya benzeri statik hosting için hazırlık

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PUBLISH_DIR="$PROJECT_ROOT/.gh-pages-publish"

echo "📄 Privacy Policy yayın hazırlığı..."
echo ""

# .gh-pages-publish güncelle
mkdir -p "$PUBLISH_DIR"
cp "$PROJECT_ROOT/store/privacy_policy_en.html" "$PUBLISH_DIR/" 2>/dev/null || true
cp "$PROJECT_ROOT/store/privacy_policy.html" "$PUBLISH_DIR/" 2>/dev/null || true

# index.html zaten mevcut - ana sayfa TR gizlilik politikası
# privacy_policy_en.html - İngilizce sürüm (store gereksinimi)

echo "✅ .gh-pages-publish güncellendi"
echo ""
echo "═══════════════════════════════════════════════════════"
echo "GitHub Pages ile yayınlamak için:"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "1. GitHub repo Settings > Pages > Source: Deploy from a branch"
echo "2. Branch: gh-pages (veya main) / Folder: /.gh-pages-publish"
echo "   VEYA gh-pages branch oluştur:"
echo ""
echo "   npx gh-pages -d .gh-pages-publish"
echo ""
echo "3. URL: https://<username>.github.io/<repo>/"
echo "   Privacy (EN): https://<username>.github.io/<repo>/privacy_policy_en.html"
echo ""
echo "Alternatif: Netlify/Vercel ile .gh-pages-publish klasörünü deploy edin."
echo ""
