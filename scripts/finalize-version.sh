#!/bin/bash
# finalize-version.sh - Create and validate version metadata files
set -euo pipefail

TOOL_NAME="${1-}"
CONFIGURED_VERSION="${2-}"
FETCHED_VERSION="${3-}"
REPO_VERSION="${4:-1.0.0}"
WORKING_DIR="${5-}"

if [[ -z ${TOOL_NAME} ]]; then
	echo "Usage: $0 <tool_name> [configured_version] [fetched_version] [repo_version] [working_dir]"
	exit 1
fi

VERSION_FILE="${TOOL_NAME}.version"

# Ensure version file exists and is not empty
if [[ ! -f ${VERSION_FILE} ]]; then
	# File doesn't exist, create with fallback
	if [[ -n ${WORKING_DIR} ]]; then
		echo "${REPO_VERSION}" >"${VERSION_FILE}"
		echo "Created version file for ${TOOL_NAME} with repo version: ${REPO_VERSION}"
	elif [[ -n ${CONFIGURED_VERSION} ]]; then
		echo "${CONFIGURED_VERSION}" >"${VERSION_FILE}"
		echo "Created version file for ${TOOL_NAME} with configured version: ${CONFIGURED_VERSION}"
	else
		echo "${FETCHED_VERSION}" >"${VERSION_FILE}"
		echo "Created version file for ${TOOL_NAME} with fetched version: ${FETCHED_VERSION}"
	fi
else
	# File exists, clean it up and validate
	VERSION=$(tr -d '\n\r' <"${VERSION_FILE}" | xargs | sed 's/^v//')

	if [[ -z ${VERSION} ]] || [[ ${VERSION} == "unknown" ]]; then
		# Empty or unknown, use fallback
		if [[ -n ${WORKING_DIR} ]]; then
			echo "${REPO_VERSION}" >"${VERSION_FILE}"
			echo "Version file was empty, using repo version for ${TOOL_NAME}: ${REPO_VERSION}"
		elif [[ -n ${CONFIGURED_VERSION} ]]; then
			echo "${CONFIGURED_VERSION}" >"${VERSION_FILE}"
			echo "Version file was empty, using configured version for ${TOOL_NAME}: ${CONFIGURED_VERSION}"
		else
			echo "${FETCHED_VERSION}" >"${VERSION_FILE}"
			echo "Version file was empty, using fetched version for ${TOOL_NAME}: ${FETCHED_VERSION}"
		fi
	else
		# Valid version, write it back (cleaned)
		echo "${VERSION}" >"${VERSION_FILE}"
		echo "Version for ${TOOL_NAME}: ${VERSION}"
	fi
fi
