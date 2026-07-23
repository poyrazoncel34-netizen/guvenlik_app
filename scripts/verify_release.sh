#!/usr/bin/env bash
# KoruBeni — yerel/smoke aday doğrulama zinciri.
#
# Yerel olarak çalıştırılabilen build/test kapılarını doğru exit koduyla toplar.
# Play Console, fiziksel cihaz, billing, hukuk ve closed-soak kapılarını
# doğrulayamaz; başarı çıktısı production readiness iddiası değildir.
#
# Neden script, neden akil yurutme degil:
#   - Deterministik is akil yurutmeden ucuz ve guvenilirdir.
#   - `cmd | tail` gibi borular exit kodunu MASKELER: tail'in 0'i gercek
#     BUILD FAILED'i gizler. Bu script her adimin gercek koduna bakar
#     (pipefail + dogrudan kontrol), boylece boru kaynaklı hata maskelemesini
#     azaltır. Dış kapılar ayrıca kanıtlanır.
#
# Adim sirasi bilinclidir:
#   analyze -> test -> (flutter) build AAB -> (gradle) lint+unit+androidTest build
#   -> 16KB -> etiketli-yayin blocker durumu (SBOM/lisans/notices)
#   flutter build, gitignore'lu GeneratedPluginRegistrant'i YENILER; dogrudan
#   gradlew release task'lari bayat registrant'la "package does not exist" ile
#   patlar. Bu yuzden gradle lint HER ZAMAN flutter build'DEN SONRA kosar.
#
# Domain kontrolleri (legal surum<->HTML paritesi, secret yoklugu regresyonu,
# manifest<->docs tutarliligi) ZATEN test paketinde kodlu
# (test/release_readiness_policy_test.dart, test/release_artifact_paths_test.dart),
# bu yuzden ayri grep yoktur — `flutter test` onlari kapsar.
#
# Kullanim:
#   ./scripts/verify_release.sh
#
# Dogrulama-amacli build farkli `.smoke` application ID ve devre disi billing
# ile derlenir. CI gecici imza kullanir; yerelde mevcut release signing config'i
# kullanabilir, ancak farkli application ID nedeniyle gercek Play uygulamasinin
# release provenance'i degildir. Uretilen AAB Play uygulamasina
# YUKLENEMEZ; yalnizca kod/build/lint/16KB kapilarinin kanitidir. Gercek uretim
# AAB'si yalniz production release zincirinden alinir.
#
# Exit kodlari:
#   0  tum kapilar yesil
#   1  bir kapi kirmizi (ilk hatada durur)

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FLAVOR="${FLAVOR:-smoke}"
CAP_FLAVOR="$(tr '[:lower:]' '[:upper:]' <<< "${FLAVOR:0:1}")${FLAVOR:1}"
AAB="build/app/outputs/bundle/${FLAVOR}Release/app-${FLAVOR}-release.aab"
MERGED_MANIFEST="build/app/intermediates/merged_manifest/${FLAVOR}Release/process${CAP_FLAVOR}ReleaseMainManifest/AndroidManifest.xml"
ANDROID_SURFACE_REPORT="build/release-evidence/android-release-surface.json"
RC_KEY="NON_RELEASE_SMOKE_REVENUECAT_KEY"

if [ "$FLAVOR" != "smoke" ]; then
  printf '\033[31mBu script yalniz --flavor smoke dogrulamasi yapar.\033[0m\n' >&2
  exit 1
fi

# Etiketli yayin kapisi (SBOM lisans kanidi + notices paritesi) uzun sureli
# kirmizi kalabilir; varsayilan RAPOR modudur ki gunluk dogrulama dongusu
# kullanilabilir kalsin. --strict-release-gates ile bloklayici hale gelir.
STRICT_RELEASE_GATES=0
for arg in "$@"; do
  case "$arg" in
    --strict-release-gates) STRICT_RELEASE_GATES=1 ;;
    *) printf 'Bilinmeyen argüman: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

step=0
pass() { printf '  \033[32m✓ PASS\033[0m  %s\n' "$1"; }
run() {
  step=$((step + 1))
  printf '\n\033[1m[%d/6] %s\033[0m\n' "$step" "$1"
}
fail() {
  printf '\n\033[31m✗ FAIL\033[0m  %s\n' "$1" >&2
  printf '\033[31mYAYIN DOGRULAMA KIRMIZI — adim %d.\033[0m\n' "$step" >&2
  exit 1
}
trap 'fail "beklenmeyen hata (yukaridaki ciktiya bak)"' ERR

printf '\033[1m=== KoruBeni yayin dogrulama zinciri ===\033[0m\n'

printf '\n\033[1m[hazirlik] temiz build ara dizini + bagimlilik cozumu\033[0m\n'
flutter clean || fail "flutter clean basarisiz"
flutter pub get || fail "flutter pub get basarisiz"
pass "temiz yerel build zemini hazir"

run "flutter analyze (sifir sorun sarti)"
flutter analyze || fail "flutter analyze sorun buldu"
pass "analyze temiz"

run "flutter test + kritik safety coverage (tam paket)"
flutter test --coverage || fail "flutter test kirmizi"
dart scripts/verify_critical_coverage.dart \
  --report build/coverage-evidence/critical-coverage.json \
  || fail "kritik safety coverage %90 esigini gecemedi"
pass "tum testler yesil; kritik safety coverage kapisi gecti"

run "imzali NON_RELEASE_SMOKE AAB (registrant'i yeniler; gradle'dan ONCE)"
flutter build appbundle --release --flavor "$FLAVOR" \
  --target-platform android-arm64,android-x64 \
  --dart-define=ENV=ci_smoke \
  --dart-define=REVENUECAT_ANDROID_API_KEY="$RC_KEY" \
  || fail "release AAB derlenemedi (key.properties + signing kontrol et)"
[ -f "$AAB" ] || fail "AAB beklenen yolda yok: $AAB"
[ -s "$MERGED_MANIFEST" ] || fail "birlesik manifest beklenen yolda yok: $MERGED_MANIFEST"
if unzip -Z1 "$AAB" | grep -Eq '^base/lib/(armeabi|armeabi-v7a|x86|mips[^/]*)/'; then
  fail "AAB beklenmeyen 32-bit native ABI iceriyor"
fi
for required_abi in arm64-v8a x86_64; do
  if ! unzip -Z1 "$AAB" | awk -F/ -v abi="$required_abi" \
      '$1 == "base" && $2 == "lib" && $3 == abi { found = 1 } END { exit !found }'; then
    fail "NON_RELEASE_SMOKE AAB gerekli ABI'yi icermiyor: $required_abi"
  fi
done
grep -q 'package="com.poyrazoncel.korubeni.smoke"' "$MERGED_MANIFEST" \
  || fail "smoke manifest paket kimligi yanlis"
python3 scripts/audit_android_release_surface.py \
  --manifest "$MERGED_MANIFEST" \
  --network-security-config android/app/src/main/res/xml/network_security_config.xml \
  --data-extraction-rules android/app/src/main/res/xml/data_extraction_rules.xml \
  --expected-package com.poyrazoncel.korubeni.smoke \
  --output "$ANDROID_SURFACE_REPORT" \
  || fail "birlesik Android release yuzeyi guvenlik denetimini gecemedi"
SIGNATURE_LOG="$(mktemp /tmp/korubeni_smoke_signature.XXXXXX)"
if LC_ALL=C jarsigner -verify -strict "$AAB" >"$SIGNATURE_LOG" 2>&1; then
  SIGNATURE_STATUS=0
else
  # A command in an if-condition is exempt from errexit and the global ERR
  # trap, so the complete strict bitmask can be evaluated below.
  SIGNATURE_STATUS=$?
fi
if [[ "$SIGNATURE_STATUS" -ne 0 && "$SIGNATURE_STATUS" -ne 4 ]]; then
  sed -n '1,80p' "$SIGNATURE_LOG"
  rm -f "$SIGNATURE_LOG"
  fail "smoke AAB JAR imzasi dogrulanamadi"
fi
if ! grep -Eq '^jar verified([,.]|$)' "$SIGNATURE_LOG"; then
  sed -n '1,80p' "$SIGNATURE_LOG"
  rm -f "$SIGNATURE_LOG"
  fail "smoke AAB imzasiz veya dogrulanamadi"
fi
rm -f "$SIGNATURE_LOG"
pass "AAB, imza ve birlesik Android release yuzeyi dogrulandi: $AAB"

run "Android lint + Kotlin unit + instrumentation derleme (build'den SONRA)"
# Keep release lint tied to the deliberately non-uploadable smoke artifact,
# but compile host/instrumentation tests against playDebug. They MUST run in
# separate Gradle invocations: Flutter native-assets uses a shared build path,
# so concurrent smoke/play variant tasks can invalidate each other's directory
# snapshots even when both variants support the same 64-bit ABI set.
( cd android && ./gradlew "app:lint${CAP_FLAVOR}Release" --console=plain ) \
  || fail "Android release lint kirmizi"
( cd android && ./gradlew "app:testPlayDebugUnitTest" "app:assemblePlayDebugAndroidTest" --console=plain ) \
  || fail "Kotlin unit veya instrumentation derlemesi kirmizi"
pass "lint + Kotlin unit + instrumentation derlemesi yesil"

run "16KB sayfa boyutu hizalamasi"
./scripts/verify_16kb_alignment.sh "$AAB" || fail "16KB hizalama basarisiz"
pass "tum native kutuphaneler 16KB uyumlu"

run "etiketli-yayin blocker durumu (SBOM lisans kanidi + notices paritesi)"
# Bu kapi .github/workflows/release.yml icinde AAB derlemesinden ONCE kosar ve
# etiketli yayinin ilk kirmizi noktasidir. Yerelde hic kosulmazsa "kod yesil"
# sinyali, tag atildiginda CI'da kirmizi ile karsilasmayi gizler.
RELEASE_GATE_LOG="$(mktemp)"
RELEASE_GATE_STATUS=0
{
  dart scripts/generate_cyclonedx_sbom.dart \
    --output build/release-evidence/sbom.cdx.json \
    --license-evidence config/dependency_license_evidence.json &&
  dart scripts/verify_sbom_license_policy.dart \
    --sbom build/release-evidence/sbom.cdx.json \
    --policy config/dependency_license_policy.json &&
  python3 scripts/generate_third_party_notices.py \
    --sbom build/release-evidence/sbom.cdx.json \
    --evidence config/dependency_license_evidence.json \
    --license-text-dir config/license-texts \
    --output build/release-evidence/THIRD_PARTY_NOTICES.txt &&
  cmp --silent \
    assets/legal/THIRD_PARTY_NOTICES.txt \
    build/release-evidence/THIRD_PARTY_NOTICES.txt
} >"$RELEASE_GATE_LOG" 2>&1 || RELEASE_GATE_STATUS=$?

if [ "$RELEASE_GATE_STATUS" -eq 0 ]; then
  pass "etiketli yayin lisans/notices kapisi yesil"
  TAGGED_RELEASE_STATE='TAGGED_RELEASE_GATES_LOCAL_PASS'
else
  sed -n '1,40p' "$RELEASE_GATE_LOG"
  printf '  \033[33m! BLOCKED\033[0m  etiketli yayin lisans/notices kapisi kirmizi\n'
  printf '    Bu kapi tag atildiginda CI de ayni sekilde kirmizi olur.\n'
  printf '    Kanit toplama: scripts/harvest_license_evidence.py\n'
  printf '    Inceleme sureci: docs/release/dependency_license_review.md\n'
  TAGGED_RELEASE_STATE='TAGGED_RELEASE_BLOCKED'
fi
rm -f "$RELEASE_GATE_LOG"

trap - ERR
printf '\n\033[1;32m=== KOD/SMOKE DOGRULAMA YESIL — 5/5 kod+smoke kapisi gecti ===\033[0m\n'
printf 'LOCAL_CANDIDATE_PASS\n'
printf 'EXTERNAL_RELEASE_GATES_UNVERIFIED\n'
printf '%s\n' "$TAGGED_RELEASE_STATE"
printf 'Not: bu AAB .smoke paket kimligiyle derlendi; gercek Play uygulamasina YUKLENEMEZ.\n'
printf 'Gercek uretim AAB si yalniz production release zincirinden alinir.\n'
if [ "$TAGGED_RELEASE_STATE" = 'TAGGED_RELEASE_BLOCKED' ]; then
  printf 'Not: kod+smoke yesil olmasi etiketli yayinin hazir oldugu anlamina GELMEZ.\n'
  if [ "$STRICT_RELEASE_GATES" -eq 1 ]; then
    exit 1
  fi
fi
