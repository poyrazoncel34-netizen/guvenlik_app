#!/bin/bash
export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$PATH"
PKG=com.poyrazoncel.korubeni
S="/data/user_de/0/$PKG/shared_prefs/korubeni_emergency_session_v1.xml"
snap() {
  local tag="$1"
  local xml=$(adb shell "cat $S" 2>/dev/null | tr -d '\r')
  local st=$(echo "$xml" | /usr/bin/grep -o 'lifecycleState">[a-zA-Z]*' | cut -d'>' -f2)
  local es=$(echo "$xml" | /usr/bin/grep -o 'elapsedStampMs" value="[0-9-]*' | /usr/bin/grep -o '[0-9-]*$')
  local ed=$(echo "$xml" | /usr/bin/grep -o 'elapsedRealtimeDeadlineMs" value="[0-9-]*' | /usr/bin/grep -o '[0-9-]*$')
  local fd=$(echo "$xml" | /usr/bin/grep -o 'finalDeadlineMs" value="[0-9-]*' | /usr/bin/grep -o '[0-9-]*$')
  local bc=$(echo "$xml" | /usr/bin/grep -o 'elapsedBootCount" value="[0-9-]*' | /usr/bin/grep -o '[0-9-]*$')
  local up=$(adb shell cat /proc/uptime | tr -d '\r' | cut -d' ' -f1)
  local wall=$(adb shell date +%s | tr -d '\r')
  local bid=$(adb shell cat /proc/sys/kernel/random/boot_id | tr -d '\r' | cut -c1-8)
  local gbc=$(adb shell settings get global boot_count | tr -d '\r')
  printf '%-34s state=%-28s elapsedStamp=%-10s elapsedDeadline=%-10s wallDeadline=%-14s uptime_ms=%-10s wall=%-12s bootId=%s gBootCount=%s envBootCount=%s\n' \
    "$tag" "${st:-none}" "${es:-none}" "${ed:-none}" "${fd:-none}" "$(python3 -c "print(int(float('$up')*1000))")" "$wall" "$bid" "$gbc" "${bc:-none}"
}
snap "A: before clock change"
adb shell am force-stop $PKG; sleep 2
snap "B: after force-stop"
adb shell "date @$(( $(adb shell date +%s | tr -d '\r') + 86400 ))" >/dev/null
adb shell am broadcast -a android.intent.action.TIME_SET >/dev/null 2>&1
sleep 4
snap "C: after +1d (app stopped)"
adb logcat -c
adb shell am start -n $PKG/com.poyrazoncel.korubeni.MainActivity >/dev/null 2>&1
sleep 10
snap "D: after reopen"
echo "--- BootCompletedReceiver lines since reopen ---"
adb logcat -d -v time 2>&1 | tr -d '\r' | /usr/bin/grep -iE "BootCompletedReceiver|ProcessStartReconcile" | tail -6
echo "--- restore clock ---"
adb shell "date @$(date +%s)" >/dev/null; adb shell am broadcast -a android.intent.action.TIME_SET >/dev/null 2>&1; sleep 2
snap "E: clock restored"
