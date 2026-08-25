#!/usr/bin/env bash
# KoruBeni — legal SURUM + TARIH propagasyonu (KVKK/aydinlatma ve Kullanim Sartlari).
#
# Legal metnin GOVDESINI degistirmez (o insan isidir). Yalnizca surum
# numarasi ve tarih string'ini tum aynalar arasinda tutarli tasir.
#
# KVKK/aydinlatma aynalari:
#   1. lib/constants/legal_texts.dart  (Dart tek-kaynak sabitleri)
#   2. store/aydinlatma_metni.html     (HTML tek-kaynak)
#   3. test/release_readiness_policy_test.dart (drift-yakalayan pinler)
#   4. .gh-pages-publish/aydinlatma.html  -> store/'dan URETILIR (elle DEGIL)
#
# Kullanim Sartlari aynalari:
#   1. lib/constants/legal_texts.dart  (termsVersion, lastUpdated, lastUpdatedEn)
#   2. store/kullanim_sartlari.html    (HTML tek-kaynak; EN aynasi YOKTUR)
#   3. test/release_readiness_policy_test.dart (pinler)
#   4. .gh-pages-publish/kullanim_sartlari.html -> store/'dan URETILIR
#
# Eski degerler legal_texts.dart'tan OTOMATIK kesfedilir; elle "eski surum ne
# idi" hatasi olmaz. Sonunda artik-deger taramasi + parity testi kosar:
# deterministik yesil/kirmizi.
#
# Kullanim:
#   ./scripts/bump_legal.sh --kvkk 3.5.0 --date "10 Temmuz 2026" --date-en "July 10, 2026"
#   ./scripts/bump_legal.sh --terms 4.0.0 --terms-date "25 Agustos 2026" --terms-date-en "August 25, 2026"
#   ...ikisi ayni anda da verilebilir. --dry-run hicbir dosyayi degistirmez.
#
# NEDEN: kvkkVersion VE termsVersion bump'i LegalVersionChecker uzerinden mevcut
# kullanicilari yeniden onaya yonlendirir (tasarim). Bu yuzden keyfi bump yapma —
# yalnizca metin gercekten degistiginde. Ayrinti: memory/legal-version-bump-process.
#
# BU SCRIPT'IN DOKUNMADIGI DOSYA — ve nedeni:
#   test/screens/unlock_screen_density_overflow_test.dart
#   Surum satiri orada IKI farkli rolde geciyor: yorumlarda CIHAZDA OLCULMUS
#   tarihsel bir bulgunun birebir alintisi ("API 36, density 560, 82 px tasma"),
#   test govdesinde ise canli regresyon fixture'i. Kor bir sed ikisini birden
#   yazar ve tarihsel olcum kaydini tahrif eder — bu reponun CERT2-05'te
#   yasakladigi seyin ta kendisi. Fixture'i insan bilincli olarak gunceller.
#   Script bu dosyanin KOD satirlarini mutasyondan ONCE kontrol eder ve eski
#   deger duruyorsa hicbir dosyaya dokunmadan durur; yorumlarina hic bakmaz.

set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"

NEW_KVKK=""; NEW_DATE=""; NEW_DATE_EN=""
NEW_TERMS=""; NEW_TDATE=""; NEW_TDATE_EN=""
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --kvkk) NEW_KVKK="$2"; shift 2;;
    --date) NEW_DATE="$2"; shift 2;;
    --date-en) NEW_DATE_EN="$2"; shift 2;;
    --terms) NEW_TERMS="$2"; shift 2;;
    --terms-date) NEW_TDATE="$2"; shift 2;;
    --terms-date-en) NEW_TDATE_EN="$2"; shift 2;;
    --dry-run) DRY=1; shift;;
    *) echo "Bilinmeyen arg: $1" >&2; exit 2;;
  esac
done

DO_KVKK=0; DO_TERMS=0
[ -n "$NEW_KVKK$NEW_DATE$NEW_DATE_EN" ] && DO_KVKK=1
[ -n "$NEW_TERMS$NEW_TDATE$NEW_TDATE_EN" ] && DO_TERMS=1

[ "$DO_KVKK" = 1 ] || [ "$DO_TERMS" = 1 ] || {
  echo "En az biri gerekli:" >&2
  echo "  --kvkk X.Y.Z --date 'TR tarih' --date-en 'EN date'" >&2
  echo "  --terms X.Y.Z --terms-date 'TR tarih' --terms-date-en 'EN date'" >&2
  exit 2; }

# Kismi arg = sessiz yarim bump. Her uclusu birlikte istenir.
if [ "$DO_KVKK" = 1 ]; then
  [ -n "$NEW_KVKK" ] && [ -n "$NEW_DATE" ] && [ -n "$NEW_DATE_EN" ] || {
    echo "KVKK bump'i icin ucu birden gerekli: --kvkk --date --date-en" >&2; exit 2; }
fi
if [ "$DO_TERMS" = 1 ]; then
  [ -n "$NEW_TERMS" ] && [ -n "$NEW_TDATE" ] && [ -n "$NEW_TDATE_EN" ] || {
    echo "Terms bump'i icin ucu birden gerekli: --terms --terms-date --terms-date-en" >&2; exit 2; }
fi

L="lib/constants/legal_texts.dart"
T="test/release_readiness_policy_test.dart"
U="test/screens/unlock_screen_density_overflow_test.dart"

read_const() { sed -n "s/.*$1 = '\\([^']*\\)'.*/\\1/p" "$L"; }

if [ "$DO_KVKK" = 1 ]; then
  OLD_KVKK="$(read_const kvkkVersion)"
  OLD_DATE="$(read_const lastUpdatedKvkk)"
  OLD_DATE_EN="$(read_const lastUpdatedKvkkEn)"
  [ -n "$OLD_KVKK" ] || { echo "Mevcut kvkkVersion okunamadi." >&2; exit 1; }
  echo "kvkkVersion  : $OLD_KVKK -> $NEW_KVKK"
  echo "KVKK TR tarih: $OLD_DATE -> $NEW_DATE"
  echo "KVKK EN tarih: $OLD_DATE_EN -> $NEW_DATE_EN"
fi

if [ "$DO_TERMS" = 1 ]; then
  # lastUpdated / lastUpdatedEn KVKK ikizleriyle karismaz: read_const deseni
  # ' = ' ayiracini kullanir, "lastUpdatedKvkk = " ile eslesmez.
  OLD_TERMS="$(read_const termsVersion)"
  OLD_TDATE="$(read_const lastUpdated)"
  OLD_TDATE_EN="$(read_const lastUpdatedEn)"
  [ -n "$OLD_TERMS" ] || { echo "Mevcut termsVersion okunamadi." >&2; exit 1; }
  echo "termsVersion  : $OLD_TERMS -> $NEW_TERMS"
  echo "Terms TR tarih: $OLD_TDATE -> $NEW_TDATE"
  echo "Terms EN tarih: $OLD_TDATE_EN -> $NEW_TDATE_EN"
fi

if [ "$DRY" = 1 ]; then
  echo ""; echo "[dry-run] Etkilenecek satirlar:"
  if [ "$DO_KVKK" = 1 ]; then
    grep -rn --fixed-strings "$OLD_KVKK" "$L" "$T" store/aydinlatma_metni.html 2>/dev/null \
      | grep -iE "version|Sürüm|surum" | head || true
    grep -rn --fixed-strings "$OLD_DATE" "$L" store/aydinlatma_metni.html 2>/dev/null | head || true
  fi
  if [ "$DO_TERMS" = 1 ]; then
    grep -rn --fixed-strings "$OLD_TERMS" "$L" "$T" "$U" store/kullanim_sartlari.html 2>/dev/null \
      | grep -iE "version|Sürüm|surum" | head || true
    grep -rn --fixed-strings "$OLD_TDATE" "$L" "$T" "$U" store/kullanim_sartlari.html 2>/dev/null | head || true
    echo "[dry-run] NOT: $U script tarafindan DEGISTIRILMEZ (tarihsel olcum alintisi)."
  fi
  echo "[dry-run] Hicbir dosya degistirilmedi."; exit 0
fi

# --- ON-KONTROL: mutasyondan ONCE, karar dosyasinin KOD satirlari ------------
# $U script tarafindan hic yazilmaz (bkz. baslik). YORUMLARI cihazda olculmus
# tarihsel bir bulguyu birebir tasir ve oyle kalmalidir; KOD satirlari ise
# uygulamanin gercekten cizdigi string'i yansitmalidir. Kapi bu yuzden dar:
# eski deger yorumda kalabilir, kodda kalamaz.
#
# Kontrol mutasyondan ONCE kosar. Sonra kosaydi -- ilk tasarimda oyleydi --
# dosyalar zaten degismis olurdu ve script'in kendi tavsiye ettigi "duzelt,
# tekrar kos" akisi calismazdi: ikinci kosuda OLD == NEW olur, tarama YENI
# degeri arar ve her yerde bulurdu. O akis hicbir zaman yesile ulasmiyordu.
preflight_judgement_file() {
  local old="$1" label="$2" stale
  [ -f "$U" ] || return 0
  stale="$(grep -nvE '^[[:space:]]*//' "$U" 2>/dev/null | grep --fixed-strings "$old" || true)"
  [ -n "$stale" ] || return 0
  echo "ON-KONTROL DURDURDU — hicbir dosya degistirilmedi." >&2
  echo "$U icindeki KOD satirlari hala eski $label '$old' degerini tasiyor:" >&2
  echo "$stale" >&2
  echo "" >&2
  echo "Bu dosyanin fixture'i uygulamanin cizdigi string'i yansitmali; ayni" >&2
  echo "dosyadaki YORUMLAR ise tarihsel cihaz olcumu oldugu icin AYNEN kalmali" >&2
  echo "(CERT2-05). Fixture'i elle guncelle, sonra bu script'i kos." >&2
  exit 1
}
if [ "$DO_TERMS" = 1 ]; then
  [ "$OLD_TERMS" = "$NEW_TERMS" ] || preflight_judgement_file "$OLD_TERMS" "surum"
  [ "$OLD_TDATE" = "$NEW_TDATE" ] || preflight_judgement_file "$OLD_TDATE" "tarih"
fi

sed_i() { if [[ "$OSTYPE" == "darwin"* ]]; then sed -i '' "$@"; else sed -i "$@"; fi; }

if [ "$DO_KVKK" = 1 ]; then
  # 1. Dart sabitleri
  sed_i "s/kvkkVersion = '$OLD_KVKK'/kvkkVersion = '$NEW_KVKK'/" "$L"
  sed_i "s/lastUpdatedKvkk = '$OLD_DATE'/lastUpdatedKvkk = '$NEW_DATE'/" "$L"
  sed_i "s/lastUpdatedKvkkEn = '$OLD_DATE_EN'/lastUpdatedKvkkEn = '$NEW_DATE_EN'/" "$L"
  # 2. store/ HTML tek-kaynak
  sed_i "s/Sürüm $OLD_KVKK/Sürüm $NEW_KVKK/g; s/$OLD_DATE/$NEW_DATE/g" store/aydinlatma_metni.html
  # 3. Test pinleri
  sed_i "s/kvkkVersion, '$OLD_KVKK'/kvkkVersion, '$NEW_KVKK'/" "$T"
  sed_i "s/lastUpdatedKvkk, '$OLD_DATE'/lastUpdatedKvkk, '$NEW_DATE'/" "$T"
  sed_i "s/Sürüm $OLD_KVKK/Sürüm $NEW_KVKK/g" "$T"
fi

if [ "$DO_TERMS" = 1 ]; then
  # 1. Dart sabitleri. 'lastUpdated = ' deseni 'lastUpdatedEn = ' ve
  #    'lastUpdatedKvkk = ' ile eslesmez; ayirac bosluklu esittir.
  sed_i "s/termsVersion = '$OLD_TERMS'/termsVersion = '$NEW_TERMS'/" "$L"
  sed_i "s/lastUpdated = '$OLD_TDATE'/lastUpdated = '$NEW_TDATE'/" "$L"
  sed_i "s/lastUpdatedEn = '$OLD_TDATE_EN'/lastUpdatedEn = '$NEW_TDATE_EN'/" "$L"
  # 2. store/ HTML tek-kaynak. Tarih "Son güncelleme: " onekine sabitlenir ki
  #    govdedeki baska bir tarih gecisi yanlislikla tasinmasin.
  sed_i "s/Sürüm $OLD_TERMS/Sürüm $NEW_TERMS/g; s/Son güncelleme: $OLD_TDATE/Son güncelleme: $NEW_TDATE/g" \
    store/kullanim_sartlari.html
  # 3. Test pinleri. Virgul ayiraci 'lastUpdatedKvkk,' ile karismayi onler.
  sed_i "s/termsVersion, '$OLD_TERMS'/termsVersion, '$NEW_TERMS'/" "$T"
  sed_i "s/lastUpdated, '$OLD_TDATE'/lastUpdated, '$NEW_TDATE'/" "$T"
fi

# 4. gh-pages aynasini URET (elle degil). kullanim_sartlari.html de kopyalanir.
./scripts/sync_privacy_policy.sh >/dev/null
echo "gh-pages aynasi store/'dan yeniden uretildi."

# 5. Artik-deger taramasi (backstop): propagasyonun kacirdigi bir yer var mi?
#    Karar dosyasi $U DISARIDA birakilir -- yorumlari eski degeri bilerek tasir,
#    kod satirlari ise yukaridaki on-kontrolde zaten kapatildi. Ikisini ayni
#    taramaya sokmak, birbiriyle celisen iki kural yazmak olurdu.
#    Eski ile yeni ayniysa (idempotent tekrar kosu) taranacak artik da yoktur.
RESIDUE=0
scan_residue() {
  local old="$1" new="$2" label="$3" hits
  [ "$old" = "$new" ] && return 0
  hits="$(grep -rn --fixed-strings "$old" lib/ test/ store/ 2>/dev/null \
          | grep -v "^$U:" || true)"
  if [ -n "$hits" ]; then
    echo ""; echo "ARTIK DEGER — $label '$old' hala su satirlarda:" >&2
    echo "$hits" >&2
    RESIDUE=1
  fi
}
if [ "$DO_TERMS" = 1 ]; then
  scan_residue "$OLD_TERMS" "$NEW_TERMS" "termsVersion"
  scan_residue "$OLD_TDATE" "$NEW_TDATE" "Terms TR tarihi"
fi
if [ "$DO_KVKK" = 1 ]; then
  scan_residue "$OLD_KVKK" "$NEW_KVKK" "kvkkVersion"
  scan_residue "$OLD_DATE" "$NEW_DATE" "KVKK TR tarihi"
fi
if [ "$RESIDUE" = 1 ]; then
  echo "" >&2
  echo "Propagasyon bu satirlari kacirdi. Elle guncelleyip script'i tekrar kos." >&2
  exit 1
fi

# 6. Deterministik kapi: parity testi
echo ""; echo "Parity testi kosuluyor..."
if flutter test "$T" >/dev/null 2>&1; then
  echo "PARITY YESIL — legal bump tutarli."
  echo "Sonraki: ./scripts/verify_release.sh  &&  git push origin main gh-pages"
else
  echo "PARITY KIRMIZI — pinler ya da aynalar tutmadi; 'flutter test $T' ile bak." >&2
  exit 1
fi
