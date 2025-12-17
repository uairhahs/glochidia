# Examples Builds

The `grow_glochidium.sh` script uses **native container builds in Alpine** or **Debian container for Rust cross-compilation**, providing:

- Simpler setup (no wrapper scripts needed)
- Better compatibility with projects using standard ./configure
- Automatic dependency installation within Alpine or Debian container

## Prerequisites

1. **Podman** (or Docker): Used for container runtime

   ```bash
   podman --version  # Should be 3.0+
   ```

2. **Base Images**: Ensure you have the latest Alpine and Debian images

   ```bash
   podman pull alpine:latest
   podman pull debian:bookworm-slim
   ```

**Status**: ✅ Successfully tested and deployed

## Microsoft Edit 1.2.1

```bash
bash grow_glochidium.sh https://github.com/microsoft/edit msedit "cargo build --config .cargo/release-nightly.toml --release"
```

## GNU Make 4.4.1

```bash
bash grow_glochidium.sh https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz make "./configure LDFLAGS=-static && make -j$(nproc)"
```

## Gawk 5.3.2

```bash
bash grow_glochidium.sh https://ftp.gnu.org/gnu/gawk/gawk-5.3.2.tar.xz gawk "./configure LDFLAGS=-static && make -j$(nproc)"
```

## ble.sh 0.4.0-devel

```bash
bash grow_glochidium.sh https://github.com/akinomyoga/ble.sh.git ble
```

## starship 1.24.1

```bash
bash grow_glochidium.sh https://github.com/starship/starship.git starship "cargo build --release"
```

## fastfetch 2.56.1-66

```bash
bash grow_glochidium.sh https://github.com/fastfetch-cli/fastfetch.git fastfetch "cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF && cmake --build build"
```

**To be tested:**

- Suggestions?
