use std::fs::{self, File};
use std::io::{BufRead, BufReader};
use std::path::Path;
use std::process::{exit, Command};

const LOCALE_GEN_PATH: &str = "/etc/locale.gen";
const LOCALE_ARCHIVE: &str = "/usr/lib/locale/locale-archive";

fn is_root() -> bool {
    unsafe { libc::geteuid() == 0 }
}

fn parse_locale_gen() -> Result<Vec<(String, String)>, String> {
    let path = Path::new(LOCALE_GEN_PATH);

    if !path.exists() {
        return Ok(Vec::new());
    }

    let file =
        File::open(path).map_err(|e| format!("Failed to open {}: {}", LOCALE_GEN_PATH, e))?;

    let reader = BufReader::new(file);
    let mut locales = Vec::new();

    for line in reader.lines() {
        let line = line.map_err(|e| format!("Error reading line: {}", e))?;
        let line = line.trim();

        // Skip comments and empty lines
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        // Parse locale lines: "en_US.UTF-8 UTF-8" or "en_US UTF-8"
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 2 {
            locales.push((parts[0].to_string(), parts[1].to_string()));
        } else if parts.len() == 1 {
            // If only locale name provided, try to extract charset
            let locale = parts[0];
            if let Some(charset) = locale.split('.').nth(1) {
                locales.push((locale.to_string(), charset.to_string()));
            } else {
                eprintln!("Warning: Skipping malformed entry: {}", line);
            }
        }
    }

    Ok(locales)
}

fn generate_locale(locale: &str, charset: &str) -> Result<(), String> {
    eprintln!("Generating locale: {} {}", locale, charset);

    // Extract locale components
    let locale_name = locale.split('.').next().unwrap_or(locale);

    // Use localedef to compile the locale
    let status = Command::new("localedef")
        .arg("-i")
        .arg(locale_name)
        .arg("-f")
        .arg(charset)
        .arg(locale)
        .status()
        .map_err(|e| format!("Failed to execute localedef: {}", e))?;

    if !status.success() {
        return Err(format!("localedef failed for {}", locale));
    }

    eprintln!("  Generated: {}", locale);
    Ok(())
}

fn create_default_locale_gen() -> Result<(), String> {
    let default_content = r#"# This file lists locales that you wish to have built.
# Uncomment the locales you want to generate.
# Locales are specified as: locale charset

en_US.UTF-8 UTF-8
# en_GB.UTF-8 UTF-8
# de_DE.UTF-8 UTF-8
# fr_FR.UTF-8 UTF-8
# es_ES.UTF-8 UTF-8
# ja_JP.UTF-8 UTF-8
# zh_CN.UTF-8 UTF-8
C.UTF-8 UTF-8
"#;

    fs::write(LOCALE_GEN_PATH, default_content)
        .map_err(|e| format!("Failed to create {}: {}", LOCALE_GEN_PATH, e))?;

    eprintln!("Created default {} file", LOCALE_GEN_PATH);
    eprintln!("Edit this file and uncomment the locales you want to generate");
    Ok(())
}

fn list_available_locales() {
    eprintln!("Available locale definitions:");

    let locale_dir = "/usr/share/i18n/locales";
    if let Ok(entries) = fs::read_dir(locale_dir) {
        let mut locales: Vec<String> = entries
            .filter_map(|e| e.ok())
            .filter_map(|e| e.file_name().into_string().ok())
            .filter(|name| !name.starts_with('.'))
            .collect();

        locales.sort();
        for locale in locales {
            eprintln!("  {}", locale);
        }
    } else {
        eprintln!("Could not read locale directory: {}", locale_dir);
    }

    eprintln!("\nAvailable charmaps:");
    let charmap_dir = "/usr/share/i18n/charmaps";
    if let Ok(entries) = fs::read_dir(charmap_dir) {
        let mut charmaps: Vec<String> = entries
            .filter_map(|e| e.ok())
            .filter_map(|e| e.file_name().into_string().ok())
            .filter(|name| name.ends_with(".gz"))
            .map(|name| name.trim_end_matches(".gz").to_string())
            .collect();

        charmaps.sort();
        for charmap in charmaps {
            eprintln!("  {}", charmap);
        }
    } else {
        eprintln!("Could not read charmap directory: {}", charmap_dir);
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();

    // Check for help or list flags
    if args.len() > 1 {
        match args[1].as_str() {
            "-h" | "--help" => {
                println!("Usage: locale-gen [OPTIONS]");
                println!("\nGenerate locales based on /etc/locale.gen configuration");
                println!("\nOptions:");
                println!("  -h, --help          Show this help message");
                println!("  -v, --version       Show version information");
                println!("  -l, --list          List available locale definitions");
                println!("  --init              Create default /etc/locale.gen file");
                println!("\nWithout options, generates all locales listed in /etc/locale.gen");
                exit(0);
            }
            "-v" | "--version" => {
                println!("locale-gen {}", env!("CARGO_PKG_VERSION"));
                exit(0);
            }
            "-l" | "--list" => {
                list_available_locales();
                exit(0);
            }
            "--init" => {
                if !is_root() {
                    eprintln!("Error: Must be root to initialize {}", LOCALE_GEN_PATH);
                    exit(1);
                }
                match create_default_locale_gen() {
                    Ok(_) => exit(0),
                    Err(e) => {
                        eprintln!("Error: {}", e);
                        exit(1);
                    }
                }
            }
            _ => {
                eprintln!("Unknown option: {}", args[1]);
                eprintln!("Run 'locale-gen --help' for usage information");
                exit(1);
            }
        }
    }

    // Check for root privileges
    if !is_root() {
        eprintln!("Error: locale-gen must be run as root");
        exit(1);
    }

    // Check if localedef exists
    if Command::new("localedef").arg("--version").output().is_err() {
        eprintln!("Error: localedef command not found");
        eprintln!("Please install glibc-bin or libc-bin package");
        exit(1);
    }

    // Parse locale.gen file
    let locales = match parse_locale_gen() {
        Ok(locales) => locales,
        Err(e) => {
            eprintln!("Error: {}", e);
            eprintln!("\nRun 'locale-gen --init' to create a default configuration");
            exit(1);
        }
    };

    if locales.is_empty() {
        eprintln!("No locales to generate");
        eprintln!(
            "Edit {} and uncomment the locales you want",
            LOCALE_GEN_PATH
        );
        eprintln!("Or run 'locale-gen --init' to create a default configuration");
        exit(0);
    }

    eprintln!("Generating locales (this might take a while)...");

    let mut success_count = 0;
    let mut error_count = 0;

    for (locale, charset) in &locales {
        match generate_locale(locale, charset) {
            Ok(_) => success_count += 1,
            Err(e) => {
                eprintln!("Error: {}", e);
                error_count += 1;
            }
        }
    }

    eprintln!("\nGeneration complete!");
    eprintln!("  Success: {}", success_count);
    if error_count > 0 {
        eprintln!("  Errors: {}", error_count);
    }

    // Update locale cache if locale-archive exists
    if Path::new(LOCALE_ARCHIVE).exists() {
        eprintln!("\nTo see generated locales, run: locale -a");
    }
}
