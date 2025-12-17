use anyhow::{Context, Result};
use indicatif::{ProgressBar, ProgressStyle};
use sha2::{Digest, Sha256};
use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::Path;
use std::thread;
use std::time::Duration;

const MAX_RETRIES: u32 = 3;
const RETRY_DELAY_MS: u64 = 1000;

pub fn download_with_retry(url: &str, dest: &Path, expected_sha256: &str) -> Result<()> {
    let mut last_error = None;

    for attempt in 1..=MAX_RETRIES {
        match download_file(url, dest, expected_sha256) {
            Ok(_) => return Ok(()),
            Err(e) => {
                last_error = Some(e);
                if attempt < MAX_RETRIES {
                    eprintln!(
                        "Download attempt {} failed, retrying in {}ms...",
                        attempt, RETRY_DELAY_MS
                    );
                    thread::sleep(Duration::from_millis(RETRY_DELAY_MS));
                }
            }
        }
    }

    Err(last_error.unwrap())
}

fn download_file(url: &str, dest: &Path, expected_sha256: &str) -> Result<()> {
    // Download to temporary file
    let temp_path = dest.with_extension("tmp");

    let mut response = reqwest::blocking::get(url)
        .context("Failed to start download")?
        .error_for_status()
        .context("Download URL returned error")?;

    let total_size = response.content_length().unwrap_or(0);

    let pb = ProgressBar::new(total_size);
    pb.set_style(
        ProgressStyle::default_bar()
            .template("{spinner:.green} [{elapsed_precise}] [{bar:40.cyan/blue}] {bytes}/{total_bytes} ({eta})")
            .unwrap()
            .progress_chars("#>-"),
    );

    let mut file = File::create(&temp_path).context("Failed to create temporary file")?;
    let mut downloaded = 0u64;
    let mut buffer = [0u8; 8192];

    loop {
        let n = response.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        file.write_all(&buffer[..n])?;
        downloaded += n as u64;
        pb.set_position(downloaded);
    }

    pb.finish_with_message("Download complete");
    drop(file);

    // Verify SHA256
    verify_sha256(&temp_path, expected_sha256)?;

    // Atomic move to final destination
    fs::rename(&temp_path, dest).context("Failed to move file to final destination")?;

    Ok(())
}

fn verify_sha256(path: &Path, expected: &str) -> Result<()> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 8192];

    loop {
        let n = file.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        hasher.update(&buffer[..n]);
    }

    let hash = hasher.finalize();
    let computed = format!("{:x}", hash);

    if computed != expected {
        anyhow::bail!(
            "SHA256 mismatch: expected {}, got {}",
            expected,
            computed
        );
    }

    Ok(())
}
