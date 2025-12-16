#!/bin/bash
# Native Alpine container build and deploy to embedded Linux target
# Usage: grow_glochidium.sh <repo_url> <binary_name> [build_command]

set -e

# ============ PARAMETERS ============
REPO_URL="${1:?Error: Repository or tarball URL required. Usage: grow_glochidium.sh <repo_or_tar_url> <binary_name> [build_command]}"
BINARY_NAME="${2:?Error: Binary name required. Usage: grow_glochidium.sh <repo_or_tar_url> <binary_name> [build_command]}"
BUILD_COMMAND="${3:-}"
BUILD_DIR="/tmp/glochidia_build_$$"
PROJECT_DIR="$BUILD_DIR/project"
IS_TARBALL=false
TARBALL_FILE=""
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"

# ============ CONFIGURATION ============
# Check if deployment variables are set, prompt if not
if [ -z "$DEPLOY_USER" ]; then
    read -p "Enter DEPLOY_USER: " DEPLOY_USER
    [ -z "$DEPLOY_USER" ] && { echo "Error: DEPLOY_USER is required"; exit 1; }
fi

# Verify SSH key setup before proceeding
verify_ssh_setup() {
    local user="$1"
    local host="$2"
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$user@$host" "echo OK" &>/dev/null; then
        echo "Error: Cannot connect to $user@$host using SSH keys"
        echo "Please set up SSH key authentication:"
        echo "  1. Generate keys: ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N \"\""
        echo "  2. Copy to device: ssh-copy-id -i ~/.ssh/id_rsa.pub $user@$host"
        return 1
    fi
    return 0
}

if [ -z "$DEPLOY_HOST" ]; then
    read -p "Enter DEPLOY_HOST: " DEPLOY_HOST
    [ -z "$DEPLOY_HOST" ] && { echo "Error: DEPLOY_HOST is required"; exit 1; }
fi

if [ -z "$DEPLOY_PATH" ]; then
    read -p "Enter DEPLOY_PATH: " DEPLOY_PATH
    [ -z "$DEPLOY_PATH" ] && { echo "Error: DEPLOY_PATH is required"; exit 1; }
fi

# Verify SSH connectivity before proceeding
echo "Verifying SSH connectivity..."
if ! verify_ssh_setup "$DEPLOY_USER" "$DEPLOY_HOST"; then
    exit 1
fi
echo "SSH connectivity verified"
echo

# ============ PIPELINE ============

echo "--- Starting Native Alpine Build & Deployment Pipeline ---"
echo "Source: $REPO_URL"
echo "Binary: $BINARY_NAME"
echo "Target: $DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_PATH"
echo

# 1. Fetch Source
mkdir -p "$BUILD_DIR"

if [[ "$REPO_URL" =~ \.tar\.(gz|xz|bz2)$ || "$REPO_URL" =~ \.tgz$ ]]; then
    IS_TARBALL=true
    echo "1. Downloading tarball..."
    TARBALL_FILE="$BUILD_DIR/$(basename "$REPO_URL")"
    wget -q "$REPO_URL" -O "$TARBALL_FILE"
    echo "Tarball downloaded: $TARBALL_FILE"
    echo "Extracting..."
    tar xf "$TARBALL_FILE" -C "$BUILD_DIR"
    TOP_DIR=$(tar tf "$TARBALL_FILE" | head -1 | cut -d/ -f1)
    if [ -z "$TOP_DIR" ] || [ ! -d "$BUILD_DIR/$TOP_DIR" ]; then
        echo "Error: Could not determine top-level directory from tarball"
        exit 1
    fi
    PROJECT_DIR="$BUILD_DIR/$TOP_DIR"
    echo "Source extracted to $PROJECT_DIR"
else
    echo "1. Cloning repository..."
    git clone "$REPO_URL" "$PROJECT_DIR" 2>&1 | grep -E "(Cloning|done)" || true
    echo "Repository cloned to $PROJECT_DIR"
    if [ ! -d "$PROJECT_DIR" ]; then
        echo "Error: Project directory was not created at $PROJECT_DIR"
        exit 1
    fi
    echo "Verified: $PROJECT_DIR exists ($(ls -la "$PROJECT_DIR" | wc -l) entries)"
fi

# 2. Detect build system if not specified
echo "2. Preparing build environment..."
if [ -z "$BUILD_COMMAND" ]; then
    if [ -f "$PROJECT_DIR/Makefile" ] || [ -f "$PROJECT_DIR/makefile" ]; then
        BUILD_COMMAND="make -j\$(nproc)"
    elif [ -f "$PROJECT_DIR/build.sh" ]; then
        BUILD_COMMAND="bash build.sh"
    elif [ -f "$PROJECT_DIR/CMakeLists.txt" ]; then
        BUILD_COMMAND="mkdir -p build && cd build && cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF .. && make -j\$(nproc)"
    else
        echo "Error: Could not detect build system (Makefile, build.sh, or CMakeLists.txt not found)"
        echo "Provide build command as 3rd argument: grow_glochidium.sh <url> <binary> '<build_cmd>'"
        exit 1
    fi
fi
echo "Build command: $BUILD_COMMAND"

# 3. Build in container
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use Debian for Rust/cargo builds (proc-macros need gnu host), Alpine for everything else
if echo "$BUILD_COMMAND" | grep -q "cargo"; then
    echo "3. Building Rust project in Debian container (cross-compile to musl)..."
    BUILD_SCRIPT="$SCRIPT_DIR/debian-build.sh"
    CONTAINER_IMAGE="debian:bookworm-slim"
    SCRIPT_NAME="debian-build.sh"
else
    echo "3. Building in Alpine container..."
    BUILD_SCRIPT="$SCRIPT_DIR/alpine-build.sh"
    CONTAINER_IMAGE="alpine:latest"
    SCRIPT_NAME="alpine-build.sh"
fi

if [ ! -f "$BUILD_SCRIPT" ]; then
    echo "Error: $SCRIPT_NAME not found in $SCRIPT_DIR"
    exit 1
fi

# Ensure output directory exists before running container
mkdir -p "$BUILD_DIR"

# Run build in container
$CONTAINER_RUNTIME run --rm \
    -v "$PROJECT_DIR":/src \
    -v "$BUILD_DIR":/output \
    -v "$BUILD_SCRIPT":/$SCRIPT_NAME:ro \
    -e BUILD_COMMAND="$BUILD_COMMAND" \
    -e ARTIFACT_NAME="$BINARY_NAME" \
    "$CONTAINER_IMAGE" \
    sh /$SCRIPT_NAME

echo "Build complete"

# 4. Verify Artifact
echo "4. Verifying artifact..."

# Extract artifact from build dir
ARTIFACT_PATH=""
if [ -f "$BUILD_DIR/$BINARY_NAME" ]; then
    ARTIFACT_PATH="$BUILD_DIR/$BINARY_NAME"
elif [ -f "$BUILD_DIR/$BINARY_NAME.sh" ]; then
    ARTIFACT_PATH="$BUILD_DIR/$BINARY_NAME.sh"
else
    # Fallback: search for any executable file in build dir (for cases where binary name differs from build output)
    ARTIFACT_PATH=$(find "$BUILD_DIR" -maxdepth 1 -type f \( -executable -o -name "*.sh" \) 2>/dev/null | head -1)
fi

if [ -z "$ARTIFACT_PATH" ]; then
    echo "Error: Artifact '$BINARY_NAME' not found after compilation"
    echo "Searched: $BUILD_DIR/$BINARY_NAME, $BUILD_DIR/$BINARY_NAME.sh"
    echo "Available files in $BUILD_DIR:"
    ls -la "$BUILD_DIR" || true
    exit 1
fi

# Check if it's a binary executable or script
if file "$ARTIFACT_PATH" | grep -q "ELF"; then
    echo "Artifact '$ARTIFACT_PATH' verified as ELF binary (musl/static)"
elif file "$ARTIFACT_PATH" | grep -q "text"; then
    echo "Artifact '$ARTIFACT_PATH' verified as shell script"
    if [ ! -x "$ARTIFACT_PATH" ]; then
        chmod +x "$ARTIFACT_PATH"
        echo "Made artifact executable"
    fi
else
    echo "Artifact '$ARTIFACT_PATH' found ($(file "$ARTIFACT_PATH" | cut -d: -f2-))"
fi

# 5. Deploy via SSH/rsync
echo "5. Deploying binary to remote device..."
if [ -z "$DEPLOY_USER" ] || [ -z "$DEPLOY_HOST" ] || [ -z "$DEPLOY_PATH" ]; then
    echo "Error: DEPLOY_USER, DEPLOY_HOST, and DEPLOY_PATH must be configured"
    exit 1
fi

# Create deployment directory on remote device
echo "Creating deployment directory..."
ssh "$DEPLOY_USER@$DEPLOY_HOST" "mkdir -p '$DEPLOY_PATH'" || {
    echo "Error: Failed to create deployment directory on remote device"
    exit 1
}

rsync -av --progress "$ARTIFACT_PATH" "$DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_PATH/" || {
    echo "Deployment failed"
    exit 1
}

DEPLOYED_NAME=$(basename "$ARTIFACT_PATH")
echo "Deployment complete: $DEPLOYED_NAME deployed to $DEPLOY_HOST:$DEPLOY_PATH"
echo

# 6. Cleanup
echo "6. Cleaning up build directory..."
rm -rf "$BUILD_DIR"
echo "Build directory removed"

echo
echo "--- Pipeline Complete ---"
