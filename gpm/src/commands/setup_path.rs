use anyhow::{Context, Result};
use std::env;
use std::fs;
use std::path::PathBuf;

use crate::config::Config;

pub fn run(config: &Config) -> Result<()> {
    let home_dir = env::var("HOME").context("HOME environment variable not set")?;
    let home_path = PathBuf::from(&home_dir);

    let install_dir = config.install_dir.to_string_lossy();
    let path_export = format!("export PATH=\"{}:$PATH\"", install_dir);
    let marker_comment = "# Added by gpm (Glochidia Package Manager)";
    let gpm_wrapper = format!(
        "# gpm wrapper to handle shell globbing\ngpm() {{\n    set -f\n    {} \"$@\"\n    set +f\n}}",
        config.install_dir.join("gpm").to_string_lossy()
    );

    println!("Setting up PATH for gpm binaries...");
    println!("Install directory: {}", install_dir);
    println!();

    let mut modified_files = Vec::new();
    let mut already_configured = Vec::new();

    // Shell config files to check (in priority order)
    let shell_configs = vec![
        home_path.join(".bashrc"),
        home_path.join(".bash_profile"),
        home_path.join(".zshrc"),
        home_path.join(".profile"),
    ];

    for config_file in shell_configs {
        if !config_file.exists() {
            continue;
        }

        let file_name = config_file.file_name().unwrap().to_string_lossy();
        let content =
            fs::read_to_string(&config_file).context(format!("Failed to read {}", file_name))?;

        // Check if already configured
        if content.contains(&install_dir.to_string()) || content.contains(&marker_comment) {
            already_configured.push(file_name.to_string());
            continue;
        }

        // Prepend PATH configuration and gpm wrapper at the top
        let new_content = format!(
            "{marker_comment}\n{path_export}\n{gpm_wrapper}\n\n{content}",
            marker_comment = marker_comment,
            path_export = path_export,
            gpm_wrapper = gpm_wrapper,
            content = content
        );

        fs::write(&config_file, new_content)
            .context(format!("Failed to write to {}", file_name))?;

        modified_files.push(file_name.to_string());
    }

    // Report results
    if !modified_files.is_empty() {
        println!("Added PATH configuration and gpm wrapper to:");
        for file in &modified_files {
            println!("  - {}", file);
        }
        println!();
        println!("To apply changes, run:");
        println!("  source ~/.bashrc   # or ~/.zshrc, ~/.profile");
        println!();
        println!("The gpm wrapper prevents shell glob expansion issues.");
        println!("Or start a new shell session.");
    }

    if !already_configured.is_empty() {
        println!("Already configured in:");
        for file in &already_configured {
            println!("  - {}", file);
        }
    }

    if modified_files.is_empty() && already_configured.is_empty() {
        println!("Warning: No shell configuration files found.");
        println!();
        println!("You can manually add to your shell config:");
        println!("  {}", path_export);
        println!("  {}", gpm_wrapper);
    }

    Ok(())
}
