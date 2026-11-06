#!/usr/bin/env bash
# Empaqueta el bundle Linux en el tar.gz que consume el actualizador.
# Uso: scripts/package_linux.sh [version] [build]
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml | head -1)}"
BUILD="${2:-$(sed -n 's/^version: *[^+]*+\([0-9]*\).*/\1/p' pubspec.yaml | head -1)}"
BUILD="${BUILD:-1}"

if [ -z "$VERSION" ]; then
  echo "No se pudo determinar la versión" >&2
  exit 1
fi

echo "Compilando $VERSION (build $BUILD)"
flutter build linux --release --build-name "$VERSION" --build-number "$BUILD"

mkdir -p dist
OUT="dist/maple-video-downloader-${VERSION}-linux-x64.tar.gz"
tar czf "$OUT" -C build/linux/x64/release/bundle .

cd dist
sha256sum "$(basename "$OUT")" > SHA256SUMS.txt
cat SHA256SUMS.txt
