#!/usr/bin/env python3
"""
generate-manifest.py - Generate manifest.json for binary distribution
"""
import hashlib
import json
import os
import sys
from datetime import datetime


def read_version(tool_name, repo_version="1.0.0"):
    """Read version from version file with robust fallback logic"""
    version_file = f"versions/{tool_name}.version"
    if os.path.exists(version_file):
        with open(version_file, "r") as f:
            version = f.read().strip()
            # Remove 'v' prefix if present
            version = version.lstrip("v")
            if version and version != "unknown" and version != "":
                return version

    # Explicit fallbacks per tool
    fallback_versions = {
        "gpm": repo_version,
        "set_locale": repo_version,
        "ble.sh": "0.4.0",
    }
    return fallback_versions.get(tool_name, "unknown")


def load_tools_metadata(repo):
    """Load and process tools metadata from JSON file"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    metadata_file = os.path.join(script_dir, "tools-metadata.json")

    with open(metadata_file, "r") as f:
        metadata = json.load(f)

    # Replace {repo} placeholders
    for tool_data in metadata.values():
        if "source_url" in tool_data:
            tool_data["source_url"] = tool_data["source_url"].format(repo=repo)

    return metadata


def main():
    if len(sys.argv) < 3:
        print("Usage: generate-manifest.py <repo> <release_tag> [repo_version]")
        sys.exit(1)

    repo = sys.argv[1]
    release_tag = sys.argv[2]
    repo_version = sys.argv[3] if len(sys.argv) > 3 else "1.0.0"

    tools_metadata = load_tools_metadata(repo)

    manifest = {
        "repo_version": repo_version,
        "updated_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "tools": {},
    }

    if not os.path.exists("release-files"):
        print("Error: release-files directory not found")
        sys.exit(1)

    for tool_name in os.listdir("release-files"):
        if tool_name.startswith("."):
            continue

        filepath = f"release-files/{tool_name}"
        if not os.path.isfile(filepath):
            continue

        with open(filepath, "rb") as f:
            data = f.read()
            sha256 = hashlib.sha256(data).hexdigest()
            size = len(data)

        if tool_name not in tools_metadata:
            print(f"Warning: No metadata for {tool_name}")
            continue

        metadata = tools_metadata[tool_name]
        tool_version = read_version(tool_name, repo_version)

        tool_entry = {
            "version": tool_version,
            "description": metadata["description"],
            "url": f"https://github.com/{repo}/releases/download/{release_tag}/{tool_name}",
            "sha256": sha256,
            "size": size,
            "build_type": metadata["build_type"],
            "license": metadata["license"],
            "source_url": metadata["source_url"],
        }

        if "source_sha256" in metadata:
            tool_entry["source_sha256"] = metadata["source_sha256"]

        manifest["tools"][tool_name] = tool_entry
        print(
            f"Added {tool_name}: {size} bytes, SHA256: {sha256[:16]}..., Version: {tool_version}"
        )

    with open("release-files/manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)

    print("\nGenerated manifest:")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
