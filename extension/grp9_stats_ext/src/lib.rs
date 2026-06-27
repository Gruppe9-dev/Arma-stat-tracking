use serde::Deserialize;
use serde_json::{json, Value};
use std::ffi::{c_char, c_int, CStr};
use std::fs;
use std::ptr;
use std::time::Duration;

#[derive(Debug, Deserialize)]
struct Config {
    api_base_url: String,
    server_key: String,
    machine_token: String,
    #[allow(dead_code)]
    queue_path: Option<String>,
    connect_timeout_ms: Option<u64>,
    request_timeout_ms: Option<u64>,
}

fn write_output(output: *mut c_char, output_size: usize, value: &str) {
    if output.is_null() || output_size == 0 {
        return;
    }

    let bytes = value.as_bytes();
    let max = output_size.saturating_sub(1);
    let len = bytes.len().min(max);

    unsafe {
        ptr::copy_nonoverlapping(bytes.as_ptr(), output.cast::<u8>(), len);
        *output.add(len) = 0;
    }
}

fn read_c_string(value: *const c_char) -> String {
    if value.is_null() {
        return String::new();
    }

    unsafe { CStr::from_ptr(value).to_string_lossy().to_string() }
}

fn decode_sqf_string_literal(value: &str) -> String {
    let trimmed = value.trim();
    if !trimmed.starts_with('"') || !trimmed.ends_with('"') || trimmed.len() < 2 {
        return value.to_string();
    }

    let inner = &trimmed[1..trimmed.len() - 1];
    let mut decoded = String::with_capacity(inner.len());
    let mut chars = inner.chars().peekable();

    while let Some(ch) = chars.next() {
        if ch == '"' && chars.peek() == Some(&'"') {
            decoded.push('"');
            chars.next();
            continue;
        }

        decoded.push(ch);
    }

    decoded
}

fn read_args(argv: *const *const c_char, argc: c_int) -> Vec<String> {
    if argv.is_null() {
        return Vec::new();
    }

    let argc = argc.max(0) as usize;
    (0..argc)
        .map(|index| unsafe { *argv.add(index) })
        .map(read_c_string)
        .map(|arg| decode_sqf_string_literal(&arg))
        .collect()
}

fn json_error(code: &str, message: &str) -> String {
    json!({
        "ok": false,
        "error": code,
        "message": message
    })
    .to_string()
}

fn load_config() -> Result<Config, String> {
    let candidates = [
        "grp9_stats_server.toml",
        "@grp9_stats_server/grp9_stats_server.toml",
        "servermod/grp9_stats_server/grp9_stats_server.toml",
    ];

    for candidate in candidates {
        if let Ok(contents) = fs::read_to_string(candidate) {
            return toml::from_str::<Config>(&contents)
                .map_err(|error| format!("Invalid config file {candidate}: {error}"));
        }
    }

    Err("Could not find grp9_stats_server.toml".to_string())
}

fn post_json(path: &str, body: &str) -> String {
    if let Err(error) = serde_json::from_str::<Value>(body) {
        return json!({
            "ok": false,
            "error": "invalid_json_payload",
            "message": error.to_string(),
            "body_length": body.len(),
            "body_preview": body.chars().take(240).collect::<String>()
        })
        .to_string();
    }

    let config = match load_config() {
        Ok(config) => config,
        Err(error) => return json_error("config_error", &error),
    };

    let url = format!("{}{}", config.api_base_url.trim_end_matches('/'), path);
    let connect_timeout = Duration::from_millis(config.connect_timeout_ms.unwrap_or(2000));
    let request_timeout = Duration::from_millis(config.request_timeout_ms.unwrap_or(5000));
    let agent = ureq::AgentBuilder::new()
        .timeout_connect(connect_timeout)
        .timeout(request_timeout)
        .build();

    match agent
        .post(&url)
        .set("Authorization", &format!("Bearer {}", config.machine_token))
        .set("X-GRP9-Server-Key", &config.server_key)
        .set("Content-Type", "application/json")
        .send_string(body)
    {
        Ok(response) => response.into_string().unwrap_or_else(|error| {
            json_error("response_read_error", &error.to_string())
        }),
        Err(ureq::Error::Status(status, response)) => {
            let response_body = response.into_string().unwrap_or_default();
            json!({
                "ok": false,
                "error": "backend_status_error",
                "status": status,
                "body": response_body
            })
            .to_string()
        }
        Err(error) => json_error("request_error", &error.to_string()),
    }
}

fn get_api_status() -> String {
    let config = match load_config() {
        Ok(config) => config,
        Err(error) => return json_error("config_error", &error),
    };

    let url = format!("{}/health", config.api_base_url.trim_end_matches('/'));
    let connect_timeout = Duration::from_millis(config.connect_timeout_ms.unwrap_or(2000));
    let request_timeout = Duration::from_millis(config.request_timeout_ms.unwrap_or(5000));
    let agent = ureq::AgentBuilder::new()
        .timeout_connect(connect_timeout)
        .timeout(request_timeout)
        .build();

    match agent.get(&url).call() {
        Ok(response) => {
            let status = response.status();
            let body = response.into_string().unwrap_or_else(|error| {
                json_error("response_read_error", &error.to_string())
            });

            json!({
                "ok": (200..300).contains(&status),
                "status": status,
                "body": body
            })
            .to_string()
        }
        Err(ureq::Error::Status(status, response)) => {
            let response_body = response.into_string().unwrap_or_default();
            json!({
                "ok": false,
                "error": "backend_status_error",
                "status": status,
                "body": response_body
            })
            .to_string()
        }
        Err(error) => json_error("request_error", &error.to_string()),
    }
}

fn handle_command(command: &str, args: &[String]) -> String {
    match command {
        "health" => "{\"ok\":true,\"extension\":\"grp9_stats_ext\"}".to_string(),
        "api_status" => get_api_status(),
        "operation_start" => {
            let Some(payload) = args.first() else {
                return json_error("missing_payload", "operation_start requires payload JSON as first argument");
            };
            post_json("/v1/operations/start", payload)
        }
        "operation_finish" => {
            let Some(operation_id) = args.first() else {
                return json_error("missing_operation_id", "operation_finish requires operation_id as first argument");
            };
            let Some(payload) = args.get(1) else {
                return json_error("missing_payload", "operation_finish requires payload JSON as second argument");
            };
            if operation_id.is_empty() {
                return json_error("missing_operation_id", "operation_id is empty; startOperation must succeed before finishOperation");
            }
            post_json(&format!("/v1/operations/{operation_id}/finish"), payload)
        }
        _ => json_error("unsupported_command", command),
    }
}

#[no_mangle]
pub extern "C" fn RVExtensionVersion(output: *mut c_char, output_size: usize) {
    write_output(output, output_size, "grp9_stats_ext 0.1.0");
}

#[no_mangle]
pub extern "C" fn RVExtension(output: *mut c_char, output_size: usize, function: *const c_char) {
    let command = read_c_string(function);
    let response = handle_command(&command, &[]);

    write_output(output, output_size, &response);
}

#[no_mangle]
pub extern "C" fn RVExtensionArgs(
    output: *mut c_char,
    output_size: usize,
    function: *const c_char,
    argv: *const *const c_char,
    argc: c_int,
) -> c_int {
    let command = read_c_string(function);
    let args = read_args(argv, argc);
    let response = handle_command(&command, &args);

    write_output(output, output_size, &response);
    0
}
