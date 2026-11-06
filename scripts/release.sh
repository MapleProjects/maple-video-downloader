#!/usr/bin/env bash
# Publica una release subiendo solo el número de parche.
#
# Política: 1.1.1 -> 1.1.2 -> 1.1.3. El número del medio y el primero solo
# cambian con autorización explícita.
#
# Uso: scripts/release.sh
# Requiere: sección "## vX.Y.Z" ya escrita en CHANGELOG.md.
set -euo pipefail

cd "$(dirname "$0")/.."

CURRENT=$(sed -n 's/^version: *\([0-9]*\.[0-9]*\.[0-9]*\)+\([0-9]*\).*/\1 \2/p' pubspec.yaml)
if [ -z "$CURRENT" ]; then
  echo "No se pudo leer la versión de pubspec.yaml" >&2
  exit 1
fi

VERSION="${CURRENT% *}"
BUILD="${CURRENT#* }"
IFS=. read -r MAJOR MINOR PATCH <<< "$VERSION"

NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
NEW_BUILD=$((BUILD + 1))

if ! grep -q "^## v$NEW_VERSION" CHANGELOG.md; then
  echo "Falta la sección '## v$NEW_VERSION' en CHANGELOG.md." >&2
  echo "Escríbela antes de publicar; el cuerpo de la release se extrae de ahí." >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Hay cambios sin confirmar. Confírmalos antes de publicar." >&2
  exit 1
fi

echo "Versión actual: $VERSION+$BUILD"
echo "Nueva versión:  $NEW_VERSION+$NEW_BUILD"

sed -i "s/^version: .*/version: $NEW_VERSION+$NEW_BUILD/" pubspec.yaml

git add pubspec.yaml CHANGELOG.md
git commit -m "chore(release): $NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "Maple Video Downloader $NEW_VERSION"
git push origin main
git push origin "v$NEW_VERSION"

echo "Release v$NEW_VERSION publicada. El workflow compila y publica en unos minutos."
