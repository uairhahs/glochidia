use std::env;
use std::ffi::CString;
use std::fs;
use std::process::{exit, Command};

fn check_locale_available(locale: &str) -> bool {
    // Try to get list of available locales
    if let Ok(output) = Command::new("locale").arg("-a").output() {
        let locales = String::from_utf8_lossy(&output.stdout);
        // Check for exact match or without encoding suffix
        if locales.lines().any(|l| l == locale) {
            return true;
        }
        // Check for case-insensitive match or partial match (e.g., C.UTF-8 vs C.utf8)
        let locale_lower = locale.to_lowercase();
        if locales.lines().any(|l| l.to_lowercase() == locale_lower) {
            return true;
        }
    }

    // Fallback: check if locale directory exists
    let locale_base = locale.split('.').next().unwrap_or(locale);
    let locale_path = format!("/usr/share/i18n/locales/{}", locale_base);
    std::path::Path::new(&locale_path).exists()
}

fn set_system_locale(locale: &str) -> Result<(), String> {
    // Call actual C library setlocale
    let locale_c = CString::new(locale).map_err(|e| format!("Invalid locale string: {}", e))?;

    unsafe {
        let result = libc::setlocale(libc::LC_ALL, locale_c.as_ptr());
        if result.is_null() {
            return Err(format!(
                "Failed to set locale '{}' - locale may not be available",
                locale
            ));
        }
    }

    Ok(())
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() != 2 {
        eprintln!("Usage: set_locale <locale>");
        eprintln!("Example: set_locale en_US.UTF-8");
        eprintln!("         set_locale C.UTF-8");
        eprintln!("\nRun 'locale -a' to see available locales");
        exit(1);
    }

    if args[1] == "--version" || args[1] == "-v" {
        println!("set_locale {}", env!("CARGO_PKG_VERSION"));
        exit(0);
    }

    let locale = &args[1];

    // Validate locale is available
    if !check_locale_available(locale) {
        eprintln!(
            "Warning: Locale '{}' may not be installed on this system",
            locale
        );
        eprintln!("Run 'locale -a' to see available locales");
    }

    // Set locale using C library function
    if let Err(e) = set_system_locale(locale) {
        eprintln!("Error: {}", e);
        exit(1);
    }

    eprintln!("Successfully set locale to: {}", locale);

    // Set locale environment variables
    let locale_vars = [
        "LANG",
        "LC_ALL",
        "LC_CTYPE",
        "LC_NUMERIC",
        "LC_TIME",
        "LC_COLLATE",
        "LC_MONETARY",
        "LC_MESSAGES",
        "LC_PAPER",
        "LC_NAME",
        "LC_ADDRESS",
        "LC_TELEPHONE",
        "LC_MEASUREMENT",
        "LC_IDENTIFICATION",
    ];

    // Write to /etc/locale.conf if writable (for persistence)
    if let Ok(_) = fs::write("/etc/locale.conf", format!("LANG={}\n", locale)) {
        eprintln!("Updated /etc/locale.conf for system-wide persistence");
    }

    // Output export statements for shell integration
    for var in &locale_vars {
        println!("export {}={}", var, locale);
    }

    eprintln!("\nTo apply in current shell, run:");
    eprintln!("  eval \"$(set_locale {})\"", locale);
}
