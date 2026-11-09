// META-ONLY fixture for security/bounds/rust.yml (EVOL-106): every rule fires on a `ruleid:` line, stays quiet on an `ok:` line.
use aws_config::retry::RetryConfig;
use aws_config::timeout::TimeoutConfig;
use aws_config::BehaviorVersion;
use reqwest::Client;
use std::time::Duration;

async fn reqwest_clients(configured: Duration) -> Result<(), reqwest::Error> {
    // ruleid: rust-reqwest-extract-deadline
    let a = reqwest::Client::builder().timeout(Duration::from_secs(10)).build()?;
    // ok: rust-reqwest-extract-deadline
    let b = Client::builder().timeout(configured).build()?;
    // ruleid: rust-reqwest-extract-retries
    let c = Client::builder().connect_timeout(Duration::from_secs(2)).read_timeout(Duration::from_millis(500)).retry(reqwest::retry::for_host("api.example.com").max_retries_per_request(2)).build()?;
    // ok: rust-reqwest-extract-retries
    let d = Client::builder().connect_timeout(configured).read_timeout(Duration::from_millis(500)).retry(reqwest::retry::for_host("api.example.com").max_retries_per_request(2)).build()?;
    // ruleid: rust-reqwest-unbounded
    let e = reqwest::Client::new();
    // ruleid: rust-reqwest-unbounded
    let f = reqwest::get("https://api.example.com").await?;
    // ruleid: rust-reqwest-unbounded
    let g = Client::builder().connect_timeout(Duration::from_secs(2)).read_timeout(Duration::from_secs(5)).build()?;
    // ok: rust-reqwest-unbounded
    let h = Client::builder().timeout(configured).build()?;
    // ok: rust-reqwest-extract-retries
    // ruleid: rust-reqwest-extract-deadline
    let j = Client::builder().timeout(Duration::from_secs(9)).connect_timeout(Duration::from_secs(2)).read_timeout(Duration::from_secs(5)).retry(reqwest::retry::for_host("api.example.com").max_retries_per_request(2)).build()?;
    // ok: rust-reqwest-unbounded
    let i = Client::builder().connect_timeout(configured).read_timeout(configured).retry(reqwest::retry::never()).build()?;
    Ok(())
}

async fn aws_clients(configured: Duration, attempts: u32) {
    // ruleid: rust-aws-extract-deadline
    let a = TimeoutConfig::builder().operation_timeout(Duration::from_secs(5)).build();
    // ok: rust-aws-extract-deadline
    let b = TimeoutConfig::builder().operation_timeout(configured).build();
    // ruleid: rust-aws-extract-total
    let c = aws_config::defaults(BehaviorVersion::latest()).timeout_config(TimeoutConfig::builder().connect_timeout(Duration::from_secs(1)).operation_attempt_timeout(Duration::from_secs(3)).build()).retry_config(RetryConfig::standard().with_max_attempts(3)).load().await;
    // ok: rust-aws-extract-total
    let d = aws_config::defaults(BehaviorVersion::latest()).timeout_config(TimeoutConfig::builder().connect_timeout(Duration::from_secs(1)).operation_attempt_timeout(Duration::from_secs(3)).build()).retry_config(RetryConfig::standard().with_max_attempts(attempts)).load().await;
    // ok: rust-aws-extract-total
    // ruleid: rust-aws-extract-deadline
    let k = aws_config::defaults(BehaviorVersion::latest()).timeout_config(TimeoutConfig::builder().operation_timeout(Duration::from_secs(20)).connect_timeout(Duration::from_secs(1)).operation_attempt_timeout(Duration::from_secs(3)).build()).retry_config(RetryConfig::standard().with_max_attempts(3)).load().await;
    // ruleid: rust-aws-unbounded
    let e = aws_config::load_from_env().await;
    // ruleid: rust-aws-unbounded
    let f = aws_config::defaults(BehaviorVersion::latest()).region("eu-west-1").load().await;
    // ruleid: rust-aws-unbounded
    let g = aws_config::defaults(BehaviorVersion::latest()).timeout_config(TimeoutConfig::builder().connect_timeout(Duration::from_secs(1)).build()).retry_config(RetryConfig::standard().with_max_attempts(3)).load().await;
    // ok: rust-aws-unbounded
    let h = aws_config::defaults(BehaviorVersion::latest()).timeout_config(TimeoutConfig::builder().operation_timeout(configured).build()).load().await;
    // ok: rust-aws-unbounded
    let timeouts = TimeoutConfig::builder().operation_timeout(configured).build();
    // ok: rust-aws-unbounded
    let i = aws_config::defaults(BehaviorVersion::latest()).timeout_config(timeouts).load().await;
}
