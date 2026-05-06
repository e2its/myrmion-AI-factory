---
description: "Security policy — OWASP Top 10 compliance, secret management, Zero Trust principles, vulnerability remediation."
applicable_when:
  always: true
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial template version"
last_updated: {{TIMESTAMP}}
project_mode: {{GREENFIELD|BROWNFIELD}}
stack: {{PRIMARY_LANGUAGE}} + {{PRIMARY_FRAMEWORK}}
---

# Security Driven Development & Anti-Drift Policy

> Mandate: Security is enforced in every phase.  
> Enforcement: Validated by agents and CI/CD gates.

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
  - See `constitution.md` § Tiered Secrets Strategy for full policy
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
- **Agent Validation:** `/DEV`, `/ARCH` check during generation (Governance Index)
- **Peer Review:** `/REVIEW` blocks PRs with absolute paths (`[PATH-XX]` error)
- **CI/CD:** `scripts/lint-format.sh` scans all source files (BLOCKER)

## 4. Enforcement Mechanisms
- Developer workflow: check RED ZONE before edits; use adapters for legacy
- Copilot refusal pattern for RED ZONES and protected blocks
- CI/CD gate: secrets scan, SAST, dependency scan, drift check; block on findings
- CI/CD secrets: pipeline MUST use native orchestrator vault (see `ci-cd.instructions.md` § Secrets Management in Pipelines). NEVER `.env` files in CI/CD.
- Branch protection: require `security-scan` status, 2 approvals (incl. Architect/Security)

## 5. Security Testing (QA Integration)
- Mandatory scenarios: SQLi prevention, XSS sanitization, authz enforcement, secrets absent from logs
- Align with `docs/constitution.md` testing standards and `.claude/rules/testing.md`

## 6. Further Reading
- OWASP Top 10, ASVS, CWE Top 25
- NIST Cybersecurity Framework
- `.claude/rules/protected-code.md`, `.claude/rules/testing.md`

## 7. Changelog
| Date | Change | Author |
|------|--------|--------|
| {{TIMESTAMP}} | Initial security policy generated by /SETUP | SETUP Agent |

> Update when tools change, new vulnerabilities surface, or incidents reveal gaps.
