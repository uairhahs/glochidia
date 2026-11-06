# Glochidia

**Static binaries for immutable Linux** - A curated collection of statically-compiled development tools and utilities for ZimaOS servers and other immutable, musl-based x86_64 systems, managed by the `gpm` package manager.

[![License: MIT OR Apache-2.0](https://img.shields.io/badge/License-MIT%20OR%20Apache--2.0-blue.svg)](COPYING)
[![Build Status](https://img.shields.io/badge/build-automated-brightgreen.svg)](https://github.com/uairhahs/glochidia/actions)

## What is Glochidia?

Glochidia provides instantly-usable static binaries of development tools (GNU Make, Gawk, fastfetch, starship, etc.) for ZimaOS and similar immutable systems where traditional package managers are unavailable or restricted. Instead of running heavy Docker containers or dealing with complex dependencies, users get:

✓ **Instant execution** - No installation, just download and run  
✓ **Zero dependencies** - Statically linked with musl libc (except msedit, which is linked against glibc for ZimaOS compatibility)  
✓ **Tiny size** - Individual binaries (2-15MB each)  
✓ **Seamless integration** - Works alongside system tools  
✓ **Auto-updates** - Managed via the `gpm` package manager

### Why "Glochidia"?

A glochidium is a larval stage of freshwater mussels that attaches to a host temporarily before maturing. Similarly, this project provides tools that integrate into your system temporarily (or permanently) without invasive modifications.

## Quick Start

### For End Users (ZimaOS and other immutable systems)

`gpm` is a single static binary, so it runs directly on ZimaOS's immutable system without
`zpkg` or any install step. The same binary works on other immutable, musl-based x86_64
distributions.

```bash
# Put gpm in the directory it manages, so `gpm upgrade` can keep gpm itself up to date
mkdir -p /DATA/AppData/glochidia/bin
curl -fL -o /DATA/AppData/glochidia/bin/gpm \
  https://github.com/uairhahs/glochidia/releases/download/latest/gpm
chmod +x /DATA/AppData/glochidia/bin/gpm

# Add that directory to PATH (edits ~/.bashrc and/or ~/.zshrc), then reload your shell
/DATA/AppData/glochidia/bin/gpm setup-path
source ~/.bashrc
```

(`wget -O <file> <url>` works in place of `curl -fL -o <file> <url>`.)

Then install tools on demand:

```bash
gpm list-remote          # See all available tools
gpm install make gawk    # Install one or more tools
gpm upgrade              # Upgrade everything installed, gpm included
gpm remove gawk          # Remove a tool
```

Every binary's sha256 is listed in `manifest.json` in the same release, and `gpm` verifies
it on every download. To check the gpm binary you downloaded by hand:

```bash
curl -fsL https://github.com/uairhahs/glochidia/releases/download/latest/manifest.json \
  | grep -A5 '"gpm": {' | grep sha256
sha256sum /DATA/AppData/glochidia/bin/gpm
```

**Other systems:** gpm stores tools in `/DATA/AppData/glochidia/bin` and its cache in
`/DATA/AppData/glochidia/.cache` by default. On a system without a writable `/DATA`, pass
`--install-dir` and `--cache-dir` to every gpm command.

**ZimaOS packages:** gpm is not available through `zpkg` or ZimaOS's Mod-Store today. Each
release also publishes `gpm.raw`, a ZimaOS system extension built from the same binary, as
groundwork for a future Mod-Store listing.

### For Developers

Build and deploy binaries from source:

```bash
# Set deployment target
export DEPLOY_METHOD=ssh
export DEPLOY_USER=username
export DEPLOY_HOST=device.ip
export DEPLOY_PATH=/path/on/device

# Build a tool: grow_glochidium.sh <repo_or_tarball_url> <binary_name> [build_command]
./grow_glochidium.sh https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz make
```

## Architecture

This project consists of three components:

1. **Build System** ([grow_glochidium.sh](grow_glochidium.sh)) - Automated compilation pipeline
2. **Binary Distribution** (CI/CD workflow) - Automated builds via GitHub Actions
3. **Package Manager** (`gpm`) - Client-side tool for installation and updates

## Prerequisites

### For End Users

- x86_64 ZimaOS, or another immutable, musl-based x86_64 Linux system
- `/DATA` directory with write permissions (standard on ZimaOS), or use `--install-dir` and `--cache-dir`
- `curl` or `wget` for the first gpm download, and an internet connection

### For Developers (Building from Source)

**Required:**

- **podman** (default) or **docker** (set `CONTAINER_RUNTIME=docker`) - For containerized builds
- **git** - For cloning git sources
- **wget** - For downloading tarball sources
- **file** - For identifying the built artifact
- **bash** 4.0+ - For build scripts

**For SSH deployment:**

- **ssh** with key-based authentication to the target, and **rsync**

### Deployment Methods

The build system supports multiple deployment targets:

1. **SSH/rsync** (default)

   ```bash
   export DEPLOY_METHOD=ssh
   export DEPLOY_USER=username
   export DEPLOY_HOST=device.ip
   export DEPLOY_PATH=/path/on/device
   ```

2. **CI/CD** (for automated workflows)

   ```bash
   export DEPLOY_METHOD=ci-cd
   # Artifact will be left in build directory for CI/CD to copy
   ```

3. **None** (skip deployment)
   ```bash
   export DEPLOY_METHOD=none
   # Only build, don't deploy
   ```

### Build Environments

Builds run in pinned container images (override with `ALPINE_IMAGE`, `RUST_ALPINE_IMAGE` and `RUST_GNU_IMAGE`):

- **alpine:3.24** (musl) - Static compilation for C/C++ projects
- **rust:1.99-alpine3.24** (musl) - Static compilation for Rust projects (used when the build command runs `cargo`)
- **rust:1.99-slim-bookworm** (glibc) - Only for msedit, which needs glibc on ZimaOS

## Building From Source

### Basic Usage

```bash
./grow_glochidium.sh <repo_or_tarball_url> <binary_name> [build_command]
```

The source URL can be a git repository or a `.tar.gz`, `.tar.xz`, `.tar.bz2` or `.tgz`
tarball. Without a build command, the build system is auto-detected (see below).

Environment variables:

| Variable            | Description                                            | Default              |
| ------------------- | ------------------------------------------------------ | -------------------- |
| `DEPLOY_METHOD`     | `ssh`, `ci-cd` or `none`                               | `ssh`                |
| `DEPLOY_USER`       | SSH username                                           | prompted (SSH only)  |
| `DEPLOY_HOST`       | SSH hostname/IP                                        | prompted (SSH only)  |
| `DEPLOY_PATH`       | Deployment path on the host                            | prompted (SSH only)  |
| `CONTAINER_RUNTIME` | Container runtime to use                               | `podman`             |
| `GIT_REF`           | Branch, tag or commit to build (git sources)           | default branch       |
| `SOURCE_SHA256`     | Expected tarball sha256; the build aborts on mismatch  | not checked          |

### Examples

**Build GNU Make:**

```bash
./grow_glochidium.sh \
  https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz \
  make \
  "./configure LDFLAGS=-static && make -j$(nproc)"
```

**Build fastfetch:**

```bash
./grow_glochidium.sh \
  https://github.com/fastfetch-cli/fastfetch \
  fastfetch \
  "cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXE_LINKER_FLAGS=-static -DENABLE_DRM=OFF && cmake --build build --target fastfetch"
```

**Build Rust project (starship):**

```bash
./grow_glochidium.sh \
  https://github.com/starship/starship \
  starship \
  "cargo build --release --target x86_64-unknown-linux-musl --no-default-features --features battery"
```

### Custom Build Commands

For projects with non-standard build systems, pass the build command as the third argument:

```bash
./grow_glochidium.sh https://github.com/example/tool tool \
  "mkdir -p build && cd build && cmake -DCMAKE_BUILD_TYPE=Release .. && make"
```

## How It Works

### Build Pipeline

1. **Download Source** - Clones git repo or extracts tarball
2. **Container Selection** - Alpine (C/C++) or the Rust Alpine image (build commands that run `cargo`)
3. **Compatibility Fixes** - Sets musl-compatible flags (CFLAGS, LDFLAGS)
4. **Compilation** - Builds statically with `-static` LDFLAGS
5. **Artifact Extraction** - Copies binary from container
6. **Verification** - Reports the artifact type (CI additionally fails any dynamically linked ELF binary, see `scripts/verify-binary.sh`)
7. **Deployment** - SSH deployment or artifact preservation for CI/CD

### Auto-Detection

Without a build command, the script checks for these files in order:

- **Makefile** → `make -j$(nproc)`
- **build.sh** → `bash build.sh`
- **CMakeLists.txt** → `mkdir -p build && cd build && cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF .. && make -j$(nproc)`

Static linking comes from the `LDFLAGS`/`CFLAGS` set in the container. Rust projects are not
auto-detected: pass a `cargo build` command, which also selects the Rust container.

### Distribution

Built binaries are published to:

- **GitHub Releases** - `https://github.com/uairhahs/glochidia/releases/tag/latest`
- **manifest.json** - Metadata with SHA256 checksums for verification

## License & Compliance

### This Repository

Glochidia's own code (gpm, set_locale, the build scripts and CI tooling) is dual-licensed
under [MIT](LICENSE-MIT) or [Apache-2.0](LICENSE-APACHE), at your option. See
[COPYING](COPYING) for details.

### Distributed Binaries

Each third-party binary keeps its original license (distributing them alongside this
project's code is mere aggregation):

- **GNU Make** - GPL-3.0-or-later
- **GNU Awk** - GPL-3.0-or-later
- **fastfetch** - MIT
- **ble.sh** - BSD-3-Clause
- **starship** - ISC
- **msedit** - MIT
- **gpm** and **set_locale** (this repository) - MIT OR Apache-2.0

### GPL Compliance

For the GPL-licensed binaries, this project complies with GPL requirements by:

✓ **Source Availability** - All source URLs documented in [SOURCES.txt](SOURCES.txt)  
✓ **License Distribution** - Full texts in [licenses/](licenses/) directory  
✓ **Build Reproducibility** - Complete build scripts in this repository  
✓ **No Additional Restrictions** - Original GPL terms preserved

For details, see [COPYING](COPYING) and [SOURCES.txt](SOURCES.txt).

## Contributing

Contributions are welcome! To add a new tool:

1. Add tool metadata to `scripts/tools-metadata.json`
2. Test the build locally using `grow_glochidium.sh`
3. Update [SOURCES.txt](SOURCES.txt) with source provenance
4. Submit a pull request with build instructions

### Adding New Tools

To add a new tool, edit `scripts/tools-metadata.json`:

```json
{
  "newtool": {
    "description": "New tool description",
    "license": "MIT",
    "source_url": "https://github.com/example/newtool",
    "build_type": "alpine",
    "source_sha256": "optional_checksum_for_tarballs"
  }
}
```

Then add the tool to the GitHub Actions workflow matrix.

## Support

- **Issues**: <https://github.com/uairhahs/glochidia/issues>
- **Discussions**: <https://github.com/uairhahs/glochidia/discussions>
- **License Questions**: See [COPYING](COPYING)

---

**Note**: Glochidia is independent of ZimaOS and is not officially affiliated with IceWhale Technology.

## Project Structure

```txt
glochidia/
├── .github/workflows/
│   └── build-release.yml          # Builds every tool and publishes the release
├── gpm/                           # gpm package manager (Rust)
├── glochidia-locale/              # set_locale and locale-gen utilities (Rust)
├── zpkg/
│   ├── build-zpkg.sh              # Packages gpm as gpm.raw (ZimaOS system extension)
│   ├── raw/                       # gpm.raw filesystem tree (binary added at build time)
│   └── zpkg.md                    # ZimaOS RAW package format notes
├── scripts/
│   ├── build-rust-tool.sh         # Rust build automation
│   ├── build-c-tool.sh            # C/C++ build automation
│   ├── fetch-version.sh           # Version fetching logic
│   ├── verify-binary.sh           # Static linking check
│   ├── extract-binary-version.sh  # Version extraction
│   ├── finalize-version.sh        # Version metadata handling
│   ├── generate-manifest.py       # Manifest generation
│   ├── generate-release-body.py   # Release notes generation
│   ├── tools-metadata.json        # Tool metadata configuration
│   └── README.md                  # Scripts documentation
├── licenses/                      # Full license texts
├── grow_glochidium.sh             # Universal native build & deploy script
├── container-build.sh             # Container-side build executor
├── Examples.md                    # Build examples for various projects
├── SOURCES.txt                    # Source provenance for distributed binaries
├── COPYING                        # License notice
└── README.md                      # This file
```

## Technical Details

### Native Compilation with musl

All builds run natively in Alpine Linux containers:

- **Base Image:** alpine:3.24 (pinned; bump deliberately)
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

Supported build systems:

- **Makefile** - Standard GNU Make projects (gawk, GNU Make, etc.)
- **build.sh** - Custom shell build scripts
- **CMakeLists.txt** - CMake-based projects (fastfetch, etc.)
- **Cargo.toml** - Rust projects (starship, msedit, etc.), with an explicit `cargo build` command

For other build systems, provide a custom build command as the 3rd parameter.

### Known Compatibility Fixes

The build containers handle most projects automatically:

- **Rust projects** - Uses the pinned Rust Alpine container with native musl toolchain
- **CMake projects** - Includes `-DBUILD_SHARED_LIBS=OFF` to disable shared libraries
- **C/Autoconf projects** - Sets `LDFLAGS="-static" CFLAGS="-static -std=gnu11"` to enforce static linking
- **GCC 15 compatibility** - Forces gnu11 standard to avoid C23 function prototype issues
- **Linux headers** - Includes linux-headers for projects requiring kernel interface headers
- **Musl compatibility** - Handles musl-specific issues automatically

## Binary Verification

To verify a compiled binary is statically linked:

```bash
file <binary_name>
# Output: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), static-pie linked
# (or "statically linked"; anything mentioning an "interpreter" is dynamic)

ldd <binary_name>
# Output: not a dynamic executable
```

## Troubleshooting

### Build fails with container not found

- Ensure podman is installed: `podman --version`
- Alpine image will be pulled automatically on first run
- Manual pull: `podman pull alpine:3.24`

### Build fails during compilation

- Check for musl/Alpine compatibility issues in the error output
- Additional compatibility fixes can be added to the build script in `grow_glochidium.sh`
- For complex projects, provide a custom build command with necessary flags

### Binary fails with "required file not found" on target device

- **Cause:** Binary has dynamic library dependencies that don't exist on the target system
- **Solution:** Ensure binaries are statically linked
  - Verify on build host: `file <binary_name>` should show "statically linked" or "static-pie linked"
  - Check with: `ldd <binary_name>` should output "not a dynamic executable"
- **For Cargo projects:** Verify the target system matches or use `x86_64-unknown-linux-musl` target
- **For CMake projects:** Ensure `-DBUILD_SHARED_LIBS=OFF` is used (default in auto-detection)
- **For Autoconf projects:** Verify `LDFLAGS="-static"` is passed during configure

### Deployment fails due to SSH

- Verify remote device IP and SSH credentials
- Test SSH connectivity: `ssh your_username@your.device.ip 'echo OK'`
- Ensure DEPLOY_PATH exists or is writable on remote device
- For buildroot systems, ensure /DATA/bin exists and is in $PATH

## Development Guidelines

Changes should:

1. Work when statically linked with musl
2. Pass `cargo test` for changes to `gpm/` or `glochidia-locale/`
3. Be tested with: `DEPLOY_USER=user DEPLOY_HOST=ip DEPLOY_PATH=/DATA/bin grow_glochidium.sh <repo> <binary>` (optionally set `GIT_REF` to build a specific tag or commit, and `SOURCE_SHA256` to verify a tarball)

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE))
- MIT License ([LICENSE-MIT](LICENSE-MIT))

at your option. Third-party binaries distributed by this project keep their own licenses;
see [COPYING](COPYING).

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion
in this project, as defined in the Apache-2.0 license, shall be dual-licensed as above,
without any additional terms or conditions.

---

**Deployment Status:** Production Ready
**Build Systems Tested:** GNU Autoconf, Rust/Cargo, CMake, Custom Make
