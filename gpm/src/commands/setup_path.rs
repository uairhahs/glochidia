use anyhow::{Context, Result};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use crate::config::Config;

const BLOCK_BEGIN: &str = "# >>> gpm (Glochidia Package Manager) >>>";
const BLOCK_END: &str = "# <<< gpm (Glochidia Package Manager) <<<";
const LEGACY_MARKER: &str = "# Added by gpm (Glochidia Package Manager)";

#[derive(Clone, Copy, PartialEq, Debug)]
enum Shell {
    /// bash and POSIX sh (busybox ash, dash)
    Posix,
    Zsh,
}

pub fn run(config: &Config) -> Result<()> {
    let home_dir = env::var("HOME").context("HOME environment variable not set")?;
    let home = PathBuf::from(&home_dir);
    let install_dir = config.install_dir.to_string_lossy().to_string();

    println!("Setting up PATH for gpm binaries...");
    println!("Install directory: {}", install_dir);
    println!();

    // One file per shell: bash reads .bashrc for interactive shells (and .bash_profile
    // usually sources it), so writing to several files only duplicates the setup.
    let posix_target = [".bashrc", ".bash_profile", ".profile"]
        .iter()
        .map(|f| home.join(f))
        .find(|p| p.exists());
    let zsh_target = Some(home.join(".zshrc")).filter(|p| p.exists());

    let mut targets: Vec<(PathBuf, Shell)> = Vec::new();
    if let Some(p) = posix_target {
        targets.push((p, Shell::Posix));
    }
    if let Some(p) = zsh_target {
        targets.push((p, Shell::Zsh));
    }

    if targets.is_empty() {
        println!("Warning: No shell configuration files found.");
        println!();
        println!("Add this to your shell config manually:");
        println!();
        println!("{}", managed_block(&config.install_dir, Shell::Posix));
        return Ok(());
    }

    // Earlier gpm versions wrote a block to every config file they found. Clean those up,
    // including in files that are no longer targets.
    for name in [".bashrc", ".bash_profile", ".profile", ".zshrc"] {
        let path = home.join(name);
        if targets.iter().any(|(t, _)| *t == path) || !path.exists() {
            continue;
        }
        let content = read(&path)?;
        let cleaned = remove_legacy_block(&content, &config.install_dir);
        if cleaned != content {
            write(&path, &cleaned)?;
            println!("Removed outdated gpm setup from {}", name);
        }
    }

    let mut changed = false;
    for (path, shell) in &targets {
        let name = path.file_name().unwrap().to_string_lossy().to_string();
        let content = read(path)?;
        let block = managed_block(&config.install_dir, *shell);
        match apply_block(&content, &block, &config.install_dir) {
            Some(new_content) => {
                write(path, &new_content)?;
                println!("Configured {}", name);
                changed = true;
            }
            None => println!("Already configured: {}", name),
        }
    }

    if changed {
        println!();
        println!("To apply changes, start a new shell or run:");
        for (path, _) in &targets {
            println!("  source {}", path.display());
        }
        println!();
        println!("The gpm alias disables shell globbing for its arguments, so patterns");
        println!("such as 'gpm install g*' reach gpm intact.");
    }

    Ok(())
}

fn read(path: &Path) -> Result<String> {
    fs::read_to_string(path).with_context(|| format!("Failed to read {}", path.display()))
}

fn write(path: &Path, content: &str) -> Result<()> {
    fs::write(path, content).with_context(|| format!("Failed to write {}", path.display()))
}

/// The shell snippet gpm manages, delimited by begin/end markers so it can be updated
/// in place later.
fn managed_block(install_dir: &Path, shell: Shell) -> String {
    let dir = install_dir.to_string_lossy();
    let gpm = install_dir.join("gpm");
    let gpm = gpm.to_string_lossy();
    // Globbing must be disabled before the shell expands the arguments. A function cannot
    // do that (its arguments are expanded before its body runs), so an alias switches
    // globbing off first and the function restores the previous state and exit status.
    let wrapper = match shell {
        Shell::Posix => format!(
            "alias gpm='_gpm_glob=$-; set -f; _gpm_run'\n\
             _gpm_run() {{\n\
             \x20   \"{gpm}\" \"$@\"\n\
             \x20   _gpm_rc=$?\n\
             \x20   case $_gpm_glob in *f*) ;; *) set +f ;; esac\n\
             \x20   return $_gpm_rc\n\
             }}"
        ),
        Shell::Zsh => format!("alias gpm='noglob \"{gpm}\"'"),
    };
    format!("{BLOCK_BEGIN}\nexport PATH=\"{dir}:$PATH\"\n{wrapper}\n{BLOCK_END}")
}

/// The exact block earlier gpm versions prepended to every shell config file.
fn legacy_block(install_dir: &Path) -> String {
    format!(
        "{LEGACY_MARKER}\nexport PATH=\"{}:$PATH\"\n# gpm wrapper to handle shell globbing\ngpm() {{\n    set -f\n    {} \"$@\"\n    set +f\n}}\n\n",
        install_dir.to_string_lossy(),
        install_dir.join("gpm").to_string_lossy()
    )
}

fn remove_legacy_block(content: &str, install_dir: &Path) -> String {
    content.replacen(&legacy_block(install_dir), "", 1)
}

/// Return the new file content with `block` installed, or None when nothing changes.
/// Replaces an existing managed block or a legacy block; otherwise prepends the block,
/// unless the install directory is already referenced (configured by hand).
fn apply_block(content: &str, block: &str, install_dir: &Path) -> Option<String> {
    if let (Some(start), Some(end)) = (content.find(BLOCK_BEGIN), content.find(BLOCK_END)) {
        if start < end {
            let end = end + BLOCK_END.len();
            if &content[start..end] == block {
                return None;
            }
            return Some(format!("{}{}{}", &content[..start], block, &content[end..]));
        }
    }

    let legacy = legacy_block(install_dir);
    if content.contains(&legacy) {
        return Some(content.replacen(&legacy, &format!("{block}\n\n"), 1));
    }

    if content.contains(&*install_dir.to_string_lossy()) {
        return None;
    }

    Some(format!("{block}\n\n{content}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn dir() -> PathBuf {
        PathBuf::from("/DATA/AppData/glochidia/bin")
    }

    #[test]
    fn prepends_block_to_fresh_file() {
        let block = managed_block(&dir(), Shell::Posix);
        let out = apply_block("alias ll='ls -l'\n", &block, &dir()).unwrap();
        assert!(out.starts_with(BLOCK_BEGIN));
        assert!(out.ends_with("alias ll='ls -l'\n"));
    }

    #[test]
    fn is_idempotent() {
        let block = managed_block(&dir(), Shell::Posix);
        let once = apply_block("x\n", &block, &dir()).unwrap();
        assert_eq!(apply_block(&once, &block, &dir()), None);
    }

    #[test]
    fn updates_existing_managed_block_in_place() {
        let old = format!("a\n{BLOCK_BEGIN}\nold stuff\n{BLOCK_END}\nb\n");
        let block = managed_block(&dir(), Shell::Posix);
        let out = apply_block(&old, &block, &dir()).unwrap();
        assert_eq!(out, format!("a\n{block}\nb\n"));
    }

    #[test]
    fn replaces_legacy_block() {
        let content = format!("{}rest\n", legacy_block(&dir()));
        let block = managed_block(&dir(), Shell::Posix);
        let out = apply_block(&content, &block, &dir()).unwrap();
        assert_eq!(out, format!("{block}\n\nrest\n"));
        assert!(!out.contains(LEGACY_MARKER));
    }

    #[test]
    fn leaves_hand_configured_file_alone() {
        let content = "export PATH=\"/DATA/AppData/glochidia/bin:$PATH\"\n";
        let block = managed_block(&dir(), Shell::Posix);
        assert_eq!(apply_block(content, &block, &dir()), None);
    }

    #[test]
    fn removes_legacy_block_only() {
        let content = format!("top\n{}bottom\n", legacy_block(&dir()));
        assert_eq!(remove_legacy_block(&content, &dir()), "top\nbottom\n");
        assert_eq!(remove_legacy_block("untouched\n", &dir()), "untouched\n");
    }
}
