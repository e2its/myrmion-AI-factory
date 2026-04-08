---
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial snippet version"
---

# Express Wrapper (Code Protection)

Do not modify framework code. Use a wrapper:

```typescript
// ❌ DON'T: Modify express source (node_modules/express/...)

// ✅ DO: Create wrapper
import express from 'express';
import { logger } from '../logging';

export class CustomRouter {
  private router: express.Router;

  constructor() {
    this.router = express.Router();
  }

  addLogging(): this {
    this.router.use((req, res, next) => {
      logger.info(`${req.method} ${req.path}`);
      next();
    });
    return this;
  }

  getRouter(): express.Router {
    return this.router;
  }
}
```
