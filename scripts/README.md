# Build Scripts

This directory contains modular scripts extracted from the GitHub Actions workflow to improve maintainability and testability.

## Scripts Overview

### Shell Scripts

- **`fetch-version.sh`** - Fetches version information from GitHub releases or uses configured fallbacks
- **`verify-binary.sh`** - Verifies that binaries are statically linked
- **`extract-binary-version.sh`** - Extracts version information from compiled binaries
- **`finalize-version.sh`** - Creates and validates version metadata files
- **`build-rust-tool.sh`** - Builds Rust tools with version extraction
- **`build-c-tool.sh`** - Builds C/C++ tools using grow_glochidium.sh

### Python Scripts

- **`generate-manifest.py`** - Generates the manifest.json file with tool metadata and checksums
- **`generate-release-body.py`** - Generates the release body markdown

### Configuration Files

- **`tools-metadata.json`** - Tool metadata including descriptions, licenses, and source URLs

## Usage Examples

### Build Tools

```bash
# Build Rust tool from local directory
./scripts/build-rust-tool.sh "gpm" "https://github.com/user/repo" "gpm" "" "" "1.2.3" "1.0.0"

# Build Rust tool from external repo
./scripts/build-rust-tool.sh "starship" "https://github.com/starship/starship" "" "cargo build --release --no-default-features" "starship" "1.2.3" "1.0.0"

# Build C/C++ tool
./scripts/build-c-tool.sh "make" "https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz" "./configure LDFLAGS=-static && make -j\$(nproc)" "4.4.1" "4.4.1"
```

### Version Management

```bash
# Fetch version from GitHub releases
./scripts/fetch-version.sh "starship" "https://github.com/starship/starship" "https://github.com/starship/starship"

# Use configured version
./scripts/fetch-version.sh "make" "https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz" "" "4.4.1"
```

### Binary Verification

```bash
./scripts/verify-binary.sh "./make-bin" "make"
```

### Version Extraction

```bash
./scripts/extract-binary-version.sh "./starship-bin" "1.0.0"
```

### Version Finalization

```bash
./scripts/finalize-version.sh "gpm" "" "1.2.3" "1.0.0" "gpm"
```

### Manifest Generation

```bash
./scripts/generate-manifest.py "uairhahs/glochidia" "latest" "1.0.0"
```

### Tool Metadata Management

```json
# Add new tool to tools-metadata.json
{
  "newtool": {
    "description": "New tool description",
    "license": "MIT",
    "source_url": "https://github.com/example/newtool",
    "build_type": "alpine"
  }
}
```

### Release Body Generation

```bash
./scripts/generate-release-body.py "uairhahs/glochidia" "latest" "manually" "abc123"
```

## Benefits of Modular Approach

1. **Maintainability** - Each script has a single responsibility
2. **Testability** - Scripts can be tested independently
3. **Reusability** - Scripts can be used outside of GitHub Actions
4. **Debugging** - Easier to isolate and fix issues
5. **Readability** - Workflow file is much cleaner and easier to understand

## Integration with Workflow

The GitHub Actions workflow now calls these scripts instead of having inline logic:

```yaml
- name: Build ${{ matrix.tool.name }}
  run: |
    bash scripts/build-rust-tool.sh \
      "${{ matrix.tool.name }}" \
      "${{ matrix.tool.source_url }}" \
      "${{ matrix.tool.working_dir }}" \
      "${{ matrix.tool.build_cmd }}" \
      "${{ matrix.tool.binary_name }}" \
      "${{ steps.fetch-version.outputs.version }}" \
      "${{ env.REPO_VERSION }}"
```

This approach makes the workflow more maintainable while preserving all existing functionality.
