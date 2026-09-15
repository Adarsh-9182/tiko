#!/usr/bin/env bash
# Creates a self-signed code-signing identity for Tiko in its own keychain.
#
# Why: an ad-hoc signature changes with every build, and macOS ties privacy
# permissions (Accessibility, Screen Recording, Microphone, Speech) to the
# signature — so every rebuild or update had to be granted them again. Signing
# every build with the same certificate keeps the designated requirement the
# same, and the permissions stick.
#
# It does not satisfy Gatekeeper; that still needs a paid Developer ID.
#
# Undo with:
#   security delete-keychain ~/Library/Keychains/tiko-signing.keychain-db
#   rm ~/.config/tiko/signing-keychain-password
set -euo pipefail

identity_name="Tiko Local Signing"
keychain_path="$HOME/Library/Keychains/tiko-signing.keychain-db"
password_folder="$HOME/.config/tiko"
password_file="$password_folder/signing-keychain-password"

if [[ -f "$keychain_path" ]]; then
  echo "A Tiko signing keychain already exists at $keychain_path — nothing to do."
  exit 0
fi

mkdir -p "$password_folder"
chmod 700 "$password_folder"
openssl rand -hex 24 > "$password_file"
chmod 600 "$password_file"
keychain_password="$(cat "$password_file")"

work_folder="$(mktemp -d)"
trap 'rm -rf "$work_folder"' EXIT

cat > "$work_folder/certificate.cnf" <<EOF
[req]
distinguished_name = subject
x509_extensions = code_signing
prompt = no

[subject]
CN = $identity_name

[code_signing]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config "$work_folder/certificate.cnf" \
  -keyout "$work_folder/private-key.pem" \
  -out "$work_folder/certificate.pem" 2>/dev/null

bundle_password="$(openssl rand -hex 16)"
openssl pkcs12 -export \
  -inkey "$work_folder/private-key.pem" \
  -in "$work_folder/certificate.pem" \
  -name "$identity_name" \
  -out "$work_folder/identity.p12" \
  -passout "pass:$bundle_password"

security create-keychain -p "$keychain_password" "$keychain_path"
# No automatic locking, so builds don't stop to ask for the password.
security set-keychain-settings "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"
security import "$work_folder/identity.p12" -k "$keychain_path" -P "$bundle_password" -T /usr/bin/codesign >/dev/null
# Let codesign use the key without a confirmation dialog.
security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain_path" >/dev/null

echo "Created \"$identity_name\" in $keychain_path"
security find-identity -p codesigning "$keychain_path"
