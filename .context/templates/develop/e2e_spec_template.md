# Plantilla D: E2E Test Spec Template (`tests/e2e/specs/{feature}.spec.ts`)

```typescript
import { test, expect } from '@playwright/test';
import { {FeatureName}Page } from '../pages/{feature}.page';

/**
 * E2E Tests for {Feature Name}
 * Ref: {{FEATURE_ID}}
 * Test Plan: test_plan.md → § 1 AC-XX (scenario-anchored, via Gherkin Ref) + § 3 UX-XX/A11Y-XX
 * Route composition: user_journey.md § 3 Paths (each E2E flow follows a named Path's Paso sequence)
 */
test.describe('{Feature Name} E2E Tests', () => {
  let {feature}Page: {FeatureName}Page;

  test.beforeEach(async ({ page }) => {
    {feature}Page = new {FeatureName}Page(page);
    await {feature}Page.goto();
  });

  /**
   * AC-01 — {exact Gherkin scenario title from test_plan § 1 Gherkin Ref}
   * Path: user_journey.md § 3 "{path name}" (Paso 1 → Paso 2)
   */
  test('should {action} successfully with valid data', async () => {
    // Arrange: Valid test data
    const validData = 'valid-input';

    // Act: Perform action
    await {feature}Page.performAction(validData);

    // Assert: Success state
    await {feature}Page.assertSuccess();
  });

  /**
   * AC-02 — {exact Gherkin scenario title from test_plan § 1 Gherkin Ref}
   * Path: user_journey.md § 3 "{recovery path name}"
   */
  test('should display error with invalid data', async () => {
    // Arrange: Invalid test data
    const invalidData = '';

    // Act: Perform action
    await {feature}Page.performAction(invalidData);

    // Assert: Error message displayed
    await {feature}Page.assertError('Expected error message');
  });

  /**
   * A11Y-03 — Keyboard Navigation (test_plan § 3, exact ID)
   */
  test('should be fully keyboard navigable', async ({ page }) => {
    // Tab through all interactive elements
    await page.keyboard.press('Tab');
    await expect(page.locator(':focus')).toHaveAttribute('name', 'element');
    
    // Submit with Enter
    await page.keyboard.press('Enter');
    await {feature}Page.assertSuccess();
  });
});
```
