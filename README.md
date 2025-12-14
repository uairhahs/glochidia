# Glochidia

Universal cross-compilation and deployment tool for building projects targeting x86_64 embedded Linux systems with musl.

## Overview

This repository provides a streamlined pipeline to:
- Clone any git repository
- Auto-detect or specify build systems (Makefile, CMake, custom build scripts)
- Cross-compile for x86_64 using musl static linking
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

### Recommended
- **cmake** - For CMake-based projects
- **make** - For Make-based projects

### Container Images
The build system automatically uses:
- `ghcr.io/cross-rs/x86_64-unknown-linux-musl:latest` - x86_64 musl cross-compiler

## Usage

### Install the Tool

```bash
cp grow_glochidium.sh ~/bin/
chmod +x ~/bin/grow_glochidium.sh
```

### Quick Start

```bash
grow_glochidium.sh <repository_url> <binary_name>
```

The script will:
1. Prompt for deployment credentials (DEPLOY_USER, DEPLOY_HOST, DEPLOY_PATH)
2. Clone the repository
3. Auto-detect the build system
4. Cross-compile for x86_64
5. Deploy to target device

**Example:**

```bash
grow_glochidium.sh https://github.com/fastfetch-cli/fastfetch fastfetch
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

## Building Locally (This Repository)

For testing this glochidia pipeline itself:

### Option 1: Using the Makefile

```bash
git clone https://github.com/uairhahs/glochidia.git
cd glochidia
make clean
make
```

The Makefile automatically:
- Detects and uses the `x86_64-linux-musl-gcc` wrapper
- Applies the `-static` flag for musl static linking
- Cross-compiles via podman container

### Option 2: Manual Cross-Compilation

```bash
# Using the wrapper script directly
x86_64-linux-musl-gcc -Wall -Werror -Os -std=c99 -static -o glochidia_app glochidia_app.c
```

### Option 3: Using Native Compiler (if available)

```bash
CC=x86_64-linux-musl-gcc make
```

## How It Works

### Build System Auto-Detection

The `grow_glochidium.sh` script automatically detects:

- **Makefile** - Runs `make clean && make`
- **build.sh** - Runs `bash build.sh`
- **CMakeLists.txt** - Runs `mkdir -p build && cd build && cmake .. && make`

For unsupported build systems, provide a custom build command as the 3rd parameter.

### Cross-Compilation Pipeline

1. **Clone Repository** - Fetches the target project
2. **Setup x86_64 musl Compiler** - Prepares cross-compilation environment
3. **Build System Detection** - Identifies how to compile the project
4. **Cross-Compile** - Builds for x86_64 with musl static linking
5. **Binary Verification** - Confirms the binary was created
6. **Create Remote Directory** - Ensures deployment path exists on target device
7. **Deploy via rsync** - Transfers binary over SSH
8. **Cleanup** - Removes temporary build directory

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

### x86_64 musl Static Linking

The build system uses musl for static compilation:
- **Compiler:** x86_64-linux-musl-gcc
- **C Standard:** C99
- **Linking:** Static (`-static` flag)
- **Optimization:** `-Os` (size optimization)

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

## Binary Verification

To verify a compiled binary is statically linked:

```bash
file <binary_name>
# Output: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked

ldd <binary_name>
# Output: not a dynamic executable
```


## Troubleshooting

### Build fails with "x86_64-linux-musl-gcc: No such file or directory"
- Ensure wrapper script is in `$PATH`: `echo $PATH | grep ~/bin`
- Copy wrapper: `cp x86_64-linux-musl-gcc ~/bin/`

### Podman container not found
- Pull musl image: `podman pull ghcr.io/cross-rs/x86_64-unknown-linux-musl:latest`

### Deployment fails due to SSH
- Verify remote device IP and SSH credentials in your deploy script
- Test SSH connectivity: `ssh your_username@your.device.ip 'echo OK'`

## Contributing

Changes should:
1. Maintain C99 compatibility
2. Compile cleanly with `-Wall -Werror`
3. Work when statically linked with musl
4. Be tested with: `DEPLOY_USER=user DEPLOY_HOST=ip DEPLOY_PATH=/bin grow_glochidium.sh <repo> <binary>`

## License

This project is licensed under the GNU General Public License v2.0 (GPLv2).

See the COPYING file for the full license text.

---

**Last Updated:** 14 Dec 2025  
**Deployment Status:** Production Ready
