#!/usr/bin/env bash
# KoruBeni - Privacy Policy GitHub Pages Yayınlama
# Plan Madde 2: Privacy Policy'i yayınlayıp URL'yi Play Console'a yaz
# Kullanım: ./scripts/publish_privacy_policy.sh

set -e

echo "═══════════════════════════════════════════════════════════"
echo "  KoruBeni - Privacy Policy Yayınlama"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. Senkronize et
./scripts/sync_privacy_policy.sh
echo ""

# 2. Git commit ve push
echo "Git commit ve push yapılıyor..."
git add .gh-pages-publish
git status
echo ""
read -p "Commit ve push yapılsın mı? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git commit -m "chore: sync privacy policy for Play Store" || echo "Nothing to commit"
    git push
    echo ""
    echo "✅ Push tamamlandı. GitHub Actions .gh-pages-publish deploy edecek."
else
    echo "Manuel: git add .gh-pages-publish && git commit -m 'chore: sync privacy policy' && git push"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Sonraki Adım: Play Console"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "URL: https://poyrazoncel34-netizen.github.io/guvenlik_app/privacy_policy.html"
echo ""
echo "Play Console → Store presence → Store listing → Privacy policy alanına yukarıdaki URL'yi yaz."
echo ""
