---
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial policy version"
---

# E2E Testing Policy & Best Practices

**Status:** Active  
**Owner:** QA Agent  
**Last Update:** ${TIMESTAMP}  
**Ref:** Template M

## 1. Purpose
Defines strategy, best practices, and conventions for E2E testing (Playwright/Newman).

## 2. E2E Testing Strategy
- Validate critical user journeys, cross-browser coverage, mobile responsiveness, visual regression, and API integration.
- Excludes unit logic, security vulns (DAST), and performance benchmarks.
- Run locally before push; in CI on PRs to staging/main; full suite on staging; smoke on prod.

## 3. Page Object Model
- Required structure under `tests/e2e/` with `pages/`, `fixtures/`, `specs/`.
- Base class `BasePage`; feature pages inherit and encapsulate selectors/actions.

## 4. Naming Conventions
- Files: `<feature>.spec.ts`
- Suites: `test.describe('<Feature Name>')`
- Cases: `test('should <expectation>')`

## 5. Visual Regression
- Use `expect(page).toHaveScreenshot()`; store baselines in `tests/e2e/specs/__snapshots__/`.
- Review diffs; update baselines only for intentional UI changes.

## 6. Test Data Management
- Use fixtures (e.g., `tests/e2e/fixtures/test-data.json`); avoid hardcoded secrets.

## 7. CI/CD Integration
- Example GitHub Actions: install deps, `npx playwright install --with-deps`, run `npm run test:e2e`, upload report artifact.

## 8. Troubleshooting
- Mitigate timeouts with tuned timeouts and `waitForNetworkIdle`.
- Reduce flakiness via retries, avoiding fixed waits, leveraging auto-wait.
- Review visual diffs; update snapshots as needed.

## 9. Compliance
- Must follow POM, descriptive names, visual regression for UI changes, CI success, and multi-browser pass.
