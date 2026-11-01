use crate::http::HttpClient;
use crate::opencode_console;
use crate::output::ProviderPayload;
use std::path::Path;

/// Fetch all OpenCode subscription windows from the console API.
pub fn fetch(http: &HttpClient, timeout_ms: u64) -> Vec<ProviderPayload> {
    let _ = timeout_ms;
    opencode_console::fetch(http, "opencode", Path::new("/"))
}
