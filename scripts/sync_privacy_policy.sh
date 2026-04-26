#!/usr/bin/env bash
# store/ gizlilik politikası HTML dosyalarını .gh-pages-publish/ ile senkronize eder.
# GitHub Pages deploy için .gh-pages-publish kullanılır.
# Kullanım: ./scripts/sync_privacy_policy.sh

set -e

DEST=".gh-pages-publish"
SRC="store"

mkdir -p "$DEST"
cp "$SRC/privacy_policy.html" "$DEST/"
cp "$SRC/privacy_policy_en.html" "$DEST/"
cp "$SRC/kullanim_sartlari.html" "$DEST/"
cp "$SRC/aydinlatma_metni.html" "$DEST/aydinlatma.html"
cp "$SRC/data_deletion.html" "$DEST/"
# index.html: ana sayfa olarak TR versiyonuna yönlendir
if [ -f "$DEST/index.html" ]; then
  # Mevcut index varsa güncelle (linkler için)
  cp "$SRC/privacy_policy.html" "$DEST/index.html"
else
  cp "$SRC/privacy_policy.html" "$DEST/index.html"
fi

echo "✅ Gizlilik politikası .gh-pages-publish/ ile senkronize edildi."
echo "   Sonraki adım: git add .gh-pages-publish && git commit -m 'chore: sync privacy policy' && git push"
