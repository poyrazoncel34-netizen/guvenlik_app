#!/usr/bin/env bash
# KoruBeni — C5/C6/C7 (armli geri sayim sirasinda gelen cagri) EMULATOR ON UCUSU.
#
# NE KANITLAR, NE KANITLAMAZ
# --------------------------
# Bu script yalnizca su soruyu yanitlar: "store/REAL_DEVICE_QA_MATRIX.md icindeki
# C5/C6/C7 vakasini kosmak icin gereken enstrumantasyon calisiyor mu?"
#
# KANITLAMAZ: fiziksel cihaz davranisi, OEM pil politikalari, gercek Telecom
# yigini, gercek bir aboneligin entitlement'i. Emulator telefonu SIMULE eder;
# `adb emu gsm call` gercek bir sebeke cagrisi degildir. C5/C6/C7 satirlari
# lisansli test hesabiyla FIZIKSEL cihazda kosulana kadar NEEDS_REAL_DEVICE_TEST
# olarak kalir. Bu scriptin PASS ciktisi hicbir satiri gecirmez.
#
# NEDEN YINE DE VAR
# -----------------
# Bir QA vakasini yazmak ile kosulabilir oldugunu bilmek ayri seylerdir. Bir
# operatoru fiziksel cihazla basbasa birakip "geri sayim gercekten armli mi"
# sorusunu goz karariyla yanitlatmak, tam olarak bu denetimin kaldirmaya
# calistigi belirsizlik turudur. Burada her on kosul MAKINE ile dogrulanir.
#
# Kullanim:
#   ANDROID_SERIAL=emulator-5554 ./scripts/phase3_incoming_call_preflight.sh
#
# Exit kodlari:
#   0  butun on kosullar dogrulandi (vaka kosulabilir)
#   1  en az bir on kosul dogrulanamadi (ne oldugu yazilir)

set -Eeuo pipefail

PKG="${KORUBENI_PACKAGE:-com.poyrazoncel.korubeni}"
CALLER="${PREFLIGHT_CALLER_NUMBER:-5551234567}"
DE_PREFS="/data/user_de/0/${PKG}/shared_prefs/korubeni_emergency_session_v1.xml"

ADB=(adb)
[[ -n "${ANDROID_SERIAL:-}" ]] && ADB=(adb -s "$ANDROID_SERIAL")

FAILED=0
declare -a FINDINGS=()

note()  { printf '  %s\n' "$*"; }
ok()    { FINDINGS+=("PASS  $1"); printf '  [PASS] %s\n' "$1"; }
bad()   { FINDINGS+=("FAIL  $1"); printf '  [FAIL] %s\n' "$1"; FAILED=1; }

printf '== C5/C6/C7 gelen-cagri on ucusu ==\n\n'

# --------------------------------------------------------------------------
# 0. Cihaz ve emulator kimligi
# --------------------------------------------------------------------------
printf -- '-- cihaz --\n'
if ! "${ADB[@]}" get-state >/dev/null 2>&1; then
  bad "adb cihazi yok"
  printf '\nINCOMING_CALL_PREFLIGHT_FAIL\n'; exit 1
fi
MODEL="$("${ADB[@]}" shell getprop ro.product.model | tr -d '\r')"
SDK="$("${ADB[@]}" shell getprop ro.build.version.sdk | tr -d '\r')"
IS_EMU="$("${ADB[@]}" shell getprop ro.kernel.qemu | tr -d '\r')"
note "model=$MODEL sdk=$SDK"
if [[ "$IS_EMU" == "1" || "$MODEL" == *"sdk"* || "$MODEL" == *"emulator"* ]]; then
  ok "emulator tespit edildi (bu bir ON UCUS; cihaz kaniti DEGIL)"
else
  bad "bu bir emulator degil -- fiziksel cihaz kosumu QA matrisine kaydedilmeli, bu scripte degil"
fi

# --------------------------------------------------------------------------
# 1. Amaclanan APK kurulu mu
# --------------------------------------------------------------------------
printf -- '\n-- 1. amaclanan APK --\n'
INSTALLED="$("${ADB[@]}" shell pm list packages "$PKG" | tr -d '\r')"
if [[ "$INSTALLED" == *"package:$PKG"* ]]; then
  VERSION_NAME="$("${ADB[@]}" shell dumpsys package "$PKG" | grep -m1 versionName | tr -d '\r' | sed 's/.*versionName=//')"
  VERSION_CODE="$("${ADB[@]}" shell dumpsys package "$PKG" | grep -m1 versionCode | tr -d '\r' | sed 's/.*versionCode=\([0-9]*\).*/\1/')"
  ok "paket kurulu: $PKG versionName=$VERSION_NAME versionCode=$VERSION_CODE"
  EXPECTED_VERSION_NAME="${EXPECTED_VERSION_NAME:-}"
  if [[ -n "$EXPECTED_VERSION_NAME" && "$VERSION_NAME" != "$EXPECTED_VERSION_NAME" ]]; then
    bad "versionName beklenen ile uyusmuyor: $VERSION_NAME != $EXPECTED_VERSION_NAME"
  fi
else
  bad "paket kurulu degil: $PKG"
fi

# --------------------------------------------------------------------------
# 2. Uygulama sureci calisiyor mu
# --------------------------------------------------------------------------
printf -- '\n-- 2. uygulama sureci --\n'
PID="$("${ADB[@]}" shell pidof "$PKG" | tr -d '\r' || true)"
if [[ -n "$PID" ]]; then
  ok "surec calisiyor (pid=$PID)"
else
  bad "surec calismiyor -- uygulamayi acin, sonra bu scripti tekrar kosun"
fi

# --------------------------------------------------------------------------
# 3. Geri sayim GERCEKTEN armli mi
# --------------------------------------------------------------------------
# UI metnine bakmak yeterli degil: ekranda sayi gormek native oturumun armli
# oldugunu kanitlamaz. Otorite, cihaz-korumali depodaki oturum kaydidir --
# generation, deadline ve lifecycle. G7 satirinin de baktigi yer burasi.
printf -- '\n-- 3. armli oturum (cihaz-korumali depo) --\n'
SESSION_XML="$("${ADB[@]}" shell "run-as $PKG cat $DE_PREFS 2>/dev/null || cat $DE_PREFS 2>/dev/null" | tr -d '\r' || true)"
if [[ -z "$SESSION_XML" ]]; then
  bad "oturum deposu okunamadi ($DE_PREFS). Debuggable build ve armli bir oturum gerekir"
  note "     not: entitlement/PIN/kisi on kosullari saglanmadan panik ARMLANAMAZ;"
  note "     bu, yanlis bir PASS degil, dogru bir fail-closed davranistir"
else
  GENERATION="$(printf '%s' "$SESSION_XML" | sed -n 's/.*name="[^"]*generation"[^>]*value="\([0-9]*\)".*/\1/p' | head -1)"
  if [[ -n "$GENERATION" && "$GENERATION" -gt 0 ]]; then
    ok "native oturum armli (generation=$GENERATION)"
  else
    bad "oturum deposu var ama armli bir generation yok -- geri sayim armli DEGIL"
  fi
fi

# --------------------------------------------------------------------------
# 4. Simule cagri GERCEKTEN Android cagri durumuna ulasiyor mu
# --------------------------------------------------------------------------
# Bu, on ucusun asil sorusu. `adb emu gsm call` OK dondurebilir ve telefon
# yigini hicbir sey yapmamis olabilir; kanit telephony.registry'nin call
# state'idir. 0=IDLE 1=RINGING 2=OFFHOOK.
printf -- '\n-- 4. simule gelen cagri --\n'
call_state() {
  "${ADB[@]}" shell dumpsys telephony.registry 2>/dev/null \
    | grep -m1 'mCallState' | tr -d '\r' | sed 's/.*mCallState=\([0-9]*\).*/\1/'
}

BEFORE="$(call_state || echo unknown)"
note "cagri oncesi mCallState=$BEFORE"
if [[ "$BEFORE" != "0" ]]; then
  bad "baslangicta hat bos degil (mCallState=$BEFORE) -- olcum guvenilir olmaz"
fi

if adb emu gsm call "$CALLER" >/dev/null 2>&1; then
  note "adb emu gsm call $CALLER gonderildi"
else
  bad "adb emu gsm call basarisiz -- bu emulatorde telefon simulasyonu yok"
fi

RINGING=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
  STATE="$(call_state || echo unknown)"
  if [[ "$STATE" == "1" ]]; then RINGING=1; break; fi
  sleep 1
done

if [[ "$RINGING" -eq 1 ]]; then
  ok "simule cagri Android cagri durumuna ULASTI (mCallState=1 RINGING)"
else
  bad "simule cagri Android cagri durumuna ulasmadi (son mCallState=$(call_state || echo unknown))"
fi

# Hatti her durumda geri birak.
adb emu gsm cancel "$CALLER" >/dev/null 2>&1 || true
sleep 2
AFTER="$(call_state || echo unknown)"
if [[ "$AFTER" == "0" ]]; then
  ok "hat geri birakildi (mCallState=0)"
else
  bad "hat bosa donmedi (mCallState=$AFTER) -- sonraki kosum kirlenir"
fi

# --------------------------------------------------------------------------
printf -- '\n== ozet ==\n'
for line in "${FINDINGS[@]}"; do printf '  %s\n' "$line"; done
printf '\nmodel=%s sdk=%s paket=%s\n' "$MODEL" "$SDK" "$PKG"

if [[ "$FAILED" -ne 0 ]]; then
  printf '\nINCOMING_CALL_PREFLIGHT_FAIL\n'
  printf 'Bir veya daha fazla on kosul dogrulanamadi. C5/C6/C7 hala\n'
  printf 'NEEDS_REAL_DEVICE_TEST; bu script zaten hicbir satiri gecirmez.\n'
  exit 1
fi
printf '\nINCOMING_CALL_PREFLIGHT_PASS\n'
printf 'Enstrumantasyon calisiyor. C5/C6/C7 satirlari HALA NEEDS_REAL_DEVICE_TEST:\n'
printf 'emulator telefonu simule eder, OEM davranisini ve gercek Telecom yiginini temsil etmez.\n'
exit 0
