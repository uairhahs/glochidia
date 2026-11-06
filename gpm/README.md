# gpm - Glochidia Package Manager

A lightweight package manager for installing static binary tools on ZimaOS.

## Features

- **Install static binaries** from curated manifest
- **SHA256 verification** for security
- **Automatic retries** for network resilience
- **Progress bars** for downloads
- **Manifest caching** (24-hour TTL)
- **Atomic operations** for safe upgrades

## Installation

Build static binary using Alpine Linux container (ZimaOS compatible):

```bash
cd /path/to/glochidia
podman run --rm -v "$(pwd)/gpm:/src:Z" -w /src rust:alpine sh -c '
  apk add --no-cache musl-dev >/dev/null 2>&1 &&
  cargo build --release --target x86_64-unknown-linux-musl &&
  strip target/x86_64-unknown-linux-musl/release/gpm &&
  cp target/x86_64-unknown-linux-musl/release/gpm /src/gpm-bin
'
# Binary at gpm/gpm-bin
```

To package it as the ZimaOS RAW extension (needs `mksquashfs`):

```bash
bash zpkg/build-zpkg.sh gpm/gpm-bin gpm.raw
```

Built binaries and `gpm.raw` are not committed; CI builds and publishes them.

Or for local development (may not work on ZimaOS):

```bash
cd gpm
cargo build --release
# Binary at target/release/gpm
```

## Usage

### Install a tool

```bash
gpm install make
```

### List installed tools

```bash
gpm list
```

### List available tools

```bash
gpm list-remote
```

### Upgrade tools

```bash
gpm upgrade             # every installed tool (gpm included)
gpm upgrade starship    # one tool
gpm upgrade 'g*'        # installed tools matching a pattern
```

`upgrade` always fetches a fresh manifest and only downloads tools whose published
binary differs from the installed one. Use `gpm install` for tools not yet installed.

### Remove a tool

```bash
gpm remove ble.sh
gpm remove 'g*'       # wildcard: only matches tools from the manifest
gpm remove --all      # all manifest tools; gpm itself and other files are kept
# Aliases: uninstall, rm
# Running 'gpm remove' with no arguments is an error.
```

### Update manifest cache

```bash
gpm update
```

## Configuration

Global flags:

- `--install-dir` - Installation directory (default: `/DATA/AppData/glochidia/bin`)
- `--cache-dir` - Cache directory (default: `/DATA/AppData/glochidia/.cache`)
- `--manifest-url` - Manifest URL (default: GitHub releases)
- `--verbose` - Enable verbose output

Example:

```bash
gpm --install-dir ~/bin --verbose install fastfetch
```

## Development

Run tests:

```bash
cargo test
```

Run with logging:

```bash
RUST_LOG=debug cargo run -- install make
```

## License

GPL-2.0-or-later
