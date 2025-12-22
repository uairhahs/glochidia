#!/bin/sh
# Container build script for C/C++ and Rust projects
set -e
cd /src

# For CMake and autoconf to prefer static libraries
export LDFLAGS="-static"
# GCC 15 defaults to C23 which makes () mean (void), conflicting with (const char *)
# We force gnu11 to restore old behavior where () means unspecified arguments
export CFLAGS="-static -D_GNU_SOURCE -std=gnu11"
export CXXFLAGS="-static"

if echo "${ARTIFACT_NAME}" | grep -q "edit"; then
	# Update and install build tools
	apt-get update && apt-get install -y build-essential libicu-dev git pkg-config

	# Inside your build script logic:
	unset LDFLAGS CFLAGS CXXFLAGS
	export RUSTC_BOOTSTRAP=1
	export EDIT_CFG_ICUUC_SONAME=libicuuc.so.73
	export EDIT_CFG_ICUI18N_SONAME=libicui18n.so.73
	export EDIT_CFG_ICU_RENAMING_VERSION=73
	export EDIT_CFG_ICU_CPP_EXPORTS=false

	# Build natively for glibc
	export TARGET="x86_64-unknown-linux-gnu"
else
	export TARGET="x86_64-unknown-linux-musl"
	# Install build dependencies
	echo "Installing build tools..."
	apk add --no-cache build-base wget curl git autoconf automake libtool pkgconfig gawk cmake linux-headers
fi

# Run build command (passed from host)
echo "Starting build..."

eval "${BUILD_COMMAND}"

# Find and prepare artifact
echo "Finding artifact..."
ARTIFACT=""

# Special handling for ble.sh - use the build output, not wrapper
if [ "${ARTIFACT_NAME}" = "ble.sh" ] && [ -f "out/ble.sh" ]; then
	ARTIFACT="out/ble.sh"
else
	# Search strategy: look for executables with preference order (generic build systems first)
	SEARCH_DIRS=". bin out build target/release target/${TARGET}/release"

	for dir in ${SEARCH_DIRS}; do
		if [ -d "${dir}" ]; then
			# First try: exact name match
			if [ -f "${dir}/${ARTIFACT_NAME}" ] && [ -x "${dir}/${ARTIFACT_NAME}" ]; then
				ARTIFACT="${dir}/${ARTIFACT_NAME}"
				break
			fi

			# Second try: name with common extensions
			for ext in "" ".sh" ".bin"; do
				if [ -f "${dir}/${ARTIFACT_NAME}${ext}" ] && [ -x "${dir}/${ARTIFACT_NAME}${ext}" ]; then
					ARTIFACT="${dir}/${ARTIFACT_NAME}${ext}"
					break 2
				fi
			done
		fi
	done

	# If exact match not found, try partial matches
	if [ -z "${ARTIFACT}" ]; then
		for dir in ${SEARCH_DIRS}; do
			if [ -d "${dir}" ]; then
				# Third try: find executable that contains the artifact name
				FOUND=$(find "${dir}" -maxdepth 2 -type f -executable -name "*${ARTIFACT_NAME}*" 2>/dev/null | head -1)
				if [ -n "${FOUND}" ]; then
					ARTIFACT="${FOUND}"
					break
				fi
			fi
		done
	fi

	# Last resort: find any reasonable executable
	if [ -z "${ARTIFACT}" ]; then
		for dir in ${SEARCH_DIRS}; do
			if [ -d "${dir}" ]; then
				# Find any executable (prefer non-test, non-example binaries)
				FOUND=$(find "${dir}" -maxdepth 2 -type f \( -executable -o -name "*.sh" \) ! -name "*test*" ! -name "*example*" ! -name "*demo*" ! -name "*example*" 2>/dev/null | head -1)
				if [ -n "${FOUND}" ]; then
					ARTIFACT="${FOUND}"
					break
				fi
			fi
		done
	fi
fi

if [ -z "${ARTIFACT}" ]; then
	echo "Error: No executable artifact found"
	echo "Searched for: ${ARTIFACT_NAME} (and variants) in: ${SEARCH_DIRS}"
	exit 1
fi

# Strip and copy to output
if file "${ARTIFACT}" | grep -q "ELF"; then
	strip "${ARTIFACT}" 2>/dev/null || true
fi
# Always rename to match expected ARTIFACT_NAME
cp "${ARTIFACT}" "/output/${ARTIFACT_NAME}"
echo "Artifact prepared: ${ARTIFACT} -> /output/${ARTIFACT_NAME}"
