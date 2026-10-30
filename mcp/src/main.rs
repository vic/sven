//! yen-mcp: an MCP server (JSON-RPC 2.0, one message per line on stdio) over a yen fleet.
//! Each tool call is one `nix eval` of `tool.nix`; its inputs go through the environment and a file, never a string.
//! Env: YEN_TOOL_NIX (tool.nix), YEN_FLEET (the fleet dir; default: the working directory), YEN_FLAKE (its flake
//! ref; default `git+file://<git top>?dir=<fleet dir in the repo>`), YEN_TIMEOUT (seconds per call; default 120).

use serde_json::{json, Value};
use std::io::{self, BufRead, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

const TOOLS: &str = include_str!("tools.json");

struct Config {
    tool_nix: PathBuf,
    fleet: PathBuf,
    flake: String,
    timeout: Duration,
    scratch: PathBuf,
}

/// What one `nix eval` gave: its JSON, a timeout, or the first error line.
enum Eval {
    Done(Value),
    Timeout,
    Failed(String),
}

fn main() -> io::Result<()> {
    let cfg = config()?;
    let tools: Value = serde_json::from_str(TOOLS).map_err(io::Error::other)?;
    let mut out = io::stdout().lock();
    for line in io::stdin().lock().lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        if let Some(reply) = answer(&cfg, &tools, &line) {
            writeln!(out, "{reply}")?;
            out.flush()?;
        }
    }
    std::fs::remove_dir_all(&cfg.scratch).or(Ok(()))
}

fn config() -> io::Result<Config> {
    let env = |k: &str| std::env::var(k).ok().filter(|v| !v.is_empty());
    let tool_nix = env("YEN_TOOL_NIX")
        .map(PathBuf::from)
        .ok_or_else(|| io::Error::other("YEN_TOOL_NIX is not set"))?;
    let fleet = match env("YEN_FLEET") {
        Some(f) => PathBuf::from(f).canonicalize()?,
        None => std::env::current_dir()?,
    };
    let flake = match env("YEN_FLAKE") {
        Some(f) => f,
        None => flake_ref(&fleet),
    };
    let timeout = env("YEN_TIMEOUT")
        .and_then(|t| t.parse::<f64>().ok())
        .filter(|t| t.is_finite() && *t >= 0.0)
        .map_or(Duration::from_secs(120), Duration::from_secs_f64);
    let scratch = std::env::temp_dir().join(format!("yen-mcp-{}", std::process::id()));
    std::fs::create_dir_all(&scratch)?;
    Ok(Config {
        tool_nix,
        fleet,
        flake,
        timeout,
        scratch,
    })
}

/// `git+file:` reads tracked files only; `path:` would copy the whole tree (node_modules too) on every call.
fn flake_ref(fleet: &Path) -> String {
    let top = Command::new("git")
        .arg("-C")
        .arg(fleet)
        .args(["rev-parse", "--show-toplevel"])
        .stderr(Stdio::null())
        .output()
        .ok()
        .filter(|o| o.status.success())
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| PathBuf::from(s.trim()));
    match top {
        Some(top) => {
            let rel = fleet
                .strip_prefix(&top)
                .map(|r| r.display().to_string())
                .unwrap_or_default();
            let dir = if rel.is_empty() {
                String::new()
            } else {
                format!("?dir={rel}")
            };
            format!("git+file://{}{dir}", top.display())
        }
        None => format!("path:{}", fleet.display()),
    }
}

/// The reply to one message, or none for a notification.
fn answer(cfg: &Config, tools: &Value, line: &str) -> Option<Value> {
    let msg: Value = match serde_json::from_str(line) {
        Ok(v @ Value::Object(_)) => v,
        _ => return Some(fail(&Value::Null, -32700, "parse error")),
    };
    let id = msg.get("id").cloned().unwrap_or(Value::Null);
    let method = msg.get("method").and_then(Value::as_str).unwrap_or("");
    match method {
        "initialize" => Some(reply(
            &id,
            json!({"protocolVersion": "2024-11-05", "capabilities": {"tools": {}},
                   "serverInfo": {"name": "yen-mcp", "version": env!("CARGO_PKG_VERSION")}}),
        )),
        m if m.starts_with("notifications/") => None,
        "tools/list" => Some(reply(&id, json!({ "tools": tools }))),
        "tools/call" => {
            let params = msg.get("params");
            let name = params
                .and_then(|p| p.get("name"))
                .and_then(Value::as_str)
                .unwrap_or("");
            let args = params
                .and_then(|p| p.get("arguments"))
                .cloned()
                .unwrap_or_else(|| json!({}));
            Some(call(cfg, tools, &id, name, &args))
        }
        _ if id.is_null() => None,
        m => Some(fail(&id, -32601, &format!("method not found: {m}"))),
    }
}

fn call(cfg: &Config, tools: &Value, id: &Value, name: &str, args: &Value) -> Value {
    let known = tools
        .as_array()
        .is_some_and(|ts| ts.iter().any(|t| t["name"] == name));
    let Some(tool) = name.strip_prefix("yen_").filter(|_| known) else {
        return fail(id, -32602, &format!("unknown tool: {name}"));
    };
    let (text, is_error) = match eval(cfg, tool, args) {
        Ok(Eval::Done(result)) => (json!({"complete": true, "result": result}), false),
        Ok(Eval::Timeout) => (json!({"complete": false, "error": "timeout"}), false),
        Ok(Eval::Failed(error)) => (json!({"complete": false, "error": error}), true),
        Err(e) => (json!({"complete": false, "error": e.to_string()}), true),
    };
    reply(
        id,
        json!({"content": [{"type": "text", "text": text.to_string()}], "isError": is_error}),
    )
}

/// One `nix eval` of tool.nix, killed at the timeout. Its output goes to files: an export is large.
fn eval(cfg: &Config, tool: &str, args: &Value) -> io::Result<Eval> {
    let args_file = cfg.scratch.join("args.json");
    let out_file = cfg.scratch.join("out.json");
    let err_file = cfg.scratch.join("err.txt");
    std::fs::write(&args_file, args.to_string())?;
    let mut child = Command::new("nix")
        .args(["eval", "--offline", "--impure", "--json", "--file"])
        .arg(&cfg.tool_nix)
        .env("YEN_TOOL", tool)
        .env("YEN_ARGS", &args_file)
        .env("YEN_FLEET", &cfg.fleet)
        .env("YEN_FLAKE", &cfg.flake)
        .stdin(Stdio::null())
        .stdout(std::fs::File::create(&out_file)?)
        .stderr(std::fs::File::create(&err_file)?)
        .spawn()?;
    let start = Instant::now();
    let status = loop {
        if let Some(status) = child.try_wait()? {
            break status;
        }
        if start.elapsed() >= cfg.timeout {
            child.kill()?;
            child.wait()?;
            return Ok(Eval::Timeout);
        }
        std::thread::sleep(Duration::from_millis(5));
    };
    if !status.success() {
        let err = std::fs::read_to_string(&err_file)?;
        let line = err
            .lines()
            .find(|l| l.trim_start().starts_with("error:"))
            .or_else(|| err.lines().next())
            .unwrap_or("nix eval failed");
        return Ok(Eval::Failed(line.to_string()));
    }
    let out = std::fs::read_to_string(&out_file)?;
    serde_json::from_str(&out)
        .map(Eval::Done)
        .map_err(io::Error::other)
}

fn reply(id: &Value, result: Value) -> Value {
    json!({"jsonrpc": "2.0", "id": id, "result": result})
}

fn fail(id: &Value, code: i64, message: &str) -> Value {
    json!({"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}})
}
