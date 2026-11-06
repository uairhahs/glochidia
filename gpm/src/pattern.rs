//! Tool name patterns shared by the install and remove commands.

/// Keep only arguments that look like tool names or patterns. Arguments containing '/'
/// or starting with '.' are almost always paths produced by the shell expanding an
/// unquoted glob (e.g. `gpm install *` in a non-empty directory), so they are dropped.
pub fn sanitize(args: &[String]) -> Vec<String> {
    args.iter()
        .filter(|p| !p.contains('/') && !p.starts_with('.'))
        .cloned()
        .collect()
}

/// Match `text` against `pattern`, where '*' matches any run of characters
/// (including none). All other characters match literally.
pub fn wildcard_match(pattern: &str, text: &str) -> bool {
    let pattern: Vec<char> = pattern.chars().collect();
    let text: Vec<char> = text.chars().collect();

    // Iterative matcher with single-star backtracking: linear in practice and free of
    // the exponential blowup a naive recursive matcher has on patterns like "*a*a*a*b".
    let (mut p, mut t) = (0, 0);
    let mut star: Option<usize> = None;
    let mut star_t = 0;

    while t < text.len() {
        if p < pattern.len() && pattern[p] == '*' {
            star = Some(p);
            star_t = t;
            p += 1;
        } else if p < pattern.len() && pattern[p] == text[t] {
            p += 1;
            t += 1;
        } else if let Some(s) = star {
            p = s + 1;
            star_t += 1;
            t = star_t;
        } else {
            return false;
        }
    }

    pattern[p..].iter().all(|&c| c == '*')
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn literal_patterns() {
        assert!(wildcard_match("make", "make"));
        assert!(!wildcard_match("make", "makes"));
        assert!(!wildcard_match("make", "mak"));
        assert!(wildcard_match("ble.sh", "ble.sh"));
        assert!(wildcard_match("", ""));
        assert!(!wildcard_match("", "a"));
    }

    #[test]
    fn star_patterns() {
        assert!(wildcard_match("*", "anything"));
        assert!(wildcard_match("*", ""));
        assert!(wildcard_match("g*", "gawk"));
        assert!(wildcard_match("g*", "gpm"));
        assert!(!wildcard_match("g*", "make"));
        assert!(wildcard_match("*sh", "ble.sh"));
        assert!(wildcard_match("s*_*e", "set_locale"));
        assert!(wildcard_match("**", "x"));
        assert!(!wildcard_match("*a*b", "aaaa"));
        assert!(wildcard_match("*a*b", "xaxb"));
    }

    #[test]
    fn pathological_pattern_is_fast() {
        let text = "a".repeat(200);
        assert!(!wildcard_match("*a*a*a*a*a*a*a*a*a*b", &text));
    }

    #[test]
    fn sanitize_drops_shell_expanded_paths() {
        let args: Vec<String> = ["make", "./gpm", "src/main.rs", ".bashrc", "g*"]
            .iter()
            .map(|s| s.to_string())
            .collect();
        assert_eq!(sanitize(&args), vec!["make", "g*"]);
    }
}
