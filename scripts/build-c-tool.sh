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
echo "Contents of build directory:"
ls -la "${BUILD_DIR}" || true
echo "Looking for files matching pattern:"
find "${BUILD_DIR}" -name "*${TOOL_NAME}*" -type f || true

# Copy binary and extract version
if [[ -f "${BUILD_DIR}/${TOOL_NAME}" ]]; then
	cp "${BUILD_DIR}/${TOOL_NAME}" "./${TOOL_NAME}-bin"
	chmod +x "./${TOOL_NAME}-bin"
	VERSION=$(bash scripts/extract-binary-version.sh "./${TOOL_NAME}-bin" "${CONFIGURED_VERSION}")
	echo "Found binary: ${BUILD_DIR}/${TOOL_NAME}"
elif [[ ${TOOL_NAME} == "ble.sh" ]]; then
	# Special handling for ble.sh
	if [[ -d "${BUILD_DIR}/project/out" ]]; then
		echo "Found ble.sh build output: ${BUILD_DIR}/project/out"
		tar -czf "./${TOOL_NAME}-bin" -C "${BUILD_DIR}/project/out" .
		echo "Created ble.sh installation tarball"
		# Extract version using --version flag
		VERSION=$(cd "${BUILD_DIR}/project/out" && bash ble.sh --version 2>/dev/null | grep -o -E "([0-9]+\.?)+[0-9]+(-[a-zA-Z0-9+]+)?" | head -n1 || echo "")
		echo "Extracted version from ble.sh --version: '${VERSION}'"
	elif [[ -d "${BUILD_DIR}/out" ]]; then
		echo "Found ble.sh build output: ${BUILD_DIR}/out"
		tar -czf "./${TOOL_NAME}-bin" -C "${BUILD_DIR}/out" .
		echo "Created ble.sh installation tarball"
		VERSION=$(cd "${BUILD_DIR}/out" && bash ble.sh --version 2>/dev/null | grep -o -E "([0-9]+\.?)+[0-9]+(-[a-zA-Z0-9+]+)?" | head -n1 || echo "")
		echo "Extracted version from ble.sh --version: '${VERSION}'"
	else
		echo "Error: ble.sh build output not found in ${BUILD_DIR}"
		exit 1
	fi
elif [[ -f "${BUILD_DIR}/${TOOL_NAME}.sh" ]]; then
	cp "${BUILD_DIR}/${TOOL_NAME}.sh" "./${TOOL_NAME}-bin"
	chmod +x "./${TOOL_NAME}-bin"
	echo "Found shell script: ${BUILD_DIR}/${TOOL_NAME}.sh"
	echo "Attempting to extract version from shell script..."
	VERSION=$(grep -o -E "([0-9]+\.?)+[0-9]+" "${BUILD_DIR}/${TOOL_NAME}.sh" | head -n1 | sed 's/^v//' || echo "")
	echo "Extracted version from script: '${VERSION}'"
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
echo "Cleaning version: '${VERSION}'"
CLEANED_VERSION=$(echo "${VERSION}" | tr -d '\n\r' | xargs | sed 's/^v//' 2>/dev/null || echo "${VERSION}")
echo "Cleaned version: '${CLEANED_VERSION}'"
echo "${CLEANED_VERSION}" >"${TOOL_NAME}.version"
echo "Version for ${TOOL_NAME}: ${CLEANED_VERSION}"
echo "Build completed successfully"

# Ensure we exit with success
exit 0
