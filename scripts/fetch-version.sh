#!/bin/bash
# fetch-version.sh - Extract version information from various sources
set -euo pipefail

TOOL_NAME="${1-}"
SOURCE_URL="${2-}"
REPO_URL="${3-}"
CONFIGURED_VERSION="${4-}"
GIT_REF="${5-}"

if [[ -z ${TOOL_NAME} ]]; then
	echo "Usage: $0 <tool_name> <source_url> [repo_url] [configured_version] [git_ref]"
	exit 1
fi

fetch_github_version() {
	local repo_path="$1"
	echo "Fetching latest release for ${TOOL_NAME}..." >&2

	local latest_tag
	if command -v curl >/dev/null 2>&1; then
		latest_tag=$(curl -s "https://api.github.com/repos/${repo_path}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
	elif command -v wget >/dev/null 2>&1; then
		latest_tag=$(wget -qO- "https://api.github.com/repos/${repo_path}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
	else
		echo "Error: Neither curl nor wget available" >&2
		return 1
	fi

	if [[ -z ${latest_tag} ]]; then
		echo "Failed to fetch latest release" >&2
		return 1
	fi

	echo "${latest_tag}"
}

# Main logic
if [[ ${SOURCE_URL} == *"github.com"* ]] && [[ -n ${REPO_URL} ]] && [[ ${REPO_URL} != "${SOURCE_URL}" ]]; then
	REPO_PATH=$(echo "${REPO_URL}" | sed 's|https://github.com/||' | sed 's|\.git$||')

	VERSION=$(fetch_github_version "${REPO_PATH}")
	if [[ -n ${VERSION} ]]; then
		echo "${VERSION}"
		echo "Latest version: ${VERSION}" >&2
	else
		echo "Failed to fetch latest release, using configured version" >&2
		echo "${GIT_REF:-${CONFIGURED_VERSION:-unknown}}"
	fi
elif [[ -n ${CONFIGURED_VERSION} ]]; then
	echo "${CONFIGURED_VERSION}"
	echo "Using configured version: ${CONFIGURED_VERSION}" >&2
else
	echo "unknown"
	echo "No version information available" >&2
fi
