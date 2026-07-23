#!/usr/bin/env bash
# KoruBeni — fail-closed 16 KB ELF verification for every AAB module.

set -euo pipefail

AAB_PATH="${1:-build/app/outputs/bundle/playRelease/app-play-release.aab}"

if [ ! -f "$AAB_PATH" ]; then
    echo "AAB_NOT_FOUND: $AAB_PATH" >&2
    exit 2
fi

# Inspect entries in-place instead of extracting an untrusted ZIP. Every native
# library in every bundle module (<module>/lib/<abi>/...) is authoritative;
# checking only base/lib would let a dynamic-feature library evade the gate.
python3 - "$AAB_PATH" <<'PY'
import re
import struct
import sys
import zipfile

path = sys.argv[1]
entry_pattern = re.compile(r"^[^/]+/lib/([^/]+)/(.+\.so)$")
allowed_abis = {"arm64-v8a", "x86_64"}
minimum_alignment = 16 * 1024


def read_u16(data: bytes, offset: int, endian: str) -> int:
    if offset < 0 or offset + 2 > len(data):
        raise ValueError("truncated ELF u16")
    return struct.unpack_from(endian + "H", data, offset)[0]


def read_u32(data: bytes, offset: int, endian: str) -> int:
    if offset < 0 or offset + 4 > len(data):
        raise ValueError("truncated ELF u32")
    return struct.unpack_from(endian + "I", data, offset)[0]


def read_u64(data: bytes, offset: int, endian: str) -> int:
    if offset < 0 or offset + 8 > len(data):
        raise ValueError("truncated ELF u64")
    return struct.unpack_from(endian + "Q", data, offset)[0]


def minimum_load_alignment(data: bytes) -> int:
    if len(data) < 64 or data[:4] != b"\x7fELF":
        raise ValueError("not a complete ELF file")
    if data[4] != 2:
        raise ValueError("native library is not ELF64")
    if data[5] == 1:
        endian = "<"
    elif data[5] == 2:
        endian = ">"
    else:
        raise ValueError("invalid ELF byte order")

    program_offset = read_u64(data, 32, endian)
    program_entry_size = read_u16(data, 54, endian)
    program_count = read_u16(data, 56, endian)
    if program_count == 0 or program_count == 0xFFFF:
        raise ValueError("unsupported or empty program-header table")
    if program_entry_size < 56:
        raise ValueError("invalid ELF64 program-header size")
    table_end = program_offset + program_entry_size * program_count
    if program_offset < 64 or table_end > len(data):
        raise ValueError("program-header table is out of bounds")

    alignments = []
    for index in range(program_count):
        offset = program_offset + index * program_entry_size
        if read_u32(data, offset, endian) != 1:  # PT_LOAD
            continue
        alignments.append(read_u64(data, offset + 48, endian))
    if not alignments:
        raise ValueError("ELF has no PT_LOAD segment")
    return min(alignments)


failures = []
checked = 0
seen_entries = set()
try:
    with zipfile.ZipFile(path) as archive:
        for info in archive.infolist():
            match = entry_pattern.fullmatch(info.filename)
            if not match:
                continue
            if info.filename in seen_entries:
                failures.append(f"{info.filename}: duplicate ZIP entry")
                continue
            seen_entries.add(info.filename)
            checked += 1
            abi = match.group(1)
            if abi not in allowed_abis:
                failures.append(f"{info.filename}: unexpected ABI {abi}")
                continue
            if info.file_size <= 0 or info.file_size > 512 * 1024 * 1024:
                failures.append(f"{info.filename}: invalid uncompressed size")
                continue
            try:
                alignment = minimum_load_alignment(archive.read(info))
            except (KeyError, OSError, ValueError, struct.error) as error:
                failures.append(f"{info.filename}: {error}")
                continue
            if alignment < minimum_alignment:
                failures.append(
                    f"{info.filename}: PT_LOAD align=0x{alignment:x}, need >=0x4000"
                )
            else:
                print(f"PASS {info.filename} PT_LOAD align=0x{alignment:x}")
except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile) as error:
    print(f"AAB_ARCHIVE_INVALID: {error}", file=sys.stderr)
    sys.exit(2)

if checked == 0:
    failures.append("no native libraries found; Flutter release evidence is incomplete")

if failures:
    for failure in failures:
        print(f"FAIL {failure}", file=sys.stderr)
    print(f"ALIGNMENT_FAIL checked={checked} failures={len(failures)}", file=sys.stderr)
    sys.exit(1)

print(f"ALIGNMENT_PASS checked={checked} modules=all")
PY
