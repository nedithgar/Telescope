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

# Use sed to safely capture the version (supports optional pre-release like -rc.1)
VERSION=$(sed -nE 's/.*let version = "([0-9]+(\.[0-9]+){2}(-[0-9A-Za-z.-]+)?)".*/\1/p' "$SOURCE_FILE" | head -n1)

if [[ -z "${VERSION:-}" ]]; then
  echo "ERROR: Version declaration not found or unparsable in $SOURCE_FILE" >&2
  exit 1
fi

# Validate SemVer (allow optional pre-release; no build metadata handled here)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "ERROR: Parsed version '$VERSION' is not valid semver" >&2
  exit 1
fi

printf '%s' "$VERSION"
