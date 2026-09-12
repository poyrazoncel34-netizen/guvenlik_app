#!/usr/bin/env bash
# Verify an annotated tag against operator-configured public trust in isolation.
# Never reads a developer's default keyring or changes the release signing keys.
set -euo pipefail
TAG="${1:?tag required}"
if [ "$(git cat-file -t "refs/tags/$TAG")" != tag ]; then
  echo 'Release tag must be annotated and signed.' >&2
  exit 1
fi
TRUST_DIR="$(mktemp -d)"
trap 'rm -rf "$TRUST_DIR"' EXIT
chmod 700 "$TRUST_DIR"
if git cat-file tag "refs/tags/$TAG" | grep -q -- '-----BEGIN SSH SIGNATURE-----'; then
  if [ -z "${RELEASE_TAG_SSH_ALLOWED_SIGNERS:-}" ]; then
    echo 'Missing approved RELEASE_TAG_SSH_ALLOWED_SIGNERS public trust.' >&2
    exit 1
  fi
  printf '%s\n' "$RELEASE_TAG_SSH_ALLOWED_SIGNERS" > "$TRUST_DIR/allowed_signers"
  git -c gpg.format=ssh -c gpg.ssh.allowedSignersFile="$TRUST_DIR/allowed_signers" verify-tag -- "$TAG"
else
  if [ -z "${RELEASE_TAG_GPG_PUBLIC_KEYS:-}" ]; then
    echo 'Missing approved RELEASE_TAG_GPG_PUBLIC_KEYS public trust.' >&2
    exit 1
  fi
  if printf '%s' "$RELEASE_TAG_GPG_PUBLIC_KEYS" | grep -q 'PRIVATE KEY'; then
    echo 'Only public tag-verification keys are accepted.' >&2
    exit 1
  fi
  printf '%s\n' "$RELEASE_TAG_GPG_PUBLIC_KEYS" > "$TRUST_DIR/public.asc"
  GNUPGHOME="$TRUST_DIR" gpg --batch --quiet --import "$TRUST_DIR/public.asc"
  GNUPGHOME="$TRUST_DIR" git -c gpg.format=openpgp verify-tag -- "$TAG"
fi
