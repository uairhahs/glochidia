use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::time::SystemTime;

use crate::config::Config;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Manifest {
    pub repo_version: String,
    pub updated_at: String,
    pub tools: HashMap<String, Tool>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Tool {
    pub version: String,
    pub description: String,
    pub url: String,
    pub sha256: String,
    pub size: u64,
    pub build_type: String,
    pub license: String,
    pub source_url: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub source_sha256: Option<String>,
}

const CACHE_TTL_HOURS: i64 = 24;

pub fn fetch_manifest(config: &Config) -> Result<Manifest> {
    let cache_path = config.manifest_cache_path();

    // Check if cached manifest is fresh
    if let Ok(cached) = load_cached_manifest(config) {
        if config.verbose {
            println!("Using cached manifest");
        }
        return Ok(cached);
    }

    // Fetch fresh manifest
    if config.verbose {
        println!("Fetching manifest from {}", config.manifest_url);
    }

    let response = reqwest::blocking::get(&config.manifest_url)
        .context("Failed to fetch manifest")?
        .error_for_status()
        .context("Manifest URL returned error status")?;

    let manifest: Manifest = response.json().context("Failed to parse manifest JSON")?;

    // Cache the manifest
    let json = serde_json::to_string_pretty(&manifest)?;
    fs::write(&cache_path, json).context("Failed to write manifest cache")?;

    Ok(manifest)
}

fn load_cached_manifest(config: &Config) -> Result<Manifest> {
    let cache_path = config.manifest_cache_path();

    if !cache_path.exists() {
        anyhow::bail!("Cache file does not exist");
    }

    // Check cache age
    let metadata = fs::metadata(&cache_path)?;
    let modified = metadata.modified()?;
    let age = SystemTime::now().duration_since(modified)?;

    if age.as_secs() > (CACHE_TTL_HOURS * 3600) as u64 {
        anyhow::bail!("Cache is stale");
    }

    // Load and parse
    let json = fs::read_to_string(&cache_path)?;
    let manifest: Manifest = serde_json::from_str(&json)?;

    Ok(manifest)
}

pub fn find_tool<'a>(manifest: &'a Manifest, tool_name: &str) -> Option<&'a Tool> {
    manifest.tools.get(tool_name)
}
