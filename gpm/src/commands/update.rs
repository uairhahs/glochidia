use anyhow::Result;
use std::fs;

use crate::config::Config;
use crate::manifest;

pub fn run(config: &Config) -> Result<()> {
    let cache_path = config.manifest_cache_path();

    // Remove cached manifest
    if cache_path.exists() {
        fs::remove_file(&cache_path)?;
        println!("Removed cached manifest");
    }

    // Fetch fresh manifest
    println!("Fetching fresh manifest...");
    let manifest = manifest::fetch_manifest(config)?;

    println!(
        "Manifest updated successfully (v{}, {} tools available)",
        manifest.repo_version,
        manifest.tools.len()
    );

    Ok(())
}
