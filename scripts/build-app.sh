#!/usr/bin/env bash
# Builds build/Tiko.app from the Swift package.
# No Xcode needed — the Command Line Tools are enough.
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
app_bundle="$project_root/build/Tiko.app"

cd "$project_root"
swift build -c release --product Tiko

rm -rf "$app_bundle"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp ".build/release/Tiko" "$app_bundle/Contents/MacOS/Tiko"
cp "Resources/Info.plist" "$app_bundle/Contents/Info.plist"
# Regenerate with: swift scripts/make-icon.swift build/Tiko.iconset && iconutil -c icns build/Tiko.iconset -o Resources/Tiko.icns
cp "Resources/Tiko.icns" "$app_bundle/Contents/Resources/Tiko.icns"

# Ad-hoc signature ("-") is enough to run on this Mac. macOS ties privacy
# permissions to the signature, so after a rebuild it asks for them again.
codesign --force --sign - --identifier com.adarshbhardwaj.tiko "$app_bundle"

echo "Built $app_bundle"
