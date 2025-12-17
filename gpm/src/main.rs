mod cli;
mod commands;
mod config;
mod downloader;
mod manifest;

use anyhow::Result;

fn main() -> Result<()> {
    let cli = cli::parse();
    commands::execute(cli)
}
