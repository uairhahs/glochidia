use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "gpm")]
#[command(about = "Glochidia Package Manager - Install static binaries", long_about = None)]
#[command(version)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,

    /// Installation directory for binaries
    #[arg(long, global = true, default_value = "/DATA/AppData/glochidia/bin")]
    pub install_dir: String,

    /// Cache directory for manifest and temporary files
    #[arg(long, global = true, default_value = "/DATA/AppData/glochidia/.cache")]
    pub cache_dir: String,

    /// Manifest URL
    #[arg(
        long,
        global = true,
        default_value = "https://github.com/uairhahs/glochidia/releases/download/latest/manifest.json"
    )]
    pub manifest_url: String,

    /// Enable verbose output
    #[arg(short, long, global = true)]
    pub verbose: bool,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Install or upgrade one or more tools
    Install {
        /// Names or patterns of tools to install/upgrade (supports wildcards like 'g*' or '*')
        tool_names: Vec<String>,

        /// Install all available tools
        #[arg(short, long)]
        all: bool,
    },
    /// List installed tools
    List,
    /// List available tools from manifest
    #[command(name = "list-remote")]
    ListRemote,
    /// Remove one or more installed tools
    #[command(alias = "uninstall", alias = "rm")]
    Remove {
        /// Names or patterns of tools to remove (supports wildcards like 'g*' or '*')
        tool_names: Vec<String>,

        /// Remove all installed tools
        #[arg(short, long)]
        all: bool,
    },
    /// Update manifest cache
    Update,

    /// Configure shell PATH for installed binaries
    #[command(name = "setup-path")]
    SetupPath,
}

pub fn parse() -> Cli {
    Cli::parse()
}
