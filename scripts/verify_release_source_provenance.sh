#!/usr/bin/env bash
# Fail-closed source identity check for a tagged production candidate.
# Run before dependency resolution or build generation mutates the workspace.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TAG=""
EXPECTED_COMMIT=""
OUTPUT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --expected-commit)
      EXPECTED_COMMIT="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! "$TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "Invalid release tag: $TAG" >&2
  exit 2
fi
if [[ ! "$EXPECTED_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Expected commit must be 40 lowercase hex characters." >&2
  exit 2
fi
if [ -z "$OUTPUT" ]; then
  echo "--output is required" >&2
  exit 2
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a Git worktree." >&2
  exit 1
fi

SOURCE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [ -n "$SOURCE_STATUS" ]; then
  echo "Release source is not clean; tracked, staged, or untracked drift exists:" >&2
  printf '%s\n' "$SOURCE_STATUS" | sed -n '1,80p' >&2
  exit 1
fi

HEAD_COMMIT="$(git rev-parse HEAD)"
HEAD_TREE="$(git rev-parse "HEAD^{tree}")"
TAG_TYPE="$(git cat-file -t "refs/tags/$TAG")"
TAG_COMMIT="$(git rev-parse "refs/tags/$TAG^{commit}")"

if [ "$TAG_TYPE" != "tag" ]; then
  echo "Release ref must be an annotated tag object." >&2
  exit 1
fi
if [ "$HEAD_COMMIT" != "$EXPECTED_COMMIT" ]; then
  echo "HEAD does not match the workflow commit." >&2
  exit 1
fi
if [ "$TAG_COMMIT" != "$HEAD_COMMIT" ]; then
  echo "Signed tag target does not match HEAD." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
printf 'schema_version=1\nsource_status=clean\ntag=%s\ngit_commit=%s\ngit_tree=%s\n' \
  "$TAG" \
  "$HEAD_COMMIT" \
  "$HEAD_TREE" \
  > "$OUTPUT"

echo "SOURCE_PROVENANCE_PASS"
echo "git_commit=$HEAD_COMMIT"
echo "git_tree=$HEAD_TREE"
