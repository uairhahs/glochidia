use std::env;
use std::fs;
use std::process;

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() != 2 {
        eprintln!("Usage: set_locale <locale>");
        eprintln!("Example: set_locale en_US.UTF-8");
        process::exit(1);
    }

    let locale = &args[1];

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

    println!("Setting locale to: {}", locale);

    // Write to /etc/locale.conf if writable
    if let Ok(_) = fs::write("/etc/locale.conf", format!("LANG={}\n", locale)) {
        println!("Updated /etc/locale.conf");
    }

    // Export for current session
    for var in &locale_vars {
        env::set_var(var, locale);
        println!("export {}={}", var, locale);
    }

    println!("Locale set successfully. Restart shell or source profile to apply.");
}
