#!/bin/bash
# Claude Code cloud-environment setup script. The cloud base image ships no
# Flutter SDK and no ssh-keygen, so without this a cloud session can run
# neither `flutter analyze` nor `flutter test`.
#
# Use: paste this file's contents into the environment's Setup script (cloud
# environment menu > Edit > Setup script). It runs as root on Ubuntu before
# Claude Code launches, and the environment cache snapshots the result, so
# later sessions start with the toolchain already on disk. Inside a running
# session, `bash scripts/cloud_session_setup.sh` applies the same steps.
#
# Deliberately not a .claude/ SessionStart hook:
# config/release_change_classification.json keeps .claude/ out of release
# source, and a hook would download the SDK again on every new session.
set -euo pipefail

# The SAME toolchain CI certifies (FLUTTER_VERSION in .github/workflows/*.yml):
# a session that is green on another Flutter proves nothing about CI. The
# checksum is the published SHA-256 of the official release archive, so a
# truncated or substituted download fails closed instead of being installed.
# test/release/cloud_session_setup_test.dart keeps these pins in step; after
# changing them, paste the new file into the environment's Setup script too.
FLUTTER_VERSION="3.38.9"
FLUTTER_SHA256="cb39eeb717c7d7dce95736b862cada2fdedeebcbb0107c44a346659c77031003"
FLUTTER_HOME="${FLUTTER_HOME:-/opt/flutter}"
FLUTTER_ARCHIVE_URL="${FLUTTER_ARCHIVE_URL:-https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz}"
# A setup script cannot export variables into the session, so the SDK reaches
# PATH through links in a directory that is already on it.
BIN_DIR="${BIN_DIR:-/usr/local/bin}"

# FLUTTER_HOME is replaced wholesale below; never let an override aim that at
# "/" or at a relative path.
case "$FLUTTER_HOME" in
  /*[!/]*) ;;
  *)
    echo "cloud_session_setup: FLUTTER_HOME must be an absolute path other than /" >&2
    exit 1
    ;;
esac

flutter_is_pinned() {
  [ -x "$FLUTTER_HOME/bin/flutter" ] &&
    grep -qF "\"frameworkVersion\": \"$FLUTTER_VERSION\"" \
      "$FLUTTER_HOME/bin/cache/flutter.version.json" 2>/dev/null
}

if ! flutter_is_pinned; then
  # Download and extract beside the target, then swap it in: an interrupted or
  # rejected run never leaves a half-written SDK at FLUTTER_HOME.
  mkdir -p "$(dirname "$FLUTTER_HOME")"
  work="$(mktemp -d "$(dirname "$FLUTTER_HOME")/.flutter-install.XXXXXX")"
  trap 'rm -rf "$work"' EXIT
  curl -fsSL --retry 3 -o "$work/flutter.tar.xz" "$FLUTTER_ARCHIVE_URL"
  (cd "$work" && echo "$FLUTTER_SHA256  flutter.tar.xz" | shasum -a 256 -c -) >&2
  # --no-same-owner: the archive carries its builder's uid, and git refuses to
  # work in a root-run SDK checkout owned by another user.
  tar --no-same-owner -xJf "$work/flutter.tar.xz" -C "$work"
  rm -rf "$FLUTTER_HOME"
  mv "$work/flutter" "$FLUTTER_HOME"
fi

mkdir -p "$BIN_DIR"
ln -sf "$FLUTTER_HOME/bin/flutter" "$BIN_DIR/flutter"
ln -sf "$FLUTTER_HOME/bin/dart" "$BIN_DIR/dart"

"$FLUTTER_HOME/bin/flutter" config --no-analytics >&2
"$FLUTTER_HOME/bin/dart" --disable-analytics >&2

# scripts/test_release_tag_trust.py, which release_hardening_contract_test.dart
# runs, signs a disposable git tag with an SSH key. The base image ships git but
# not openssh-client, so that test failed with "No such file: 'ssh-keygen'".
if ! command -v ssh-keygen >/dev/null 2>&1; then
  apt-get update -qq >&2
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    --no-install-recommends openssh-client >&2
fi

echo "cloud_session_setup: Flutter $FLUTTER_VERSION at $FLUTTER_HOME (on PATH via $BIN_DIR); ssh-keygen available."
