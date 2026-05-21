#!/usr/bin/env bash
# KoruBeni — 16 KB page size compatibility verification for the release AAB.
#
# Per Google Play, starting Nov 1, 2025, new apps and updates targeting
# Android 15+ on 64-bit devices must ship native libraries aligned to a
# 16 KB page size. This script extracts the AAB, finds every .so under
# lib/arm64-v8a and lib/x86_64, and reads each ELF's PT_LOAD program
# header alignment. Anything less than 0x4000 (16 KB) is flagged.
#
# Usage:
#   ./scripts/verify_16kb_alignment.sh [path/to/app.aab]
#
# If no path is given, defaults to the Play flavor release output:
#   build/app/outputs/bundle/playRelease/app-play-release.aab
#
# Exit codes:
#   0  all native libs 16 KB-aligned (or no native libs found)
#   1  one or more native libs are NOT 16 KB-aligned
#   2  AAB not found or extraction failed

set -euo pipefail

AAB_PATH="${1:-build/app/outputs/bundle/playRelease/app-play-release.aab}"

if [ ! -f "$AAB_PATH" ]; then
    echo "❌ AAB not found at: $AAB_PATH"
    echo ""
    echo "Build it first:"
    echo "  ./scripts/build_production.sh"
    exit 2
fi

WORK_DIR="$(mktemp -d /tmp/korubeni_16kb_check.XXXXXX)"
trap "rm -rf '$WORK_DIR'" EXIT

echo "🔍 Extracting $AAB_PATH to $WORK_DIR ..."
unzip -q "$AAB_PATH" -d "$WORK_DIR"

echo ""
echo "🧮 Checking 16 KB (0x4000) PT_LOAD alignment for 64-bit native libraries:"
echo ""

FAILED=0
CHECKED=0

for abi in arm64-v8a x86_64; do
    abi_dir="$WORK_DIR/base/lib/$abi"
    [ -d "$abi_dir" ] || continue

    for so in "$abi_dir"/*.so; do
        [ -f "$so" ] || continue
        CHECKED=$((CHECKED + 1))
        rel="$abi/$(basename "$so")"

        # Read PT_LOAD alignments from the ELF program headers. The minimum
        # alignment across all LOAD segments must be >= 0x4000 (16 KB).
        min_align=$(python3 - "$so" <<'PY'
import struct
import sys

path = sys.argv[1]
with open(path, "rb") as f:
    magic = f.read(4)
    if magic != b"\x7fELF":
        print("0")
        sys.exit(0)
    f.seek(4)
    ei_class = f.read(1)[0]  # 1=32-bit, 2=64-bit
    if ei_class != 2:
        # 32-bit ABI shouldn't be shipping for 16 KB targets at all
        print("0")
        sys.exit(0)
    # 64-bit ELF header offsets
    f.seek(32)
    e_phoff = struct.unpack("<Q", f.read(8))[0]
    f.seek(54)
    e_phentsize = struct.unpack("<H", f.read(2))[0]
    e_phnum = struct.unpack("<H", f.read(2))[0]

    min_align = None
    for i in range(e_phnum):
        f.seek(e_phoff + i * e_phentsize)
        p_type = struct.unpack("<I", f.read(4))[0]
        if p_type != 1:  # PT_LOAD
            continue
        f.seek(e_phoff + i * e_phentsize + 48)
        p_align = struct.unpack("<Q", f.read(8))[0]
        if min_align is None or p_align < min_align:
            min_align = p_align
    print(min_align if min_align is not None else 0)
PY
        )

        if [ "$min_align" -ge 16384 ]; then
            printf "  ✅ %-50s align=0x%x\n" "$rel" "$min_align"
        else
            printf "  ❌ %-50s align=0x%x  (need >= 0x4000)\n" "$rel" "$min_align"
            FAILED=$((FAILED + 1))
        fi
    done
done

echo ""
if [ "$CHECKED" -eq 0 ]; then
    echo "ℹ️  No 64-bit native libraries found in the AAB (Dart-only build?)."
    echo "    Nothing to verify."
    exit 0
fi

if [ "$FAILED" -eq 0 ]; then
    echo "✅ All $CHECKED native libraries are 16 KB page-size compatible."
    echo ""
    echo "Next step: upload the AAB to Play Console and confirm the bundle"
    echo "details show 'Memory page size: 16 KB compatible' under App bundle"
    echo "explorer."
    exit 0
else
    echo "❌ $FAILED / $CHECKED native libraries are NOT 16 KB-aligned."
    echo ""
    echo "Likely causes and fixes:"
    echo "  - Outdated plugin: run 'flutter pub upgrade --major-versions'"
    echo "    and review which native plugin produced the offending .so."
    echo "  - NDK older than r28: ensure Flutter's bundled NDK is current"
    echo "    (Flutter 3.27+ + AGP 8.5.1+)."
    echo "  - Vendor-provided closed-source .so: contact the plugin author"
    echo "    or vendor for a 16 KB-aligned build."
    echo ""
    echo "Do not upload this AAB to Play Console for the first release."
    exit 1
fi
