#!/bin/bash
# Usage: ./scripts/with-secrets.sh <env> <command>
# Decrypts SOPS credentials (.env format) and runs a command with secrets exported.
set -euo pipefail

ENV="${1:?Usage: $0 <env> <command>}"
shift
CMD="$*"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CREDS_DIR="$(dirname "$SCRIPT_DIR")/credentials"

if ! command -v sops &> /dev/null; then
  echo "Error: sops is not installed. Install with: brew install sops"
  exit 1
fi

for f in "$CREDS_DIR/common.enc.env" "$CREDS_DIR/$ENV.enc.env"; do
  if [ ! -f "$f" ]; then
    echo "Error: $f not found."
    echo "Copy from ${f}.example and encrypt with: sops -e -i $f"
    exit 1
  fi
done

# Chain: decrypt common, then decrypt env-specific, then run command
sops exec-env "$CREDS_DIR/common.enc.env" \
  "sops exec-env \"$CREDS_DIR/$ENV.enc.env\" '$CMD'"
