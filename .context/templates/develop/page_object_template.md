# Plantilla C: Page Object Template (`tests/e2e/pages/{feature}.page.ts`)

```typescript
import { Page, Locator } from '@playwright/test';
import { BasePage } from './base.page';

/**
 * Page Object for {Feature Name}
 * Ref: {{FEATURE_ID}}
 * Test Plan: test_plan.md → Section 3 (UX & Accessibility)
 */
export class {FeatureName}Page extends BasePage {
  // Locators (map UI elements from design.md)
  private readonly elementInput: Locator;
  private readonly submitButton: Locator;
  private readonly errorMessage: Locator;

  constructor(page: Page) {
    super(page);
    // Define locators based on design.md UI structure
    this.elementInput = page.locator('#element-id');
    this.submitButton = page.locator('button[type="submit"]');
    this.errorMessage = page.locator('.error-message');
  }

  /**
   * Navigate to feature page
   */
  async goto(): Promise<void> {
    await super.goto('/feature-path');
  }

  /**
   * Perform main action (map from test_plan.md scenarios)
   */
  async performAction(data: string): Promise<void> {
    await this.fill(this.elementInput, data);
    await this.click(this.submitButton);
  }

  /**
   * Assert success state
   */
  async assertSuccess(): Promise<void> {
    await expect(this.page).toHaveURL('/success-path');
  }

  /**
   * Assert error state (map from test_plan.md negative cases)
   */
  async assertError(expectedMessage: string): Promise<void> {
    await this.assertText(this.errorMessage, expectedMessage);
  }
}
```
