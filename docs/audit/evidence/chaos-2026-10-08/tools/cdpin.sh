#!/bin/bash
# Fast CountdownScreen PIN entry, fixed pad coordinates (1080x2400, 420dpi).
ADB=~/Library/Android/sdk/platform-tools/adb; P=${1:-2468}; OFF=${2:-0}; CMD=""  # OFF=52 for Test Mode (banner)
for ((i=0;i<${#P};i++)); do d=${P:$i:1}
  case $d in 1) xy="259 1369";; 2) xy="540 1369";; 3) xy="821 1369";; 4) xy="259 1556";; 5) xy="540 1556";; 6) xy="821 1556";; 7) xy="259 1743";; 8) xy="540 1743";; 9) xy="821 1743";; 0) xy="540 1930";; esac
  set -- $xy; CMD="$CMD input tap $1 $(( $2 + OFF ));"; done
$ADB shell "$CMD"; echo "CDPIN $P $(date +%H:%M:%S)"
