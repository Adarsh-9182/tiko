#!/usr/bin/env bash
# Builds build/Tiko.app from the Swift package.
# No Xcode needed — the Command Line Tools are enough.
#
#   scripts/build-app.sh              this Mac's architecture only (fast)
#   scripts/build-app.sh --universal  Apple silicon and Intel in one app
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
app_bundle="$project_root/build/Tiko.app"
bundle_identifier="com.adarshbhardwaj.tiko"
minimum_macos_version="14.0"

signing_identity="Tiko Local Signing"
signing_keychain="$HOME/Library/Keychains/tiko-signing.keychain-db"
signing_password_file="$HOME/.config/tiko/signing-keychain-password"

is_universal=false
if [[ "${1:-}" == "--universal" ]]; then
  is_universal=true
fi

cd "$project_root"
rm -rf "$app_bundle"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"

if $is_universal; then
  # SwiftPM's own multi-architecture build needs Xcode, so build each
  # architecture separately and join the two executables with lipo.
  architecture_binaries=()
  for architecture in arm64 x86_64; do
    triple="$architecture-apple-macosx$minimum_macos_version"
    scratch_path=".build/$architecture"
    swift build -c release --product Tiko --triple "$triple" --scratch-path "$scratch_path"
    architecture_binaries+=("$(swift build -c release --product Tiko --triple "$triple" --scratch-path "$scratch_path" --show-bin-path)/Tiko")
  done
  lipo -create "${architecture_binaries[@]}" -output "$app_bundle/Contents/MacOS/Tiko"
  echo "Universal: $(lipo -archs "$app_bundle/Contents/MacOS/Tiko")"
else
  swift build -c release --product Tiko
  cp ".build/release/Tiko" "$app_bundle/Contents/MacOS/Tiko"
fi

cp "Resources/Info.plist" "$app_bundle/Contents/Info.plist"
# Regenerate with: swift scripts/make-icon.swift build/Tiko.iconset && iconutil -c icns build/Tiko.iconset -o Resources/Tiko.icns
cp "Resources/Tiko.icns" "$app_bundle/Contents/Resources/Tiko.icns"

if [[ -f "$signing_keychain" && -f "$signing_password_file" ]]; then
  # The same certificate on every build keeps the designated requirement
  # unchanged, so macOS keeps Tiko's privacy permissions across rebuilds.
  security unlock-keychain -p "$(cat "$signing_password_file")" "$signing_keychain"
  signing_certificate_hash="$(security find-identity -p codesigning "$signing_keychain" \
    | awk -v identity="\"$signing_identity\"" 'index($0, identity) { print $2; exit }')"

  # codesign only finds a private key in a keychain on the user's search list,
  # even with --keychain. Add Tiko's keychain just for signing, and put the
  # list back afterwards — also if signing fails.
  original_search_list=()
  while IFS= read -r keychain_line; do
    keychain_line="$(printf '%s' "$keychain_line" | sed -e 's/^[[:space:]]*"//' -e 's/"$//')"
    [[ -n "$keychain_line" ]] && original_search_list+=("$keychain_line")
  done < <(security list-keychains -d user)
  restore_search_list() { security list-keychains -d user -s "${original_search_list[@]}"; }
  trap restore_search_list EXIT
  security list-keychains -d user -s "${original_search_list[@]}" "$signing_keychain"

  codesign --force --sign "$signing_certificate_hash" --keychain "$signing_keychain" \
    --identifier "$bundle_identifier" --timestamp=none "$app_bundle"

  restore_search_list
  trap - EXIT
  echo "Signed with \"$signing_identity\""
else
  # Ad-hoc runs on this Mac, but its signature changes every build, so macOS
  # asks for permissions again each time. scripts/create-signing-identity.sh fixes that.
  codesign --force --sign - --identifier "$bundle_identifier" "$app_bundle"
  echo "Signed ad-hoc (run scripts/create-signing-identity.sh to keep permissions across builds)"
fi

echo "Built $app_bundle"
