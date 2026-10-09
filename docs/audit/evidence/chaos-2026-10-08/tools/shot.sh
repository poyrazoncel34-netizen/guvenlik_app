#!/bin/bash
# shot.sh <name> [maxpx] : full screenshot into evidence shots/, downscaled copy into scratchpad
ADB=~/Library/Android/sdk/platform-tools/adb; D=$(cd "$(dirname "$0")/.." && pwd)/shots
SP=/private/tmp/claude-501/-Users-poyrazoncel-Projects-guvenlik-app/53dc7a26-0f79-4878-85a0-74d07698c976/scratchpad; mkdir -p $SP/s
$ADB exec-out screencap -p > $D/$1.png && sips -Z ${2:-700} $D/$1.png --out $SP/s/$1.png >/dev/null && echo $SP/s/$1.png
