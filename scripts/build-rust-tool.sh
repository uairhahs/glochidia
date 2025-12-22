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
TARGET="${8:-x86_64-unknown-linux-musl}"

if [[ -z ${TOOL_NAME} ]] || [[ -z ${SOURCE_URL} ]]; then
	echo "Usage: $0 <tool_name> <source_url> [working_dir] [build_cmd] [binary_name] [fetched_version] [repo_version] [target]"
	exit 1
fi

echo "Building ${TOOL_NAME} with target ${TARGET}..."

# Install target if not musl
if [[ ${TARGET} != "x86_64-unknown-linux-musl" ]]; then
	rustup target add "${TARGET}"
fi

if [[ -n ${WORKING_DIR} ]] && [[ ${WORKING_DIR} != "" ]]; then
	# Build from local working directory
	cd "${WORKING_DIR}"
	cargo build --release --target "${TARGET}"
	strip "target/${TARGET}/release/${TOOL_NAME}"
	cp "target/${TARGET}/release/${TOOL_NAME}" "../${TOOL_NAME}-bin"

	# Extract version from built binary
	VERSION_OUTPUT=$(target/"${TARGET}"/release/"${TOOL_NAME}" --version 2>&1 || echo "")
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

	# Use fetched version or clone default branch
	if [[ -n ${FETCHED_VERSION} ]] && [[ ${FETCHED_VERSION} != "unknown" ]]; then
		git clone --depth 1 --branch "${FETCHED_VERSION}" "${SOURCE_URL}" "${BUILD_DIR}"
	else
		git clone --depth 1 "${SOURCE_URL}" "${BUILD_DIR}"
	fi
	cd "${BUILD_DIR}"

	# Use provided build command or default Rust build
	if [[ -n ${BUILD_CMD} ]]; then
		eval "${BUILD_CMD}"
	else
		cargo build --release --target "${TARGET}"
	fi

	# Find and copy binary
	BINARY_NAME="${BINARY_NAME:-${TOOL_NAME}}"
	TARGET_PATH="target/${TARGET}/release/${BINARY_NAME}"
	echo "Looking for binary: ${TARGET_PATH}"
	ls -la "target/${TARGET}/release/" || true

	if [[ -f ${TARGET_PATH} ]]; then
		strip "${TARGET_PATH}"

		# Extract version from built binary
		VERSION_OUTPUT=$("${TARGET_PATH}" --version 2>&1 || echo "")
		VERSION=$(echo "${VERSION_OUTPUT}" | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' | head -n1)

		if [[ -z ${VERSION} ]]; then
			VERSION=$(echo "${VERSION_OUTPUT}" | grep -o -E "([0-9]+\.?)+[0-9]+" | head -1)
		fi

		VERSION=${VERSION#v}
		echo "${VERSION:-${FETCHED_VERSION}-${REPO_VERSION}}" >"${TOOL_NAME}.version"
		echo "Version extracted for ${TOOL_NAME}: ${VERSION:-${FETCHED_VERSION}}"
		cp "${TARGET_PATH}" "${TOOL_NAME}-bin"
	else
		echo "Error: Binary not found at expected path"
		exit 1
	fi
else
	echo "Error: Unsupported source URL format"
	exit 1
fi
