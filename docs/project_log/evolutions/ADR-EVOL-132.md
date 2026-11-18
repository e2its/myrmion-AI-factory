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
2. **The resolver refuses a malformed answer.** `_check_answers` is the one reader; it exits 2 on `--resolve` and `--eval`. It refuses:
   - a value that is not a non-empty list of mappings;
   - a blank name;
   - a `for` outside the vocabulary;
   - `for: feature` without its feature, or a feature without `for: feature`;
   - a link that is not `http(s)://`;
   - an unknown field;
   - «first of its kind» with a blank reason.

   A condition tests a `references` key with `exists` only, the same rule as a `list` key.
3. **One home: Q13 folds in.**
   - `frontend.visual_dna.references` leaves Q13 and the answer-home template.
   - The registry's new key-spec field `carries: {from, for}`, allowed only on a `references` key, folds an answered old key into the new one. It applies when the new key is unanswered, in `answers()`, so every reader sees one home.
   - Each old value becomes `{name: <verbatim>, for: look_and_feel, carried_from}`. Nothing is reworded.
   - V1 is red when `from` is still a registry or derived key, because that would be two homes.
   - `--resolve` reports `carried: [{key, from}]`. A key holding only carried entries is still pending, so `SETUP --upgrade` asks Q2.1 with the carried entries shown.
   - Upgrade step 8b writes each carried value under its key and removes the old key. This is generic: no per-key migration entry.
   - The ux-constitution brand identity reads the `look_and_feel` entries.
4. **Read where decisions are made, and only there.** Each phase reads the one key and keeps the entries its decision concerns. This is the existing single-key read (`READ docs/setup.md → hosting.deploy_tool`); no new command or flag is added.
   - CODESIGN feature reads `product`, `operating_model`, and `feature` entries that name the feature.
   - CODESIGN vision reads `look_and_feel`.
   - BLUEPRINT reads `product`, and `feature` entries that name the feature.
   - DEVOPS reads `operating_model` and `product`.
   - A decision cites ``Reference: `Name` · <official source>``. The facts come from the vendor's, standard's or platform's official documentation (the docs reader), never from the reference product.
   - #225 owns the RDR «Market:» line and reads this key once it ships.
5. **The check is mechanical: `gate.py freeze` clause (e).** No new gate is added.
   - Freeze already runs at the push, in CI and at `BLUEPRINT --approve`.
   - It scans the changed decision artefacts (`docs/spec/*/**/*.md|.feature`, `docs/project_log/adr/*.md`) outside code fences.
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
- The check judges citations written in the ``Reference: `Name` `` form. A product named in prose is not a citation and is not judged.
- `for: feature` entries are matched to a feature by the agent's reading. The gate does not tie them to a feature id.
- A carried Q13 value is kept verbatim as one entry's name. Splitting it into products is the person's re-answer.

## Verification record
_(filled at delivery)_
