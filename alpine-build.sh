#!/bin/sh
# Alpine build script for C/C++ and Rust projects
set -e
cd /src

# Install build dependencies
echo "Installing build tools..."
apk add --no-cache build-base wget curl git autoconf automake libtool pkgconfig gawk cmake linux-headers

# Run build command (passed from host)
echo "Starting build..."
# For CMake and autoconf to prefer static libraries
export LDFLAGS="-static"
# GCC 15 defaults to C23 which makes () mean (void), conflicting with (const char *)
# We force gnu11 to restore old behavior where () means unspecified arguments
export CFLAGS="-static -D_GNU_SOURCE -std=gnu11"
export CXXFLAGS="-static"

eval "${BUILD_COMMAND}"

# Find and prepare artifact
echo "Finding artifact..."
if [ -f "${ARTIFACT_NAME}" ]; then
	ARTIFACT="${ARTIFACT_NAME}"
elif [ -f "out/${ARTIFACT_NAME}" ]; then
	ARTIFACT="out/${ARTIFACT_NAME}"
elif [ -f "build/${ARTIFACT_NAME}" ]; then
	ARTIFACT="build/${ARTIFACT_NAME}"
elif [ -f "${ARTIFACT_NAME}.sh" ]; then
	ARTIFACT="${ARTIFACT_NAME}.sh"
elif [ -f "out/${ARTIFACT_NAME}.sh" ]; then
	ARTIFACT="out/${ARTIFACT_NAME}.sh"
elif [ -f "target/release/${ARTIFACT_NAME}" ]; then
	ARTIFACT="target/release/${ARTIFACT_NAME}"
elif [ -f "target/x86_64-unknown-linux-musl/release/${ARTIFACT_NAME}" ]; then
	ARTIFACT="target/x86_64-unknown-linux-musl/release/${ARTIFACT_NAME}"
elif [ -f "target/release/edit" ]; then
	# For cargo builds, try 'edit' as fallback
	ARTIFACT="target/release/edit"
else
	echo "Error: Artifact not found"
	echo "Searched in: ., out/, build/, target/release/"
	exit 1
fi

# Strip and copy to output
if file "${ARTIFACT}" | grep -q "ELF"; then
	strip "${ARTIFACT}" 2>/dev/null || true
fi
# Copy with the artifact name, or rename to match ARTIFACT_NAME if different
if [ "$(basename "${ARTIFACT}")" != "${ARTIFACT_NAME}" ]; then
	cp "${ARTIFACT}" "/output/${ARTIFACT_NAME}"
	echo "Artifact prepared: ${ARTIFACT} -> /output/${ARTIFACT_NAME}"
else
	cp "${ARTIFACT}" /output/
	echo "Artifact prepared: ${ARTIFACT}"
fi
