# Template A: "Remedy Proposal" (Internal for the Report)
```markdown
> **Vulnerability:** SQL Injection in `UserRepository.ts:45`
> **Vulnerable Code:** `query("SELECT * FROM users WHERE id = " + id)`
> **Remedy Proposal (DevSecOps):**
> ```typescript
> // Use bound parameters to prevent injection
> query("SELECT * FROM users WHERE id = ?", [id])
> ```
```
