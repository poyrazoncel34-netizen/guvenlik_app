#!/usr/bin/env bash

# Pre-production legal-site drift check. This is intentionally separate from
# the offline code/build gates because it requires network access to GitHub
# Pages. It verifies the exact public routes users and Play reviewers open.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/korubeni-live-legal.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

verify_route() {
    local label="$1"
    local source_file="$2"
    local url="$3"
    local downloaded="$TMP_DIR/$label.html"
    local digest

    curl --fail --silent --show-error --location \
        --proto '=https' \
        --tlsv1.2 \
        --output "$downloaded" \
        "$url"

    if ! cmp -s "$REPO_ROOT/$source_file" "$downloaded"; then
        echo "FAIL $label: live content differs from $source_file" >&2
        exit 1
    fi

    digest="$(shasum -a 256 "$downloaded" | awk '{print $1}')"
    echo "PASS $label $digest"
}

BASE_URL="https://poyrazoncel34-netizen.github.io/guvenlik_app"

verify_route privacy_html store/privacy_policy.html "$BASE_URL/privacy_policy.html"
verify_route privacy_root store/privacy_policy.html "$BASE_URL/"
verify_route terms_html store/kullanim_sartlari.html "$BASE_URL/kullanim_sartlari.html"
verify_route terms_route store/kullanim_sartlari.html "$BASE_URL/kullanim_sartlari"
verify_route notice_html store/aydinlatma_metni.html "$BASE_URL/aydinlatma.html"
verify_route notice_route store/aydinlatma_metni.html "$BASE_URL/aydinlatma"
verify_route deletion_html store/data_deletion.html "$BASE_URL/data_deletion.html"

echo "All public legal routes match the repository sources."
