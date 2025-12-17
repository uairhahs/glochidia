use anyhow::Result;
use std::fs;

use crate::config::Config;

pub fn run(config: &Config) -> Result<()> {
    let entries = fs::read_dir(&config.install_dir)?;

    println!("Installed tools in {:?}:\n", config.install_dir);
    println!("{:<20}\t{}", "NAME", "SIZE");
    println!("{}", "-".repeat(40));

    let mut found_any = false;

    for entry in entries {
        let entry = entry?;
        let path = entry.path();

        if path.is_file() {
            let metadata = fs::metadata(&path)?;
            let name = path.file_name().unwrap().to_string_lossy();
            let size = metadata.len();

            println!("{:<20}\t{} bytes", name, size);
            found_any = true;
        }
    }

    if !found_any {
        println!("No tools installed");
    }

    Ok(())
}
