#!/usr/bin/env bash
set -euo pipefail

# Détecte une version de JDK à partir d'un pom.xml Maven.
# Priorité : maven.compiler.release > java.version > maven.compiler.target > maven.compiler.source > défaut
#
# Usage:
#   ./detect_jdk_from_pom.sh /path/to/pom.xml [defaultVersion]
# Sortie:
#   écrit la version retenue sur stdout

POM_PATH="${1:-}"
DEFAULT_VERSION="${2:-17}"

if [ -z "$POM_PATH" ]; then
  echo "Usage: $0 /path/to/pom.xml [defaultVersion]" >&2
  exit 2
fi

extract_prop() {
  local prop="$1"
  if [ ! -f "$POM_PATH" ]; then
    return 0
  fi
  # Extrait la valeur d'une propriété Maven sous forme <prop>value</prop>
  # Tolère les espaces et reste portable (pas de PCRE).
  sed -n "s@.*<${prop}>\\([^<]*\\)</${prop}>.*@\\1@p" "$POM_PATH" | head -n 1 | tr -d '[:space:]'
}

FINAL_VERSION="$DEFAULT_VERSION"

if [ -f "$POM_PATH" ]; then
  DETECTED_RELEASE="$(extract_prop "maven.compiler.release" || true)"
  DETECTED_JAVA_VERSION="$(extract_prop "java.version" || true)"
  DETECTED_TARGET="$(extract_prop "maven.compiler.target" || true)"
  DETECTED_SOURCE="$(extract_prop "maven.compiler.source" || true)"

  if [ -n "$DETECTED_RELEASE" ]; then
    FINAL_VERSION="$DETECTED_RELEASE"
  elif [ -n "$DETECTED_JAVA_VERSION" ]; then
    FINAL_VERSION="$DETECTED_JAVA_VERSION"
  elif [ -n "$DETECTED_TARGET" ]; then
    FINAL_VERSION="$DETECTED_TARGET"
  elif [ -n "$DETECTED_SOURCE" ]; then
    FINAL_VERSION="$DETECTED_SOURCE"
  fi
fi

echo "$FINAL_VERSION"

