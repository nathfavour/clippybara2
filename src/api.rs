//! API client for interacting with noplacelike server.

use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};
use std::time::Duration;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClipboardRequest {
    pub text: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StatusResponse {
    pub status: String,
    pub error: Option<String>,
}

/// API client for interacting with the noplacelike server
#[derive(Debug, Clone)]
pub struct ApiClient {
    client: reqwest::Client,
    server_url: Arc<Mutex<String>>,
    connected: Arc<Mutex<bool>>,
}

impl ApiClient {
    /// Create a new API client
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(5))
            .build()
            .expect("Failed to create HTTP client");

        Self {
            client,
            server_url: Arc::new(Mutex::new(String::new())),
            connected: Arc::new(Mutex::new(false)),
        }
    }

    /// Set the server URL
    pub fn set_server_url(&self, url: &str) {
        let mut server_url = self.server_url.lock().unwrap();
        *server_url = url.to_string().trim_end_matches('/').to_string();
    }

    /// Get the current server URL
    pub fn get_server_url(&self) -> String {
        let server_url = self.server_url.lock().unwrap();
        server_url.clone()
    }

    /// Check if the client is connected to a server
    pub fn is_connected(&self) -> bool {
        let connected = self.connected.lock().unwrap();
        *connected
    }

    /// Test connection to the server
    pub async fn test_connection(&self) -> Result<bool, String> {
        let server_url = self.get_server_url();
        if server_url.is_empty() {
            return Ok(false);
        }

        match self.client.get(&format!("{}/api/clipboard", server_url)).send().await {
            Ok(response) => {
                let success = response.status().is_success();
                let mut connected = self.connected.lock().unwrap();
                *connected = success;
                Ok(success)
            }
            Err(e) => {
                let mut connected = self.connected.lock().unwrap();
                *connected = false;
                Err(format!("Connection error: {}", e))
            }
        }
    }

    /// Get clipboard content from the server
    pub async fn get_clipboard(&self) -> Result<String, String> {
        let server_url = self.get_server_url();
        if server_url.is_empty() {
            return Err("No server URL set".to_string());
        }

        match self.client.get(&format!("{}/api/clipboard", server_url)).send().await {
            Ok(response) => {
                if !response.status().is_success() {
                    return Err(format!("Server error: {}", response.status()));
                }

                match response.json::<ClipboardRequest>().await {
                    Ok(data) => Ok(data.text),
                    Err(e) => Err(format!("Failed to parse response: {}", e)),
                }
            }
            Err(e) => Err(format!("Request error: {}", e)),
        }
    }

    /// Send clipboard content to the server
    pub async fn send_clipboard(&self, text: &str) -> Result<(), String> {
        let server_url = self.get_server_url();
        if server_url.is_empty() {
            return Err("No server URL set".to_string());
        }

        let request = ClipboardRequest {
            text: text.to_string(),
        };

        match self
            .client
            .post(&format!("{}/api/clipboard", server_url))
            .json(&request)
            .send()
            .await
        {
            Ok(response) => {
                if !response.status().is_success() {
                    return Err(format!("Server error: {}", response.status()));
                }
                Ok(())
            }
            Err(e) => Err(format!("Request error: {}", e)),
        }
    }
}

impl Default for ApiClient {
    fn default() -> Self {
        Self::new()
    }
}
