#!/usr/bin/env bash
# Generate manifest.json from built artifacts
set -euo pipefail

REPO_VERSION="1.0.0"
MANIFEST_FILE="${1:-manifest.json}"
ARTIFACTS_DIR="${2:-.}"
REPO_URL="${REPO_URL:-https://github.com/uairhahs/glochidia}"
RELEASE_TAG="${RELEASE_TAG:-latest}"

# Initialize manifest
cat >"${MANIFEST_FILE}" <<EOF
{
  "repo_version": "${REPO_VERSION}",
  "updated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "tools": {
EOF

first=true

# Function to add tool entry
add_tool() {
	local name="$1"
	local binary_path="$2"
	local version="$3"
	local description="$4"
	local build_type="$5"
	local license="$6"
	local source_url="$7"
	local source_sha256="${8-}"

	if [[ ! -f ${binary_path} ]]; then
		echo "Warning: Binary not found: ${binary_path}" >&2
		return
	fi

	local sha256
	local size
	sha256=$(sha256sum "${binary_path}" | awk '{print $1}')
	size=$(stat -c%s "${binary_path}")

	local download_url="${REPO_URL}/releases/download/${RELEASE_TAG}/${name}"

	if [[ ${first} == "false" ]]; then
		echo "," >>"${MANIFEST_FILE}"
	fi
	first=false

	cat >>"${MANIFEST_FILE}" <<EOF
    "${name}": {
      "version": "${version}",
      "description": "${description}",
      "url": "${download_url}",
      "sha256": "${sha256}",
      "size": ${size},
      "build_type": "${build_type}",
      "license": "${license}",
      "source_url": "${source_url}"$(if [[ -n ${source_sha256} ]]; then
		echo ","
		echo "      \"source_sha256\": \"${source_sha256}\""
	fi)
    }
EOF
}

# Add tools here (this will be populated by the build script)
# Example entries - these should match what grow_glochidium.sh builds:

# GNU Make
if [[ -f "${ARTIFACTS_DIR}/make" ]]; then
	add_tool "make" "${ARTIFACTS_DIR}/make" "4.4.1" "GNU Make build tool" "alpine" "GPL-3.0-or-later" "https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz"
fi

# Git
if [[ -f "${ARTIFACTS_DIR}/git" ]]; then
	add_tool "git" "${ARTIFACTS_DIR}/git" "2.43.0" "Git version control system" "alpine" "GPL-2.0-only" "https://www.kernel.org/pub/software/scm/git/git-2.43.0.tar.xz"
fi

# Nano
if [[ -f "${ARTIFACTS_DIR}/nano" ]]; then
	add_tool "nano" "${ARTIFACTS_DIR}/nano" "7.2" "GNU nano text editor" "alpine" "GPL-3.0-or-later" "https://www.nano-editor.org/dist/v7/nano-7.2.tar.xz"
fi

# Close JSON
cat >>"${MANIFEST_FILE}" <<EOF

  }
}
EOF

echo "Manifest generated: ${MANIFEST_FILE}"
jq . "${MANIFEST_FILE}" >/dev/null && echo "JSON validation: OK" || echo "JSON validation: FAILED"
