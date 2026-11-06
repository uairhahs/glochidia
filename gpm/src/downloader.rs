use anyhow::{Context, Result};
use indicatif::{ProgressBar, ProgressStyle};
use sha2::{Digest, Sha256};
use std::fs::{self, File};
use std::io::{Read, Write};
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
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

    // Do not leave a partial download behind in the install directory
    let _ = fs::remove_file(temp_path_for(dest));
    Err(last_error.unwrap())
}

fn download_file(url: &str, dest: &Path, expected_sha256: &str) -> Result<()> {
    // Download to a temporary file next to the destination. The existing binary (if any)
    // stays in place until the new one is verified, then gets replaced atomically.
    let temp_path = temp_path_for(dest);

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

    // Verify SHA256 and make executable before swapping it in
    if let Err(e) = verify_sha256(&temp_path, expected_sha256) {
        let _ = fs::remove_file(&temp_path);
        return Err(e);
    }
    fs::set_permissions(&temp_path, fs::Permissions::from_mode(0o755))
        .context("Failed to make downloaded file executable")?;

    // Atomic replace of the final destination
    fs::rename(&temp_path, dest).context("Failed to move file to final destination")?;

    Ok(())
}

fn temp_path_for(dest: &Path) -> PathBuf {
    let mut name = dest.file_name().unwrap_or_default().to_os_string();
    name.push(".gpm-download");
    dest.with_file_name(name)
}

fn verify_sha256(path: &Path, expected: &str) -> Result<()> {
    let computed = file_sha256(path)?;

    if computed != expected {
        anyhow::bail!("SHA256 mismatch: expected {}, got {}", expected, computed);
    }

    Ok(())
}

pub fn file_sha256(path: &Path) -> Result<String> {
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

    Ok(format!("{:x}", hasher.finalize()))
}
