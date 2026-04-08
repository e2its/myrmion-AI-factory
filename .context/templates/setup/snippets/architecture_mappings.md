---
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial snippet version"
---

# Architecture: Machine-Readable Mapping Examples

## MVC (Ruby)
```json
{
  "architecture": {
    "pattern": "MVC",
    "rationale_adr": "docs/adr/ADR-001-mvc-architecture.md",
    "language": "Ruby",
    "base_path": "app",
    "layers": {
      "models": {
        "path": "models",
        "purpose": "Business objects and ORM",
        "cannot_depend_on": ["controllers", "views"]
      },
      "controllers": {
        "path": "controllers",
        "purpose": "Request routing and processing",
        "cannot_depend_on": ["views"]
      },
      "views": {
        "path": "views",
        "purpose": "HTML rendering and templates",
        "cannot_depend_on": []
      }
    }
  }
}
```

## Feature-based (Go)
```json
{
  "architecture": {
    "pattern": "Feature-based",
    "rationale_adr": "docs/adr/ADR-001-feature-based-architecture.md",
    "language": "Go",
    "base_path": "internal",
    "layers": {
      "features": {
        "path": "features",
        "purpose": "Self-contained feature modules",
        "cannot_depend_on": []
      },
      "shared": {
        "path": "shared",
        "purpose": "Shared utilities (not business logic)",
        "cannot_depend_on": []
      }
    }
  }
}
```

## Brownfield Migration Strategy
```json
{
  "architecture": {
    "pattern": "{{TARGET_PATTERN}}",
    "migration": {
      "from_pattern": "{{DETECTED_PATTERN}}",
      "strategy": "Strangler Fig",
      "rationale": "Gradual feature-by-feature migration. New features implement target pattern.",
      "tracked_in": "Feature-specific design.md files"
    },
    ...
  }
}
```
