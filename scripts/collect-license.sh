#!/bin/bash
# collect-license.sh - Gather a source tree's license files for redistribution
# Usage: collect-license.sh <source_dir> <tool_name> <output_file>
#
# Licenses such as MIT, ISC and BSD require their copyright and permission notice to
# accompany redistributed binaries. This copies every top-level LICENSE*, LICENCE*,
# COPYING*, COPYRIGHT* and NOTICE* file of the source into one text file, and fails if
# the source has none, so a binary is never published without its license.
set -euo pipefail

SOURCE_DIR="${1:?Usage: $0 <source_dir> <tool_name> <output_file>}"
TOOL_NAME="${2:?Usage: $0 <source_dir> <tool_name> <output_file>}"
OUTPUT_FILE="${3:?Usage: $0 <source_dir> <tool_name> <output_file>}"

if [[ ! -d ${SOURCE_DIR} ]]; then
	echo "Error: source directory not found: ${SOURCE_DIR}"
	exit 1
fi

mapfile -t FILES < <(find "${SOURCE_DIR}" -maxdepth 1 -type f \
	\( -iname 'LICENSE*' -o -iname 'LICENCE*' -o -iname 'COPYING*' -o -iname 'COPYRIGHT*' -o -iname 'NOTICE*' \) |
	LC_ALL=C sort)

if [[ ${#FILES[@]} -eq 0 ]]; then
	echo "Error: no license file found in ${SOURCE_DIR} for ${TOOL_NAME}"
	exit 1
fi

{
	echo "License files from the ${TOOL_NAME} source code, as distributed with the ${TOOL_NAME} binary."
	for file in "${FILES[@]}"; do
		echo
		echo "================================================================================"
		echo "${TOOL_NAME}: $(basename "${file}")"
		echo "================================================================================"
		echo
		cat "${file}"
	done
} >"${OUTPUT_FILE}"

echo "Collected license for ${TOOL_NAME}: $(for f in "${FILES[@]}"; do basename "${f}"; done | tr '\n' ' ')"
