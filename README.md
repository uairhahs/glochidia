# Glochidia

**Static Binary Library for ZimaOS** - A curated collection of statically-compiled development tools and utilities for musl-based embedded Linux systems.

[![License: GPL](https://img.shields.io/badge/License-GPL-blue.svg)](COPYING)
[![Build Status](https://img.shields.io/badge/build-automated-brightgreen.svg)](https://github.com/uairhahs/glochidia/actions)

## What is Glochidia?

Glochidia provides instantly-usable static binaries of essential development tools (Make, Git, Nano, etc.) for ZimaOS and similar systems where traditional package managers are unavailable or restricted. Instead of running heavy Docker containers or dealing with complex dependencies, users get:

✓ **Instant execution** - No installation, just download and run  
✓ **Zero dependencies** - Statically linked with musl libc  
✓ **Tiny size** - Individual binaries (2-15MB each)  
✓ **Seamless integration** - Works alongside system tools  
✓ **Auto-updates** - Managed via the `gpm` package manager

### Why "Glochidia"?

A glochidium is a larval stage of freshwater mussels that attaches to a host temporarily before maturing. Similarly, this project provides tools that integrate into your system temporarily (or permanently) without invasive modifications.

## Quick Start

### For End Users (ZimaOS)

Install the ZimaOS Terminal app (includes `gpm`):

```bash
zpkg install zimaos_terminal
```

Then install tools on-demand:

```bash
gpm install make    # GNU Make
gpm install git     # Git VCS
gpm install nano    # Text editor
gpm list-remote     # See all available tools
```

### For Developers

Build and deploy binaries from source:

```bash
# Set deployment target
export DEPLOY_METHOD=github
export GITHUB_TOKEN=your_token_here
export GENERATE_MANIFEST=true

# Build a tool
REPO_URL=https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz \
BINARY_NAME=make \
./grow_glochidium.sh
```

## Architecture

This project consists of three components:

1. **Build System** ([grow_glochidium.sh](grow_glochidium.sh)) - Automated compilation pipeline
2. **Binary Distribution** (GitHub Releases) - Versioned artifacts with manifest.json
3. **Package Manager** (`gpm`) - Client-side tool for installation and updates

## Prerequisites

### For End Users

- ZimaOS or compatible musl-based Linux system
- `/DATA` directory with write permissions (standard on ZimaOS)
- Internet connection for downloading binaries

### For Developers (Building from Source)

**Required:**

- **podman** or **docker** - For containerized builds
- **git** - For repository operations
- **bash** 4.0+ - For build scripts
- **GitHub CLI** (`gh`) or **curl** - For release uploads

**Optional:**

- **jq** - For JSON manipulation in manifest generation

### Deployment Methods

The build system supports two deployment targets:

1. **GitHub Releases** (default, recommended)

   ```bash
   export DEPLOY_METHOD=github
   export GITHUB_TOKEN=your_personal_access_token
   export REPO_OWNER=uairhahs
   export REPO_NAME=glochidia
   ```

2. **SSH/rsync** (legacy)
   ```bash
   export DEPLOY_METHOD=ssh
   export DEPLOY_USER=username
   export DEPLOY_HOST=device.ip
   export DEPLOY_PATH=/path/on/device
   ```

### Build Environments

The system uses Alpine Linux (musl) for all projects:

- **Alpine Linux** (musl) - Static compilation for C/C++ and Rust projects

## Building From Source

### Basic Usage

```bash
./grow_glochidium.sh
```

The script accepts environment variables for configuration:

| Variable            | Description                   | Default    | Required              |
| ------------------- | ----------------------------- | ---------- | --------------------- |
| `REPO_URL`          | Source code URL (git/tarball) | (prompted) | Yes                   |
| `BINARY_NAME`       | Output binary filename        | (prompted) | Yes                   |
| `DEPLOY_METHOD`     | Deployment target             | `github`   | No                    |
| `GITHUB_TOKEN`      | GitHub API token              | -          | For GitHub deployment |
| `GENERATE_MANIFEST` | Auto-generate manifest        | `false`    | No                    |

### Examples

**Build GNU Make:**

```bash
REPO_URL=https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz \
BINARY_NAME=make \
DEPLOY_METHOD=github \
GITHUB_TOKEN=$GITHUB_TOKEN \
./grow_glochidium.sh
```

**Build Git:**

```bash
REPO_URL=https://www.kernel.org/pub/software/scm/git/git-2.43.0.tar.xz \
BINARY_NAME=git \
./grow_glochidium.sh
```

**Build Rust project (gpm):**

```bash
cd glochidia
podman run --rm -v "$(pwd)/gpm:/src:Z" -w /src rust:alpine sh -c '
  apk add --no-cache musl-dev &&
  cargo build --release --target x86_64-unknown-linux-musl &&
  strip target/x86_64-unknown-linux-musl/release/gpm &&
  cp target/x86_64-unknown-linux-musl/release/gpm /src/gpm-bin
'
```

### Custom Build Commands

For projects with non-standard build systems:

```bash
CUSTOM_BUILD_COMMAND="mkdir -p build && cd build && cmake -DCMAKE_BUILD_TYPE=Release .. && make" \
./grow_glochidium.sh
```

## How It Works

### Build Pipeline

1. **Download Source** - Clones git repo or extracts tarball
2. **Container Selection** - Alpine (C/C++) or Debian (Rust)
3. **Compatibility Fixes** - Patches known musl issues (getenv, getopt, etc.)
4. **Compilation** - Builds statically with `-static` LDFLAGS
5. **Artifact Extraction** - Copies binary from container
6. **Verification** - Confirms static ELF linking
7. **Deployment** - Uploads to GitHub Releases or SSH target
8. **Manifest Generation** - Updates manifest.json with checksums

### Auto-Detection

The script automatically detects:

- **Makefile** → `./configure && make LDFLAGS="-static"`
- **CMakeLists.txt** → `cmake -DCMAKE_EXE_LINKER_FLAGS="-static" && make`
- **build.sh** → Executes custom script

Note: Rust projects (like gpm) use the Alpine rust container separately.

### Distribution

Built binaries are published to:

- **GitHub Releases** - `https://github.com/uairhahs/glochidia/releases/tag/latest`
- **manifest.json** - Metadata with SHA256 checksums for verification

## License & Compliance

### This Repository

Build scripts and infrastructure are licensed under GPL-3.0-or-later. See [COPYING](COPYING) for details.

### Distributed Binaries

Each binary is distributed under its original license:

- **GNU Make** - GPL-3.0-or-later
- **Git** - GPL-2.0-only
- **GNU Nano** - GPL-3.0-or-later

### GPL Compliance

This project complies with GPL requirements by:

✓ **Source Availability** - All source URLs documented in [SOURCES.txt](SOURCES.txt)  
✓ **License Distribution** - Full texts in [licenses/](licenses/) directory  
✓ **Build Reproducibility** - Complete build scripts in this repository  
✓ **No Additional Restrictions** - Original GPL terms preserved

For details, see [COPYING](COPYING) and [SOURCES.txt](SOURCES.txt).

## Contributing

Contributions are welcome! To add a new tool:

1. Test the build locally using `grow_glochidium.sh`
2. Update [SOURCES.txt](SOURCES.txt) with source provenance
3. Submit a pull request with build instructions

## Support

- **Issues**: https://github.com/uairhahs/glochidia/issues
- **Discussions**: https://github.com/uairhahs/glochidia/discussions
- **License Questions**: See [COPYING](COPYING)

---

**Note**: Glochidia is independent of ZimaOS and is not officially affiliated with IceWhale Technology.

```bash
grow_glochidium.sh https://github.com/fastfetch-cli/fastfetch fastfetch
Enter DEPLOY_USER: <your_remote_user>
Enter DEPLOY_HOST: <ssh_target>
Enter DEPLOY_PATH: <destination_path>
```

With environment variables (no prompts):

```bash
  grow_glochidium.sh https://github.com/fastfetch-cli/fastfetch fastfetch
```

With custom CMake build flags:

```bash
grow_glochidium.sh https://github.com/fastfetch-cli/fastfetch fastfetch \
  "mkdir -p build && cd build && cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_DRM=OFF .. && make"
```

```bash
grow_glochidium.sh <repo_url> <binary_name> "make -f custom.mk"
```

## Project Structure

```txt
glochidia/
├── grow_glochidium.sh          # Universal native build & deploy script
├── alpine-build.sh             # Container-side build executor (C/C++ projects)
├── debian-build.sh             # Container-side build executor (Rust/cargo projects)
├── Examples.md                 # Build examples for various projects
├── .gitignore                  # Git ignore rules
└── README.md                   # This file
```

## Technical Details

### Native Compilation with musl

All builds run natively in Alpine Linux containers:

- **Base Image:** alpine:latest (3.20 or later)
- **Libc:** musl (native compilation, not cross-compiled)
- **Linking:** Static by default (musl + static libraries)
- **Toolchain:** Native gcc, make, autotools, cargo, cmake on x86_64

Benefits of native Alpine builds:

- **Maximum Compatibility** - No cross-compiler quirks, fully native toolchain behavior
- **Simple, Reliable** - Fewer header/path resolution issues
- **Portable Binaries** - Static musl builds run on any x86_64 Linux system
- **Clean Environment** - Fresh Alpine container for each build
- **Automatic Cleanup** - Container removed after build completes
- **Multi-Language Support** - Automatically handles C, Rust, CMake projects

### Alpine Container Build Process

For each build, the pipeline:

1. Starts a fresh Alpine container with build-base and development tools
2. Mounts the project source at `/src` inside container
3. Installs build dependencies: autoconf, automake, libtool, cargo, cmake, linux-headers, etc.
4. Runs the build command natively inside Alpine
5. Strips the resulting binary
6. Extracts binary back to host
7. Removes container and cleans up

Benefits of musl static linking:

- Single, portable binary
- No runtime glibc dependency
- Runs on any x86_64 Linux system (buildroot, Alpine, embedded systems)
- Smaller footprint for embedded devices

### Cross-Compilation via Podman

Unlike traditional cross-compilation:

- **No native toolchain installation** needed on host
- **No cross-compiler setup** required
- **Native builds inside container** using Alpine's native gcc, cargo, cmake
- Simple container approach:
  - Mount project source to `/src`
  - Run build commands directly in Alpine
  - Extract compiled binaries from container

This approach:

- Eliminates toolchain installation burden
- Ensures consistent build environment across systems
- Works on any system with podman installed
- Leverages Alpine's lightweight, efficient native toolchain

### Supported Build Systems

Auto-detection supports:

- **Makefile** - Standard GNU Make projects (gawk, GNU Make, etc.)
- **build.sh** - Custom shell build scripts
- **CMakeLists.txt** - CMake-based projects (fastfetch, etc.)
- **Cargo.toml** - Rust projects (starship, msedit, etc.)

For unsupported systems, provide a custom build command as the 3rd parameter.

### Known Compatibility Fixes

The build containers handle most projects automatically:

- **Rust projects** - Uses Debian container with gnu host, cross-compiles to x86_64-unknown-linux-musl
- **Rust static linking** - Sets `RUSTFLAGS="-C target-feature=+crt-static -C relocation-model=static"` for fully static binaries
- **CMake projects** - Includes `-DBUILD_SHARED_LIBS=OFF` to disable shared libraries
- **C/Autoconf projects** - Sets `LDFLAGS="-static" CFLAGS="-static"` to enforce static linking
- **Linux headers** - Includes linux-headers for projects requiring kernel interface headers
- **Musl compatibility** - Handles musl-specific issues automatically

## Binary Verification

To verify a compiled binary is statically linked:

```bash
file <binary_name>
# Output: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked

ldd <binary_name>
# Output: not a dynamic executable
```

## Troubleshooting

### Build fails with container not found

- Ensure podman is installed: `podman --version`
- Alpine image will be pulled automatically on first run
- Manual pull: `podman pull alpine:latest`

### Build fails during compilation

- Check for musl/Alpine compatibility issues in the error output
- Additional compatibility fixes can be added to the build script in `grow_glochidium.sh`
- For complex projects, provide a custom build command with necessary flags

### Binary fails with "required file not found" on target device

- **Cause:** Binary has dynamic library dependencies that don't exist on the target system
- **Solution:** Ensure binaries are statically linked
  - Verify on build host: `file <binary_name>` should show "statically linked"
  - Check with: `ldd <binary_name>` should output "not a dynamic executable"
- **For Cargo projects:** Verify the target system matches or use `x86_64-unknown-linux-musl` target
- **For CMake projects:** Ensure `-DBUILD_SHARED_LIBS=OFF` is used (default in auto-detection)
- **For Autoconf projects:** Verify `LDFLAGS="-static"` is passed during configure

### Deployment fails due to SSH

- Verify remote device IP and SSH credentials
- Test SSH connectivity: `ssh your_username@your.device.ip 'echo OK'`
- Ensure DEPLOY_PATH exists or is writable on remote device
- For buildroot systems, ensure /DATA/bin exists and is in $PATH

## Contributing

Changes should:

1. Maintain C99 compatibility
2. Compile cleanly with `-Wall -Werror`
3. Work when statically linked with musl
4. Be tested with: `DEPLOY_USER=user DEPLOY_HOST=ip DEPLOY_PATH=/DATA/bin grow_glochidium.sh <repo> <binary>`

## License

This project is licensed under the GNU General Public License v2.0 (GPLv2).

See the COPYING file for the full license text.

---

**Last Updated:** 16 Dec 2025  
**Deployment Status:** Production Ready
**Build Systems Tested:** GNU Autoconf, Rust/Cargo, CMake, Custom Make
