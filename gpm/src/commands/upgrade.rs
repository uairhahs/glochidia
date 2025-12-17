use anyhow::{Context, Result};
use std::fs;
use std::os::unix::fs::PermissionsExt;

use crate::config::Config;
use crate::downloader;
use crate::manifest;

pub fn run(config: &Config, tool_name: &str) -> Result<()> {
    let dest = config.install_dir.join(tool_name);

    if !dest.exists() {
        anyhow::bail!(
            "Tool '{}' is not installed. Use 'gpm install {}' first.",
            tool_name,
            tool_name
        );
    }

    let manifest = manifest::fetch_manifest(config)?;

    let tool = manifest::find_tool(&manifest, tool_name)
        .ok_or_else(|| anyhow::anyhow!("Tool '{}' not found in manifest", tool_name))?;

    println!("Upgrading {} to v{}", tool.name, tool.version);
    println!("  License: {}", tool.license);
    println!("  Size: {} bytes", tool.size);

    let temp_dest = config.install_dir.join(format!("{}.upgrade", tool_name));

    // Download to temporary location
    downloader::download_with_retry(&tool.url, &temp_dest, &tool.sha256)
        .context("Failed to download upgrade")?;

    // Make executable
    let metadata = fs::metadata(&temp_dest)?;
    let mut permissions = metadata.permissions();
    permissions.set_mode(0o755);
    fs::set_permissions(&temp_dest, permissions)?;

    // Atomic replace
    fs::rename(&temp_dest, &dest).context("Failed to replace binary")?;

    println!("Successfully upgraded {} to v{}", tool.name, tool.version);

    Ok(())
}
