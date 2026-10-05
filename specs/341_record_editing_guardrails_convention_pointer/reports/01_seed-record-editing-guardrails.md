# Seed Report: Record-editing guardrails and the convention-maintenance context pointer

- **Task**: N2 (global, `~/.config/nvim` specs) - Add the record-editing guardrail rule to the books extension and the convention-maintenance context pointer, so an agent that touches the convention record follows the escalation protocol, the marker-plus-evidence edit contract and the version bump by construction
- **Started**: 2026-10-05
- **Completed**: 2026-10-05 (seed only)
- **Effort**: ESTIMATE half to one working day. One new rule file, one new context file, one pointer line in the lean extension, index and EXTENSION.md registration.
- **Dependencies**: N1 (anchors and the pin the rule cites must exist). Reads V1's Decision 19 when it exists; otherwise states the bump obligation conditionally.
- **Sources/Inputs**:
  - `~/.config/nvim/agent-system/extensions/books/rules/books.md`: six non-negotiables, `paths: ["**/books/**", "**/Book.lean", "**/Book/*.lean"]`; none governs editing the record itself.
  - `~/Projects/Logos/Verification/docs/book-convention/17-documentation-reconciliation-and-book-health.md:54-85`: the escalation protocol (binding clause stops work; research, escalate, amend plus marker; both silent departure and silent compliance refused; `none yet` is a hypothesis promoted by the first exercising work; no new artifact).
  - `~/Projects/Logos/Verification/docs/book-convention-evidence/README.md:56-62` (cross-link scheme), `:84-93` (reduced marker template), `:95-102` (evidence file template), `:148-156` (Ruling 5 file-split mechanics: edit the one-line marker and append a dated entry to the evidence pair; `.decisions.json` is where a ruling lands).
  - `~/Projects/Logos/Verification/books/scripts/lint-validated-by.sh` (CHECK 1/2 blocking, 3/4 advisory), `check-citation-inventory.sh` (zero-citation-loss multiset), and 210's structural checks (cross-link integrity, anchor liveness, index/content agreement, orphaned decision).
  - `~/Projects/Logos/Verification/docs/book-evidence.md:282-333`: the harness computes and proposes, never decides; no register; triage vocabulary revise now / defer / reject recorded in `.decisions.json`.
  - 210's report, Recommendation 3: a context-pointer file naming where the diagnostics and the escalation protocol live, originally proposed under the `lean4` extension because the books extension was believed not to exist.
  - `extensions/lean/rules/lean4.md`, `plan-compliance.md`: neither mentions books; `extensions/lean/context/project/lean4/` has no book-convention awareness.
  - `rules/no-task-references-in-deliverables.md`, `rules/source-store-deploy-boundary.md`.
- **Artifacts**: this report
- **Standards**: source-store-deploy-boundary.md, no-task-references-in-deliverables.md, agent-frontmatter-standard.md, report-format.md

## Project Context

- **Upstream Dependencies**: the record's own protocol text (the rule restates obligations; it must not invent any).
- **Downstream Dependents**: every future `books`-topic dispatch that amends a decision (181, 180, 157, 176, 185, 188, 189 in the Verification backlog).
- **Alternative Paths**: a PostToolUse hook refusing writes under `docs/book-convention*` (rejected: the extension has no hooks by design; the repo-side lint and citation inventory already block at the gate; a rule that loads on path match is the proportionate layer).
- **Potential Extensions**: the same rule shape could later govern `docs/architecture-decisions.md` and `docs/fault-frame-design.md`.

## Executive Summary

- The books extension's only rule file governs book directories and modules; nothing governs the act of editing the convention record, which is where the escalation protocol, the marker-plus-evidence contract, the no-register rule, the no-task-numbers rule and (after V1) the version bump all apply.
- The record's protocol is explicit about outcomes but spread across Decision 17, the evidence README and `docs/book-evidence.md`; an agent dispatched to amend a decision must currently find and reconcile all three.
- One rule file loaded on `docs/book-convention*/**` paths, stating the seven obligations below with their source anchors, plus one context file naming the diagnostics and the review loop, closes the gap 210 deferred without adding a mechanism.

## Context & Scope

In scope: `rules/book-convention-record.md` with `paths: ["**/docs/book-convention.md", "**/docs/book-convention/**", "**/docs/book-convention-evidence/**"]`; `context/project/books/patterns/record-maintenance.md` (where the lint, the citation inventory, the structural checks, the snapshot probe, the observer, `/books --review` and `/books --revise` live; the order to run them; what each certifies); a one-line pointer from `extensions/lean/context/project/lean4/README.md` to it; registration in `index-entries.json` and `EXTENSION.md` within the Rule U line cap. Out of scope: any change to the protocol's substance; hooks; repo-side files.

## Findings

### The seven obligations the rule states (each with its anchor)

1. A decision whose marker names an instance is binding; work that cannot satisfy it stops, researches, escalates, and lands the ruling as an amendment plus an updated marker (Decision 17, escalation protocol).
2. Neither silent departure nor silent compliance (same).
3. A `none yet` clause is a hypothesis: amend in place and promote the marker (same).
4. The marker edit contract under the split: edit the decision file's one-line reduced marker, keep its `<value>` vocabulary, keep the evidence pointer, and append a dated `## <ISO date> — <Newly exercised | Extended | Amended> by <instance>` entry to the paired evidence file (evidence README, Ruling 5 mechanics).
5. No new artifact and no register: the ruling lands in the task's `.decisions.json`; proposals are transient; the marker is the status (Decision 17 "No new artifact"; `docs/book-evidence.md` no-register rule).
6. Citations are durable anchors (file path, decision number, script name); never a task number in the record; every backtick citation must survive (`check-citation-inventory.sh`).
7. The version line bumps per Decision 19's table when it exists; the extension's pin is then stale and says so (conditional until V1 lands).

### What the context file must say and not say

Say: the five mechanical checks and their blocking/advisory split; that `/books --review` is read-only and `/books --revise` never edits the record; that the repository owns probes; where observation, run and snapshot records live. Not say: anything about convention substance (that lives in the record and the domain corpus already).

### Why not the lean4 extension

210's deferred pointer assumed no books extension. The books extension depends on `lean` and is loaded only where books exist; the pointer belongs there, with a single line in the lean4 README so a `lean4`-typed books task (all 14 of them in Verification are `lean4`-typed) still finds it.

## Recommendations

1. Keep the rule under 70 lines, one obligation per numbered item with its anchor, mirroring `rules/books.md`'s "measured failure mode" style where a failure has been measured (210's report records the 0% in-place reduction and the 72 KB marker mass as the failure that motivated the split).
2. Make obligation 7 conditional in wording until Decision 19 exists, then tighten in the same change that bumps the pin.
3. Verify with `check-extension-docs.sh` (Rule U) and `check-task-references.sh` (zero task numbers in the rule).
