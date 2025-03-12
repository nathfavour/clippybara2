//! Configuration handling for the Clippybara application.

use std::fs;
use std::path::{Path, PathBuf};

use dirs;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub server_url: String,
    pub auto_connect: bool,
    pub recent_servers: Vec<String>,
    pub start_minimized: bool,
    pub sync_interval: u64,  // in milliseconds
}

impl Default for Config {
    fn default() -> Self {
        Self {
            server_url: String::new(),
            auto_connect: true,
            recent_servers: Vec::new(),
            start_minimized: false,
            sync_interval: 500,
        }
    }
}

/// Get the path to the configuration file
pub fn get_config_path() -> PathBuf {
    let mut path = dirs::config_dir().unwrap_or_else(|| PathBuf::from("."));
    path.push("clippybara");
    fs::create_dir_all(&path).ok();
    path.push("config.json");
    path
}

/// Load configuration from disk
pub fn load_config() -> Config {
    let path = get_config_path();
    
    if path.exists() {
        match fs::read_to_string(&path) {
            Ok(content) => {
                match serde_json::from_str::<Config>(&content) {
                    Ok(config) => return config,
                    Err(e) => eprintln!("Error parsing config file: {}", e),
                }
            }
            Err(e) => eprintln!("Error reading config file: {}", e),
        }
    }

    // Create default config if not exists or error
    let default_config = Config::default();
    save_config(&default_config);
    default_config
}

/// Save configuration to disk
pub fn save_config(config: &Config) -> Result<(), String> {
    let path = get_config_path();
    
    // Create parent directories if they don't exist
    if let Some(parent) = path.parent() {
        match fs::create_dir_all(parent) {
            Ok(_) => {},
            Err(e) => return Err(format!("Failed to create config directory: {}", e)),
        }
    }
    
    // Write config to file
    match serde_json::to_string_pretty(config) {
        Ok(content) => {
            match fs::write(&path, content) {
                Ok(_) => Ok(()),
                Err(e) => Err(format!("Error writing config file: {}", e)),
            }
        },
        Err(e) => Err(format!("Error serializing config: {}", e)),
    }
}

/// Add a server URL to the recent servers list
pub fn add_recent_server(url: &str) -> Result<(), String> {
    let mut config = load_config();
    
    // Normalize the URL by removing trailing slashes
    let normalized_url = url.trim_end_matches('/').to_string();
    
    // Remove the URL if it already exists (to avoid duplicates)
    config.recent_servers.retain(|s| s != &normalized_url);
    
    // Add the URL to the top of the list
    config.recent_servers.insert(0, normalized_url);
    
    // Keep only the 10 most recent servers
    if config.recent_servers.len() > 10 {
        config.recent_servers.truncate(10);
    }
    
    save_config(&config)
}
