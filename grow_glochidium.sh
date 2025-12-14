#!/bin/bash
# Cross-compile and deploy a remote project to embedded Linux target
# Usage: grow_glochidium.sh <repo_url> <binary_name> [build_command]

set -e

# ============ PARAMETERS ============
REPO_URL="${1:?Error: Repository URL required. Usage: grow_glochidium.sh <repo_url> <binary_name> [build_command]}"
BINARY_NAME="${2:?Error: Binary name required. Usage: grow_glochidium.sh <repo_url> <binary_name> [build_command]}"
BUILD_COMMAND="${3:-}"

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
WRAPPER_SCRIPT="x86_64-linux-musl-gcc"

# ============ PIPELINE ============

echo "--- Starting Cross-Compilation & Deployment Pipeline ---"
echo "Repository: $REPO_URL"
echo "Binary: $BINARY_NAME"
echo "Target: $DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_PATH"
echo

# 1. Clone Repository
echo "1. Cloning repository..."
mkdir -p "$BUILD_DIR"
git clone "$REPO_URL" "$BUILD_DIR/project" 2>&1 | grep -E "(Cloning|done)" || true
cd "$BUILD_DIR/project"
echo "Repository cloned to $BUILD_DIR/project"

# 2. Copy Wrapper Script
echo "2. Setting up x86_64 musl cross-compiler..."
if command -v x86_64-linux-musl-gcc &> /dev/null; then
    # Wrapper is already in PATH, find it
    WRAPPER_PATH=$(which x86_64-linux-musl-gcc)
    cp "$WRAPPER_PATH" .
else
    echo "Error: x86_64-linux-musl-gcc wrapper not found in PATH"
    echo "Install it with: cp /path/to/x86_64-linux-musl-gcc ~/bin/"
    exit 1
fi
export PATH=".:$PATH"
echo "Wrapper script ready"

# 3. Cross-Compile
echo "3. Cross-compiling for x86_64..."

# Detect build system if not specified
if [ -z "$BUILD_COMMAND" ]; then
    if [ -f "Makefile" ] || [ -f "makefile" ]; then
        BUILD_COMMAND="make clean && make"
    elif [ -f "build.sh" ]; then
        BUILD_COMMAND="bash build.sh"
    elif [ -f "CMakeLists.txt" ]; then
        BUILD_COMMAND="mkdir -p build && cd build && cmake .. && make"
    else
        echo "Error: Could not detect build system (Makefile, build.sh, or CMakeLists.txt not found)"
        echo "Provide build command as 3rd argument: grow_glochidium.sh <url> <binary> '<build_cmd>'"
        exit 1
    fi
fi

echo "Using build command: $BUILD_COMMAND"
eval "$BUILD_COMMAND" || { echo "Build failed"; exit 1; }
echo "Build complete"

# 4. Verify Binary
echo "4. Verifying binary..."
if [ ! -f "$BINARY_NAME" ]; then
    echo "Error: Binary '$BINARY_NAME' not found after compilation"
    exit 1
fi
file "$BINARY_NAME" | grep -q "statically linked" && {
    echo "Binary '$BINARY_NAME' verified as statically linked"
} || {
    echo "Warning: Binary may not be statically linked"
    echo "Proceeding with deployment..."
    echo "Test binary on target device to confirm functionality after deployment"
}

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

rsync -av --progress "$BINARY_NAME" "$DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_PATH/" || {
    echo "Deployment failed"
    exit 1
}

echo "Deployment complete: $BINARY_NAME deployed to $DEPLOY_HOST:$DEPLOY_PATH"
echo

# 6. Cleanup
echo "6. Cleaning up build directory..."
cd /
rm -rf "$BUILD_DIR"
echo "Build directory removed"

echo
echo "--- Pipeline Complete ---"
