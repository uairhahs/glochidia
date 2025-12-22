#!/bin/bash
# Native Alpine container build and deploy to embedded Linux target
# Usage: grow_glochidium.sh <repo_url> <binary_name> [build_command]

set -e

# ============ PARAMETERS ============
REPO_URL="${1:?Error: Repository or tarball URL required. Usage: grow_glochidium.sh <repo_or_tar_url> <binary_name> [build_command]}"
BINARY_NAME="${2:?Error: Binary name required. Usage: grow_glochidium.sh <repo_or_tar_url> <binary_name> [build_command]}"
BUILD_COMMAND="${3-}"
BUILD_DIR="/tmp/glochidium_build_$$"
PROJECT_DIR="${BUILD_DIR}/project"
TARBALL_FILE=""
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"

# ============ CONFIGURATION ============
# Check if deployment variables are set, prompt if not
if [[ -z ${DEPLOY_USER} ]]; then
	read -rp "Enter DEPLOY_USER: " DEPLOY_USER
	[[ -z ${DEPLOY_USER} ]] && {
		echo "Error: DEPLOY_USER is required"
		exit 1
	}
fi

# Verify SSH key setup before proceeding
verify_ssh_setup() {
	local user="${1}"
	local host="${2}"
	if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "${user}@${host}" "echo OK" &>/dev/null; then
		echo "Error: Cannot connect to ${user}@${host} using SSH keys"
		echo "Please set up SSH key authentication:"
		echo '  1. Generate keys: ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""'
		echo "  2. Copy to device: ssh-copy-id -i ~/.ssh/id_rsa.pub ${user}@${host}"
		return 1
	fi
	return 0
}

if [[ -z ${DEPLOY_HOST} ]]; then
	read -rp "Enter DEPLOY_HOST: " DEPLOY_HOST
	[[ -z ${DEPLOY_HOST} ]] && {
		echo "Error: DEPLOY_HOST is required"
		exit 1
	}
fi

if [[ -z ${DEPLOY_PATH} ]]; then
	read -rp "Enter DEPLOY_PATH: " DEPLOY_PATH
	[[ -z ${DEPLOY_PATH} ]] && {
		echo "Error: DEPLOY_PATH is required"
		exit 1
	}
fi

# Verify SSH connectivity before proceeding (only for SSH deployment)
DEPLOY_METHOD="${DEPLOY_METHOD:-ssh}"
if [[ ${DEPLOY_METHOD} == "ssh" ]]; then
	echo "Verifying SSH connectivity..."
	verify_ssh_setup "${DEPLOY_USER}" "${DEPLOY_HOST}"
	echo "SSH connectivity verified"
fi
echo

# ============ PIPELINE ============

echo "--- Starting Native Alpine Build & Deployment Pipeline ---"
echo "Source: ${REPO_URL}"
echo "Binary: ${BINARY_NAME}"
echo "Target: ${DEPLOY_USER}@${DEPLOY_HOST}:${DEPLOY_PATH}"
echo

# 1. Fetch Source
mkdir -p "${BUILD_DIR}"

if [[ ${REPO_URL} =~ \.tar\.(gz|xz|bz2)$ || ${REPO_URL} =~ \.tgz$ ]]; then
	echo "1. Downloading tarball..."
	TARBALL_FILE="${BUILD_DIR}/$(basename "${REPO_URL}")"
	wget -q "${REPO_URL}" -O "${TARBALL_FILE}"
	echo "Tarball downloaded: ${TARBALL_FILE}"
	echo "Extracting..."
	tar xf "${TARBALL_FILE}" -C "${BUILD_DIR}"
	TOP_DIR=$(tar tf "${TARBALL_FILE}" | head -1) || true
	TOP_DIR=$(echo "${TOP_DIR}" | cut -d/ -f1)
	if [[ -z ${TOP_DIR} ]] || [[ ! -d "${BUILD_DIR}/${TOP_DIR}" ]]; then
		echo "Error: Could not determine top-level directory from tarball"
		exit 1
	fi
	PROJECT_DIR="${BUILD_DIR}/${TOP_DIR}"
	echo "Source extracted to ${PROJECT_DIR}"
else
	echo "1. Cloning repository..."
	git clone "${REPO_URL}" "${PROJECT_DIR}" 2>&1 | grep -E "(Cloning|done)" || true
	echo "Repository cloned to ${PROJECT_DIR}"
	if [[ ! -d ${PROJECT_DIR} ]]; then
		echo "Error: Project directory was not created at ${PROJECT_DIR}"
		exit 1
	fi
	entry_count=$(find "${PROJECT_DIR}" -maxdepth 0 | wc -l) || true
	echo "Verified: ${PROJECT_DIR} exists (${entry_count} entries)"
fi

# 2. Detect build system if not specified
echo "2. Preparing build environment..."
if [[ -z ${BUILD_COMMAND} ]]; then
	if [[ -f "${PROJECT_DIR}/Makefile" ]] || [[ -f "${PROJECT_DIR}/makefile" ]]; then
		BUILD_COMMAND="make -j$(nproc)"
	elif [[ -f "${PROJECT_DIR}/build.sh" ]]; then
		BUILD_COMMAND="bash build.sh"
	elif [[ -f "${PROJECT_DIR}/CMakeLists.txt" ]]; then
		BUILD_COMMAND="mkdir -p build && cd build && cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF .. && make -j$(nproc)"
	else
		echo "Error: Could not detect build system (Makefile, build.sh, or CMakeLists.txt not found)"
		echo "Provide build command as 3rd argument: grow_glochidium.sh <url> <binary> '<build_cmd>'"
		exit 1
	fi
fi
echo "Build command: ${BUILD_COMMAND}"

# 3. Build in container
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use Rust Alpine for Rust/cargo builds, Standard Alpine for everything else
if echo "${BUILD_COMMAND}" | grep -q "cargo"; then
	if echo "${BINARY_NAME}" | grep -q "edit"; then
		echo "Detected msedit: Switching to glibc-based container for ZimaOS compatibility..."
		CONTAINER_IMAGE="rust:slim-bookworm"
	else
		echo "3. Building Rust project in rust:alpine container..."
		CONTAINER_IMAGE="rust:alpine"
	fi
	BUILD_SCRIPT="${SCRIPT_DIR}/container-build.sh"
	SCRIPT_NAME="container-build.sh"
else
	echo "3. Building in Alpine container..."
	BUILD_SCRIPT="${SCRIPT_DIR}/container-build.sh"
	CONTAINER_IMAGE="alpine:latest"
	SCRIPT_NAME="container-build.sh"
fi

if [[ ! -f ${BUILD_SCRIPT} ]]; then
	echo "Error: ${SCRIPT_NAME} not found in ${SCRIPT_DIR}"
	exit 1
fi

# Ensure output directory exists before running container
mkdir -p "${BUILD_DIR}"

# Run build in container
${CONTAINER_RUNTIME} run --rm \
	-v "${PROJECT_DIR}":/src \
	-v "${BUILD_DIR}":/output \
	-v "${BUILD_SCRIPT}":/"${SCRIPT_NAME}":ro \
	-e BUILD_COMMAND="${BUILD_COMMAND}" \
	-e ARTIFACT_NAME="${BINARY_NAME}" \
	-e CONTAINER_IMAGE="${CONTAINER_IMAGE}" \
	"${CONTAINER_IMAGE}" \
	sh /"${SCRIPT_NAME}"

echo "Build complete"

# 4. Verify Artifact
echo "4. Verifying artifact..."

# Extract artifact from build dir
ARTIFACT_PATH=""
if [[ -f "${BUILD_DIR}/${BINARY_NAME}" ]]; then
	ARTIFACT_PATH="${BUILD_DIR}/${BINARY_NAME}"
elif [[ -f "${BUILD_DIR}/${BINARY_NAME}.sh" ]]; then
	ARTIFACT_PATH="${BUILD_DIR}/${BINARY_NAME}.sh"
else
	# Fallback: search for any executable file in build dir (for cases where binary name differs from build output)
	ARTIFACT_PATH=$(find "${BUILD_DIR}" -maxdepth 1 -type f \( -executable -o -name "*.sh" \) 2>/dev/null | head -1) || true
fi

if [[ -z ${ARTIFACT_PATH} ]]; then
	echo "Error: Artifact '${BINARY_NAME}' not found after compilation"
	echo "Searched: ${BUILD_DIR}/${BINARY_NAME}, ${BUILD_DIR}/${BINARY_NAME}.sh"
	echo "Available files in ${BUILD_DIR}:"
	ls -la "${BUILD_DIR}" || true
	exit 1
fi

# Check if it's a binary executable or script
file_output=$(file "${ARTIFACT_PATH}")
if echo "${file_output}" | grep -q "ELF"; then
	echo "Artifact '${ARTIFACT_PATH}' verified as ELF binary (musl/static)"
elif echo "${file_output}" | grep -q "text"; then
	echo "Artifact '${ARTIFACT_PATH}' verified as shell script"
	if [[ ! -x ${ARTIFACT_PATH} ]]; then
		chmod +x "${ARTIFACT_PATH}"
		echo "Made artifact executable"
	fi
else
	file_output=$(file "${ARTIFACT_PATH}" || true)
	file_output=$(echo "${file_output}" | cut -d: -f2-)
	echo "Artifact '${ARTIFACT_PATH}' found (${file_output})"
fi

# 5. Deploy to GitHub Release
echo "5. Publishing binary to GitHub Releases..."

# Rename artifact to requested name if different
ARTIFACT_BASENAME=$(basename "${ARTIFACT_PATH}")
if [[ ${ARTIFACT_BASENAME} != "${BINARY_NAME}" ]]; then
	echo "Renaming artifact: ${ARTIFACT_BASENAME} -> ${BINARY_NAME}"
	mv "${ARTIFACT_PATH}" "${BUILD_DIR}/${BINARY_NAME}"
	ARTIFACT_PATH="${BUILD_DIR}/${BINARY_NAME}"
fi

# Deployment method selection
DEPLOY_METHOD="${DEPLOY_METHOD:-ssh}"

if [[ ${DEPLOY_METHOD} == "ssh" ]]; then
	# SSH/rsync deployment (default local method)
	echo "Using SSH deployment..."

	if [[ -z ${DEPLOY_USER} ]] || [[ -z ${DEPLOY_HOST} ]] || [[ -z ${DEPLOY_PATH} ]]; then
		echo "Error: DEPLOY_USER, DEPLOY_HOST, and DEPLOY_PATH must be configured"
		exit 1
	fi

	echo "Creating deployment directory..."
	if ssh "${DEPLOY_USER}@${DEPLOY_HOST}" "mkdir -p \"${DEPLOY_PATH}\"" &&
		ssh "${DEPLOY_USER}@${DEPLOY_HOST}" "test -d \"${DEPLOY_PATH}\""; then
		:
	else
		echo "Error: Failed to create deployment directory on remote device"
		echo "Path attempted: ${DEPLOY_PATH}"
		exit 1
	fi

	rsync -av --progress "${ARTIFACT_PATH}" "${DEPLOY_USER}@${DEPLOY_HOST}:${DEPLOY_PATH}/" || {
		echo "SSH deployment failed"
		exit 1
	}

	echo "Deployment complete: ${BINARY_NAME} deployed to ${DEPLOY_HOST}:${DEPLOY_PATH}"
elif [[ ${DEPLOY_METHOD} == "ci-cd" ]] || [[ ${DEPLOY_METHOD} == "none" ]]; then
	echo "Skipping deployment (DEPLOY_METHOD=${DEPLOY_METHOD})"
	echo "Artifact ready at: ${ARTIFACT_PATH}"
else
	echo "Error: Unknown DEPLOY_METHOD '${DEPLOY_METHOD}'. Use 'ssh', 'ci-cd', or 'none'"
	exit 1
fi

echo

# 6. Cleanup
if [[ ${DEPLOY_METHOD} == "ci-cd" ]] || [[ ${DEPLOY_METHOD} == "none" ]]; then
	echo "6. Skipping cleanup (artifact preservation for CI/CD)"
	echo "Build directory preserved: ${BUILD_DIR}"
else
	echo "6. Cleaning up build directory..."
	rm -rf "${BUILD_DIR}"
	echo "Build directory removed"
fi

echo
echo "--- Pipeline Complete ---"
