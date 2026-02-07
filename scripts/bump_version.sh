#!/usr/bin/env bash
# Build numarasını (versionCode/build number) bir artırır.
# Kullanım: ./scripts/bump_version.sh
# Örnek: 1.0.0+1 -> 1.0.0+2

set -e
PUBSPEC="pubspec.yaml"
if [[ ! -f "$PUBSPEC" ]]; then
  echo "pubspec.yaml bulunamadı."
  exit 1
fi

CURRENT=$(grep "^version:" "$PUBSPEC" | sed 's/version: *//')
NAME=$(echo "$CURRENT" | cut -d+ -f1)
BUILD=$(echo "$CURRENT" | cut -d+ -f2)
NEW_BUILD=$((BUILD + 1))
NEW_VERSION="${NAME}+${NEW_BUILD}"

if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC"
else
  sed -i "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC"
fi

echo "Version: $CURRENT -> $NEW_VERSION"
