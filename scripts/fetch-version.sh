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

	local api_url="https://api.github.com/repos/${repo_path}/releases/latest"
	local latest_tag
	# Authenticate when a token is available to avoid the low anonymous API rate limit
	if command -v curl >/dev/null 2>&1; then
		if [[ -n ${GITHUB_TOKEN-} ]]; then
			latest_tag=$(curl -s -H "Authorization: Bearer ${GITHUB_TOKEN}" "${api_url}" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
		else
			latest_tag=$(curl -s "${api_url}" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
		fi
	elif command -v wget >/dev/null 2>&1; then
		if [[ -n ${GITHUB_TOKEN-} ]]; then
			latest_tag=$(wget -qO- --header="Authorization: Bearer ${GITHUB_TOKEN}" "${api_url}" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
		else
			latest_tag=$(wget -qO- "${api_url}" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || true)
		fi
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
# Precedence: explicit git ref, then configured version, then latest GitHub release.
# The release lookup uses REPO_URL when given, otherwise SOURCE_URL.
GITHUB_URL="${REPO_URL:-${SOURCE_URL}}"

if [[ -n ${GIT_REF} ]]; then
	echo "${GIT_REF}"
	echo "Using configured git ref: ${GIT_REF}" >&2
elif [[ -n ${CONFIGURED_VERSION} ]]; then
	echo "${CONFIGURED_VERSION}"
	echo "Using configured version: ${CONFIGURED_VERSION}" >&2
elif [[ ${GITHUB_URL} == *"github.com"* ]]; then
	REPO_PATH=$(echo "${GITHUB_URL}" | sed 's|https://github.com/||' | sed 's|\.git$||')
	if VERSION=$(fetch_github_version "${REPO_PATH}"); then
		echo "${VERSION}"
		echo "Latest version: ${VERSION}" >&2
	else
		echo "unknown"
		echo "Failed to fetch latest release for ${REPO_PATH}" >&2
	fi
else
	echo "unknown"
	echo "No version information available" >&2
fi
