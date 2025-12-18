use anyhow::Result;

use crate::config::Config;
use crate::manifest;

pub fn run(config: &Config) -> Result<()> {
    let manifest = manifest::fetch_manifest(config)?;

    println!("Available tools (Manifest v{}):\n", manifest.repo_version);
    println!(
        "{:<15}\t{:<10}\t{:<15}\t{}",
        "NAME", "VERSION", "LICENSE", "DESCRIPTION"
    );
    println!("{}", "-".repeat(80));

    for (name, tool) in &manifest.tools {
        println!(
            "{:<15}\t{:<10}\t{:<15}\t{}",
            name, tool.version, tool.license, tool.description
        );
    }

    println!("\nUse 'gpm install <name>' to install a tool");

    Ok(())
}
