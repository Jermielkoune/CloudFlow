#!/usr/bin/env bash
set -euo pipefail

# Détecte une version de JDK à partir d'un pom.xml Maven.
# Priorité : maven.compiler.release > java.version > maven.compiler.target > maven.compiler.source > défaut
#
# Usage:
#   ./detect_jdk_from_pom.sh /path/to/pom.xml [defaultVersion]
# Sortie:
#   écrit la version retenue sur stdout

ROOT_POM_PATH="${1:-}"
DEFAULT_VERSION="${2:-21}"

if [ -z "$ROOT_POM_PATH" ]; then
  echo "Usage: $0 /path/to/root/pom.xml [defaultVersion]" >&2
  exit 2
fi

extract_prop() {
  local pom="$1"
  local prop="$2"
  if [ ! -f "$pom" ]; then
    return 0
  fi
  sed -n "s@.*<${prop}>\\([^<]*\\)</${prop}>.*@\\1@p" "$pom" | head -n 1 | tr -d '[:space:]'
}

FINAL_VERSION="$DEFAULT_VERSION"

if [ ! -f "$ROOT_POM_PATH" ]; then
  echo "$FINAL_VERSION"
  exit 0
fi

RELEASE="$(extract_prop "$ROOT_POM_PATH" "maven.compiler.release" || true)"
JAVA_VERSION="$(extract_prop "$ROOT_POM_PATH" "java.version" || true)"
TARGET="$(extract_prop "$ROOT_POM_PATH" "maven.compiler.target" || true)"
SOURCE="$(extract_prop "$ROOT_POM_PATH" "maven.compiler.source" || true)"

if [ -n "$RELEASE" ]; then
  FINAL_VERSION="$RELEASE"
elif [ -n "$JAVA_VERSION" ]; then
  FINAL_VERSION="$JAVA_VERSION"
elif [ -n "$TARGET" ]; then
  FINAL_VERSION="$TARGET"
elif [ -n "$SOURCE" ]; then
  FINAL_VERSION="$SOURCE"
fi

echo "$FINAL_VERSION"

