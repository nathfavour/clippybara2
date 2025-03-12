//! Clipboard monitoring and syncing functionality.

use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use arboard::Clipboard;
use tokio::time;

use crate::api::ApiClient;

/// Structure to handle clipboard monitoring and syncing
pub struct ClipboardManager {
    last_content: Arc<Mutex<String>>,
    last_update: Arc<Mutex<Instant>>,
    api_client: Arc<ApiClient>,
}

impl ClipboardManager {
    /// Create a new clipboard manager
    pub fn new(api_client: Arc<ApiClient>) -> Self {
        Self {
            last_content: Arc::new(Mutex::new(String::new())),
            last_update: Arc::new(Mutex::new(Instant::now())),
            api_client,
        }
    }

    /// Start monitoring the clipboard for changes
    pub async fn start_monitoring(&self) {
        let last_content = self.last_content.clone();
        let last_update = self.last_update.clone();
        let api_client = self.api_client.clone();

        // First sync from server to local clipboard
        self.sync_from_server().await;

        // Start the monitoring loop
        tokio::spawn(async move {
            let mut interval = time::interval(Duration::from_millis(500));
            let mut clipboard = match Clipboard::new() {
                Ok(clipboard) => clipboard,
                Err(e) => {
                    eprintln!("Failed to access clipboard: {}", e);
                    return;
                }
            };

            loop {
                interval.tick().await;
                
                // Check if we're connected to a server
                if !api_client.is_connected() {
                    continue;
                }
                
                // Check for local clipboard changes
                if let Ok(text) = clipboard.get_text() {
                    let mut last_content_guard = last_content.lock().unwrap();
                    let current_content = text;

                    // If content changed, update server
                    if *last_content_guard != current_content {
                        let now = Instant::now();
                        let mut last_update_guard = last_update.lock().unwrap();
                        
                        // Skip immediate updates if we've just updated (prevents loops)
                        if now.duration_since(*last_update_guard) > Duration::from_millis(1000) {
                            *last_content_guard = current_content.clone();
                            *last_update_guard = now;
                            
                            // Send to server
                            let api_client_clone = api_client.clone();
                            let content_clone = current_content.clone();
                            tokio::spawn(async move {
                                if let Err(e) = api_client_clone.send_clipboard(&content_clone).await {
                                    eprintln!("Error syncing clipboard to server: {}", e);
                                }
                            });
                        }
                    }
                }

                // Check for server clipboard changes
                match api_client.get_clipboard().await {
                    Ok(server_content) => {
                        let mut last_content_guard = last_content.lock().unwrap();
                        
                        // If server has newer content, update local clipboard
                        if !server_content.is_empty() && *last_content_guard != server_content {
                            let mut last_update_guard = last_update.lock().unwrap();
                            
                            // Skip immediate updates if we've just updated
                            if Instant::now().duration_since(*last_update_guard) > Duration::from_millis(1000) {
                                *last_content_guard = server_content.clone();
                                *last_update_guard = Instant::now();
                                
                                // Update local clipboard
                                if let Err(e) = clipboard.set_text(&server_content) {
                                    eprintln!("Error updating local clipboard: {}", e);
                                }
                            }
                        }
                    }
                    Err(e) => {
                        // Only log if it's a connection error, not "clipboard empty"
                        if !e.contains("parse") {
                            eprintln!("Error getting clipboard from server: {}", e);
                        }
                    }
                }
            }
        });
    }

    /// Get the last synced content
    pub fn get_last_content(&self) -> String {
        let last_content = self.last_content.lock().unwrap();
        last_content.clone()
    }

    /// Manually sync from the local clipboard to the server
    pub async fn sync_to_server(&self) -> Result<(), String> {
        match Clipboard::new() {
            Ok(clipboard) => {
                match clipboard.get_text() {
                    Ok(text) => {
                        let mut last_content = self.last_content.lock().unwrap();
                        *last_content = text.clone();
                        
                        let mut last_update = self.last_update.lock().unwrap();
                        *last_update = Instant::now();
                        
                        self.api_client.send_clipboard(&text).await
                    }
                    Err(e) => Err(format!("Failed to get text from clipboard: {}", e)),
                }
            }
            Err(e) => Err(format!("Failed to access clipboard: {}", e)),
        }
    }

    /// Manually sync from the server to the local clipboard
    pub async fn sync_from_server(&self) -> Result<(), String> {
        match self.api_client.get_clipboard().await {
            Ok(text) => {
                let mut last_content = self.last_content.lock().unwrap();
                *last_content = text.clone();
                
                let mut last_update = self.last_update.lock().unwrap();
                *last_update = Instant::now();
                
                match Clipboard::new() {
                    Ok(mut clipboard) => {
                        match clipboard.set_text(&text) {
                            Ok(_) => Ok(()),
                            Err(e) => Err(format!("Failed to update clipboard: {}", e)),
                        }
                    }
                    Err(e) => Err(format!("Failed to access clipboard: {}", e)),
                }
            }
            Err(e) => Err(e),
        }
    }
}
