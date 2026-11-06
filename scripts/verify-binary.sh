#!/bin/bash
# verify-binary.sh - Verify a built artifact is statically linked
#
# An ELF binary that requests a program interpreter (ld.so) is dynamically linked and
# fails verification, unless "allow-dynamic" is passed as the third argument (used for
# tools deliberately built against glibc, such as msedit). Static and static-pie binaries
# pass. Non-ELF artifacts (shell scripts such as ble.sh) are reported and pass.
set -euo pipefail

BINARY_PATH="${1-}"
TOOL_NAME="${2-}"
LINK_POLICY="${3-}"

if [[ -z ${BINARY_PATH} ]] || [[ -z ${TOOL_NAME} ]]; then
	echo "Usage: $0 <binary_path> <tool_name> [allow-dynamic]"
	exit 1
fi

if [[ ! -f ${BINARY_PATH} ]]; then
	echo "Error: Binary not found at ${BINARY_PATH}"
	exit 1
fi

FILE_OUTPUT=$(file -bL "${BINARY_PATH}")
echo "Verifying ${TOOL_NAME}: ${FILE_OUTPUT}"

if [[ ${FILE_OUTPUT} != *ELF* ]]; then
	echo "Not an ELF binary, skipping link check"
	exit 0
fi

# Older versions of file(1) describe static-pie binaries as "dynamically linked", so the
# presence of an interpreter is the reliable signal for dynamic linking.
if [[ ${FILE_OUTPUT} == *"interpreter"* ]]; then
	if [[ ${LINK_POLICY} == "allow-dynamic" ]]; then
		echo "Warning: ${TOOL_NAME} is dynamically linked (allowed for this tool)"
		exit 0
	fi
	echo "Error: ${TOOL_NAME} is dynamically linked but must be static"
	exit 1
fi

echo "${TOOL_NAME} is statically linked"
