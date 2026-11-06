use anyhow::Result;

use crate::commands::install::{self, InstallResult};
use crate::commands::remove;
use crate::config::Config;
use crate::manifest;
use crate::pattern;

pub fn run(config: &Config, tool_patterns: &[String]) -> Result<()> {
    // Upgrading is about getting the latest versions, so never trust a cached manifest
    let manifest = manifest::refresh_manifest(config)?;

    // Only tools gpm manages: installed files that are listed in the manifest
    let installed: Vec<String> = remove::get_installed_tools(config)?
        .into_iter()
        .filter(|name| manifest.tools.contains_key(name.as_str()))
        .collect();

    if installed.is_empty() {
        println!("No gpm-managed tools are installed. Use 'gpm install <tool>' first.");
        return Ok(());
    }

    let mut targets = Vec::new();
    let mut not_installed = Vec::new();

    if tool_patterns.is_empty() {
        targets = installed.clone();
    } else {
        let patterns = pattern::sanitize(tool_patterns);
        if patterns.is_empty() {
            anyhow::bail!("No valid tool patterns specified");
        }
        for pattern in &patterns {
            if pattern.contains('*') {
                targets.extend(
                    installed
                        .iter()
                        .filter(|name| pattern::wildcard_match(pattern, name))
                        .cloned(),
                );
            } else if installed.contains(pattern) {
                targets.push(pattern.clone());
            } else {
                not_installed.push(pattern.clone());
            }
        }
    }

    for name in &not_installed {
        eprintln!("'{}' is not installed (use 'gpm install {}')", name, name);
    }

    targets.sort();
    targets.dedup();

    if targets.is_empty() {
        anyhow::bail!("No installed tools match the given names or patterns");
    }

    println!("Checking {} tool(s) for upgrades...", targets.len());

    let mut upgraded = 0;
    let mut up_to_date = 0;
    let mut failed = Vec::new();

    for name in &targets {
        match install::install_single_tool(config, &manifest, name) {
            Ok(InstallResult::Upgraded) | Ok(InstallResult::Installed) => upgraded += 1,
            Ok(InstallResult::Skipped) => up_to_date += 1,
            Err(e) => {
                eprintln!("Failed to upgrade {}: {:#}", name, e);
                failed.push(name.clone());
            }
        }
    }

    println!("\nSummary:");
    if upgraded > 0 {
        println!("  Upgraded: {}", upgraded);
    }
    if up_to_date > 0 {
        println!("  Up to date: {}", up_to_date);
    }
    if !failed.is_empty() {
        println!("  Failed: {} ({})", failed.len(), failed.join(", "));
    }

    if !failed.is_empty() || !not_installed.is_empty() {
        anyhow::bail!("Some tools could not be upgraded");
    }

    Ok(())
}
