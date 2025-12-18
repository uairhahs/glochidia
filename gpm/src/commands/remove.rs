use anyhow::Result;
use std::fs;

use crate::config::Config;

pub fn run(config: &Config, tool_patterns: &[String], all: bool) -> Result<()> {
    // Get list of installed tools
    let installed_tools = get_installed_tools(config)?;

    if installed_tools.is_empty() {
        println!("No tools are currently installed");
        return Ok(());
    }

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
        anyhow::bail!("No valid tool patterns specified. Use --all to remove all tools.");
    }

    // Expand patterns to actual tool names
    let mut tools_to_remove = Vec::new();

    for pattern in &patterns {
        if pattern == "*" {
            // Remove all installed tools
            for tool_name in &installed_tools {
                tools_to_remove.push(tool_name.clone());
            }
        } else if pattern.contains('*') {
            // Wildcard matching against installed tools
            for tool_name in &installed_tools {
                if wildcard_match(pattern, tool_name) {
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

fn get_installed_tools(config: &Config) -> Result<Vec<String>> {
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

fn remove_single_tool(config: &Config, tool_name: &str) -> Result<()> {
    let path = config.install_dir.join(tool_name);

    if !path.exists() {
        anyhow::bail!("Tool '{}' is not installed", tool_name);
    }

    fs::remove_file(&path)?;
    Ok(())
}
