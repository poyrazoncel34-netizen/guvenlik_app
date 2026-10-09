#!/bin/bash
# TEST-ONLY: offline Pro anchor pair into a NON-debuggable build's prefs via adb root
# (userdebug emulator). Lets Pro-gated safety flows run on a release smoke build
# without Play Billing. Never a commerce proof.
ADB=~/Library/Android/sdk/platform-tools/adb; P=${1:-com.poyrazoncel.korubeni.smoke}
F=/data/data/$P/shared_prefs/FlutterSharedPreferences.xml; TMP=$(mktemp)
$ADB shell am force-stop $P
OWNER=$($ADB shell stat -c %U:%G $F | tr -d '\r')
$ADB shell cat $F > $TMP
NOW=$(( $(date +%s) * 1000 - 60000 ))
grep -v 'revenuecat_prior_verified_pro_hint_v1\|revenuecat_last_verified_pro_at_v1' $TMP | sed "s#</map>#    <boolean name=\"flutter.revenuecat_prior_verified_pro_hint_v1\" value=\"true\" />\n    <long name=\"flutter.revenuecat_last_verified_pro_at_v1\" value=\"$NOW\" />\n</map>#" > $TMP.new
$ADB push $TMP.new /data/local/tmp/fsp.xml >/dev/null
$ADB shell "cat /data/local/tmp/fsp.xml > $F && chown $OWNER $F && restorecon $F && rm /data/local/tmp/fsp.xml"
$ADB shell ls -lZ $F; $ADB shell grep revenuecat $F
