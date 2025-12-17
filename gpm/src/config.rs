use anyhow::{Context, Result};
use std::fs;
use std::path::PathBuf;

pub struct Config {
    pub install_dir: PathBuf,
    pub cache_dir: PathBuf,
    pub manifest_url: String,
    pub verbose: bool,
}

impl Config {
    pub fn new(
        install_dir: String,
        cache_dir: String,
        manifest_url: String,
        verbose: bool,
    ) -> Result<Self> {
        let install_dir = PathBuf::from(install_dir);
        let cache_dir = PathBuf::from(cache_dir);

        // Create directories if they don't exist
        fs::create_dir_all(&install_dir)
            .context(format!("Failed to create install directory: {:?}", install_dir))?;
        fs::create_dir_all(&cache_dir)
            .context(format!("Failed to create cache directory: {:?}", cache_dir))?;

        Ok(Config {
            install_dir,
            cache_dir,
            manifest_url,
            verbose,
        })
    }

    pub fn manifest_cache_path(&self) -> PathBuf {
        self.cache_dir.join("manifest.json")
    }
}
