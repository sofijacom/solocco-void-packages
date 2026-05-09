#!/bin/bash
set -euo pipefail

REPO="brave/brave-browser"
TPL="srcpkgs/brave-origin-beta/template"

echo "### Checking for brave-origin-beta updates..."

# Validasi file template ada
if [ ! -f "$TPL" ]; then
    echo "Error: Template file not found: $TPL"
    exit 1
fi

# Ambil versi beta terbaru dari GitHub releases
LATEST_VERSION=$(gh api "repos/$REPO/releases" \
    --jq '[.[] | select(.prerelease == false) | select(.name | test("Beta|beta"; "i"))] | first | .tag_name' \
    | sed 's/^v//')

# Fallback: cari dari nama aset release
if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION=$(gh api "repos/$REPO/releases" \
        --jq '[.[] | select(.assets[].name | test("brave-origin-beta"))] | first | .tag_name' \
        | sed 's/^v//')
fi

if [ -z "$LATEST_VERSION" ]; then
    echo "Error: Failed to fetch latest version."
    exit 1
fi

CURRENT_VERSION=$(grep '^version=' "$TPL" | cut -d= -f2)

if [ -z "$CURRENT_VERSION" ]; then
    echo "Error: Failed to read current version from template."
    exit 1
fi

echo "Current version : $CURRENT_VERSION"
echo "Latest version  : $LATEST_VERSION"

if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
    echo "No update required."
    exit 0
fi

echo "Update found: $CURRENT_VERSION -> $LATEST_VERSION"

URL="https://github.com/$REPO/releases/download/v${LATEST_VERSION}/brave-origin-beta-${LATEST_VERSION}-1.x86_64.rpm"
echo "Fetching checksum from: $URL"

# Hitung checksum dengan error handling
CHK=$(curl -fL --retry 3 --retry-delay 2 -s "$URL" | sha256sum | awk '{print $1}')

if [ -z "$CHK" ]; then
    echo "Error: Failed to calculate checksum."
    exit 1
fi

echo "Checksum: $CHK"

# Update template
sed -i "s/^version=.*/version=$LATEST_VERSION/" "$TPL"
sed -i "s/^revision=.*/revision=1/" "$TPL"
sed -i "s/^checksum=.*/checksum=\"$CHK\"/" "$TPL"

# Export ke GitHub Actions environment (hanya jika berjalan di CI)
if [ -n "${GITHUB_ENV:-}" ]; then
    echo "NEW_VERSION=$LATEST_VERSION" >> "$GITHUB_ENV"
fi

echo "### Done! brave-origin-beta updated to $LATEST_VERSION"
