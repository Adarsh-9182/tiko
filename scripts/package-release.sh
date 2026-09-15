#!/usr/bin/env bash
# Builds Tiko.app and packs it into a zip for a GitHub release, with a
# SHA-256 checksum people can verify the download against.
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

./scripts/build-app.sh

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
release_folder="build/release"
zip_name="Tiko-${version}.zip"

rm -rf "$release_folder"
mkdir -p "$release_folder"

# ditto keeps the app bundle's structure, extended attributes and signature
# intact, which a plain `zip` can break.
ditto -c -k --keepParent build/Tiko.app "$release_folder/$zip_name"
(cd "$release_folder" && shasum -a 256 "$zip_name" > "$zip_name.sha256")

echo "Packed $release_folder/$zip_name"
cat "$release_folder/$zip_name.sha256"
