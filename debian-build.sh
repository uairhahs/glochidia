#!/bin/sh
# Debian-based build script for Rust projects that require proc-macros
# Uses gnu host (for proc-macros) but cross-compiles to musl target (for static binary)
set -e
cd /src

# Install build dependencies
echo "Installing build tools..."
apt-get update -qq
apt-get install -y -qq build-essential wget curl git autoconf automake libtool pkg-config cmake gawk musl-tools >/dev/null

# Install Rust with gnu host, then add musl target
echo "Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
export PATH="/root/.cargo/bin:${PATH}"
rustup target add x86_64-unknown-linux-musl
rustup component add rust-src --toolchain nightly-x86_64-unknown-linux-gnu

# Run build command (passed from host)
echo "Starting build..."
export RUSTC_BOOTSTRAP=1
# Use musl-gcc as the linker for the musl target
export CC_x86_64_unknown_linux_musl=musl-gcc
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=musl-gcc
# Force fully static binary: crt-static links C runtime statically, relocation-model=static disables PIE
export RUSTFLAGS="-C target-feature=+crt-static -C relocation-model=static"
export LDFLAGS="-static"

# If it's a cargo build, add the musl target
if echo "${BUILD_COMMAND}" | grep -q "cargo build"; then
	# Strip any existing target and add musl
	BUILD_COMMAND=$(echo "${BUILD_COMMAND}" | sed 's/ --target [^ ]*//')
	BUILD_COMMAND="${BUILD_COMMAND} --target x86_64-unknown-linux-musl"
fi

eval "${BUILD_COMMAND}"

# Find and prepare artifact
echo "Finding artifact..."
ARTIFACT=""

# Search paths in order of priority
SEARCH_PATHS="
    ${ARTIFACT_NAME}
    out/${ARTIFACT_NAME}
    build/${ARTIFACT_NAME}
    target/x86_64-unknown-linux-musl/release/${ARTIFACT_NAME}
    target/release/${ARTIFACT_NAME}
"

for path in ${SEARCH_PATHS}; do
	if [ -f "${path}" ]; then
		ARTIFACT="${path}"
		break
	fi
done

# If not found, search for any executable in common cargo output directories
if [ -z "${ARTIFACT}" ]; then
	echo "Artifact '${ARTIFACT_NAME}' not found by name, searching for executables..."
	# First try musl target directory
	if [ -d "target/x86_64-unknown-linux-musl/release" ]; then
		ARTIFACT=$(find "target/x86_64-unknown-linux-musl/release" -maxdepth 1 -type f -executable ! -name "*.d" ! -name "*.rlib" ! -name "*.rmeta" ! -name "*.so" 2>/dev/null | head -1)
	fi
	# Fall back to regular release directory
	if [ -z "${ARTIFACT}" ] && [ -d "target/release" ]; then
		ARTIFACT=$(find "target/release" -maxdepth 1 -type f -executable ! -name "*.d" ! -name "*.rlib" ! -name "*.rmeta" ! -name "*.so" 2>/dev/null | head -1)
	fi
fi

if [ -z "${ARTIFACT}" ]; then
	echo "Error: Artifact not found"
	echo "Searched in: ., out/, build/, target/x86_64-unknown-linux-musl/release/, target/release/"
	echo "Available files in target directories:"
	find target -type f -name "*" 2>/dev/null | grep -E "release/[^/]+$" | head -20 || true
	exit 1
fi

# Strip and copy to output
if file "${ARTIFACT}" | grep -q "ELF"; then
	strip "${ARTIFACT}" 2>/dev/null || true
fi
if [ "$(basename "${ARTIFACT}")" != "${ARTIFACT_NAME}" ]; then
	cp "${ARTIFACT}" "/output/${ARTIFACT_NAME}"
	echo "Artifact prepared: ${ARTIFACT} -> /output/${ARTIFACT_NAME}"
else
	cp "${ARTIFACT}" /output/
	echo "Artifact prepared: ${ARTIFACT}"
fi
