---
description: "Security policy — OWASP Top 10 compliance, secret management, Zero Trust principles, vulnerability remediation."
applicable_when:
  always: true
version: 1.7.1
date: 2026-09-25
last_updated: "{{TIMESTAMP}}"
project_mode: "{{GREENFIELD|BROWNFIELD}}"
stack: "{{PRIMARY_LANGUAGE}} + {{PRIMARY_FRAMEWORK}}"
---

# Security Driven Development & Anti-Drift Policy

> Mandate: Security is enforced in every phase.  
> Enforcement: Validated by agents and CI/CD gates.

## [PLAW-06] Security by Design
> Security is validated in every feature, never deferred to a sprint: OWASP controls, static analysis gates and default-deny networking apply from the first line.

> **Mandate:** Security is NOT a feature sprint. It's validated in EVERY feature.

### OWASP Top 10 Controls
- **Injection:** Prepared statements, ORM, input validation.
- **Broken Auth:** MFA, rate limiting, JWT rotation.
- **XSS/CSRF:** CSP headers, SameSite cookies.
- **Batch operations (API1, API4):** a size cap, per-item authorization, a named failure mode and a safe retry — `rules/contract-first-policy.md` § Bulk Operations.
- **Secrets:** NEVER hardcode. Use tiered strategy: CI/CD vault (Tier A) → Cloud vault (Tier B) → `.env` local only (Tier C). See `[PLAW-05]` in `.claude/rules/configuration.md`.

### Static Analysis (SAST)
- **Tools:** Semgrep (code), Gitleaks (secrets), Dependabot (dependencies).
- **Base packs (EVOL-074):** `security/sast/<pack>.yml` — the framework's own Semgrep rules, one pack per language the project uses and only those (Python, JavaScript/TypeScript, UI templates, Java, Go, C#, Rust): debug mode outside development, insecure temporary files, raw HTML, a shell fed a non-literal, TLS verification off. The `sast` verification member runs them all (`config/quality.json → verification.gates.sast`); a finding blocks, and the member is never skipped. Engine pinned to the version the packs are proven on: `pipx install semgrep==1.182.0`, or the image `semgrep/semgrep:1.182.0`. A stack with no pack gets no member, and the setup report says so. Fix the code, never the pack; a project's own rule goes in a file of its own under `security/sast/` (a governed path: a pack edit needs an approved plan; on a stack with no pack, the project adds the `sast` row itself). A false positive is suppressed on its line only — `nosemgrep: <rule-id> — <reason>` — never with a bare `nosemgrep`, which the security loop blocks; the security lens reviews every new suppression in the diff. A `.semgrepignore` (governed) replaces the engine's default ignore list (`tests/`, `build/`, `dist/`, `vendor/`, `node_modules/` are skipped by default); the security lens adjudicates every change to it. The packs cover the common forms of each class, not every form: the security lens still reads the code. A file the engine cannot parse is skipped silently — the gate's `--quiet` output does not name it.
- **CI/CD:** Block merge if HIGH/CRITICAL vulnerabilities.

### Network Security
- **Default Deny:** Firewall rules whitelist-only.
- **mTLS:** For inter-service communication in production.
- **API Gateway:** Centralized auth + rate limiting.

### Verification Standard
- **Standard:** `{{SECURITY_STANDARD}}` · **level:** `{{SECURITY_LEVEL}}` (SETUP Q35, Q35.1 — `none` asks no level).
- The design's `## Reliability Questions` map each question to this standard's requirement at this level; `gate.py freeze` holds every security- or availability-weighted capability to an answer and a cited source (EVOL-115).

### Further Reading
- [OWASP Top 10](https://owasp.org/Top10/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

## 1. Security Agent Responsibilities
- SAST: check OWASP Top 10 patterns (Injection, XSS/CSRF, Broken Auth, etc.)
- Secret scanning: API keys, DB strings, private keys, OAuth secrets
- Dependency analysis: CVEs HIGH/CRITICAL block; license review
- Anti-drift: enforce allowed hashes, forbid RED ZONE edits (`.claude/rules/protected-code.md`)
- Reporting: classify findings (CRITICAL/HIGH/MODERATE/LOW) and block accordingly

## 2. Anti-Drift Policy (Third-Party Integrity)
- Never edit: dependencies (`node_modules/`, `venv/`, `vendor/`), framework code, legacy RED ZONE paths, or blocks marked `PROTECTED-CODE START/END`
- Extension patterns only: Wrapper, Decorator, Dependency Injection, or framework hooks/middleware in GREEN ZONE
- Rationale: maintain upgradeability, security, and auditability

## 3. Security Driven Development (SecDD)
- Input validation at edge (schema validation) + domain invariants + DB constraints
- OWASP Top 10 controls mapped to implementation and tests
- Secrets management: no hardcoded secrets; tiered strategy:
  - **Tier A (CI/CD):** Use orchestrator vault (GitHub Secrets, GitLab CI Variables, etc.) — NEVER `.env` in pipelines
  - **Tier B (Runtime/Cloud):** Use cloud vault (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault, Doppler)
  - **Tier C (Local Dev):** `.env` files acceptable for environments with `hosting: local` (dev, local staging, etc.); provide `.env.example` with categorized sections
  - See `[PLAW-05]` in `.claude/rules/configuration.md` § Tiered Secrets Strategy for full policy
- **Path Security (CRITICAL):** No absolute paths in source code (see Section 3.1)

### 3.1 Absolute Path Prohibition (Security & Portability)

**RULE:** All file path references MUST use relative paths or environment variables.

**Security Rationale:**
- **Information Disclosure:** Absolute paths expose internal server/developer directory structures in version control
- **Attack Surface:** Reveals OS type (`/home/` = Linux, `C:\` = Windows), aiding reconnaissance
- **Environment Leakage:** Developer usernames in paths (`/Users/john/`) compromise anonymity
- **Configuration Exposure:** Production paths in code reveal deployment topology

**Portability Rationale:**
- Code must run on any developer machine, CI/CD, Docker, Kubernetes, cloud platforms
- Different environments have different directory layouts

**PROHIBITED Patterns:**
```python
# ❌ NEVER - Exposes server structure
DB_PATH = "/home/user/project/data/database.db"
CONFIG_FILE = "/opt/app/config/production.yaml"
UPLOAD_DIR = "/var/www/uploads/"

# ❌ NEVER - Exposes developer info
LOG_PATH = "/Users/john/workspace/logs/app.log"
CERT_PATH = "C:\\Users\\Developer\\certs\\cert.pem"
```

**REQUIRED Patterns:**
```python
# ✅ Relative paths
DB_PATH = "./data/database.db"
CONFIG_FILE = "../config/production.yaml"
UPLOAD_DIR = path.join(__dirname, "uploads")

# ✅ Environment variables (production)
DB_PATH = os.getenv("DATABASE_PATH", "./data/database.db")
UPLOAD_DIR = os.environ["UPLOAD_DIR"]

# ✅ System paths (documented exception)
TEMP_FILE = "/tmp/cache.tmp"  # System temp dir (OS-standard)
```

**Exceptions (MUST document with inline comment):**
- OS-standard paths: `/tmp/`, `/dev/null`, `/proc/`, `/sys/`
- Example: `log_file = "/dev/null"  # Null device (OS-standard)`

**Enforcement:**
- **Agent Validation:** `/DEV`, `/ARCH` check during generation
- **Peer Review:** `/REVIEW` blocks PRs with absolute paths (`[PATH-XX]` error)
- **CI/CD:** `scripts/lint-format.sh` scans all source files (BLOCKER)

## 4. Enforcement Mechanisms
- Developer workflow: check RED ZONE before edits; use adapters for legacy
- Copilot refusal pattern for RED ZONES and protected blocks
- CI/CD gate: secrets scan, SAST, dependency scan, drift check; block on findings
- CI/CD secrets: pipeline MUST use native orchestrator vault (see `.claude/rules/ci-cd.md` § Secrets Management in Pipelines). NEVER `.env` files in CI/CD.
- Branch protection: require `security-scan` status, {{PR_APPROVAL_COUNT}} approval(s) per `.claude/rules/branching.md` (incl. Architect/Security)

## 5. Security Testing (QA Integration)
- Mandatory scenarios: SQLi prevention, XSS sanitization, authz enforcement, secrets absent from logs
- Align with `.claude/rules/testing.md` (testing standards, `[PLAW-13]`)

## 6. Further Reading
- OWASP ASVS, CWE Top 25 (OWASP Top 10 + NIST: see `[PLAW-06]` Further Reading above)
- `.claude/rules/protected-code.md`, `.claude/rules/testing.md`

> Update when tools change, new vulnerabilities surface, or incidents reveal gaps.

## [LAW-04] Security
> No secret lives in code — configuration and vault supply them — and every change is checked against the OWASP Top 10.

Zero secrets in code — environment variables or the vault SDK supply them; the secrets scanner (`scripts/security-scan.sh --secrets`, tool chosen at SETUP) runs at commit and push. Every change is checked against the OWASP Top 10 (injection, broken auth, sensitive-data exposure, XXE, broken access control, misconfiguration, XSS, insecure deserialisation, vulnerable components, insufficient logging). The security lens of the review reads this rule; DAST policy in `policies/dast.md`.
