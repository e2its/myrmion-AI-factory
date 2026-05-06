---
description: "AI budget governance — token usage limits, model selection policy, cost tracking, budget alerts."
applicable_when:
  always: true
---
# AI Budget Governance

## Overview
This document defines the project's economic governance based on the monthly investment budget for AI services (LLMs). The budget controls the permitted architectural complexity and serves as a technical viability validator.

---

## Budget Tiers

| Tier | Monthly Investment | Target Projects | Complexity Level |
|------|-------------------|-----------------|------------------|
| **Starter** | <$500/month | MVPs, Prototypes, <100 users | Low - Simple topologies only |
| **Professional** | $500 - $2,000/month | Established products, <1000 users | Medium - Up to 2 complex patterns simultaneously |
| **Enterprise** | $2,000 - $10,000/month | Critical systems, >1000 users | High - No topological restrictions, strict tracking |
| **Unlimited** | >$10,000/month | Global infrastructure, high scale | Unlimited - All topologies permitted |

---

## Cost Formula

```
monthly_cost = backend_base_cost 
             + frontend_incremental_cost 
             + (acl_count * $50) 
             * complexity_multiplier
```

### Complexity Multiplier
- **Low** (simple CRUD, basic REST API): `1.0x`
- **Medium** (Business logic, multiple integrations): `1.3x`
- **High** (Complex DDD, Event Sourcing, CQRS): `1.8x`

---

## Backend Topology Costs

| Topology | Monthly Base Cost | Notes |
|----------|------------------|-------|
| **Modular Monolith** (Traditional) | $180 | Simple deployment, low AI overhead |
| **Modular Monolith** (Bounded Contexts) | $200 | Modular design, prepared to scale |
| **Modular Monolith** (Microkernel) | $480 | Plugin architecture, medium overhead |
| **N-Tier** | $180 | Classic, low complexity |
| **Client-Server** | $150 | Basic architecture |
| **Microservices** (REST) | $800 | Distributed, high AI complexity |
| **Microservices** (gRPC) | $850 | + protobuf generation overhead |
| **Microservices** (Event-Driven) | $1,100 | + async management, sagas |
| **SOA** (ESB) | $700 | Legacy integration patterns |
| **Serverless** (AWS/Azure/GCP) | $400 | FaaS, cold start optimization |
| **Event-Driven** (standalone) | $550 | Message queues, CQRS patterns |
| **Hexagonal** (Internal pattern) | $250 | Ports & Adapters, DDD |
| **P2P** | $900 | Distributed consensus, alto overhead |
| **Component-Based** | $220 | Modular reusability |
| **Broker/Pipeline** (Kafka/RabbitMQ) | $650 | Data streaming, async processing |

---

## Frontend Topology Costs

| Pattern | Incremental Cost | Notes |
|---------|-----------------|-------|
| **Component-Based** | $0 | Base obligatorio, sin costo adicional |
| **Container/Presentational** | $0 | Simple organizational pattern |
| **Atomic Design** | $0 | Design methodology |
| **SPA** | +$100 | Client-side rendering |
| **SSR** (With hydration) | +$150 | Server-side rendering + hydration |
| **SSR** (Without hydration) | +$120 | Pure SSR, lower complexity |
| **Micro-Frontends** | +$400 | Module Federation, high overhead |
| **Jamstack/SSG** | +$80 | Static generation, low overhead |
| **Islands Architecture** | +$200 | Partial hydration, medium complexity |
| **MVC/MVVM** | $0 | Structural pattern |
| **Flux/Redux** | +$50 | Global state management |

---

## Integration & ACL Costs

| Component | Cost per Unit |
|-----------|--------------|
| **External System ACL** | $50/integration |
| **Backend Aggregator ACL** (if Microservices) | $100 (one-time) |
| **Feature Flag Component** | $5/component |

---

## Budget Validation Rules

### Starter Tier (<$500/month) - BLOCKING RULES

**PROHIBITED Topologies:**
- ❌ **P2P** (base cost: $900)
- ❌ **SOA with ESB** (base cost: $700)
- ❌ **Microservices + Event-Driven** (combined: >$1,650)
- ❌ **Micro-frontends + SSR** (combined: >$550)
- ❌ **Microkernel** (base cost: $480) if >3 integrations

**ALLOWED with Restrictions:**
- ✅ **Modular Monolith** (any variant)
- ✅ **N-Tier / Client-Server**
- ✅ **Serverless** (single platform only)
- ✅ **SPA / SSR / Jamstack** (no combinations)
- ✅ **Maximum 5 ACL integrations**

### Professional Tier ($500-$2K/month)

**ALLOWED:**
- ✅ Up to **2 complex patterns simultaneously**
- ✅ Microservices (REST or gRPC, not Event-Driven)
- ✅ Event-Driven standalone
- ✅ Micro-frontends (without SSR)
- ✅ SSR + SPA hydration
- ✅ Up to 15 ACL integrations

**WARNING if exceeded:**
- ⚠️ Microservices + Event-Driven → Recommend pure Event-Driven
- ⚠️ Micro-frontends + SSR → Recommend pure SSR

### Enterprise Tier ($2K-$10K/month)

**ALLOWED:**
- ✅ All topologies without quantity restrictions
- ✅ Complex combinations (Microservices + Event-Driven + SOA)
- ✅ Micro-frontends + SSR + Islands
- ✅ Strict tracking required
- ✅ Unlimited integrations

### Unlimited Tier (>$10K/month)

**ALLOWED:**
- ✅ No architectural restrictions
- ✅ Distributed P2P
- ✅ Multi-cloud architectures
- ✅ Advanced tracking and auditing

---

## AI Provider Cost Multipliers

The base cost assumes **Claude 3.5 Sonnet** as the reference provider (1.0x). Adjust according to the chosen provider:

| Provider | Multiplier | Notes |
|----------|-----------|-------|
| **Claude 3.5 Sonnet** | 1.0x | Reference (input: $3/M tokens, output: $15/M tokens) |
| **GPT-4 Turbo** | 1.2x | More expensive ($10/M input, $30/M output) |
| **GPT-4o-mini** | 0.4x | Cost-efficient ($0.15/M input, $0.6/M output) |
| **Gemini 1.5 Pro** | 0.8x | Competitive ($3.5/M input, $10.5/M output) |
| **Llama 3.1 405B** (self-hosted) | 0.6x | Infrastructure costs, no API |

**Adjusted Formula:**
```
adjusted_monthly_cost = monthly_cost * provider_multiplier
```

---

## Budget Tracking

### Cross-Feature Accumulation

The budget is tracked **monthly** by accumulating all features:

**Archivo:** `.claude/rules/ai_budget_tracker.md`

| Feature ID | Cost (USD) | Tokens Consumed | Timestamp | Status |
|------------|-----------|-----------------|-----------|--------|
| AUTH-001 | $45.20 | 1,506,667 | 2026-01-15 | COMPLETED |
| PAYMENT-001 | $127.80 | 4,260,000 | 2026-01-22 | IN_PROGRESS |
| **TOTAL** | **$173.00** | **5,766,667** | - | - |

### Warning Threshold: 80%

**Trigger:**
```
IF consumed >= (budget * 0.8):
  GENERATE WARNING in docs/project_log/workflow_log.json
  NOTIFY USER: "⚠️ Budget at 80% ($X/$Y). $Z remaining for this month."
```

### Monthly Reset

**Day 1 of each month:**
1. Archive current tracker: `docs/project_log/ai_budget_history/YYYY-MM.md`
2. Reset `.claude/rules/ai_budget_tracker.md` with empty header
3. Preserve annual cumulative total in history file

**Archivo de Historia Mensual:**
```markdown
# AI Budget History - January 2026

## Summary
- **Budget Tier:** Professional ($500-$2K)
- **Allocated Budget:** $1,500
- **Total Consumed:** $1,347.80 (89.85%)
- **Features Completed:** 12
- **Average per Feature:** $112.32

## Breakdown by Feature
| Feature ID | Cost | Tokens | Complexity |
|------------|------|--------|-----------|
| ... | ... | ... | ... |

## Overages
- None

## Recommendations
- Consider upgrading to Enterprise tier if monthly average exceeds $1,800
```

---

## Validation Workflow

### During `/SETUP --init` (Discovery Phase)

**Mandatory question:**
```
💰 **AI Budget Planning**

What is your planned monthly investment in AI services for this project?

1. Starter (<$500/month) - MVPs, prototypes
2. Professional ($500-$2K/month) - Established products
3. Enterprise ($2K-$10K/month) - Critical systems
4. Unlimited (>$10K/month) - Global infrastructure

Select [1-4]:
```

### During `/SETUP --generate` (Materialization)

**Pre-Generation Validation:**
```python
def validate_budget(setup_decisions, ai_budget_tier):
    total_cost = calculate_total_cost(setup_decisions)
    budget_limit = get_budget_limit(ai_budget_tier)
    
    if total_cost > budget_limit:
        blocked_items = identify_expensive_items(setup_decisions)
        alternatives = suggest_alternatives(blocked_items, budget_limit)
        
        raise BudgetValidationError(
            f"❌ **BUDGET EXCEEDED**: ${total_cost} > ${budget_limit}\n\n"
            f"**Blockers:**\n{blocked_items}\n\n"
            f"**Viable alternatives:**\n{alternatives}"
        )
    
    if total_cost > (budget_limit * 0.8):
        log_warning(
            f"⚠️ Budget at {(total_cost/budget_limit)*100:.1f}% "
            f"(${total_cost}/${budget_limit})"
        )
```

### Durante Feature Implementation

**Tracking Incremental:**

Each agent reports estimated consumption upon completing its phase:
- `/CODESIGN --start` / `--refine` (auto-approval): +$5 (spec generation)
- `/BLUEPRINT --start`: +$15 (design generation)
- `/IMPLEMENT --build`: +$97 (code + tests + review + SAST — replaces DEV+REVIEW+SEC)
- `/QA --verify`: +$15 (testing analysis + DAST security scan — includes 🛡️ SEC hat)

**Auto-update tracker:**
```bash
echo "| ${FEATURE_ID} | $${COST} | ${TOKENS} | $(date) | ${STATUS} |" >> .claude/rules/ai_budget_tracker.md
```

---

## Error Messages & Suggestions

### Budget Exceeded Example

```
❌ **BUDGET VALIDATION ERROR**

Your current configuration exceeds the monthly budget:

**Selected Configuration:**
- Backend: Microservices (Event-Driven) → $1,100
- Frontend: Micro-frontends + SSR → $550
- Integrations: 8 ACLs → $400
- **TOTAL:** $2,050/month

**Budget Tier:** Professional ($500-$2,000/month)
**Excess:** +$50 (+2.5%)

**Viable Alternatives (within budget):**

1. **Option A** - Simplify Backend ($1,850/month)
   - Backend: Microservices (pure REST) → $800 (-$300)
   - Frontend: Micro-frontends + SSR → $550
   - Integrations: 8 ACLs → $400
   - **Savings:** $200

2. **Option B** - Simplify Frontend ($1,650/month)
   - Backend: Microservices (Event-Driven) → $1,100
   - Frontend: SSR with hydration → $150 (-$400)
   - Integrations: 8 ACLs → $400
   - **Savings:** $400

3. **Option C** - Upgrade Budget Tier
   - Upgrade to Enterprise Tier ($2K-$10K/month)
   - No architectural changes needed

Which option do you prefer? [A/B/C/Custom]
```

---

## Integration with Other Rules

### Reference in Constitution

**`.context/constitution.md`** must include:
```json
{
  "governance": {
    "ai_budget": {
      "tier": "professional",
      "monthly_limit": 2000,
      "tracking_file": ".claude/rules/ai_budget_tracker.md",
      "policy": ".claude/rules/ai_budget_governance.md"
    }
  }
}
```

### CI/CD Integration

**Pre-commit Hook:**
```bash
#!/bin/bash
# scripts/check-budget.sh

current_consumption=$(scripts/calculate-tokens.sh)
budget_limit=$(jq -r '.governance.ai_budget.monthly_limit' .context/constitution.md)

if [ "$current_consumption" -gt "$((budget_limit * 80 / 100))" ]; then
    echo "⚠️ WARNING: Budget at 80% ($current_consumption tokens)"
fi
```

---

## Further Reading

- [OpenAI Pricing](https://openai.com/pricing)
- [Anthropic Pricing](https://www.anthropic.com/pricing)
- [Google Cloud Vertex AI Pricing](https://cloud.google.com/vertex-ai/pricing)
- [Token Economics for AI-Driven Development](https://arxiv.org/abs/2310.12345) (hypothetical reference)

---

**Version:** 1.0  
**Last Updated:** 2026-01-23  
**Maintained by:** Setup & Governance Agent
