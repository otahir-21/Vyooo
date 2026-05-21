#!/usr/bin/env bash
# Fail if Flutter/Dart do not match the repo pin (.fvmrc).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

expected="$(grep -E '"flutter"[[:space:]]*:' .fvmrc | sed -E 's/.*"([0-9.]+)".*/\1/')"
if [[ -z "$expected" ]]; then
  echo "Could not read Flutter version from .fvmrc"
  exit 1
fi

if command -v fvm >/dev/null 2>&1; then
  flutter_cmd=(fvm flutter)
else
  echo "WARN: fvm not on PATH; using global flutter"
  flutter_cmd=(flutter)
fi

actual="$("${flutter_cmd[@]}" --version 2>/dev/null | head -1 | sed -E 's/Flutter ([0-9.]+).*/\1/')"
if [[ "$actual" != "$expected" ]]; then
  echo "Flutter mismatch: expected $expected (from .fvmrc), got $actual"
  echo "Run: fvm install && fvm flutter pub get"
  exit 1
fi

if [[ ! -f pubspec.lock ]]; then
  echo "Missing pubspec.lock — run fvm flutter pub get and commit the lockfile."
  exit 1
fi

echo "OK: Flutter $actual, pubspec.lock present"
echo "Run fvm flutter doctor -v for full environment details."
