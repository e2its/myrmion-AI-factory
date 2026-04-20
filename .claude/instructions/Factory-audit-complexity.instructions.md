---
description: "Factory AUDIT complexity analysis — COMP1 scoring, risk weighting, technical debt assessment. Use when: AUDIT complexity scoring."
---

# AUDIT Agent — Phase E: Complexity Analysis (COMP1) & SETUP Integration

## Purpose
This instruction file defines the **Multi-Dimensional Complexity Assessment** (Phase E, COMP1) and the **Integration with SETUP Agent** for the AUDIT agent. COMP1 analyzes 21 categories of project complexity, producing a score that determines migration strategy recommendations.

---

## Phase E: COMP1 Multi-Dimensional Complexity Assessment

### Overview
- **21 categories**, each scored **0-3 points**
- Maximum total: 63 points
- **Complexity Score** = total_points / 21 (range: 0.0 - 3.0)
- Assessment Level: ≥2.5 CRITICAL (3), ≥2.0 HIGH (2), ≥1.0 MEDIUM (1), <1.0 LOW (0)

### Auto-Detection + RDR Protocol
For each category:
1. **Scan** workspace for evidence (files, configs, patterns)
2. If confidence ≥80%: Auto-assign score, present to user for confirmation
3. If confidence <80%: Use RDR (Recommendation → Decision → Ratification)
4. Categories marked "ALWAYS ASK": Always use RDR regardless of scan confidence

---

### Category 1: Approach (0-3)
- **0**: Clean start, new project, no constraints
- **1**: Existing project, minor constraints, clear direction
- **2**: Legacy modernization, significant constraints, unclear direction
- **3**: Full rewrite of critical production system with migration requirements
- **Auto-detect**: Check for existing codebase size, legacy markers, migration docs

### Category 2: Development Expertise (0-3)
- **0**: Team has deep expertise in target stack
- **1**: Team knows stack, some gaps in advanced features
- **2**: Team learning target stack, expertise in different stack
- **3**: Team has no experience in target stack
- **Auto-detect**: Scan git log for commit patterns, check technology consistency

### Category 3: SaaS Product Expertise (0-3)
- **0**: Team built SaaS products before
- **1**: Team has general web app experience
- **2**: Team has desktop/embedded experience, new to SaaS
- **3**: Team has no software product experience
- **Auto-detect**: Check for SaaS patterns (multi-tenancy, billing, subscription logic)

### Category 4: Legacy Transformation (0-3)
- **0**: No legacy to transform
- **1**: Legacy exists but isolated, clean interfaces
- **2**: Legacy is core with some modular boundaries
- **3**: Monolithic legacy deeply coupled, no clear boundaries
- **Auto-detect**: Scan for module coupling, dependency graphs, circular imports

### Category 5: Legacy API (0-3)
- **0**: No legacy API or clean documented API
- **1**: Legacy API exists, documented, versioned
- **2**: Legacy API exists, partially documented, consumers unknown
- **3**: Undocumented legacy API with unknown consumers and implicit contracts
- **Auto-detect**: Scan for API specs (openapi, swagger), route registrations

### Category 6: Legacy Tech (0-3)
- **0**: Modern, supported stack
- **1**: Mature stack, some components approaching EOL
- **2**: Multiple components at or past EOL
- **3**: Entire stack is obsolete/unsupported
- **Auto-detect**: Cross-reference dependency versions with EOL databases

### Category 7: Legacy Coupling (0-3)
- **0**: Clean architecture, loose coupling, dependency injection
- **1**: Mostly decoupled, some tight coupling in specific areas
- **2**: Significant coupling between modules, shared mutable state
- **3**: Deep coupling: shared DB schemas, circular deps, god classes, no boundaries
- **Auto-detect**: Scan import graphs, detect circular dependencies, shared state patterns

### Category 8: Legacy Product Size (0-3)
- **0**: <10K LOC
- **1**: 10K-50K LOC
- **2**: 50K-200K LOC
- **3**: >200K LOC
- **Auto-detect**: Count LOC with `find . -name "*.{ext}" | xargs wc -l` (exclude node_modules, dist)

### Category 9: Data Sync (0-3)
- **0**: No data sync required
- **1**: One-way sync, batch, well-defined
- **2**: Bidirectional sync or real-time requirements
- **3**: Complex multi-source sync with conflict resolution, eventual consistency
- **Auto-detect**: Scan for sync patterns, message queues, event sourcing, CDC

### Category 10: Persistence Engine (0-3)
- **0**: Single relational DB, clean schema
- **1**: Single DB with some complexity (stored procs, triggers)
- **2**: Multiple databases or polyglot persistence
- **3**: Complex polyglot + legacy data models + data warehouse + ETL
- **Auto-detect**: Scan for DB configs, ORM models, migration files, connection strings

### Category 11: Agile Culture (0-3)
- **0**: Mature agile (sprint cadence, retrospectives, CI/CD, automated testing)
- **1**: Agile adopted, some practices missing
- **2**: Waterfall-leaning, infrequent releases
- **3**: No defined methodology, ad-hoc development
- **Auto-detect**: Check for sprint boards, CI/CD configs, test coverage, release frequency

### Category 12: Window of Opportunity (0-3) — ⚠️ ALWAYS ASK
- **0**: No deadline pressure, flexible timeline
- **1**: Soft deadline, some flexibility
- **2**: Hard deadline, limited flexibility
- **3**: Critical deadline with penalties/contractual obligations
- **Cannot auto-detect**: Business context required

### Category 13: Product Size (0-3)
- **0**: Small product (<5 pages/endpoints)
- **1**: Medium product (5-20 pages/endpoints)
- **2**: Large product (20-50 pages/endpoints)
- **3**: Very large product (>50 pages/endpoints + complex domain)
- **Auto-detect**: Count routes/pages, analyze feature complexity, check roadmap

### Category 14: Availability of Teams (0-3)
- **0**: Full dedicated team available
- **1**: Mostly available, some shared resources
- **2**: Partially available, split across projects
- **3**: Severely constrained, key people unavailable
- **Auto-detect**: Scan CONTRIBUTING, README for team info; confirm with RDR

### Category 15: Company SaaS Mindset (0-3)
- **0**: SaaS-native company, cloud-first culture
- **1**: Company transitioning to SaaS
- **2**: Traditional software company, SaaS is new
- **3**: Non-software company building software
- **Auto-detect**: Check company docs, product portfolio; confirm with RDR

### Category 16: Company Size (0-3) — minimum score: 1
- **0**: N/A (minimum is 1)
- **1**: Startup/small (1-50 employees)
- **2**: Medium (50-500 employees)
- **3**: Enterprise (>500 employees, complex governance)
- **Auto-detect**: Check company docs; confirm with RDR

### Category 17: Market Competency (0-3) — ⚠️ ALWAYS ASK
- **0**: First mover, no direct competitors
- **1**: Established market, clear differentiator
- **2**: Competitive market, need to catch up
- **3**: Saturated market, need radical innovation
- **Cannot auto-detect**: Business context required

### Category 18: SDLC-CI/CD Ecosystem (0-3)
- **0**: Mature CI/CD, automated testing, IaC, monitoring
- **1**: CI/CD exists, partial automation
- **2**: Basic CI, minimal automation
- **3**: No CI/CD, manual everything
- **Auto-detect**: Scan for CI configs, deployment scripts, IaC files, monitoring configs

### Category 19: Development Technology (0-3) — minimum score: 1
- **0**: N/A (minimum is 1)
- **1**: Modern, well-supported stack with strong ecosystem
- **2**: Stable but aging stack, migration path exists
- **3**: Obsolete stack, no clear migration path
- **Auto-detect**: Cross-reference stack with community support, update frequency

### Category 20: Integrations (0-3)
- **0**: No external integrations
- **1**: 1-3 well-documented API integrations
- **2**: 4-8 integrations, some legacy or poorly documented
- **3**: >8 integrations, complex protocols, some undocumented
- **Auto-detect**: Scan for API clients, SDK imports, webhook configs, integration docs

### Category 21: Regulatory Policies (0-3) — ⚠️ ALWAYS ASK
- **0**: No regulatory requirements
- **1**: Standard data protection (GDPR basic)
- **2**: Industry-specific regulations (healthcare, finance)
- **3**: Highly regulated (PCI-DSS, HIPAA, SOX, FedRAMP)
- **Cannot auto-detect**: Compliance context required

---

## Complexity Score Calculation

```yaml
total_points = SUM(all 21 category scores)
complexity_score = total_points / 21  # 0.0 - 3.0

complexity_assessment_level:
  IF complexity_score >= 2.5: LEVEL 3 (CRITICAL)
  IF complexity_score >= 2.0: LEVEL 2 (HIGH)
  IF complexity_score >= 1.0: LEVEL 1 (MEDIUM)
  IF complexity_score <  1.0: LEVEL 0 (LOW)
```

### Interpretation & Recommendations

**LEVEL 0 — LOW (score < 1.0):**
- Low risk, proceed with standard approach
- Extension Strategy: E0 (Native Extension) or clean start
- Expected effort: Standard SDLC timeline

**LEVEL 1 — MEDIUM (score 1.0-1.9):**
- Moderate complexity, plan for risk mitigation
- Extension Strategy: E0 or E1 (Preserve + Wrapper)
- Focus areas: highest-scoring categories
- Expected effort: 1.5-2x standard timeline

**LEVEL 2 — HIGH (score 2.0-2.4):**
- Significant complexity, dedicated mitigation plan required
- Extension Strategy: E1 or E2 (Strangler Fig)
- Requires ADR for key architecture decisions
- Expected effort: 2-3x standard timeline

**LEVEL 3 — CRITICAL (score ≥ 2.5):**
- Very high complexity, comprehensive risk management essential
- Extension Strategy: E2 or E3 (Full Rewrite)
- Requires executive sponsor, phased approach, extensive testing
- Expected effort: 3-5x standard timeline, 18-36 months

### Output Format
The COMP1 section includes:
1. **Breakdown table**: All 21 categories with score, evidence, confidence
2. **Radar visualization**: Markdown description of score distribution
3. **Highest impact areas**: Top 5 categories by score
4. **Specific mitigations**: Per high-scoring category, actionable recommendations

---

## Integration with SETUP Agent (Section 5)

### 5.1: Field-by-Field Mapping (AUDIT → setup.md)

| AUDIT Finding | setup.md Field | Mapping Logic |
|--------------|----------------|---------------|
| S3 stack analysis | `backend.runtime` | Detected language + version |
| S3 stack analysis | `frontend.framework` | Detected framework + version |
| S2 topology mapping | `architecture.topology` | B1-B12 classification |
| S2 pattern analysis | `architecture.patterns` | Detected patterns list |
| I1 hosting analysis | `infrastructure.cloud_provider` | Detected provider |
| I2 CI/CD analysis | `infrastructure.ci_cd` | Pipeline tool detected |
| SEC5 compliance | `compliance_requirements` | Detected regulations |
| G1 team analysis | `team.size`, `team.seniority` | Team composition |
| G3 budget analysis | `budget.monthly_infra` | Estimated monthly cost |
| Overall verdict | `project_mode` | Always "Brownfield" for audited projects |

### 5.1b: Migration Strategies Catalog (E0-E3)

#### E0 — Native Extension
- **When**: risk_score < 25 AND complexity_score < 1.0
- **What**: Active project with coherent architecture — extend natively
- **Pattern**: Zero disruption. Add governance overlay alongside existing code
- **Scaffolding**: Add `.claude/rules/`, `contracts/`, `scripts/`, `config/` alongside existing code
- **Effort**: 1-2 weeks setup
- **Risk**: Lowest — no changes to existing code
- **Anti-pattern**: Forcing E0 on projects with deep coupling or obsolete stacks

#### E1 — Preserve + Wrapper
- **When**: risk_score < 40 AND complexity_score < 1.5
- **What**: Legacy as data/logic engine behind new API layer
- **Patterns**: ACL (Anti-Corruption Layer), Facade, DB Wrapper
- **Architecture**: New → Wrapper → Legacy (legacy hidden behind clean API)
- **Effort**: 2-4 weeks setup, 15-20% monthly adapter maintenance overhead
- **Risk**: Medium — adapter complexity grows over time
- **Success signal**: Legacy stabilized, new features only through wrapper
- **Anti-pattern**: Wrapper becomes as complex as legacy (Leaky Abstraction)

#### E2 — Strangler Fig
- **When**: risk_score 40-69 OR complexity_score 1.5-2.4
- **What**: Progressive module-by-module replacement of legacy
- **Patterns**: Strangler Fig, Intelligent Router, Dual-Write, Feature Toggles
- **Architecture**: Router → [Legacy Module | New Module] (per route/feature)
- **Effort**: 4-8 weeks setup, 12-24 months total migration
- **Risk**: High — dual systems during transition, data consistency challenges
- **Success signal**: Progressive legacy module count → 0
- **Anti-pattern**: Migrating all modules simultaneously (defeats the purpose)

#### E3 — Full Rewrite
- **When**: risk_score ≥ 70 OR complexity_score ≥ 2.5
- **What**: Complete rewrite with feature parity matrix
- **Patterns**: Big Bang Cutover OR Phased Cutover
- **Architecture**: Entirely new system built from spec
- **Effort**: 18-36 months, 2-5x cost of E1/E2
- **Risk**: Highest — Second System Effect, scope creep, feature parity gaps
- **Success signal**: Feature parity matrix at 100%, all integration tests pass
- **Anti-pattern**: Starting rewrite without complete feature parity matrix

### Comparative Decision Matrix

| Factor | E0 Native | E1 Wrapper | E2 Strangler | E3 Rewrite |
|--------|-----------|------------|--------------|------------|
| Risk | Minimum | Low-Med | Medium-High | Very High |
| Timeline | 1-2 weeks | 2-4 weeks | 12-24 months | 18-36 months |
| Cost | Minimal | Low | Medium | High (2-5x) |
| Disruption | Zero | Low | Medium | High |
| Technical Debt | Preserved | Contained | Reduced | Eliminated |
| Team Risk | None | Low | Medium | High |

### 5.2: SETUP Consumption Flow

When `SETUP --init` starts and `docs/technical_due.md` exists with `status: APPROVED`:

```yaml
SETUP reads technical_due.md:
  1. Auto-set project_mode: Brownfield
  2. Pre-fill answers from setup_mapping block
  3. Show audit conclusions for each pre-filled field
  4. SKIP questions already answered by audit (unless user wants to override)
  5. Recommend extension_strategy based on risk + complexity:
     
     IF risk_score < 25 AND complexity_score < 1.0:
       RECOMMEND: E0 (Native Extension)
     ELIF risk_score < 40 AND complexity_score < 1.5:
       RECOMMEND: E1 (Preserve + Wrapper)
     ELIF risk_score < 70 AND complexity_score < 2.5:
       RECOMMEND: E2 (Strangler Fig)
     ELSE:
       RECOMMEND: E3 (Full Rewrite)
```

### 5.3: Fields SETUP Always Asks (Even with Audit)

These fields require business decisions that AUDIT cannot determine:
1. `ai_budget_tier` — AI spending level (user decision)
2. Target `architecture.topology` — may differ from current (user decision)
3. `extension.strategy` — recommended by audit but user decides
4. `frontend.pattern` — UI architecture pattern (user decision)
5. `branching.strategy` — Git workflow (user decision)
6. `compliance_requirements` — audit detects existing, user confirms target

---

## Summary Flow

```
--audit → P0(Language) → A(G1→G3) → B(S1→S4) → C(I1→I4) → D(SEC1→SEC5) → E(COMP1)
                                                                                ↓
--approve → Risk Score → Recommendations → Verdict → Setup Mapping → APPROVED
                                                                        ↓
                                                            SETUP --init (consumes)
```
