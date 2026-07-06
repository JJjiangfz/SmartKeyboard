#!/usr/bin/env bash
set -euo pipefail

IDENTITY_NAME="${SMARTKEYBOARD_LOCAL_SIGNING_IDENTITY:-SmartKeyboard Local Code Signing}"
KEYCHAIN="${SMARTKEYBOARD_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
IMPORT_PASSWORD="smartkeyboard-local-signing"

if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -F "\"$IDENTITY_NAME\"" >/dev/null; then
  echo "Using existing code-signing identity: $IDENTITY_NAME"
  exit 0
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "OpenSSL is required to create the local code-signing identity." >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cat > "$WORK_DIR/openssl.cnf" <<CONFIG
[req]
distinguished_name = dn
x509_extensions = codesign_ext
prompt = no

[dn]
CN = $IDENTITY_NAME

[codesign_ext]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
CONFIG

openssl req \
  -x509 \
  -newkey rsa:2048 \
  -sha256 \
  -nodes \
  -days 3650 \
  -keyout "$WORK_DIR/key.pem" \
  -out "$WORK_DIR/cert.pem" \
  -config "$WORK_DIR/openssl.cnf" >/dev/null 2>&1

openssl pkcs12 \
  -export \
  -inkey "$WORK_DIR/key.pem" \
  -in "$WORK_DIR/cert.pem" \
  -name "$IDENTITY_NAME" \
  -out "$WORK_DIR/identity.p12" \
  -passout "pass:$IMPORT_PASSWORD" >/dev/null 2>&1

security import "$WORK_DIR/identity.p12" \
  -k "$KEYCHAIN" \
  -P "$IMPORT_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security >/dev/null

security add-trusted-cert \
  -r trustRoot \
  -p codeSign \
  -k "$KEYCHAIN" \
  "$WORK_DIR/cert.pem" >/dev/null 2>&1 || true

if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -F "\"$IDENTITY_NAME\"" >/dev/null; then
  echo "Created code-signing identity: $IDENTITY_NAME"
else
  echo "Created '$IDENTITY_NAME', but macOS does not list it as a valid code-signing identity yet." >&2
  echo "Open Keychain Access and set the certificate to Always Trust for Code Signing, then rerun this script." >&2
  exit 1
fi
