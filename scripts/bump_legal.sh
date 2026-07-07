#!/usr/bin/env bash
# KoruBeni — KVKK/aydinlatma legal SURUM + TARIH propagasyonu.
#
# Legal metnin GOVDESINI degistirmez (o insan isidir). Yalnizca surum
# numarasi ve tarih string'ini tum aynalar arasinda tutarli tasir:
#   1. lib/constants/legal_texts.dart  (Dart tek-kaynak sabitleri)
#   2. store/aydinlatma_metni.html     (HTML tek-kaynak)
#   3. test/release_readiness_policy_test.dart (drift-yakalayan pinler)
#   4. .gh-pages-publish/aydinlatma.html  -> store/'dan URETILIR (elle DEGIL)
#
# Eski degerler legal_texts.dart'tan OTOMATIK kesfedilir; elle "eski surum ne
# idi" hatasi olmaz. Sonunda parity testi kosar: deterministik yesil/kirmizi.
#
# Kullanim:
#   ./scripts/bump_legal.sh --kvkk 3.3.0 --date "10 Temmuz 2026" --date-en "July 10, 2026"
#   ./scripts/bump_legal.sh --kvkk 3.3.0 --date "10 Temmuz 2026" --date-en "July 10, 2026" --dry-run
#
# --dry-run: hicbir dosyayi degistirmeden, hangi degisikligin yapilacagini yazar.
#
# NEDEN: kvkkVersion bump'i LegalVersionChecker uzerinden mevcut kullanicilari
# yeniden onaya yonlendirir (tasarim). Bu yuzden keyfi bump yapma — yalnizca
# aydinlatma metni gercekten degistiginde. Ayrinti: memory/legal-version-bump-process.

set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"

NEW_KVKK=""; NEW_DATE=""; NEW_DATE_EN=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --kvkk) NEW_KVKK="$2"; shift 2;;
    --date) NEW_DATE="$2"; shift 2;;
    --date-en) NEW_DATE_EN="$2"; shift 2;;
    --dry-run) DRY=1; shift;;
    *) echo "Bilinmeyen arg: $1" >&2; exit 2;;
  esac
done
[ -n "$NEW_KVKK" ] && [ -n "$NEW_DATE" ] && [ -n "$NEW_DATE_EN" ] || {
  echo "Gerekli: --kvkk X.Y.Z --date 'TR tarih' --date-en 'EN date'" >&2; exit 2; }

L="lib/constants/legal_texts.dart"
OLD_KVKK="$(sed -n "s/.*kvkkVersion = '\\([^']*\\)'.*/\\1/p" "$L")"
OLD_DATE="$(sed -n "s/.*lastUpdatedKvkk = '\\([^']*\\)'.*/\\1/p" "$L")"
OLD_DATE_EN="$(sed -n "s/.*lastUpdatedKvkkEn = '\\([^']*\\)'.*/\\1/p" "$L")"
[ -n "$OLD_KVKK" ] || { echo "Mevcut kvkkVersion okunamadi." >&2; exit 1; }

echo "kvkkVersion : $OLD_KVKK -> $NEW_KVKK"
echo "TR tarih    : $OLD_DATE -> $NEW_DATE"
echo "EN tarih    : $OLD_DATE_EN -> $NEW_DATE_EN"

if [ "$DRY" = 1 ]; then
  echo ""; echo "[dry-run] Etkilenecek satirlar:"
  grep -rn --fixed-strings "$OLD_KVKK" "$L" test/release_readiness_policy_test.dart store/aydinlatma_metni.html 2>/dev/null | grep -iE "version|Sürüm|surum" | head
  grep -rn --fixed-strings "$OLD_DATE" "$L" store/aydinlatma_metni.html 2>/dev/null | head
  echo "[dry-run] Hicbir dosya degistirilmedi."; exit 0
fi

sed_i() { if [[ "$OSTYPE" == "darwin"* ]]; then sed -i '' "$@"; else sed -i "$@"; fi; }

# 1. Dart sabitleri
sed_i "s/kvkkVersion = '$OLD_KVKK'/kvkkVersion = '$NEW_KVKK'/" "$L"
sed_i "s/lastUpdatedKvkk = '$OLD_DATE'/lastUpdatedKvkk = '$NEW_DATE'/" "$L"
sed_i "s/lastUpdatedKvkkEn = '$OLD_DATE_EN'/lastUpdatedKvkkEn = '$NEW_DATE_EN'/" "$L"

# 2. store/ HTML tek-kaynak (surum + TR tarih; string-literal degistirme)
sed_i "s/Sürüm $OLD_KVKK/Sürüm $NEW_KVKK/g; s/$OLD_DATE/$NEW_DATE/g" store/aydinlatma_metni.html

# 3. Test pinleri (drift-yakalayici; bump ile bilincli tasinir)
T="test/release_readiness_policy_test.dart"
sed_i "s/kvkkVersion, '$OLD_KVKK'/kvkkVersion, '$NEW_KVKK'/" "$T"
sed_i "s/lastUpdatedKvkk, '$OLD_DATE'/lastUpdatedKvkk, '$NEW_DATE'/" "$T"
sed_i "s/Sürüm $OLD_KVKK/Sürüm $NEW_KVKK/g" "$T"

# 4. gh-pages aynasini URET (elle degil)
./scripts/sync_privacy_policy.sh >/dev/null
echo "gh-pages aynasi store/'dan yeniden uretildi."

# 5. Deterministik kapi: parity testi
echo ""; echo "Parity testi kosuluyor..."
if flutter test test/release_readiness_policy_test.dart >/dev/null 2>&1; then
  echo "PARITY YESIL — legal bump $NEW_KVKK tutarli."
  echo "Sonraki: ./scripts/verify_release.sh  &&  git push origin main gh-pages"
else
  echo "PARITY KIRMIZI — pinler ya da aynalar tutmadi; 'flutter test test/release_readiness_policy_test.dart' ile bak." >&2
  exit 1
fi
