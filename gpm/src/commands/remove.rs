use anyhow::Result;
use std::fs;

use crate::config::Config;

pub fn run(config: &Config, tool_name: &str) -> Result<()> {
    let path = config.install_dir.join(tool_name);

    if !path.exists() {
        anyhow::bail!("Tool '{}' is not installed", tool_name);
    }

    fs::remove_file(&path)?;

    println!("Successfully removed {}", tool_name);

    Ok(())
}
