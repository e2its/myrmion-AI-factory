// META-ONLY fixture for security/sast/rust.yml (EVOL-074): every rule fires on a `ruleid:` line, stays quiet on an `ok:` line.
use maud::PreEscaped;
use std::env;
use std::fs::File;
use std::process::Command;

fn temp() {
    // ruleid: rust-insecure-temp-file
    let f = File::create(env::temp_dir().join("report.txt"));
    // ok: rust-insecure-temp-file
    let g = tempfile::tempfile();
}

fn html(user_input: String, mut tera: tera::Tera) {
    // ruleid: rust-raw-html
    let a = PreEscaped(user_input);
    // ok: rust-raw-html
    let b = PreEscaped("<br>");
    // ruleid: rust-raw-html
    tera.autoescape_on(vec![]);
    // ok: rust-raw-html
    tera.autoescape_on(vec![".html"]);
}

fn shell(user_input: &str) {
    // ruleid: rust-shell-non-literal
    Command::new("sh").arg("-c").arg(format!("ls {}", user_input)).status();
    // ruleid: rust-shell-non-literal
    Command::new("bash").args(["-c", user_input]).status();
    // ok: rust-shell-non-literal
    Command::new("ls").arg(user_input).status();
    // ok: rust-shell-non-literal
    Command::new("sh").arg("-c").arg("date").status();
}

fn tls() {
    // ruleid: rust-tls-verify-disabled
    let c = reqwest::Client::builder().danger_accept_invalid_certs(true).build();
    // ok: rust-tls-verify-disabled
    let d = reqwest::Client::builder().danger_accept_invalid_certs(false).build();
    // ruleid: rust-tls-verify-disabled
    let e = reqwest::Client::builder().danger_accept_invalid_hostnames(true).build();
}
