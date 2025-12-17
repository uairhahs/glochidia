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

### Upgrade a tool

```bash
gpm upgrade starship
```

### Remove a tool

```bash
gpm remove ble.sh
# Aliases: uninstall, rm
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
