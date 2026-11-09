# Plantilla D: E2E Test Spec Template (`tests/e2e/specs/{feature}.spec.ts`)

## Contract

Proof at the close (EVOL-106). A test proves one case:

- **Title.** It opens with `[{{FEATURE_ID}}/<case id>]`, the id the case has in `test_plan.md`. A `describe` title links nothing.
- **Steps.** One helper call per clause, in order: `given` / `when` / `then`, the clause text verbatim.
  - A row with a `Gherkin Ref` takes its scenario's clauses: the Background first, then the scenario. An `And` / `But` takes the keyword before it. In a Scenario Outline, a `<x>` matches any text.
  - Any other row has one Then: its `Expected …` column.
  - Actions outside a helper call are not steps.
- **Assertions.** Every assertion goes through the helper's `expect` (`../support/clauses`), the page objects' included. A `then` that asserts nothing throws.
- **Control.** `control(page, url, mutate)` names the decisive response. It acts only in the control run (`CASE_CONTROL=1`), where the test must fail on a Then.

`gate.py proof --report <results.json>` judges a run locally. At the close QA runs the suite twice against the deployed build (green, then `CASE_CONTROL=1`; each to its own `PROOF_REPORT`) and `gate.py proof --record` writes the evidence the close reads.

```typescript
import { test } from '@playwright/test';
import { control, expect, given, then, when } from '../support/clauses';
import { {FeatureName}Page } from '../pages/{feature}.page';

/**
 * E2E Tests for {Feature Name}
 * Ref: {{FEATURE_ID}}
 * Test Plan: test_plan.md → § 1 AC-XX (scenario-anchored, via Gherkin Ref) + § 3 UX-XX/A11Y-XX
 * Route composition: user_journey.md § 3 Paths (each E2E flow follows a named Path's Paso sequence)
 */
test.describe('{Feature Name}', () => {
  let {feature}Page: {FeatureName}Page;

  test.beforeEach(async ({ page }) => {
    {feature}Page = new {FeatureName}Page(page);
  });

  // Path: user_journey.md § 3 "{path name}" (Paso 1 → Paso 2)
  test('[{{FEATURE_ID}}/AC-01] {exact Gherkin scenario title}', async ({ page }) => {
    await control(page, '**/api/{resource}', (body) => body.replace('"{decisive value}"', '"corrupted"'));
    await given('{Given clause, verbatim}', async () => {
      await {feature}Page.goto();
    });
    await when('{When clause, verbatim}', async () => {
      await {feature}Page.performAction('valid-input');
    });
    await then('{Then clause, verbatim}', async () => {
      await {feature}Page.assertSuccess();
    });
  });

  // Path: user_journey.md § 3 "{recovery path name}"
  test('[{{FEATURE_ID}}/AC-02] {exact Gherkin scenario title}', async ({ page }) => {
    await control(page, '**/api/{resource}', (body) => body.replace('"{error code}"', '"corrupted"'));
    await given('{Given clause, verbatim}', async () => {
      await {feature}Page.goto();
    });
    await when('{When clause, verbatim}', async () => {
      await {feature}Page.performAction('');
    });
    await then('{Then clause, verbatim}', async () => {
      await {feature}Page.assertError('{expected message}');
    });
  });

  // A11Y-03 (test_plan § 3): no Gherkin Ref, so its one Then is the row's Expected Result.
  test('[{{FEATURE_ID}}/A11Y-03] Keyboard navigation', async ({ page }) => {
    await control(page, '**/{feature-path}', (body) => body.replace('name="element"', ''));
    await {feature}Page.goto();
    await page.keyboard.press('Tab');
    await then('{Expected Result, verbatim}', async () => {
      await expect(page.locator(':focus')).toHaveAttribute('name', 'element');
    });
  });
});
```
