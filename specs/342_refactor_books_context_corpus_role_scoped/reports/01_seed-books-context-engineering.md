# Seed Report: Refactor the books extension's context corpus against the settled convention

- **Task**: N3 (global, `~/.config/nvim` specs) - Review the settled alpha convention and refactor the context files the books extension loads, so each books agent loads exactly the context its role needs, with the agent set itself reviewed and every file pinned to the convention version
- **Started**: 2026-10-05
- **Completed**: 2026-10-05 (seed only)
- **Effort**: ESTIMATE 2 to 3 working days. A measured read of 21 context files (3,900 lines) against 18 or 19 settled decision files, a loading-matrix ruling, the corpus rewrite, and the agent/skill frontmatter changes that implement the matrix.
- **Dependencies**: N1 (anchors and pin), N2 (guardrail rule and maintenance pointer), and the Verification repo's alpha review (revised 181) having landed with the version stamped: this task refactors against the *settled* record, not the one in flight.
- **Sources/Inputs** (under `~/.config/nvim/agent-system/extensions/books/` unless stated):
  - `index-entries.json` (538 lines, 21 entries): only `project/books/README.md` and `patterns/signal-tagging.md` carry `load_when.task_types: ["books"]`; 19 entries are on-demand with empty `task_types`. Nothing is keyed by role (research vs implement vs review vs certify).
  - `context/project/books/` corpus, measured line counts: `README.md` 88; `domain/` known-gap-register 275, layer-vocabulary-and-matrix 230, book-toml-v2 187, certificate-ledger-and-records 275, identity-and-versioning 237, status-and-trust-vocabularies 163, gate-tiers 194; `patterns/` authoring-workflow 213, warning-driven-convergence 174, gate-collision-ledger 198, signal-tagging 204, books-review-submode 219, books-revise-submode 288; `standards/` metadata-split 180, forgery-probe-discipline 171, reconciliation-contract 231, observation-record 249; `tools/` tooling-inventory 213, typst-template-contract 244, certify-guide 214. Total about 4,450 lines.
  - `agents/`: four agents (research 188, research-hard 295, implementation 294, implementation-hard 285 lines); `skills/`: seven skills; `commands/`: `/book`, `/certify`, `/books`.
  - `manifest.json`: `routing_agents` research/plan/implement for `books` and `books:certify`; `routing_agents_hard`; `keyword_overrides` (14 keywords); observer block.
  - Corpus conventions it already states: "Every figure carries a date and a measured marker"; "where the two disagree, the record wins and this corpus is stale"; `known-gap-register.md` is "a dated projection, not an authority".
  - Overlap with the record: `domain/layer-vocabulary-and-matrix.md`, `book-toml-v2.md`, `certificate-ledger-and-records.md`, `identity-and-versioning.md`, `status-and-trust-vocabularies.md` restate Decisions 2, 3, 7, 8, 9, 11, 12 with line anchors into the old single file; after the split each decision is one navigable file, so the restatement's value must be re-measured.
  - Overlap with the repo: `tools/tooling-inventory.md` and `tools/certify-guide.md` restate `books/README.md` and the scripts' own headers; `standards/reconciliation-contract.md` restates Decision 17's clauses.
  - `~/Projects/Logos/Verification/specs/state.json`: all 14 books-topic Lean tasks are `task_type: lean4`, two `general`, one `typst`; none is `books`-typed, so today the corpus loads for none of them except via on-demand reads.
  - `.claude/docs/reference/standards/agent-frontmatter-standard.md`, `.claude/context/architecture/context-layers.md` ("Where to store new content" decision tree), `.claude/context/patterns/context-discovery.md` (three-layer discovery), `check-extension-docs.sh` Rules A/K/R/T/U (EXTENSION.md 60-line cap).
- **Artifacts**: this report
- **Standards**: source-store-deploy-boundary.md, no-task-references-in-deliverables.md, agent-frontmatter-standard.md, report-format.md

## Project Context

- **Upstream Dependencies**: the settled record (alpha dispositions, version 0.1.0), the retargeted anchors (N1), the guardrail rule (N2).
- **Downstream Dependents**: every books dispatch in the Verification backlog after alpha; `/books --revise`'s proposals, which cite the corpus; the convention version's next bump, which this corpus must track by its pin.
- **Alternative Paths**: leave the corpus as is and rely on on-demand reads (rejected by the owner's stated concern: the corpus was written before the split and before the alpha review, restates decisions that are now one file each, and is not role-scoped); delete the corpus and point agents at the record directly (to be measured, not assumed: some files carry measured failure modes the record does not, e.g. the gate-collision ledger and the forgery-probe discipline).
- **Potential Extensions**: the same loading-matrix method applied to the lean4 and typst extensions' corpora.

## Executive Summary

- The corpus is large (about 4,450 lines across 21 files), pre-dates the split and the alpha review, and is loaded almost entirely on demand with no role keying. Two files load eagerly for `books`-typed tasks, a type no real task carries.
- Five domain files restate decisions that are now single navigable files with stable anchors; whether a restatement still earns its tokens is a measurable question (what the file adds beyond the decision file: worked examples, measured failure modes, cross-decision synthesis) and must be answered per file.
- The jobs the extension serves are distinct and need different context: authoring a book (layers, metadata split, authoring workflow, warning-driven convergence); certifying and diagnosing a gate failure (gate tiers, collision ledger, certify guide, tooling inventory); documenting a book (typst template contract, reconciliation contract); maintaining the record (N2's rule and pointer, the evidence schemas); reviewing and revising the convention (observation record, signal tagging, the two sub-mode files). Today one flat corpus serves all five.
- The agent set (four agents: research and implementation, each with a hard variant) is role-split by lifecycle phase, not by job; whether a documenting agent or a record-maintenance agent earns its place, or whether the existing typst and planner agents already cover those jobs, is this task's second ruling.
- Every file carries the convention version it was reviewed against (one header field, the same value as the extension pin), so the next bump produces a mechanical list of files to re-review rather than a prose SHA.

## Context & Scope

In scope: (1) a per-file review table: for each of the 21 files, what it restates, what it adds, which job needs it, measured lines, and a disposition (keep as is / trim to the delta / merge / retire into the record / split by role); (2) the loading matrix: for each job and each agent or skill, the eager set and the on-demand set, expressed in `index-entries.json` `load_when` keys and in each agent's context references, with the eager set per dispatch bounded by a stated budget (lines or tokens) and measured before and after; (3) the agent-set ruling: which jobs need their own agent, which are served by existing agents with a role-specific context slice, with the frontmatter changes that implement it and the routing table updated; (4) the version header on every corpus file plus the pin, and the rule for what a bump obliges (re-review every file whose header is older than the pin); (5) `README.md`, `EXTENSION.md`, `index-entries.json`, `manifest.json` registration and the gate suite green. Out of scope: any change to the record; any change to the `/books` sub-mode semantics beyond their context references; repo-side files.

## Findings

### Measured starting point

| Job | Files an agent needs today | Lines |
|---|---|---|
| Author a book | layer-vocabulary-and-matrix, metadata-split, book-toml-v2, authoring-workflow, warning-driven-convergence, rules/books.md | about 1,050 |
| Certify / diagnose | gate-tiers, gate-collision-ledger, certify-guide, tooling-inventory, forgery-probe-discipline | about 990 |
| Document a book | typst-template-contract, reconciliation-contract, status-and-trust-vocabularies | about 640 |
| Maintain the record | N2's rule and pointer, identity-and-versioning, known-gap-register | about 580 |
| Review / revise | observation-record, signal-tagging, books-review-submode, books-revise-submode | about 960 |

Nothing in the extension today selects by job; a research dispatch that reads the corpus README is pointed at all of it.

### What the split changes

Before the split a corpus restatement of Decision 7 saved an agent from ingesting a 359 KB file. After it, `docs/book-convention/07-book-toml-v2-schema.md` is 109 lines with a stable path. The restatement's remaining value is whatever it adds (the computed-never-authored list is in both; the word lists are in both). Each domain file should be measured as "lines that are not in the decision file", and trimmed to that delta or retired.

### What the corpus has that the record does not

Measured failure modes and operating guidance: the `Books.+` glob failure, the `certificate/` directory discovery corruption, the six gate collisions, the forgery-probe rule, the warning-driven `book_requires` loop, the certifier's economical operation. These are the files that earn eager loading for their job and must survive.

### Version pinning method

One header line per file: `- **Reviewed against convention version**: 0.1.0`. The pin in the corpus README (N1) is the extension-wide value. A bump in the consuming repository makes the preflight comparison report the mismatch; this task adds the rule that the re-review walks every file whose header is below the pin, so "update all parts" is a list, not a search.

## Recommendations

1. Research phase produces the per-file review table and the loading matrix with before/after line budgets per dispatch kind, and the agent-set ruling with reasons; plan phase gets an owner look at the matrix before the rewrite, since role separation is a design choice.
2. Prefer trimming to the delta over retiring a file, unless the delta is empty; prefer a role-specific context slice over a new agent, unless the slice would exceed the budget for an existing agent's other jobs.
3. Implement the matrix in `index-entries.json` `load_when` (by `task_types`, and by agent where the index schema allows), then in each agent's context references, and measure the eager set per dispatch kind after the change.
4. Gate: `verify-deploy.sh`, `check-extension-docs.sh`, `check-task-references.sh`, and the books test suites; plus a stated measurement that no dispatch kind's eager context grew.
