#!/bin/bash
# Deploy binary to remote device via SSH/rsync
# Configuration: Set these variables before running

set -e

# ============ CONFIGURATION ============
DEPLOY_USER="${DEPLOY_USER:-your_username}"
DEPLOY_HOST="${DEPLOY_HOST:-your.device.ip}"
DEPLOY_PATH="${DEPLOY_PATH:-/path/to/destination}"
TOOLCHAIN_PREFIX="aarch64-buildroot-linux-gnu-"
BINARY_NAME="glochidia_app"
COMMIT_MESSAGE="${1:-Update binary}"

# ============ PIPELINE ============

echo "--- Starting Cross-Compilation & Deployment Pipeline ---"

# 1. Cross-Compile
echo "1. Cross-compiling for x86_64..."
make clean
make || { echo "Cross-compilation failed"; exit 1; }

# 2. Verify Binary
echo "2. Verifying binary..."
if [ ! -f "$BINARY_NAME" ]; then
    echo "Binary '$BINARY_NAME' not found after compilation"
    exit 1
fi
echo "Binary '$BINARY_NAME' built successfully"

# 3. Deploy via SSH/rsync
echo "3. Deploying binary to remote device..."
if [ -z "$DEPLOY_USER" ] || [ -z "$DEPLOY_HOST" ] || [ -z "$DEPLOY_PATH" ]; then
    echo "Error: DEPLOY_USER, DEPLOY_HOST, and DEPLOY_PATH must be configured"
    exit 1
fi

rsync -av --progress "$BINARY_NAME" "$DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_PATH/" || {
    echo "Deployment failed"
    exit 1
}

echo "Pipeline complete: Binary deployed to $DEPLOY_HOST:$DEPLOY_PATH"
