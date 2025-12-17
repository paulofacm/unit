#!/usr/bin/env bash
set -euo pipefail

# Helper script to build relayer artifacts and optionally sign them with GPG.
# Usage: ./build_release.sh
# Prereqs: node, npm, pkg (or `npm ci` to install dev deps), gpg

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
TMP_GNUPGHOME=""

echo "Working in $ROOT_DIR"

if ! command -v node >/dev/null 2>&1; then
  echo "node not found. Install Node.js (LTS) and re-run." >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found. Install npm and re-run." >&2
  exit 1
fi

pushd "$ROOT_DIR" >/dev/null

echo "Installing dependencies..."
if [[ -f package-lock.json || -f npm-shrinkwrap.json ]]; then
  npm ci
else
  echo "No lockfile found, running 'npm install' instead of 'npm ci'"
  npm install
fi

echo "Running build (pkg) via npm script..."
npm run build:all

mkdir -p "$DIST_DIR"

echo "Generating checksums..."
(cd "$DIST_DIR" && sha256sum * > CHECKSUMS || true)

# Signing: if GPG_PRIVATE_KEY present, import into temporary GNUPGHOME and sign
if [[ -n "${GPG_PRIVATE_KEY:-}" ]]; then
  echo "GPG_PRIVATE_KEY found in environment; importing into temporary GNUPGHOME..."
  TMP_GNUPGHOME="$(mktemp -d)"
  export GNUPGHOME="$TMP_GNUPGHOME"
  echo "$GPG_PRIVATE_KEY" | gpg --batch --import
  # find the key id
  KEY_ID="$(gpg --list-secret-keys --keyid-format LONG | awk '/sec/{print $2}' | head -n1 | cut -d'/' -f2)"
  if [[ -z "$KEY_ID" ]]; then
    echo "Failed to find imported GPG key" >&2
    rm -rf "$TMP_GNUPGHOME"
    exit 1
  fi
  echo "Signing artifacts with key $KEY_ID..."
  for f in "$DIST_DIR"/*; do
    [[ -f "$f" ]] || continue
    gpg --batch --yes --pinentry-mode loopback ${GPG_PASSPHRASE:+--passphrase "$GPG_PASSPHRASE"} -u "$KEY_ID" --armor --output "$f.asc" --detach-sign "$f"
  done
  # Also sign the CHECKSUMS file
  if [[ -f "$DIST_DIR/CHECKSUMS" ]]; then
    gpg --batch --yes --pinentry-mode loopback ${GPG_PASSPHRASE:+--passphrase "$GPG_PASSPHRASE"} -u "$KEY_ID" --armor --output "$DIST_DIR/CHECKSUMS.asc" --detach-sign "$DIST_DIR/CHECKSUMS"
  fi
  # cleanup
  unset GNUPGHOME
  rm -rf "$TMP_GNUPGHOME"
  echo "Signing complete. Detached signatures written as .asc files next to artifacts."
else
  echo "No GPG_PRIVATE_KEY env var found. Skipping signing."
fi

echo "Build script completed. Artifacts (and checksums) are in: $DIST_DIR"
popd >/dev/null

exit 0
