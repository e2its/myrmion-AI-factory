---
id: ADR-EVOL-132
title: "Reference products — SETUP asks which market products the project resembles; each phase reads only the entries its decision concerns, and a citation of a product the answer does not name is red"
date: 2026-11-18
status: accepted
---

# ADR-EVOL-132: Reference products

## Context

This ADR implements issue #229 (epic #151, P0). It was verified on `main` at framework 10.6.0 (6bf8c26).

### State today
- **No question asks which products the project resembles.**
  - The nearest answers are Q2 `business_goal` (free text) and Q13 `frontend.visual_dna.references`.
  - Q13 is free text, is asked only when there is a frontend, and covers visual style only.
  - The only reader of Q13 is the ux-constitution brand identity at materialisation (`Factory-setup-materialization` § 4.2.9).
- **CODESIGN, BLUEPRINT and DEVOPS decide with no comparator.** #225's RDR «Market:» line has nothing that says which market the product belongs to.
- **Comparable products are a business fact.** An agent must not invent them (LAW-16), so the answer comes from the person, once, at SETUP.

## Decision

1. **One question, always asked.** Q2.1 is tier 0, `since: 10.7.0` and has no condition. Its key is `reference_products`, of a new free kind, `references`.
   - The answer is a list. Each entry is either:
     - `{name, for, feature?, link?}`, where `for` is one of `product | feature | look_and_feel | operating_model` (closed vocabulary), or
     - `{first_of_its_kind: "<reason>"}`.
   - Any product may be named. The framework ships no list of products (LAW-07).
   - Each entry is written as a flow mapping (`- {name: Linear, for: product}`). The fallback YAML-subset reader, used where PyYAML is absent, reads that form and not a block mapping inside a list; both readers agree on it.
2. **The resolver refuses a malformed answer.** `_check_answers` is the one reader; it exits 2 on `--resolve` and `--eval`. It refuses:
   - a value that is not a non-empty list of mappings, including one written as a mapping (read as dotted keys);
   - a blank name;
   - a `for` outside the vocabulary;
   - `for: feature` without its feature, or a feature without `for: feature`;
   - a link that is not `http(s)://`, or one that carries a user or a password;
   - an unknown field;
   - «first of its kind» with a blank reason.

   A condition tests a `references` key with `exists` only, the same rule as a `list` key.
3. **One home: Q13 folds in.**
   - `frontend.visual_dna.references` leaves Q13 and the answer-home template.
   - The registry's new key-spec field `carries: {from, for}`, allowed only on a `references` key, folds an answered old key into the new one. It applies when the new key is unanswered, in `answers()`, so every reader sees one home.
   - Each old value becomes `{name: <verbatim>, for: look_and_feel, carried_from}`. Nothing is reworded.
   - V1 is red when `from` is still a registry or derived key, because that would be two homes.
   - `--resolve` reports `carried: [{key, from, entries}]`. A key holding only carried entries is still pending, so `SETUP --upgrade` asks Q2.1 with the carried entries shown.
   - Upgrade step 8b writes each carried value under its key and removes the old key. This is generic: no per-key migration entry. The person's confirmed answer is written without `carried_from`; that ends the question.
   - The ux-constitution brand identity reads the `look_and_feel` entries (its template table: product, link, style).
4. **Read where decisions are made, and only there.** Each phase reads the one key and keeps the entries its decision concerns. This is the existing single-key read (`READ docs/setup.md → hosting.deploy_tool`); no new command or flag is added.
   - CODESIGN feature reads `product`, `operating_model`, and `feature` entries that name the feature.
   - CODESIGN vision reads `look_and_feel`.
   - BLUEPRINT reads `product`, and `feature` entries that name the feature.
   - DEVOPS reads `operating_model` and `product`. The reader sits in `Factory-devops-configure` (where the operating decisions are taken), not in provision-deploy, which executes them.
   - A decision cites ``Reference product: `Name` · <source>``. The label is its own: `Reference:` already names standards and paths across the corpus, and a citation of `RFC 6749` must never read as a product.
   - BLUEPRINT and DEVOPS take the facts from the vendor's official documentation (the docs reader), never from the reference product. The reader receives `name`, `for` and `feature` only; the `link` is the person's pointer and is never fetched.
   - CODESIGN has no docs reader. It asks the person how the product does what they point at, claims nothing about it itself (LAW-16), and cites the person's link or `docs/setup.md` as the source.
   - Only SETUP (Q2.1) writes the key. A product the person names in another phase is added at SETUP.
   - #225 owns the RDR «Market:» line and reads this key once it ships.
5. **The check is mechanical: `gate.py freeze` clause (e).** No new gate is added.
   - Freeze already runs at the push, in CI and at `BLUEPRINT --approve`.
   - It scans the changed decision artefacts (`docs/spec/*/**/*.md|.feature`, `docs/project_log/adr/*.md`, `docs/ux/vision/*.md`), in the repo or in their External home (a pin, read through the documents reader), outside code fences. The fence reader is one linear pass over lines.
   - A citation is red when:
     - it names a product the effective answer does not name (case-insensitive; the carry is included, «first of its kind» names none);
     - it carries no `· source`;
     - the answer home is unreadable.
   - No citation gives `n/a` with its reason.

### Sources
- Issue #229, the WHAT: one question, one home, read only where decisions are made, scripts check what they can.
- LAW-16 and LAW-07 for business purity and template hygiene.
- `Factory-blueprint-design` uses the precedent single-key read, `READ docs/setup.md → hosting.deploy_tool`.
- Precedent mechanical check: freeze clauses (a) and (d), whose cells read `answer · source` (EVOL-115, EVOL-082).

## Consequences
- **Every project answers one more tier-0 question.** An installed project is asked it once at `--upgrade`, with its Q13 answer already in it.
- **A design, spec or ADR citing a product the person never named turns red at the push.** A cited product without its official source turns red too.
- **No phase keeps its own list.** The ux-constitution reads the same answer.

## Honest limits
- The check judges citations written in the ``Reference product: `Name` `` form (bold label allowed). A product named in prose is not a citation and is not judged. A second citation on the same line is not judged.
- The source after `·` is checked for presence, not for being official — the same rule as clause (a).
- The names are read from `docs/setup.md` as the change leaves it. A change that adds a product to the answer and cites it in the same branch is green; the answer's edit is visible in the pull request's diff, and the instructions route a new product to SETUP. Reading the answer at the merge-base instead would block the person's own re-answer on the branch that needs it.
- `for: feature` entries are matched to a feature by the agent's reading. The gate does not tie them to a feature id.
- A carried Q13 value is kept verbatim as one entry's name. Splitting it into products is the person's re-answer.

## Verification record
- **Red first.** The 11 new tests (`References` ×5, `FreezeReferences` ×6) were run against the gate code of `origin/main` (6bf8c26). All 11 fail; the registry test fails against the old registry.
- **Mutation sweep.** 28 mutants on the new branches of `discovery.py` and `freeze.py`, run in a scratch worktree, are all killed. The one first survivor (the code-fence filter in `citations()`, masked by the caller's guard) is now killed by a mixed-file case.
- **Synthetic materialisation.** 11 of 11 fixtures pass with `--answers`.
  - `default` answers `reference_products` with product, feature and look-and-feel entries.
  - `upgrade-8.12` answers the old Q13 key and expects it carried, with Q2.1 still pending.
  - With the `carried` expectation removed, the run is red.
- **Registry.** `gate.py discovery` is green (V1–V14).
- **Critics, round 1** (4 lenses). Cured:
  - the fence reader is linear (a 2000-opener file took 2.5 s with the old regex, and grew quadratically);
  - decision artefacts in an External home and vision artefacts are judged;
  - the label is `Reference product:`, so a `Reference:` naming a standard or a path is not a citation;
  - an answer written as a mapping is refused, and so is a link with a user or a password;
  - the upgrade says that confirming drops `carried_from`;
  - the reader never receives the link, and CODESIGN claims nothing about a product;
  - the ux-constitution table reads product, link and style.

  Ten more mutants on the cure are all killed. Recorded as limits: the self-attesting answer edit, presence-only source, and one citation per line.
