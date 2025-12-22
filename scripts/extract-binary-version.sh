#!/bin/bash
# extract-binary-version.sh - Extract version from compiled binary
set -euo pipefail

BINARY_PATH="${1-}"
FALLBACK_VERSION="${2-}"

if [[ -z ${BINARY_PATH} ]]; then
	echo "Usage: $0 <binary_path> [fallback_version]"
	exit 1
fi

if [[ ! -f ${BINARY_PATH} ]]; then
	echo "Error: Binary not found at ${BINARY_PATH}"
	exit 1
fi

# Try to extract version from the binary
VERSION_OUTPUT=$("${BINARY_PATH}" --version 2>&1 || echo "")

# Try strict X.Y.Z pattern first
VERSION=$(echo "${VERSION_OUTPUT}" | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' | head -n1)

# If no match, try looser pattern
if [[ -z ${VERSION} ]]; then
	VERSION=$(echo "${VERSION_OUTPUT}" | grep -o -E "([0-9]+\.?)+[0-9]+" | head -1)
fi

# Remove 'v' prefix if present
VERSION=${VERSION#v}

# Use fallback if no version found
if [[ -z ${VERSION} ]]; then
	VERSION="${FALLBACK_VERSION}"
fi

echo "${VERSION}"
