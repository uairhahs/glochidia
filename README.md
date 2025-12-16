# Glochidia

Universal native build and deployment tool for building projects targeting x86_64 embedded Linux systems with musl.

## Overview

This repository provides a streamlined pipeline to:
- Clone any git repository or download tarballs
- Auto-detect or specify build systems (Makefile, CMake, custom build scripts)
- Build natively in Alpine Linux containers with musl for maximum compatibility
- Deploy compiled binaries to remote devices via SSH/rsync

## Prerequisites

### Required Tools
- **podman** - For containerized cross-compilation
- **git** - For cloning repositories
- **bash** - For pipeline execution
- **rsync** - For binary deployment via SSH
- **ssh** - For remote device access
- **ssh-copy-id** - For setting up SSH key authentication

### SSH Setup (Required)

Before using the deployment pipeline, set up SSH key authentication:

```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub username@device.ip.or.hostname
```

If you don't have SSH keys, generate them first:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

Then copy the public key to your target device.

### Optional
- **cmake** - Already available in Alpine containers
- **make** - Already available in Alpine containers

### Container Images
The build system automatically uses:
- `alpine:latest` - Lightweight Linux with native musl gcc toolchain

## Usage

### Enter repo and set execute

```bash
cd glochidia
chmod +x grow_glochidium.sh
```

### Quick Start (git repo or tarball)

```bash
grow_glochidium.sh <source_url> <binary_name>
```

The script will:
1. Prompt for deployment credentials (DEPLOY_USER, DEPLOY_HOST, DEPLOY_PATH)
2. Clone the repository
3. Auto-detect the build system
4. Cross-compile for x86_64
5. Deploy to target device

**Example (git):**

```bash
grow_glochidium.sh https://github.com/fastfetch-cli/fastfetch fastfetch
```

**Example (tarball):**

```bash
grow_glochidium.sh https://ftp.gnu.org/gnu/gawk/gawk-5.3.1.tar.gz gawk
```

### Custom Build Commands

For projects with non-standard build systems, provide a custom build command:

```bash
grow_glochidium.sh <repo_url> <binary_name> "<build_command>"
```

**Example with CMake:**

```bash
grow_glochidium.sh https://github.com/fastfetch-cli/fastfetch fastfetch \
  "mkdir -p build && cd build && cmake -DCMAKE_BUILD_TYPE=Release .. && make"
```

### Environment Variables

Set deployment credentials to skip prompts:

```bash
export DEPLOY_USER=username
export DEPLOY_HOST=device.ip.or.hostname
export DEPLOY_PATH=/path/to/deploy
grow_glochidium.sh <repo_url> <binary_name>
```

Or set inline:

```bash
DEPLOY_USER=user DEPLOY_HOST=<ssh_target> DEPLOY_PATH=<destination_path> \
  grow_glochidium.sh https://github.com/user/project binary_name
```
- Note: assure that the DEPLOY_PATH is added to your $PATH on the ssh target to use the binaries globally

## Building Projects with Glochidia

All builds happen natively in Alpine Linux containers for maximum compatibility.

### Alpine Container Includes
- **build-base** - GCC, Make, binutils, musl-dev
- **autoconf, automake** - For autotools projects
- **git, curl, wget** - For fetching dependencies
- **libtool, pkgconfig** - For complex projects

### Pre-Build Fixes
The pipeline automatically applies compatibility fixes for common musl/Alpine issues:
- Fixes `getenv()` and `getopt()` declarations in sources like fnmatch.c and getopt.c/h
- Ensures proper header resolution for projects with complex directory structures
- Strips binaries for smaller deployment size

## How It Works

### Build System Auto-Detection

The `grow_glochidium.sh` script automatically detects:

- **Makefile** - Runs `make -j$(nproc)`
- **build.sh** - Runs `bash build.sh`
- **CMakeLists.txt** - Runs `mkdir -p build && cd build && cmake .. && make -j$(nproc)`

For unsupported build systems, provide a custom build command as the 3rd parameter.

### Native Alpine Build Pipeline

1. **Download Source** - Clones git repo or extracts tarball
2. **Create Build Container** - Spins up Alpine container with build-base
3. **Apply Compatibility Fixes** - Patches known musl/Alpine issues (getenv, getopt declarations)
4. **Compile** - Builds natively in Alpine with musl libc
5. **Strip Binary** - Removes debug symbols for smaller size
6. **Extract Artifact** - Copies binary from container to host
7. **Binary Verification** - Confirms static ELF binary
8. **Create Remote Directory** - Ensures deployment path exists on target device
9. **Deploy via rsync** - Transfers binary over SSH
10. **Cleanup** - Removes temporary build directory

### Deployment

The deployment script performs:

1. **Remote Directory Creation**
   - Creates deployment directory on target device via SSH (mkdir -p)
   - Handles nested paths automatically

2. **Binary Transfer**
   - Uses rsync to deploy binary over SSH
   - Efficient incremental transfers
   - Progress reporting

### Examples

Clone and build fastfetch, deploy to embedded device:
e.g.
```bash
grow_glochidium.sh https://github.com/fastfetch-cli/fastfetch fastfetch
Enter DEPLOY_USER: <your_remote_user>
Enter DEPLOY_HOST: <ssh_target>
Enter DEPLOY_PATH: <destination_path>
```

With environment variables (no prompts):

```bash
DEPLOY_USER=uddin DEPLOY_HOST=<ssh_target> DEPLOY_PATH=<destination_path> \
  grow_glochidium.sh https://github.com/fastfetch-cli/fastfetch fastfetch
```

With custom CMake build flags:

```bash
grow_glochidium.sh https://github.com/fastfetch-cli/fastfetch fastfetch \
  "mkdir -p build && cd build && cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_DRM=OFF .. && make"
```
grow_glochidium.sh <repo_url> <binary_name> "make -f custom.mk"
```


## Project Structure

```
glochidia/
├── Makefile                    # Build configuration
├── x86_64-linux-musl-gcc       # Cross-compiler wrapper script
├── grow_glochidium.sh          # Universal build & deploy script
├── glochidia_app.c             # Example C source
├── .gitignore                  # Git ignore rules
├── tooling/
│   └── setup_cross_env.sh      # Pre-build environment setup
└── README.md                   # This file
```

## Technical Details

### Native Compilation with musl

All builds run natively in Alpine Linux containers:
- **Base Image:** alpine:latest
- **Libc:** musl (native, not cross-compiled)
- **Linking:** Static by default (`LDFLAGS=-static` in configure)
- **Toolchain:** Native gcc, make, autotools

Benefits of native Alpine builds:
- **Maximum Compatibility** - No cross-compiler quirks, native toolchain behavior
- **Simple, Reliable** - Fewer header/path resolution issues
- **Portable Binaries** - Static musl builds run on any x86_64 Linux system
- **Clean Environment** - Fresh Alpine container for each build
- **Automatic Cleanup** - Container removed after build completes

### Alpine Container Build Process

For each build, the pipeline:
1. Starts a fresh Alpine container with build-base package group
2. Mounts the project source at `/src` inside container
3. Applies any necessary compatibility patches
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

The wrapper script `x86_64-linux-musl-gcc` transparently:
- Invokes podman container with musl toolchain
- Mounts project directory to `/project` in container
- Compiles inside container, returns binary to host

This approach:
- Eliminates native toolchain installation
- Ensures consistent build environment across systems
- Works on any system with podman installed

### Supported Build Systems

Auto-detection supports:
- **Makefile** - Standard GNU Make projects
- **build.sh** - Custom shell build scripts  
- **CMakeLists.txt** - CMake-based projects

For unsupported systems, provide a custom build command as the 3rd parameter.

### Known Compatibility Fixes

The pipeline automatically handles:
- **fnmatch.c getenv() conflicts** - Fixed musl header strictness
- **getopt.c/h conflicts** - Corrected function signatures for musl
- Any additional fixes needed for specific projects can be added to the build script

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

### Deployment fails due to SSH
- Verify remote device IP and SSH credentials
- Test SSH connectivity: `ssh your_username@your.device.ip 'echo OK'`
- Ensure DEPLOY_PATH exists or is writable on remote device

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

**Last Updated:** 14 Dec 2025  
**Deployment Status:** Production Ready
