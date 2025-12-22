#!/bin/bash
# build-c-tool.sh - Build C/C++ tools using grow_glochidium.sh
set -euo pipefail

TOOL_NAME="${1-}"
SOURCE_URL="${2-}"
BUILD_CMD="${3-}"
CONFIGURED_VERSION="${4-}"
FETCHED_VERSION="${5-}"

if [[ -z ${TOOL_NAME} ]] || [[ -z ${SOURCE_URL} ]]; then
	echo "Usage: $0 <tool_name> <source_url> [build_cmd] [configured_version] [fetched_version]"
	exit 1
fi

# Set up environment for grow_glochidium.sh
export CONTAINER_RUNTIME=podman
export DEPLOY_METHOD=ci-cd
export DEPLOY_USER=ci
export DEPLOY_HOST=localhost
export DEPLOY_PATH=/tmp/ci

echo "Building ${TOOL_NAME} using grow_glochidium.sh..."

# Run the build script and capture output to extract BUILD_DIR
OUTPUT=$(bash grow_glochidium.sh "${SOURCE_URL}" "${TOOL_NAME}" "${BUILD_CMD}" 2>&1)
echo "${OUTPUT}"

# Extract the actual BUILD_DIR from the script output
BUILD_DIR=$(echo "${OUTPUT}" | grep "Build directory preserved:" | sed 's/.*Build directory preserved: //')

if [[ -z ${BUILD_DIR} ]]; then
	echo "Error: Could not determine BUILD_DIR from script output"
	exit 1
fi

echo "Detected BUILD_DIR: ${BUILD_DIR}"

# Copy binary and extract version
if [[ -f "${BUILD_DIR}/${TOOL_NAME}" ]]; then
	cp "${BUILD_DIR}/${TOOL_NAME}" "./${TOOL_NAME}-bin"
	chmod +x "./${TOOL_NAME}-bin"
	VERSION=$(bash scripts/extract-binary-version.sh "./${TOOL_NAME}-bin" "${CONFIGURED_VERSION}")
	echo "Found binary: ${BUILD_DIR}/${TOOL_NAME}"
elif [[ -f "${BUILD_DIR}/${TOOL_NAME}.sh" ]]; then
	cp "${BUILD_DIR}/${TOOL_NAME}.sh" "./${TOOL_NAME}-bin"
	chmod +x "./${TOOL_NAME}-bin"
	VERSION=$(grep -o -E "([0-9]+\.?)+[0-9]+" "${BUILD_DIR}/${TOOL_NAME}.sh" | head -n1 | sed 's/^v//' || echo "")
	echo "Found shell script: ${BUILD_DIR}/${TOOL_NAME}.sh"
else
	echo "Error: Binary not found in ${BUILD_DIR}"
	echo "Contents of build directory:"
	ls -la "${BUILD_DIR}" || true
	exit 1
fi

echo "Extracted version: '${VERSION}'"

# Ensure version file is created with appropriate fallback
if [[ -z ${VERSION} ]]; then
	echo "No version extracted, using fallback"
	if [[ -n ${CONFIGURED_VERSION} ]]; then
		VERSION="${CONFIGURED_VERSION}"
		echo "Using configured version: ${VERSION}"
	else
		VERSION="${FETCHED_VERSION}"
		echo "Using fetched version: ${VERSION}"
	fi
fi

# Clean version and write to file
VERSION=$(echo "${VERSION}" | tr -d '\n\r' | xargs | sed 's/^v//' || echo "${VERSION}")
echo "${VERSION}" >"${TOOL_NAME}.version"
echo "Version for ${TOOL_NAME}: ${VERSION}"
echo "Build completed successfully"

# Ensure we exit with success
exit 0
