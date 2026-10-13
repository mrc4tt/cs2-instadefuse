#!/usr/bin/env bash
# Builds Release and packages dist/InstadefusePlugin.zip in the CounterStrikeSharp layout:
#   addons/counterstrikesharp/plugins/InstadefusePlugin/...
# Also writes dist/release-notes.md from the matching CHANGELOG.md section.
#
# Usage: ./package.sh [X.Y.Z]   (version defaults to the plugin's version; when given it must match)
set -euo pipefail
cd "$(dirname "$0")"

PLUGIN=InstadefusePlugin
CSPROJ=InstadefusePlugin.csproj
OUT_DIR=bin/Release/net10.0
EXTRA_DIRS=(lang)

SOURCE_VERSION="$(grep -oP 'private const string Version = "\K[^"]+' InstadefusePlugin.cs)"
VERSION="${1:-$SOURCE_VERSION}"
if [[ -z "$SOURCE_VERSION" || "$VERSION" != "$SOURCE_VERSION" ]]; then
    echo "ERROR: version $VERSION does not match the plugin version ($SOURCE_VERSION)" >&2
    exit 1
fi

NOTES="$(awk -v v="$VERSION" '$0 ~ "^## " { if (found) exit; found = ($2 == v); next } found' CHANGELOG.md)"
if [[ -z "${NOTES//[[:space:]]/}" ]]; then
    echo "ERROR: CHANGELOG.md has no \"## $VERSION\" section" >&2
    exit 1
fi

rm -rf dist "$OUT_DIR"
dotnet build "$CSPROJ" -c Release

STAGE=dist/stage
PLUGIN_DIR="$STAGE/addons/counterstrikesharp/plugins/$PLUGIN"
mkdir -p "$PLUGIN_DIR"
cp -r "$OUT_DIR"/. "$PLUGIN_DIR/"
for d in "${EXTRA_DIRS[@]}"; do
    cp -r "$d" "$PLUGIN_DIR/"
done

# Linux only, no debug symbols or backups.
find "$STAGE" \( -name '*.pdb' -o -name '*.bak' \) -delete
find "$STAGE" -type d -path '*/runtimes/*' -prune ! -name linux-x64 ! -name unix -exec rm -rf {} +

test -f "$PLUGIN_DIR/$PLUGIN.dll"
if [[ -d "$STAGE/addons/counterstrikesharp/configs" ]]; then
    echo "ERROR: configs/ must never be shipped" >&2
    exit 1
fi

(cd "$STAGE" && zip -qr "../$PLUGIN.zip" addons)
rm -rf "$STAGE"
printf '%s\n' "$NOTES" > dist/release-notes.md

unzip -l "dist/$PLUGIN.zip"
echo "==> dist/$PLUGIN.zip ($VERSION)"
