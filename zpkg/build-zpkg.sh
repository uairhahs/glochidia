#!/bin/bash
# build-zpkg.sh - Package a gpm binary as the ZimaOS RAW extension (gpm.raw)
# Usage: zpkg/build-zpkg.sh <path/to/gpm> [output.raw]
#
# The gpm binary is not stored in the repository. CI passes the binary it just built;
# locally, build one first (see gpm/README.md) and pass its path.
set -euo pipefail

GPM_BINARY="${1:?Usage: $0 <path/to/gpm> [output.raw]}"
OUTPUT="${2:-gpm.raw}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f ${GPM_BINARY} ]]; then
	echo "Error: gpm binary not found at ${GPM_BINARY}"
	exit 1
fi

# Stage the package tree in a temp directory so the repo tree stays clean
STAGING=$(mktemp -d)
trap 'rm -rf "${STAGING}"' EXIT
cp -a "${SCRIPT_DIR}/raw/." "${STAGING}/"
mkdir -p "${STAGING}/usr/bin"
install -m 0755 "${GPM_BINARY}" "${STAGING}/usr/bin/gpm"

mksquashfs "${STAGING}" "${OUTPUT}" -noappend -all-root

echo "ZimaOS RAW package created: ${OUTPUT}"
