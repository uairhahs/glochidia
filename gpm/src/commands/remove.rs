use anyhow::{Context, Result};
use std::fs;

use crate::config::Config;
use crate::manifest;
use crate::pattern;

pub fn run(config: &Config, tool_patterns: &[String], all: bool) -> Result<()> {
    // Removing everything must be asked for explicitly
    if !all && tool_patterns.is_empty() {
        anyhow::bail!(
            "No tools specified. Pass tool names or patterns, or use --all to remove all tools."
        );
    }

    // Get list of installed tools
    let installed_tools = get_installed_tools(config)?;

    if installed_tools.is_empty() {
        println!("No tools are currently installed");
        return Ok(());
    }

    // Sanitize arguments - the all flag is treated as "*"
    let patterns = if all {
        vec!["*".to_string()]
    } else {
        pattern::sanitize(tool_patterns)
    };

    if patterns.is_empty() {
        anyhow::bail!("No valid tool patterns specified. Use --all to remove all tools.");
    }

    // Wildcards (including --all) only match files that are tools gpm manages: names listed
    // in the manifest, excluding gpm itself. Other files in the install directory are never
    // removed by a pattern; they can still be removed by exact name.
    let wildcard_candidates = if patterns.iter().any(|p| p.contains('*')) {
        let manifest = manifest::fetch_manifest(config)
            .context("Failed to load manifest, which is needed to resolve wildcard patterns")?;
        installed_tools
            .iter()
            .filter(|name| name.as_str() != "gpm" && manifest.tools.contains_key(name.as_str()))
            .cloned()
            .collect::<Vec<_>>()
    } else {
        Vec::new()
    };

    // Expand patterns to actual tool names
    let mut tools_to_remove = Vec::new();

    for pattern in &patterns {
        if pattern == "*" {
            // Remove all installed managed tools
            for tool_name in &wildcard_candidates {
                tools_to_remove.push(tool_name.clone());
            }
        } else if pattern.contains('*') {
            // Wildcard matching against installed managed tools
            for tool_name in &wildcard_candidates {
                if pattern::wildcard_match(pattern, tool_name) {
                    tools_to_remove.push(tool_name.clone());
                }
            }
        } else {
            // Exact tool name
            tools_to_remove.push(pattern.clone());
        }
    }

    if tools_to_remove.is_empty() {
        anyhow::bail!("No installed tools found matching the given patterns");
    }

    // Remove duplicates
    tools_to_remove.sort();
    tools_to_remove.dedup();

    println!("Removing {} tool(s)...", tools_to_remove.len());

    let mut removed_count = 0;
    let mut failed_tools = Vec::new();

    for tool_name in &tools_to_remove {
        match remove_single_tool(config, tool_name) {
            Ok(()) => {
                removed_count += 1;
                println!("  Removed {}", tool_name);
            }
            Err(e) => {
                eprintln!("  Failed to remove {}: {}", tool_name, e);
                failed_tools.push(tool_name.clone());
            }
        }
    }

    println!("\nSummary:");
    if removed_count > 0 {
        println!("  Removed: {}", removed_count);
    }
    if !failed_tools.is_empty() {
        println!(
            "  Failed: {} ({})",
            failed_tools.len(),
            failed_tools.join(", ")
        );
    }

    if !failed_tools.is_empty() {
        anyhow::bail!("Some tools failed to remove");
    }

    Ok(())
}

pub(crate) fn get_installed_tools(config: &Config) -> Result<Vec<String>> {
    let mut tools = Vec::new();

    if !config.install_dir.exists() {
        return Ok(tools);
    }

    for entry in fs::read_dir(&config.install_dir)? {
        let entry = entry?;
        let path = entry.path();

        if path.is_file() {
            if let Some(name) = path.file_name() {
                if let Some(name_str) = name.to_str() {
                    tools.push(name_str.to_string());
                }
            }
        }
    }

    tools.sort();
    Ok(tools)
}

fn remove_single_tool(config: &Config, tool_name: &str) -> Result<()> {
    let path = config.install_dir.join(tool_name);

    if !path.exists() {
        anyhow::bail!("Tool '{}' is not installed", tool_name);
    }

    fs::remove_file(&path)?;
    Ok(())
}
