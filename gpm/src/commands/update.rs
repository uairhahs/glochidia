use anyhow::Result;

use crate::config::Config;
use crate::manifest;

pub fn run(config: &Config) -> Result<()> {
    println!("Fetching fresh manifest...");
    let manifest = manifest::refresh_manifest(config)?;

    println!(
        "Manifest updated successfully (v{}, {} tools available)",
        manifest.repo_version,
        manifest.tools.len()
    );

    Ok(())
}
