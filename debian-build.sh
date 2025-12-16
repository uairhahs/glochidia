#!/bin/sh
# Debian-based build script for Rust projects that require proc-macros
# Uses gnu host (for proc-macros) but cross-compiles to musl target (for static binary)
set -e
cd /src

# Install build dependencies
echo "Installing build tools..."
apt-get update -qq
apt-get install -y -qq build-essential wget curl git autoconf automake libtool pkg-config cmake gawk musl-tools > /dev/null

# Install Rust with gnu host, then add musl target
echo "Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
export PATH="/root/.cargo/bin:$PATH"
rustup target add x86_64-unknown-linux-musl

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
if echo "$BUILD_COMMAND" | grep -q "cargo build"; then
    # Strip any existing target and add musl
    BUILD_COMMAND=$(echo "$BUILD_COMMAND" | sed 's/ --target [^ ]*//')
    BUILD_COMMAND="$BUILD_COMMAND --target x86_64-unknown-linux-musl"
fi

eval "$BUILD_COMMAND"

# Find and prepare artifact
echo "Finding artifact..."
if [ -f "$ARTIFACT_NAME" ]; then
    ARTIFACT="$ARTIFACT_NAME"
elif [ -f "out/$ARTIFACT_NAME" ]; then
    ARTIFACT="out/$ARTIFACT_NAME"
elif [ -f "build/$ARTIFACT_NAME" ]; then
    ARTIFACT="build/$ARTIFACT_NAME"
elif [ -f "target/x86_64-unknown-linux-musl/release/$ARTIFACT_NAME" ]; then
    ARTIFACT="target/x86_64-unknown-linux-musl/release/$ARTIFACT_NAME"
elif [ -f "target/release/$ARTIFACT_NAME" ]; then
    ARTIFACT="target/release/$ARTIFACT_NAME"
else
    echo "Error: Artifact not found"
    echo "Searched in: ., out/, build/, target/x86_64-unknown-linux-musl/release/, target/release/"
    find target -name "$ARTIFACT_NAME" 2>/dev/null || true
    exit 1
fi

# Strip and copy to output
if file "$ARTIFACT" | grep -q "ELF"; then
    strip "$ARTIFACT" 2>/dev/null || true
fi
if [ "$(basename "$ARTIFACT")" != "$ARTIFACT_NAME" ]; then
    cp "$ARTIFACT" "/output/$ARTIFACT_NAME"
    echo "Artifact prepared: $ARTIFACT -> /output/$ARTIFACT_NAME"
else
    cp "$ARTIFACT" /output/
    echo "Artifact prepared: $ARTIFACT"
fi
