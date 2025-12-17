mod install;
mod list;
mod list_remote;
mod remove;
mod setup_path;
mod update;
mod upgrade;

use anyhow::Result;

use crate::cli::{Cli, Commands};
use crate::config::Config;

pub fn execute(cli: Cli) -> Result<()> {
    let config = Config::new(
        cli.install_dir,
        cli.cache_dir,
        cli.manifest_url,
        cli.verbose,
    )?;

    match cli.command {
        Commands::Install { tool_name } => install::run(&config, &tool_name),
        Commands::List => list::run(&config),
        Commands::ListRemote => list_remote::run(&config),
        Commands::Remove { tool_name } => remove::run(&config, &tool_name),
        Commands::Update => update::run(&config),
        Commands::Upgrade { tool_name } => upgrade::run(&config, &tool_name),
        Commands::SetupPath => setup_path::run(&config),
    }
}
