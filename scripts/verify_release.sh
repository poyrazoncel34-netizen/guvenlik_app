#!/usr/bin/env bash
# KoruBeni — Tek komutluk YAYIN DOGRULAMA zinciri.
#
# "Yayina hazir mi?" sorusunun deterministik cevabi. Bir insanin (veya ajanin)
# elle kostugu her adimi tek yerde, DOGRU exit koduyla toplar. Amac: "bitti"
# artik bir iddia degil, bu script'in yesili olsun.
#
# Neden script, neden akil yurutme degil:
#   - Deterministik is akil yurutmeden ucuz ve guvenilirdir.
#   - `cmd | tail` gibi borular exit kodunu MASKELER: tail'in 0'i gercek
#     BUILD FAILED'i gizler. Bu script her adimin gercek koduna bakar
#     (pipefail + dogrudan kontrol), boylece yanlis-yesil imkansizdir.
#
# Adim sirasi bilinclidir:
#   analyze -> test -> (flutter) build AAB -> (gradle) lint+unit -> 16KB
#   flutter build, gitignore'lu GeneratedPluginRegistrant'i YENILER; dogrudan
#   gradlew release task'lari bayat registrant'la "package does not exist" ile
#   patlar. Bu yuzden gradle lint HER ZAMAN flutter build'DEN SONRA kosar.
#
# Domain kontrolleri (legal surum<->HTML paritesi, ENCRYPTION_KEY regresyonu,
# manifest<->docs tutarliligi) ZATEN test paketinde kodlu
# (test/release_readiness_policy_test.dart, test/release_artifact_paths_test.dart),
# bu yuzden ayri grep yoktur — `flutter test` onlari kapsar.
#
# Kullanim:
#   ./scripts/verify_release.sh
#
# Dogrulama-amacli build placeholder secret'larla derlenir; uretilen AAB
# Play'e YUKLENMEZ, yalnizca pipeline/sign/16KB kanitidir. Gercek uretim AAB'si
# CI'dan v1.0.0 tag'iyle, gercek secret'larla alinir.
#
# Exit kodlari:
#   0  tum kapilar yesil
#   1  bir kapi kirmizi (ilk hatada durur)

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FLAVOR="${FLAVOR:-play}"
CAP_FLAVOR="$(tr '[:lower:]' '[:upper:]' <<< "${FLAVOR:0:1}")${FLAVOR:1}"
AAB="build/app/outputs/bundle/${FLAVOR}Release/app-${FLAVOR}-release.aab"
RC_KEY="${REVENUECAT_ANDROID_API_KEY:-placeholder_build_check}"

step=0
pass() { printf '  \033[32m✓ PASS\033[0m  %s\n' "$1"; }
run() {
  step=$((step + 1))
  printf '\n\033[1m[%d/5] %s\033[0m\n' "$step" "$1"
}
fail() {
  printf '\n\033[31m✗ FAIL\033[0m  %s\n' "$1" >&2
  printf '\033[31mYAYIN DOGRULAMA KIRMIZI — adim %d.\033[0m\n' "$step" >&2
  exit 1
}
trap 'fail "beklenmeyen hata (yukaridaki ciktiya bak)"' ERR

printf '\033[1m=== KoruBeni yayin dogrulama zinciri ===\033[0m\n'

run "flutter analyze (sifir sorun sarti)"
flutter analyze || fail "flutter analyze sorun buldu"
pass "analyze temiz"

run "flutter test (tam paket — legal parity + regresyon testleri dahil)"
flutter test || fail "flutter test kirmizi"
pass "tum testler yesil"

run "imzali release AAB (registrant'i yeniler; gradle'dan ONCE)"
flutter build appbundle --release --flavor "$FLAVOR" \
  --dart-define=ENV=production \
  --dart-define=REVENUECAT_ANDROID_API_KEY="$RC_KEY" \
  || fail "release AAB derlenemedi (key.properties + signing kontrol et)"
[ -f "$AAB" ] || fail "AAB beklenen yolda yok: $AAB"
pass "AAB derlendi ve imzalandi: $AAB"

run "Android lint + Kotlin unit (release varyant; build'den SONRA)"
( cd android && ./gradlew "app:lint${CAP_FLAVOR}Release" "app:test${CAP_FLAVOR}DebugUnitTest" --console=plain ) \
  || fail "lint veya Kotlin unit testleri kirmizi"
pass "lint + Kotlin unit yesil"

run "16KB sayfa boyutu hizalamasi"
./scripts/verify_16kb_alignment.sh "$AAB" || fail "16KB hizalama basarisiz"
pass "tum native kutuphaneler 16KB uyumlu"

trap - ERR
printf '\n\033[1;32m=== YAYIN DOGRULAMA YESIL — 5/5 kapi gecti ===\033[0m\n'
printf 'Not: bu AAB placeholder secret ile derlendi; Play e YUKLENMEZ.\n'
printf 'Gercek uretim AAB si CI dan v1.0.0 tag i ile alinir.\n'
