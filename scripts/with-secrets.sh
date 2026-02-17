#!/bin/bash
# Usage: ./scripts/with-secrets.sh <env> <command>
#        ./scripts/with-secrets.sh --common-only <command>
#
# Decrypts SOPS credentials (.env format) and runs a command with secrets exported.
# Use --common-only for commands that only need common credentials (e.g. build, push).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CREDS_DIR="$(dirname "$SCRIPT_DIR")/credentials"

if ! command -v sops &> /dev/null; then
  echo "Error: sops is not installed. Install with: brew install sops"
  exit 1
fi

if [ "${1:-}" = "--common-only" ]; then
  shift
  CMD="$*"
  if [ ! -f "$CREDS_DIR/common.enc.env" ]; then
    echo "Error: $CREDS_DIR/common.enc.env not found."
    echo "Copy from common.enc.env.example and encrypt with: sops -e -i common.enc.env"
    exit 1
  fi
  sops exec-env "$CREDS_DIR/common.enc.env" "$CMD"
else
  ENV="${1:?Usage: $0 <env> <command>  or  $0 --common-only <command>}"
  shift
  CMD="$*"

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
fi
