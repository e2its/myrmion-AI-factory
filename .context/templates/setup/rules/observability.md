---
description: "Observability standards — logging, metrics, tracing, alerting, dashboard design, SLO/SLI definitions. Applied when editing monitoring configuration."
applyTo: "**/infra/monitoring/**,**/observability/**"
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial template version"
---

# Observability & Monitoring Standards

> **Auto-generated from** `docs/setup.md` decisions  
> **Scope:** Logging, Metrics, Tracing, Alerting

## Logging
- Structured JSON logs with required fields: `trace_id`, `feature_id`, `user_id` (masked)
- Log levels policy: DEBUG (local), INFO (default), WARN, ERROR, FATAL
- PII masking patterns enforced; no secrets in logs

## Metrics
- Services: RED method (Rate, Errors, Duration)
- Infrastructure: USE method (Utilization, Saturation, Errors)
- Emit metrics with consistent naming and tags (service, version, env)

## Tracing
- OpenTelemetry instrumentation required for inbound/outbound calls
- Context propagation across services; sampling configured per environment
- Trace exports to chosen backend (Jaeger/Zipkin/OTel Collector)

## Alerting & Incident Response
- Define SLOs and alerts per service; page on error budget burn
- On-call rotation documented; incidents tracked with runbooks
- Postmortems required for SEV-1/SEV-2 with action items

## Further Reading
- Observability Engineering (O'Reilly)
- OpenTelemetry Docs
- Google SRE Book
