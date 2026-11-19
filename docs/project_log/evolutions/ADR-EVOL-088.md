---
id: ADR-EVOL-088
title: "Context-compression MCP (headroom): ship only what a pre-registered, wired before/after run proves, and never compress the payload"
date: 2026-11-19
status: proposed
---

# ADR-EVOL-088: Context-compression MCP — measure before shipping

## Context

Spike for issue #142 (epic #112, wave 5). Verified on `main` at framework 10.9.1. No framework change is made by this spike.

**Today**

- The framework does not reference the tool: no hit in `.claude/**`, `.context/templates/**` or `config/` (a repo-wide grep finds the word only as English «headroom» in `.context/utils/budget_validator.py:214` and `docs/project_log/evolutions/ADR-EVOL-064.md:50`). There is no `.mcp.json` in the repo. A materialised project never gets it.
- EVOL-062 chose another path for large outputs: above `context_result_max_kb: 20` (`.context/templates/setup/rules/agents.md:64`) a verification, deployment or diff output goes to a file and **its tail is read**; reads of large files carry a limit (`rules/agents.md:133`, bound (3)).
- The payload-verbatim invariant: code, paths, identifiers, error text and a hand-off's state are copied verbatim, «never paraphrased, summarised or compressed; the diet bounds what enters the context, never rewords it» (`rules/agents.md:133`; the issue cites `:127`, the template line today is 133).
- The instrument counts tokens de-duplicated per message id, the median context per session, cache per spawn and the raw results above the threshold (`.context/templates/setup/subproducts/measure/measure.py:421-444,1171-1195`; `RUNBOOK.md` «Context (EVOL-062)» row). It has **no counter for calls to any MCP tool**: tool uses are classified by name only for Read/Bash/Agent (`measure.py:261-330`). Without a counter the «0 calls» of #91 cannot be told apart from «never offered» and a wired window cannot prove the tool was used.
- Discovery already carries an optional-MCP precedent: `qa.browser_mcp`, options `chrome-devtools | playwright | none`, `open: true`, each option `configures` an `mcp.servers` entry with a pinned version and hardened flags (`.context/templates/setup/setup/discovery_registry.json:1677-1710`). #159 owns the registry and the `.mcp.json` target.

**What the tool is** (external; README of the project, <https://github.com/chopratejas/headroom>, Apache-2.0)

- Three MCP tools: `headroom_compress`, `headroom_retrieve`, `headroom_stats`. Originals are cached locally and retrievable by hash for a TTL. Compressors are chosen by content type: JSON (drops items outside the normal range, keeps errors and first/last), AST-aware code compression, prose.
- Vendor claims: 21–57 % fewer input tokens in four agent scenarios, «scale with how repetitive the payload is»; prose and dense output compress little. Vendor-reported, not verified here.
- An anonymous telemetry beacon is on by default (disable with `HEADROOM_BEACON=off` or `HEADROOM_OFFLINE=1`). A proxy/wrapper mode (`headroom wrap`) compresses automatically.

**Owned elsewhere — never re-decided here**

- #97 (EVOL-062): the diet, `context_result_max_kb`, the hand-off, the payload-verbatim invariant. This ADR reuses that key as the only trigger and adds none.
- #106 (EVOL-063): `autoCompactWindow` 300000. Held constant in both windows.
- #235 (EVOL-133): the session notebook — working state survives a compaction verbatim. It is payload, never compressible.
- #186: the before/after windows of five shipped evolutions in the **first adopting project**. This spike's windows run on a throwaway branch of a **synthetic materialised sample**; the two never share a window, a baseline or a comment.
- #159: registry and `.mcp.json` target; #151 platform packs.

## Questions

**Q1 — Where compression is safe.**

| Class | Examples | Rule |
|---|---|---|
| Evidence of a state | a verification or test run log already written by `gate.py seal --run`, a CI log, a sealed diff, a deploy output | may be compressed; the original stays on disk and is the record |
| Work input | code under edit, paths, identifiers, error text being fixed, a hand-off, the notebook (#235), spec/design/plan artefacts, a user's words | verbatim, always |
| Ambiguous | a log whose error line is the thing to fix | verbatim: when the work is to act on the content, it is input |

The test is mechanical, not judged by an agent: the source is a file the executor already wrote above `context_result_max_kb`. Anything an agent reads to *act on* is out of scope. Compression is lossy by construction (items dropped, retrieval by hash); a lossy result is acceptable only where the full original is on disk and nothing is decided from the summary alone.

**Q2 — Measured effect.** Not run in the spike's first pass: the instrument cannot yet prove a wired window (no MCP-call counter). The measured run is #142's remaining DoD, after #253 (§ Decision). The design is fixed below, before the first run, so no number is invented.

**Q3 — Measurement design (pre-registered).**

- **What is measured** (all from `subproducts/measure --json`, de-duplicated per message id):
  1. Primary: median context per main session (input + cache-read + cache-creation per request), and cache-read per session.
  2. Secondary: session floor p50; tokens by category and dollars with the same `prices`; raw results above `context_result_max_kb` per session; writer cache per spawn by turn bucket.
  3. Use (new counter, follow-up A): calls to the compression tool per session, calls to `headroom_retrieve` per compress call, bytes in/out per call.
  4. Guards (cost of the work): gates red at first run, returns refused, rework share, review rounds per branch — all already in the instrument.
- **Where:** a throwaway branch of a sample project materialised synthetically from this framework (never an adopting project, never this repo). Window «after» wires the tool completely: MCP declared, rule naming the Q1 classes, skill step at the one point where an output above the key is read. Window «before» is the same branch without the wiring. The only difference is the wiring.
- **Same everything else:** one fixed task set (≥ 3 tasks of unlike shape: a feature increment, a fix, a verification-heavy run), same model family and effort per class, same `autoCompactWindow`, same framework version, same harness version.
- **How many:** proposed default 5 sessions per task per window, and one extra «before» window (A/A) to measure the noise floor. Report median and spread (p25–p75, min, max), never one run. Frozen in § Decision; fewer than 5 is not a verdict.
- **Threshold that decides** (pre-registered, proposed for ratification): ship only if **all** hold:
  1. median context per session in «after» is lower than «before» by more than the A/A spread **and** by at least 10 %; same for cache-read per session;
  2. the guards do not worsen beyond the A/A spread (extra red gates, refused returns, review rounds);
  3. the tool was actually used: ≥ 1 compress call in at least 80 % of «after» sessions (else the window measured missing wiring, repeating #91's 0, and is void, not a «no»);
  4. a payload audit finds **zero** compress calls on a Q1 work-input source (path/class check over the transcripts);
  5. the session floor (tool definitions in context) does not offset the gain: floor p50 delta is reported and subtracted.
- **If a window is void or fails:** it is a finding and an issue against the policy, never an edit of numbers (same rule as #186).

**Q4 — Shipping shape if adopted.** An optional registry question (`open: true`, none by default) like `qa.browser_mcp`, whose option `configures` the `mcp.servers` entry with a pinned version and the beacon disabled; a rule paragraph naming the Q1 classes; one skill step; the instrument counting calls. Proxy/wrapper mode is excluded (it rewrites the payload).

## Decision to take (RDR)

### In plain words

(es-ES)

**Qué se decide.** Si el proyecto que genera el framework debe incluir una herramienta que resume las salidas largas (registros de pruebas, de despliegues) para que las sesiones gasten menos cuota. Hoy los proyectos nuevos no la reciben.

**Por qué ahora.** Una medición anterior contó cero usos de la herramienta. Eso no demuestra que no sirva: el framework nunca se la ofreció a los agentes. Hoy ya existe otra vía más sencilla (guardar las salidas largas en un fichero y leer solo el final). Falta saber si la herramienta aporta algo encima de eso.

**Regla que no se negocia.** Nada de lo que el trabajo necesita para actuar (código, rutas, errores que hay que arreglar, notas de traspaso, tus palabras) se resume jamás. Solo se podría resumir el registro de algo que ya ocurrió y ya está guardado completo.

**Las opciones y lo que cuesta cada una.**

1. **No incluirla.** No cuesta nada y no hay riesgo. Se queda como está; nunca sabremos si se perdía un ahorro.
2. **Medir primero y decidir con números (recomendada).** Se construye solo un contador de usos y se ejecuta una prueba controlada, con el mismo trabajo antes y después, en un proyecto de ejemplo desechable. Cuesta una prueba con consumo real de sesiones y retrasa la decisión; no hay riesgo para los proyectos. Si los números no pasan el umbral fijado de antemano, no se incluye.
3. **Incluirla ya como opción de SETUP y medir después, en proyectos reales.** Más rápido para quien la quiera, pero se entrega una pieza nueva (instalación externa, aviso de telemetría activo por defecto, resumen con pérdida) sin saber si compensa, y retirarla después cuesta una migración.
4. **Activarla en modo automático para todo.** Máximo ahorro posible, pero resume también lo que el trabajo necesita: rompe la regla que no se negocia. Descartada salvo que quieras cambiar esa regla.

Decidido: la 2 (sección Decision). La prueba se ejecuta dentro de #142 cuando el contador esté entregado, con el tope de gasto diario. Esta propuesta no inventa ningún resultado.

### Technical

**Evidence.** See Context: the diet is EVOL-062 (`rules/agents.md:64,133`); the instrument lacks an MCP-call counter (`measure.py:261-330`); the registry has the optional-MCP shape (`discovery_registry.json:1677-1710`); the tool's own claims are vendor-reported and content-dependent.

**Adversarial pass on the recommendation (option B: measure-gated, nothing of the tool ships now).**

FOR
- Governance: a measure-then-ship order matches the instrument's own rule («the numbers decide», `RUNBOOK.md` before/after section) and keeps a payload-verbatim breach impossible by construction (audit item 4).
- Product: the #91 «0» measured missing wiring; only a wired window can tell. A pre-registered threshold prevents a post-hoc verdict from one run.

AGAINST (do-less lens included)
- Governance: the registry question, the rule paragraph and a skill step are new always-read surface (every added line costs context in every project); LAW-04 — a pip-installed tool with default telemetry on is a supply-chain and data-exposure surface; the OWASP/secret check has to cover its local cache of originals (logs may hold secrets).
- Product: EVOL-062 file+tail plus #106's 300k window may already capture most of the gain; the tool adds three tool definitions to the session floor and a retrieve round trip per compressed output, which can cost more than it saves on non-repetitive logs (the vendor itself says savings scale with repetition). A model-invoked compressor reads its target via a call whose result enters context anyway; only the file-path form avoids the raw entry (❓ unverified — external: whether `headroom_compress` accepts a path).
- Do-less: option A builds less and the only shipped cost of B is the counter plus one run. B survives because the counter is useful for any future context tool and the run is a spike deliverable. The surviving risk: a sample project may not predict real projects' log mix.

**Options**

| # | Option | Governance axis | Product axis |
|---|---|---|---|
| A | Do not ship; keep EVOL-062 file+tail | + no new surface, invariant untouched. − closes the issue's question unanswered, #91's 0 stays ambiguous | + zero risk. − a possible saving never measured |
| B | **Measure-gated**: build the call counter, run the pre-registered windows, decide shipping by a second RDR with numbers; conditional pack (follow-up C) filed blocked | + invariant held by audit; the instrument grows once, reusable. − one counter added to a shipped subproduct | + decision on evidence, no downstream change until proven. − delay, one run's session spend |
| C | Ship the optional pack now (registry question, rule, skill step, counter), measure in adopting projects through #186-style windows | + fast. − new surface and external dependency before proof; removal needs an upgrade step | + early adopters may save. − could cost more than it saves; rollout without a baseline |
| D | Automatic proxy/wrapper mode for all sessions | − breaks payload-verbatim (LAW-class invariant of `rules/agents.md:133`); outside the harness's visible tool path | + largest claimed saving. − compresses work input; uncontrollable by rule |

**Recommendation: B.** Main tradeoff: time and one measured run against shipping blind. Surviving risk: the sample project's output mix differs from a real project's, so a pass transfers loosely; the second RDR therefore ships the tool as `none`-by-default optional, never on by default.

Ratification (user's verbatim choice) is persisted in the commit message or in this ADR's `status:` change; no feature artefact exists here.

## Decision (evidence)

**Option B — measure-gated.** Nothing of the tool ships now. The instrument gains its counter (#253, EVOL-140). The pre-registered windows then run under #142 itself, and a second decision with the numbers settles shipping. Decided on the evidence, with no owner RDR. The owner set the precedent on #139 (2026-11-19).

**Why no RDR.** The issue's own goal, stated by the owner, is «measure before shipping, never compress the payload»:
- A closes the question unanswered.
- C ships before the measurement.
- D compresses work input, which breaks the payload-verbatim invariant.
- Only B meets the stated scope. Nothing is irreversible or outward-facing until the run.

**Pre-registered design (frozen here, before the first run):**
- 5 sessions per task per window, plus one A/A «before» window.
- Pass: median context per session lower than «before» by more than the A/A spread **and** by at least 10 %, and the same for cache-read per session.
- The tool was used: at least 1 compress call in at least 80 % of «after» sessions. Otherwise the window is void, not a «no».
- The payload audit is at 0.

These are the Q2 values, now ratified as the design.

**The run (#142's remaining DoD).**
- It runs after #253 ships, on a throwaway sample project, within the daily spend cap.
- The telemetry beacon stays off, and its state is checked in the pinned version before the first session.
- It reports numbers only on #142: no project names, no reports in the repository.

**Follow-up C** (the optional pack) is filed only if the run passes. A failing run closes the question as «do not ship» and records it here.

## Consequences

For B (nothing of the tool lands in a project until the second RDR):

- **Lands in a materialised project:** only the instrument extension (follow-up A) — `measure.py` counts calls to MCP tools whose name matches a configured list, plus bytes; the self-test gains a fixture; the RUNBOOK row. Nothing else.
- **Which answer selects it:** none; `subproducts/measure` ships to every project (EVOL-042).
- **Upgrade path:** `factory-sync.sh` / `SETUP --upgrade` carry the subproduct files byte-identical; no registry question yet.
- **If the measured run passes:** a new optional question (e.g. `context.compression_mcp: headroom | none`, default none, `open: true`) under #159's registry, whose `configures` writes the pinned `mcp.servers` entry; rule + skill step in the same change (SDLC consistent). `--upgrade` asks the question; a project that answers `none` is unchanged.
- **Synthetic proof:** `scripts/test-measure.sh` selftest over the new fixture; for the later pack, a synthetic materialisation run with `--answers` asserting the entry lands only for the headroom answer, the beacon is off, the rule paragraph names the Q1 classes, and a payload-audit fixture is red on a compress call over a work-input source.

## Follow-up issues

**A. measure — count calls to a context-compression tool** → #253 (EVOL-140)
- Goal: the instrument can say whether a compression MCP was called, how often and how much, so a wired window is provably wired.
- We want: calls per session to a configured list of MCP tool names; retrieve-per-compress ratio; bytes in and out per call; the three signals in `--compare`; a selftest fixture with repeated blocks; a payload-audit signal (compress calls whose source is a work-input class).
- We do not want: a baseline claimed from this repo; a new command or flag; any gate reading the subproduct; an agent computing what the script can.
- How it reaches a project: no SETUP answer; ships with `subproducts/measure` on `--generate` and `--upgrade` (byte-identical); proof: meta selftest through the synthetic materialisation (`scripts/test-measure.sh`).
- Depends on: none (phases with #186: it reads the same instrument, adds rows, claims no window).

**B. Run the pre-registered headroom windows on a throwaway sample project** → #142 itself (its remaining DoD; no new issue)
- Goal: the measured before/after (A/A, before, wired after) the spike's DoD requires, with median and spread, so the shipping RDR has numbers.
- We want: the design of this ADR frozen and ratified first; a synthetic sample materialised; the wiring on a throwaway branch (MCP, rule, skill step); reports kept outside the repo; numbers only, no project names, posted on the issue.
- We do not want: a single-run verdict; an «after» without the wiring; the payload compressed; any framework change; the windows mixed with #186's.
- How it reaches a project: nothing lands; proof is the posted table and the payload audit at zero.
- Depends on: A; this ADR ratified (thresholds and N).

**C. Optional context-compression MCP pack (conditional on B)**
- Goal: a project that answers yes gets the tool wired — declaration, rule, skill step, instrument — and one that answers no is untouched.
- We want: one registry question, none by default; pinned version, telemetry off, local cache covered by the security review; a rule paragraph naming evidence vs work input; one skill step at the above-key read; the counter from A.
- We do not want: on by default; proxy/wrapper mode; a second trigger key beside `context_result_max_kb`; a new command or flag.
- How it reaches a project: the registry answer selects it; `--generate` writes the `.mcp.json` entry through #159's target; `--upgrade` asks the question; proof: synthetic materialisation with `--answers` for both answers.
- Depends on: B passing its thresholds; #159 (registry, `.mcp.json` target). Filed only if B passes; never built before B's numbers.

## Honest limits

- No measurement was run; this ADR fixes the design and the run follows #253. Thresholds (10 %, 5 sessions, 80 % usage) are pre-registered design, not findings.
- `headroom` was not called on repository content (brief); its description comes from its public README and third-party summaries.
- ❓ unverified — external: the current release and its pin; whether `headroom_compress` takes a file path (so the raw output never enters context); the default state and scope of the telemetry beacon in the pinned version; where the originals' cache lives and its TTL default; the lossless/lossy status of the code compressor; the vendor's savings figures; the exact transcript name of the tool's calls (expected `mcp__headroom__headroom_compress`, seen in this harness's tool list).
- A sample project and a real project differ in output mix; a pass does not transfer by itself.
- Compression interacts with the provider cache (the vendor says the frozen prefix stays byte-identical); that was not checked and cache-creation must be watched in the window.
