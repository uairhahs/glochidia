use anyhow::{Context, Result};
use std::fs;
use std::os::unix::fs::PermissionsExt;

use crate::config::Config;
use crate::downloader;
use crate::manifest;

pub fn run(config: &Config, tool_name: &str) -> Result<()> {
    let manifest = manifest::fetch_manifest(config)?;

    let tool = manifest::find_tool(&manifest, tool_name)
        .ok_or_else(|| anyhow::anyhow!("Tool '{}' not found in manifest", tool_name))?;

    println!("Installing {} v{}", tool_name, tool.version);
    println!("  License: {}", tool.license);
    println!("  Size: {} bytes", tool.size);

    let dest = config.install_dir.join(tool_name);

    // Check if already installed
    if dest.exists() {
        anyhow::bail!(
            "Tool '{}' is already installed. Use 'gpm upgrade {}' to update.",
            tool_name,
            tool_name
        );
    }

    // Download with retry and verification
    downloader::download_with_retry(&tool.url, &dest, &tool.sha256)
        .context("Failed to download tool")?;

    // Make executable
    let metadata = fs::metadata(&dest)?;
    let mut permissions = metadata.permissions();
    permissions.set_mode(0o755);
    fs::set_permissions(&dest, permissions)?;

    println!("Successfully installed {} to {:?}", tool_name, dest);
    
    // Check if PATH is already configured
    if let Ok(path_env) = std::env::var("PATH") {
        let install_dir_str = config.install_dir.to_string_lossy();
        if !path_env.contains(&install_dir_str.to_string()) {
            println!("\nWarning: Install directory not in PATH");
            println!("Run 'gpm setup-path' to configure your shell automatically");
        }
    }

    Ok(())
}
