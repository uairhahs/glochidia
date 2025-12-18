use anyhow::{Context, Result};
use std::fs;
use std::os::unix::fs::PermissionsExt;

use crate::config::Config;
use crate::downloader;
use crate::manifest;

pub fn run(config: &Config, tool_patterns: &[String]) -> Result<()> {
    let manifest = manifest::fetch_manifest(config)?;

    // Expand patterns to actual tool names
    let mut tools_to_install = Vec::new();

    for pattern in tool_patterns {
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

    // Check if already installed and compare versions
    let is_upgrade = if dest.exists() {
        // Try to get current version
        if let Ok(current_version) = get_installed_version(&dest) {
            if current_version == tool.version {
                println!(
                    "Tool '{}' v{} is already up to date",
                    tool_name, tool.version
                );
                return Ok(InstallResult::Skipped);
            } else {
                println!(
                    "Upgrading {} from v{} to v{}",
                    tool_name, current_version, tool.version
                );
            }
        } else {
            println!(
                "Reinstalling {} v{} (version check failed)",
                tool_name, tool.version
            );
        }

        // Remove existing binary for upgrade
        fs::remove_file(&dest).context("Failed to remove existing binary")?;
        true
    } else {
        false
    };

    let action = if is_upgrade {
        "Upgrading"
    } else {
        "Installing"
    };
    println!("{} {} v{}", action, tool_name, tool.version);
    println!("  License: {}", tool.license);
    println!("  Size: {} bytes", tool.size);

    // Download with retry and verification
    downloader::download_with_retry(&tool.url, &dest, &tool.sha256)
        .context("Failed to download tool")?;

    // Make executable
    let metadata = fs::metadata(&dest)?;
    let mut permissions = metadata.permissions();
    permissions.set_mode(0o755);
    fs::set_permissions(&dest, permissions)?;

    let result = if is_upgrade {
        InstallResult::Upgraded
    } else {
        InstallResult::Installed
    };
    let action_past = if is_upgrade { "upgraded" } else { "installed" };
    println!("Successfully {} {} to {:?}", action_past, tool_name, dest);
    Ok(result)
}

fn get_installed_version(binary_path: &std::path::Path) -> Result<String> {
    use std::process::Command;

    // Try common version flags
    let version_flags = ["--version", "-V", "-v"];

    for flag in &version_flags {
        if let Ok(output) = Command::new(binary_path).arg(flag).output() {
            if output.status.success() {
                let version_output = String::from_utf8_lossy(&output.stdout);
                // Extract version number (first sequence of digits and dots)
                if let Some(version) = extract_version_number(&version_output) {
                    return Ok(version);
                }
            }
        }
    }

    anyhow::bail!("Could not determine version")
}

fn extract_version_number(text: &str) -> Option<String> {
    // Simple version extraction - look for first number.number pattern
    for line in text.lines() {
        for word in line.split_whitespace() {
            let cleaned = word.trim_start_matches('v');
            if cleaned.chars().next()?.is_ascii_digit() && cleaned.contains('.') {
                // Basic validation - starts with digit and contains dot
                let version_part: String = cleaned
                    .chars()
                    .take_while(|c| c.is_ascii_digit() || *c == '.' || *c == '-')
                    .collect();
                if !version_part.is_empty() {
                    return Some(version_part);
                }
            }
        }
    }
    None
}
