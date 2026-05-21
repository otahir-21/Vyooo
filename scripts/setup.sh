#!/usr/bin/env bash
# Vyooo — one-shot local setup (FVM + pub get). Safe to re-run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v fvm >/dev/null 2>&1; then
  echo "FVM not found. Install: dart pub global activate fvm"
  echo "Then add ~/.pub-cache/bin to PATH."
  exit 1
fi

echo "==> Installing Flutter from .fvmrc"
fvm install

echo "==> Resolving Dart packages"
fvm flutter pub get

echo "==> Toolchain check"
./scripts/verify_toolchain.sh

echo ""
echo "Done. Use: fvm flutter run"
echo "Store versions: docs/VERSIONING.md · bump build: ./scripts/bump_build.sh"
