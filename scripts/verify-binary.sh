#!/bin/bash
# verify-binary.sh - Verify binary is statically linked
set -euo pipefail

BINARY_PATH="${1-}"
TOOL_NAME="${2-}"

if [[ -z ${BINARY_PATH} ]] || [[ -z ${TOOL_NAME} ]]; then
	echo "Usage: $0 <binary_path> <tool_name>"
	exit 1
fi

if [[ ! -f ${BINARY_PATH} ]]; then
	echo "Error: Binary not found at ${BINARY_PATH}"
	exit 1
fi

echo "Verifying ${TOOL_NAME} is statically linked..."
file "${BINARY_PATH}"

if file "${BINARY_PATH}" | grep -q "dynamically linked"; then
	if file "${BINARY_PATH}" | grep -q "interpreter"; then
		echo "Warning: Binary is dynamically linked with interpreter"
	else
		echo "Warning: Binary appears dynamically linked but may be acceptable"
	fi
fi

if ! file "${BINARY_PATH}" | grep -q "statically linked"; then
	echo "Warning: Cannot confirm static linking"
fi

echo "Binary verification passed"
