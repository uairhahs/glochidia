#!/bin/bash
# build-rust-tool.sh - Build Rust tools with version extraction
set -euo pipefail

TOOL_NAME="${1-}"
SOURCE_URL="${2-}"
WORKING_DIR="${3-}"
BUILD_CMD="${4-}"
BINARY_NAME="${5-}"
FETCHED_VERSION="${6-}"
REPO_VERSION="${7:-1.0.0}"

if [[ -z ${TOOL_NAME} ]] || [[ -z ${SOURCE_URL} ]]; then
	echo "Usage: $0 <tool_name> <source_url> [working_dir] [build_cmd] [binary_name] [fetched_version] [repo_version]"
	exit 1
fi

echo "Building ${TOOL_NAME}..."

if [[ -n ${WORKING_DIR} ]]; then
	# Build from local working directory
	cd "${WORKING_DIR}"
	cargo build --release
	strip "target/x86_64-unknown-linux-musl/release/${TOOL_NAME}"
	cp "target/x86_64-unknown-linux-musl/release/${TOOL_NAME}" "../${TOOL_NAME}-bin"

	# Extract version from built binary
	VERSION_OUTPUT=$(target/x86_64-unknown-linux-musl/release/"${TOOL_NAME}" --version 2>&1 || echo "")
	VERSION=$(echo "${VERSION_OUTPUT}" | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' | head -n1)

	if [[ -z ${VERSION} ]]; then
		VERSION=$(echo "${VERSION_OUTPUT}" | grep -o -E "([0-9]+\.?)+[0-9]+" | head -1)
	fi

	VERSION=${VERSION#v}
	echo "${VERSION:-${REPO_VERSION}}" >"../${TOOL_NAME}.version"
	echo "Version extracted for ${TOOL_NAME}: ${VERSION:-${REPO_VERSION}}"

elif [[ ${SOURCE_URL} == *"github.com"* ]]; then
	# Build external repos
	BUILD_DIR="/tmp/build_${TOOL_NAME}"
	git clone --depth 1 --branch "${FETCHED_VERSION}" "${SOURCE_URL}" "${BUILD_DIR}"
	cd "${BUILD_DIR}"

	# Use provided build command or default Rust build
	if [[ -n ${BUILD_CMD} ]]; then
		eval "${BUILD_CMD}"
	else
		cargo build --release
	fi

	# Find and copy binary
	BINARY_NAME="${BINARY_NAME:-${TOOL_NAME}}"
	if [[ -f "target/x86_64-unknown-linux-musl/release/${BINARY_NAME}" ]]; then
		strip "target/x86_64-unknown-linux-musl/release/${BINARY_NAME}"

		# Extract version from built binary
		VERSION_OUTPUT=$(target/x86_64-unknown-linux-musl/release/"${BINARY_NAME}" --version 2>&1 || echo "")
		VERSION=$(echo "${VERSION_OUTPUT}" | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' | head -n1)

		if [[ -z ${VERSION} ]]; then
			VERSION=$(echo "${VERSION_OUTPUT}" | grep -o -E "([0-9]+\.?)+[0-9]+" | head -1)
		fi

		VERSION=${VERSION#v}
		echo "${VERSION:-${FETCHED_VERSION}-${REPO_VERSION}}" >"${TOOL_NAME}.version"
		echo "Version extracted for ${TOOL_NAME}: ${VERSION:-${FETCHED_VERSION}}"
		cp "target/x86_64-unknown-linux-musl/release/${BINARY_NAME}" "${TOOL_NAME}-bin"
	else
		echo "Error: Binary not found at expected path"
		exit 1
	fi
else
	echo "Error: Unsupported source URL format"
	exit 1
fi
