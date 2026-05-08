#!/bin/bash
set -e

REPO="brave/brave-browser"
TPL="srcpkgs/brave-origin-beta/template"

echo "### Checking for brave-origin-beta updates..."

# Ambil versi beta terbaru
LATEST_VERSION=$(gh api repos/$REPO/releases --jq '[.[] | select(.tag_name | startswith("v")) | select(.prerelease == false) | select(.name | test("Beta|beta"; "i"))] | first | .tag_name' | sed 's/^v//')

if [ -z "$LATEST_VERSION" ]; then
    # Fallback: cari release yang ada file brave-origin-beta
    LATEST_VERSION=$(gh api repos/$REPO/releases --jq '[.[] | select(.assets[].name | test("brave-origin-beta"))] | first | .tag_name' | sed 's/^v//')
fi

CURRENT_VERSION=$(grep '^version=' "$TPL" | cut -d= -f2)

if [ -z "$LATEST_VERSION" ]; then
    echo "Error: Failed to fetch latest version."
    exit 1
fi

if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
    echo "No update required. Current version: $CURRENT_VERSION"
    exit 0
fi

echo "Update found: $CURRENT_VERSION -> $LATEST_VERSION"

URL="https://github.com/$REPO/releases/download/v${LATEST_VERSION}/brave-origin-beta-${LATEST_VERSION}-1.x86_64.rpm"

echo "Calculating checksum..."
CHK=$(curl -L -s "$URL" | sha256sum | awk '{print $1}')

if [ -z "$CHK" ]; then
    echo "Error: Failed to fetch checksum."
    exit 1
fi

echo "Checksum: $CHK"

sed -i "s/^version=.*/version=$LATEST_VERSION/" "$TPL"
sed -i "s/^revision=.*/revision=1/" "$TPL"
sed -i "s/^checksum=.*/checksum=\"$CHK\"/" "$TPL"

echo "NEW_VERSION=$LATEST_VERSION" >> $GITHUB_ENV
echo "### Done! brave-origin-beta updated to $LATEST_VERSION"
