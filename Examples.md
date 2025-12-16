# Examples with Native Alpine Build Pipeline

The `grow_glochidium.sh` script uses **native container builds in Alpine** instead of cross-compilation, providing:

- Simpler setup (no wrapper scripts needed)
- Better compatibility with projects using standard ./configure
- Automatic dependency installation within Alpine

## Prerequisites

1. **Podman** (or Docker): Used for Alpine container runtime

```bash
podman --version  # Should be 3.0+
```

2. **Alpine Base Image**: Ensure you have the latest Alpine image

```bash
podman pull alpine:latest
```

**Status**: ✅ Successfully tested and deployed

## Microsoft Edit

```bash
bash grow_glochidium.sh https://github.com/microsoft/edit msedit "cargo build --config .cargo/release-nightly.toml --release"
```

## GNU Make 4.4.1

```bash
bash grow_glochidium.sh https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz make "./configure LDFLAGS=-static && make -j$(nproc)"
```

## Gawk 5.3.0 - Native Alpine Build

```bash
bash grow_glochidium.sh https://ftp.gnu.org/gnu/gawk/gawk-5.3.2.tar.xz gawk "./configure LDFLAGS=-static && make -j$(nproc)"
```

## ble.sh - Shell-based Example

```bash
bash grow_glochidium.sh https://github.com/akinomyoga/ble.sh.git ble
```

## starship 1.11.0

```bash
bash grow_glochidium.sh https://github.com/starship/starship.git starship "cargo build --release"
```

## fastfetch

```bash
bash grow_glochidium.sh https://github.com/fastfetch-cli/fastfetch.git fastfetch "cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF && cmake --build build"
```

**To be tested:**

- Suggestions?
