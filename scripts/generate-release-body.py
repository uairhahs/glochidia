#!/usr/bin/env python3
"""
generate-release-body.py - Generate release body markdown
"""
import json
import sys


def main():
    if len(sys.argv) < 4:
        print(
            "Usage: generate-release-body.py <repo> <release_tag> <build_info> [commit]"
        )
        sys.exit(1)

    repo = sys.argv[1]
    release_tag = sys.argv[2]
    build_info = sys.argv[3]
    commit = sys.argv[4] if len(sys.argv) > 4 else "unknown"

    with open("release-files/manifest.json", "r") as f:
        manifest = json.load(f)

    with open("release-body.md", "w") as f:
        f.write("## Static Binaries for ZimaOS\n\n")
        f.write(
            "Built from source with GPL compliance. All binaries are statically linked and verified.\n\n"
        )
        f.write("### Available Tools\n")

        for tool_name in sorted(manifest["tools"].keys()):
            tool = manifest["tools"][tool_name]
            # Strip leading 'v' from version if present to avoid 'vv' prefix
            version = tool["version"].lstrip("v") if tool["version"] else "unknown"
            f.write(f"- **{tool_name}** v{version} - {tool['description']}\n")

        f.write("\n### Installation\n")
        f.write("```bash\n")
        f.write("# Download and install gpm\n")
        f.write(f"wget https://github.com/{repo}/releases/download/{release_tag}/gpm\n")
        f.write("chmod +x gpm\n")
        f.write("mv gpm /DATA/bin/\n\n")
        f.write("# Configure PATH and install tools\n")
        f.write("gpm setup-path\n")
        f.write("source ~/.bashrc\n")
        f.write("gpm install make\n")
        f.write("gpm install gawk\n")
        f.write("gpm list\n")
        f.write("```\n\n")
        f.write("### Verification\n")
        f.write("- `manifest.json` - SHA256 checksums for all binaries\n")
        f.write("- `SOURCES.txt` - Source code provenance\n")
        f.write("- `COPYING` - GPL compliance notice\n")
        f.write("- `licenses/` - Full license texts\n\n")
        f.write("### Build Information\n")
        f.write(f"- Built: {build_info}\n")
        f.write(f"- Commit: {commit}\n")
        f.write("- All binaries verified as statically linked\n")

    print("Generated release body with tool versions")


if __name__ == "__main__":
    main()
