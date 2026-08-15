#!/usr/bin/env bash
# KoruBeni — depo yakinsamasi icin deterministik son kapi.
#
# Ne yapar
# --------
# Yalnizca OBJEKTIF degismezleri kontrol eder. Hicbir adim yorum, ozet ya da
# model karari icermez; her adim ya bir sayiyi karsilastirir ya da baska bir
# verifier'in gercek exit kodunu okur. "Bence hazir" diyen bir kapi kapi
# degildir.
#
# Neden ayri bir script
# ---------------------
# `verify_release.sh` YAYIN zincirini (build/lint/16KB) dogrular ve gizli-anahtar
# taramasini calistirmaz. Bu script DEPO yakinsamasini dogrular: muhasebe, cozum
# kuyrugu siniflandirmasi, kanit butunlugu ve -- RER-02'nin cikardigi ders --
# testlerin agaci kirletmemesi. Ikisi farkli sorulari yanitlar; birlestirmek
# ikisini de bulaniklastirirdi.
#
# Sirali uretilebilirlik zinciri (RER-02)
# ---------------------------------------
# TEMIZ AGAC -> TAM TEST -> TEMIZ AGAC -> GIZLI ANAHTAR TARAMASI
# Bu tam sira calismak ZORUNDA. Daha once calismiyordu: tek bir test dosyasi
# `docs/audit/evidence/text_scale.json` dosyasini her kosumda yeniden yaziyor,
# ardindan `--require-clean` tarama reddediyordu. Aradaki `git checkout` ile
# "her komut tek basina yesil" gostermek, tam olarak bu scriptin yasakladigi
# seydir.
#
# Boru yasagi
# -----------
# `cmd | tail` exit kodunu MASKELER. Burada hicbir kapi boruya sokulmaz; cikti
# bir dosyaya yazilir, exit kodu dogrudan okunur.
#
# Kullanim:
#   ./scripts/verify_repository_convergence.sh
#   ./scripts/verify_repository_convergence.sh --skip-tests   # sadece statik kapilar
#
# Exit kodlari:
#   0  tum degismezler saglandi
#   1  en az bir degismez kirildi (hepsi kosar, sonunda ozet)

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SKIP_TESTS=0
[[ "${1:-}" == "--skip-tests" ]] && SKIP_TESTS=1

LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

FAILED=0
declare -a RESULTS=()

# Bir kapiyi kosar, gercek exit kodunu kaydeder. Ciktilar dosyaya gider.
gate() {
  local name="$1"; shift
  local log="$LOG_DIR/$name.log"
  if "$@" > "$log" 2>&1; then
    RESULTS+=("PASS  $name")
    printf '  [PASS] %s\n' "$name"
  else
    local code=$?
    RESULTS+=("FAIL  $name (exit $code)")
    printf '  [FAIL] %s (exit %d)\n' "$name" "$code"
    sed 's/^/         | /' "$log" | head -25
    FAILED=1
  fi
}

# Calisma agaci temiz mi? `docs/audit/evidence/` DAHIL -- bu scriptin tumu
# "olagan bir kosum hicbir izlenen dosyayi degistirmez" iddiasini test eder,
# dolayisiyla burada muafiyet yoktur. Kanit paketinin kendi muafiyeti sadece
# UPDATE_AUDIT_EVIDENCE=1 modunda anlamlidir.
assert_clean_worktree() {
  local label="$1"
  local dirty
  dirty="$(git status --porcelain)"
  if [[ -n "$dirty" ]]; then
    printf '  [FAIL] worktree-clean:%s\n' "$label"
    printf '%s\n' "$dirty" | sed 's/^/         | /'
    RESULTS+=("FAIL  worktree-clean:$label")
    FAILED=1
    return 1
  fi
  RESULTS+=("PASS  worktree-clean:$label")
  printf '  [PASS] worktree-clean:%s\n' "$label"
}

printf '== KoruBeni depo yakinsama kapisi ==\n\n'

# ---------------------------------------------------------------------------
# 1. Muhasebe: 1738/1738/0/0/0
# ---------------------------------------------------------------------------
printf -- '-- muhasebe --\n'
gate audit-accounting python3 scripts/verify_audit_accounting.py

# Sayilarin kendisi. verify_audit_accounting.py PASS derse tutarlidir, ama
# BEKLENEN degerleri burada ayrica sabitliyoruz: bir gun 1739 olursa, sessizce
# tutarli kalip fark edilmemesini istemiyoruz.
gate audit-accounting-numbers bash -c '
  out="$(python3 scripts/verify_audit_accounting.py)" || exit 1
  echo "$out"
  echo "$out" | grep -q "checklist=1738" || { echo "checklist != 1738"; exit 1; }
  echo "$out" | grep -q "audit=1738"     || { echo "audit != 1738"; exit 1; }
  echo "$out" | grep -q "missing=0"      || { echo "missing != 0"; exit 1; }
  echo "$out" | grep -q "duplicated=0"   || { echo "duplicated != 0"; exit 1; }
  echo "$out" | grep -q "unaccounted=0"  || { echo "unaccounted != 0"; exit 1; }
'

# ---------------------------------------------------------------------------
# 2. Cozulmemis satirlarin siniflandirmasi
# ---------------------------------------------------------------------------
printf -- '\n-- cozum kuyrugu siniflandirmasi --\n'
gate resolution-queue-classification         python3 scripts/verify_resolution_classification.py
gate resolution-queue-classification-control python3 scripts/verify_resolution_classification.py --negative-control

# ---------------------------------------------------------------------------
# 3. Bayat yokluk/remediation iddialari
# ---------------------------------------------------------------------------
printf -- '\n-- yokluk iddialari --\n'
gate absence-claims          python3 scripts/verify_absence_claims.py
gate absence-claims-control  python3 scripts/verify_absence_claims.py --negative-control

# ---------------------------------------------------------------------------
# 4. Bildirim cagri-yeri anlamsal kapisi (RER-04)
# ---------------------------------------------------------------------------
printf -- '\n-- bildirim sonucu tuketimi --\n'
gate alert-outcome-consumption         dart run scripts/verify_alert_outcome_consumption.dart
# Bu kontrol SAYIMI sinar. Yerini aldigi kuralin kontrolu BILINEN bir cagri
# yerini mutasyona ugratiyordu, yani tuketim mantigini sinayip sayimi hic
# sinamiyordu -- RER-04 tam olarak oradan gecti.
gate alert-outcome-consumption-control dart run scripts/verify_alert_outcome_consumption.dart --negative-control

# ---------------------------------------------------------------------------
# 5. Kanit provenance / butunlugu
# ---------------------------------------------------------------------------
printf -- '\n-- kanit butunlugu --\n'
gate evidence-provenance         python3 scripts/verify_evidence_provenance.py
gate evidence-provenance-control python3 scripts/verify_evidence_provenance.py --negative-control
# Provenance kapisi yalnizca DAMGAYI dogrular. Sertifikasyon (CERT-09) bunun
# yetmedigini gosterdi: flows.json icindeki bir OLCUMU elle degistirip damgayi
# birakmak provenance kapisini yesil birakti. Bu kapi 11 python artifact'ini
# yeniden uretir ve provenance disindaki her anahtari karsilastirir.
gate evidence-reproducibility         python3 scripts/verify_evidence_reproducibility.py
gate evidence-reproducibility-control python3 scripts/verify_evidence_reproducibility.py --negative-control

# ---------------------------------------------------------------------------
# 6. Sirali uretilebilirlik: TEMIZ -> TEST -> TEMIZ -> TARAMA (RER-02)
# ---------------------------------------------------------------------------
printf -- '\n-- sirali uretilebilirlik zinciri --\n'
assert_clean_worktree before-tests || true

if [[ "$SKIP_TESTS" -eq 1 ]]; then
  printf '  [SKIP] flutter-test (--skip-tests)\n'
  RESULTS+=("SKIP  flutter-test")
else
  gate flutter-analyze flutter analyze --no-fatal-infos
  gate flutter-test    flutter test --no-pub
  # RER-02'nin kalbi: testler agaci OLDUGU GIBI birakmali.
  assert_clean_worktree after-tests || true
fi

# Testlerden HEMEN SONRA, arada `git checkout` olmadan.
gate secret-scan-after-tests \
  python3 scripts/scan_release_secrets.py --require-clean \
    --output "$LOG_DIR/secret_scan.json"

assert_clean_worktree after-secret-scan || true

# ---------------------------------------------------------------------------
# Ozet
# ---------------------------------------------------------------------------
printf -- '\n== ozet ==\n'
for line in "${RESULTS[@]}"; do printf '  %s\n' "$line"; done

if [[ "$FAILED" -ne 0 ]]; then
  printf '\nREPOSITORY_CONVERGENCE_FAIL\n'
  exit 1
fi
printf '\nREPOSITORY_CONVERGENCE_PASS\n'
printf 'Bu kapi DEPO yakinsamasini kanitlar. Yayin hazirligi iddiasi DEGILDIR:\n'
printf 'fiziksel cihaz, Play Console ve billing kapilari bu depodan dogrulanamaz.\n'
exit 0
