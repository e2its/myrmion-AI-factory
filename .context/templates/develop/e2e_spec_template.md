# Plantilla D: E2E Test Spec Template (`tests/e2e/specs/{feature}.spec.ts`)

```typescript
import { test, expect } from '@playwright/test';
import { {FeatureName}Page } from '../pages/{feature}.page';

/**
 * E2E Tests for {Feature Name}
 * Ref: {{FEATURE_ID}}
 * Test Plan: test_plan.md → Section 3 (UX & Accessibility Testing)
 */
test.describe('{Feature Name} E2E Tests', () => {
  let {feature}Page: {FeatureName}Page;

  test.beforeEach(async ({ page }) => {
    {feature}Page = new {FeatureName}Page(page);
    await {feature}Page.goto();
  });

  /**
   * TC-UX-01: Happy Path - Success Scenario
   * Ref: test_plan.md → Row 1 of UX & Accessibility Testing table
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
   * TC-UX-02: Error Handling - Invalid Data
   * Ref: test_plan.md → Row 2 of UX & Accessibility Testing table
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
   * TC-A11Y-01: Accessibility - Keyboard Navigation
   * Ref: test_plan.md → Accessibility row
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
