#!/bin/bash
# TEST-ONLY: writes the offline Pro anchor pair into a DEBUG build's SharedPreferences via run-as,
# so Pro-gated safety flows can run on an emulator without Play Billing. Never a commerce proof.
ADB=~/Library/Android/sdk/platform-tools/adb; P=${1:-com.poyrazoncel.korubeni}; T=$(mktemp)
$ADB shell am force-stop $P
$ADB shell run-as $P cat shared_prefs/FlutterSharedPreferences.xml > $T
NOW=$(( $(date +%s) * 1000 - 60000 ))
grep -v 'revenuecat_prior_verified_pro_hint_v1\|revenuecat_last_verified_pro_at_v1' $T | sed "s#</map>#    <boolean name=\"flutter.revenuecat_prior_verified_pro_hint_v1\" value=\"true\" />\n    <long name=\"flutter.revenuecat_last_verified_pro_at_v1\" value=\"$NOW\" />\n</map>#" > $T.new
$ADB shell "run-as $P sh -c 'cat > shared_prefs/FlutterSharedPreferences.xml'" < $T.new
$ADB shell run-as $P grep revenuecat shared_prefs/FlutterSharedPreferences.xml
