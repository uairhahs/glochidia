use anyhow::{Context, Result};
use crate::config::Config;
use crate::downloader;
use crate::manifest;

pub fn run(config: &Config, tool_patterns: &[String], all: bool) -> Result<()> {
    let manifest = manifest::fetch_manifest(config)?;

    // Sanitize arguments - if all flag is set or no patterns provided, treat as "*"
    let patterns = if all || tool_patterns.is_empty() {
        vec!["*".to_string()]
    } else {
        // Filter out patterns that look like shell-expanded paths (contain / or .)
        tool_patterns
            .iter()
            .filter(|p| !p.contains('/') && !p.starts_with('.'))
            .cloned()
            .collect::<Vec<_>>()
    };

    if patterns.is_empty() {
        anyhow::bail!("No valid tool patterns specified. Use --all to install all tools.");
    }

    // Expand patterns to actual tool names
    let mut tools_to_install = Vec::new();

    for pattern in &patterns {
        if pattern == "*" {
            // Install all available tools
            for tool_name in manifest.tools.keys() {
                tools_to_install.push(tool_name.clone());
            }
        } else if pattern.contains('*') {
            // Simple wildcard matching
            for tool_name in manifest.tools.keys() {
                if wildcard_match(pattern, tool_name) {
                    tools_to_install.push(tool_name.clone());
                }
            }
        } else {
            // Exact tool name
            tools_to_install.push(pattern.clone());
        }
    }

    if tools_to_install.is_empty() {
        anyhow::bail!("No tools found matching the given patterns");
    }

    // Remove duplicates
    tools_to_install.sort();
    tools_to_install.dedup();

    println!("Processing {} tool(s)...", tools_to_install.len());

    let mut installed_count = 0;
    let mut upgraded_count = 0;
    let mut skipped_count = 0;
    let mut failed_tools = Vec::new();

    for tool_name in &tools_to_install {
        match install_single_tool(config, &manifest, tool_name) {
            Ok(InstallResult::Installed) => installed_count += 1,
            Ok(InstallResult::Upgraded) => upgraded_count += 1,
            Ok(InstallResult::Skipped) => skipped_count += 1,
            Err(e) => {
                eprintln!("Failed to install {}: {}", tool_name, e);
                failed_tools.push(tool_name.clone());
            }
        }
    }

    println!("\nSummary:");
    if installed_count > 0 {
        println!("  Installed: {}", installed_count);
    }
    if upgraded_count > 0 {
        println!("  Upgraded: {}", upgraded_count);
    }
    if skipped_count > 0 {
        println!("  Up to date: {}", skipped_count);
    }
    if !failed_tools.is_empty() {
        println!(
            "  Failed: {} ({})",
            failed_tools.len(),
            failed_tools.join(", ")
        );
    }

    // Check if PATH is configured (only show once)
    if installed_count > 0 || upgraded_count > 0 {
        if let Ok(path_env) = std::env::var("PATH") {
            let install_dir_str = config.install_dir.to_string_lossy();
            if !path_env.contains(&install_dir_str.to_string()) {
                println!("\nWarning: Install directory not in PATH");
                println!("Run 'gpm setup-path' to configure your shell automatically");
            }
        }
    }

    if !failed_tools.is_empty() {
        anyhow::bail!("Some tools failed to install");
    }

    Ok(())
}

fn wildcard_match(pattern: &str, text: &str) -> bool {
    let pattern_chars: Vec<char> = pattern.chars().collect();
    let text_chars: Vec<char> = text.chars().collect();

    fn match_recursive(pattern: &[char], text: &[char], p_idx: usize, t_idx: usize) -> bool {
        if p_idx == pattern.len() {
            return t_idx == text.len();
        }

        if pattern[p_idx] == '*' {
            // Try matching zero or more characters
            for i in t_idx..=text.len() {
                if match_recursive(pattern, text, p_idx + 1, i) {
                    return true;
                }
            }
            false
        } else {
            if t_idx < text.len() && pattern[p_idx] == text[t_idx] {
                match_recursive(pattern, text, p_idx + 1, t_idx + 1)
            } else {
                false
            }
        }
    }

    match_recursive(&pattern_chars, &text_chars, 0, 0)
}

#[derive(Debug)]
enum InstallResult {
    Installed,
    Upgraded,
    Skipped,
}

fn install_single_tool(
    config: &Config,
    manifest: &crate::manifest::Manifest,
    tool_name: &str,
) -> Result<InstallResult> {
    let tool = manifest::find_tool(manifest, tool_name)
        .ok_or_else(|| anyhow::anyhow!("Tool '{}' not found in manifest", tool_name))?;

    let dest = config.install_dir.join(tool_name);

    // An installed file whose hash matches the manifest is up to date. Comparing hashes
    // (rather than running the binary and parsing --version) works for every tool,
    // including scripts and tools whose reported version differs from the manifest.
    let is_upgrade = dest.exists();
    if is_upgrade {
        if let Ok(hash) = downloader::file_sha256(&dest) {
            if hash == tool.sha256 {
                println!(
                    "Tool '{}' v{} is already up to date",
                    tool_name, tool.version
                );
                return Ok(InstallResult::Skipped);
            }
        }
        // The existing binary is left in place until the new one is downloaded and
        // verified, so a failed download does not leave the tool missing.
    }

    let action = if is_upgrade {
        "Upgrading"
    } else {
        "Installing"
    };
    println!("{} {} v{}", action, tool_name, tool.version);
    println!("  License: {}", tool.license);
    println!("  Size: {} bytes", tool.size);

    // Download with retry and verification; replaces any existing binary atomically
    downloader::download_with_retry(&tool.url, &dest, &tool.sha256)
        .context("Failed to download tool")?;

    let result = if is_upgrade {
        InstallResult::Upgraded
    } else {
        InstallResult::Installed
    };
    let action_past = if is_upgrade { "upgraded" } else { "installed" };
    println!("Successfully {} {} to {:?}", action_past, tool_name, dest);
    Ok(result)
}
