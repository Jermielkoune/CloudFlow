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
  local pom="$1"
  local prop="$2"
  if [ ! -f "$pom" ]; then
    return 0
  fi
  # Extrait la valeur d'une propriété Maven sous forme <prop>value</prop>
  # Tolère les espaces et reste portable (pas de PCRE).
  sed -n "s@.*<${prop}>\\([^<]*\\)</${prop}>.*@\\1@p" "$pom" | head -n 1 | tr -d '[:space:]'
}

detect_in_pom() {
  local pom="$1"

  local release="$(extract_prop "$pom" "maven.compiler.release" || true)"
  local java_version="$(extract_prop "$pom" "java.version" || true)"
  local target="$(extract_prop "$pom" "maven.compiler.target" || true)"
  local source="$(extract_prop "$pom" "maven.compiler.source" || true)"

  if [ -n "$release" ]; then
    echo "$release"
    return 0
  fi
  if [ -n "$java_version" ]; then
    echo "$java_version"
    return 0
  fi
  if [ -n "$target" ]; then
    echo "$target"
    return 0
  fi
  if [ -n "$source" ]; then
    echo "$source"
    return 0
  fi

  echo ""
}

parent_pom_path() {
  local pom="$1"
  local base_dir
  base_dir="$(cd "$(dirname "$pom")" && pwd)"

  # 1) parent.relativePath si présent
  local rel
  rel="$(extract_prop "$pom" "parent.relativePath" || true)"
  if [ -n "$rel" ]; then
    # La valeur par défaut Maven est ../pom.xml si relativePath vide ou absent.
    local candidate="$base_dir/$rel"
    if [ -f "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  fi

  # 2) fallback Maven standard : ../pom.xml
  local fallback="$base_dir/../pom.xml"
  if [ -f "$fallback" ]; then
    echo "$fallback"
    return 0
  fi

  echo ""
}

FINAL_VERSION="$DEFAULT_VERSION"

if [ -f "$POM_PATH" ]; then
  # 1) tente sur le POM du module
  DETECTED="$(detect_in_pom "$POM_PATH")"
  if [ -n "$DETECTED" ]; then
    echo "$DETECTED"
    exit 0
  fi

  # 2) si non trouvé, tente sur le POM parent (cas multi-module)
  PARENT_POM="$(parent_pom_path "$POM_PATH")"
  if [ -n "$PARENT_POM" ]; then
    DETECTED_PARENT="$(detect_in_pom "$PARENT_POM")"
    if [ -n "$DETECTED_PARENT" ]; then
      echo "$DETECTED_PARENT"
      exit 0
    fi
  fi
fi

echo "$FINAL_VERSION"

