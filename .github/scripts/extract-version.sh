#!/usr/bin/env bash
# Extract the semantic version from Sources/TelescopeServer/main.swift
# Usage: .github/scripts/extract-version.sh
# Prints version to STDOUT. Exits non-zero on failure.
set -euo pipefail

SOURCE_FILE="Sources/TelescopeServer/main.swift"

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "ERROR: Source file not found: $SOURCE_FILE" >&2
  exit 1
fi

line=$(grep -E 'let version = "[0-9]+\.[0-9]+\.[0-9]+([\-A-Za-z0-9\.]+)?"' "$SOURCE_FILE" || true)
if [[ -z "$line" ]]; then
  echo "ERROR: Version declaration not found in $SOURCE_FILE" >&2
  exit 1
fi
if [[ $line =~ let\ version\ =\ "([0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?)" ]]; then
  VERSION="${BASH_REMATCH[1]}"
else
  echo "ERROR: Failed to parse version from: $line" >&2
  exit 1
fi

if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "ERROR: Parsed version '$VERSION' is not valid semver" >&2
  exit 1
fi

echo -n "$VERSION"
