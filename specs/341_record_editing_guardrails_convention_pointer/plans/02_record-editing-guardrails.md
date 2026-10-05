# Implementation Plan: Record-editing guardrails and the convention-maintenance context pointer

- **Task**: 341 - Record-editing guardrails and the convention-maintenance context pointer
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: books-extension split-retarget task (anchors + convention-version pin) — SATISFIED (Decision 19 is `active`; `manifest.json` carries `convention_version: "0.1.0-pre"`, `measured_at_commit: "d255518"`)
- **Research Inputs**: `specs/341_record_editing_guardrails_convention_pointer/reports/02_record-editing-guardrails.md`, `specs/341_record_editing_guardrails_convention_pointer/reports/01_seed-record-editing-guardrails.md`
- **Artifacts**: plans/02_record-editing-guardrails.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Nothing in the books extension governs the act of **editing the convention record** — the
escalation protocol, the marker-plus-evidence edit contract, the no-register rule, the
durable-anchor rule and the version bump all live in three unconnected sources that no mechanism
loads for a dispatch. This plan closes that gap with exactly one rule file
(`rules/book-convention-record.md`, `paths:`-matched on `docs/book-convention*`) and one context
file (`context/project/books/patterns/record-maintenance.md`, diagnostics map only), plus a
single pointer line in the lean extension's `lean4/README.md` so a `lean4`-typed books task sees
it. **No mechanism is added**: no hook, no script, no repo-side file. Done means both files
exist, are registered, pass `check-extension-docs.sh` and `check-task-references.sh`, and the
rule is under 70 lines with every obligation carrying its source anchor.

All edits land in the **source store** (`agent-system/extensions/books/...`,
`agent-system/extensions/lean/...`). Nothing under `.claude/**` is hand-authored — see
`rules/source-store-deploy-boundary.md`.

### Research Integration

Report `02_record-editing-guardrails.md` is integrated in full. Its three load-bearing findings
are carried into the phases below:

1. **Obligation 7 is written unconditionally, not conditionally.** The dispatch's fallback
   wording ("WORD THIS CONDITIONALLY until that decision exists") is superseded: Decision 19
   (`docs/book-convention/19-convention-versioning-and-lockstep.md`) exists, is `**Status**:
   active`, `**Last approved**: 2026-10-05`, and carries the bump-rule table (clause 2), the
   three-declarations rule (clause 3) and the CHANGELOG-bullet rule (clause 5). The extension's
   pin already exists. The dispatch itself names "then tighten it in the same change" as the
   intended outcome once the dependency lands; it has landed.
2. **`manifest.json` is a third registration file the dispatch's Registration section omits.**
   `check-extension-docs.sh`'s **Rule H** (`check_undeclared_rules`) *fails* on a "rule file on
   disk NOT in provides.rules". A new rule file without a `provides.rules` entry is a hard gate
   failure, not a cosmetic omission.
3. **`EXTENSION.md` is at exactly 60 lines**, the Rule U cap, with zero slack. Any added pointer
   must be offset by an equal-or-greater trim in the same file.

**This plan additionally corrects two stale facts in the research report**, re-measured against
the live consuming repository (`~/Projects/Logos/Verification`) during planning:

4. **`lint-validated-by.sh` has TWELVE checks, not eight.** Its own header states: "CHECK 1,
   CHECK 2, and -- once docs/book-convention/ exists -- CHECK 5 through CHECK 11 are BLOCKING
   (exit 1 on any finding) ... CHECK 3, CHECK 4 and CHECK 12 are ADVISORY (printed, never change
   the exit code)." CHECK 9 = decision status; CHECK 10 = clause-list resolution; CHECK 11 =
   record currency; CHECK 12 = currency signals (advisory). The dispatch's "CHECK 5 through 8"
   phrasing and the report's restatement of it are both one measurement behind. The context file
   must state the live split (blocking 1, 2, 5–11; advisory 3, 4, 12), not the stale one.
5. **Two record-maintenance diagnostics exist that neither the dispatch nor the report names**,
   and both are the mechanical backing for obligations this rule restates:
   - `books/scripts/check-evidence-append-only.sh` — the append-only guard over
     `docs/book-convention-evidence/NN-*.md` (README.md excluded). Every finding BLOCKING; a
     deleted line is a finding even when a similar line is re-added, because append-only is a
     property of each commit, not of the end state. This is obligation 4's enforcement.
   - `books/scripts/check-convention-version.sh` — the three-surface version comparison.
     CHECK1 (record line), CHECK2 (manual binding), CHECK3 (record-vs-manual) and CHECK5
     (amendment ↔ CHANGELOG bullet) are BLOCKING; **CHECK4, the extension-pin leg, is ADVISORY**
     because the extension deploys from another repository on its own schedule. This is
     obligation 7's enforcement, and its advisory severity is exactly why obligation 7 says the
     pin "is then stale and says so" rather than "blocks".

### Prior Plan Reference

No prior plan. `plans/` is empty; this is round 2's first plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no ROADMAP.md was consulted.

## Goals & Non-Goals

**Goals**:

- `agent-system/extensions/books/rules/book-convention-record.md`: new, under 70 lines, seven
  numbered obligations, each carrying its source anchor, restating only what the record already
  binds.
- `agent-system/extensions/books/context/project/books/patterns/record-maintenance.md`: new;
  names where the diagnostics live, the order to run them, and what each certifies — and says
  nothing about convention substance.
- Exactly one pointer line in `agent-system/extensions/lean/context/project/lean4/README.md`.
- Both new files registered: `manifest.json` (`provides.rules`), `index-entries.json` (the
  context entry), `EXTENSION.md` (within the 60-line Rule U cap), and the corpus `README.md`
  navigation table.
- `check-extension-docs.sh` and `check-task-references.sh` green.

**Non-Goals**:

- Any change to the convention protocol's **substance**. The rule restates; it invents nothing.
- Any hook. The books extension's `manifest.json` keeps `"hooks": []`. A PostToolUse hook
  refusing writes under `docs/book-convention*` was considered and rejected.
- Any repo-side (`~/Projects/Logos/Verification`) file. The consuming repository owns its probes,
  lints and record; this task reads them and never writes them.
- Any hand-authored file under `.claude/**`.
- Extending this rule shape to `docs/architecture-decisions.md` or `docs/fault-frame-design.md`.
- The books context-corpus role-scoped-loading rework (a separate `[HOLD]` task).
- Bumping the `convention_version` pin or editing the record. Obligation 7 *describes* the bump;
  this task does not perform one.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `EXTENSION.md` passes 60 lines → Rule U fails | H | H | Budget every addition against an equal trim in the same file; candidate trim named in Phase 3's Scope Hypothesis; verify with `check-extension-docs.sh` before closing the phase |
| New rule file absent from `manifest.json`'s `provides.rules` → Rule H fails | H | M | Phase 3 edits `provides.rules` explicitly; Phase 5 re-runs the gate |
| `index-entries.json` `line_count` wrong after content edits → Rule R fails | M | H | Run `generate-context-line-counts.sh --write` in Phase 5 *after* all content is final, never by hand-typing counts |
| Adding a line to `lean4/README.md` desyncs the **lean** extension's own `line_count` (29 → 30) → Rule R fails on a second extension | M | H | Phase 4 names it; Phase 5's `--write` sweep covers both extensions |
| Rule exceeds 70 lines | M | M | `rules/books.md` fits six obligations plus a Scope Boundary in 69 lines; trim elaboration, never an obligation; Phase 1 verifies with `wc -l` |
| Context file drifts into convention substance, creating a second source | M | M | Phase 2's verification includes an explicit negative check: no clause content, no marker values, no escalation-protocol mechanics |
| A task number leaks into a deliverable file | M | L | `check-task-references.sh` in Phases 1, 2 and 5; cite durable anchors (file path, decision number, script name) only |
| Stale diagnostics figures copied from the report rather than re-measured | M | M | Findings 4 and 5 above carry the re-measured values; Phase 2 re-reads the live script headers before writing |
| The deployed `.claude/` tree is stale for `lean`, so the pointer does not reach dispatches until a redeploy | L | H | Note it in Phase 4's verification; redeploy is an operator action (`deploy-headless.sh`), explicitly NOT a hand-patch of `.claude/**` |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1, 2 |
| 3 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: The record-editing rule file [COMPLETED]

**Goal**: `agent-system/extensions/books/rules/book-convention-record.md` exists, under 70
lines, with seven numbered obligations each carrying its source anchor.

**Tasks**:

- [x] Create the file with `---`-delimited frontmatter carrying exactly *(completed)*
      `paths: ["**/docs/book-convention.md", "**/docs/book-convention/**", "**/docs/book-convention-evidence/**"]`
      (matching `rules/books.md`'s own frontmatter convention).
- [x] Write a title and a two-or-three-line preamble stating that this rule governs **editing the *(completed)*
      convention record**, mirroring `rules/books.md`'s "each item states its measured failure
      mode" framing — and applying that framing only where a failure has actually been measured
      (the record's own split was motivated by a measured 0% in-place reduction against a 72 KB
      marker mass; do not manufacture a measured failure for an item that has none).
- [x] Obligation 1 — a decision whose `Validated by` marker **names an instance** is binding; *(completed)*
      work that cannot satisfy it **stops**, researches, **escalates to the repository owner**
      for a ruling, and lands that ruling as an amendment to the clause's text **plus an updated
      marker**. Anchor: `docs/book-convention/17-documentation-reconciliation-and-book-health.md`,
      "**The escalation protocol**".
- [x] Obligation 2 — **neither silent departure nor silent compliance**; both are refused. *(completed)*
      Anchor: same section.
- [x] Obligation 3 — a `none yet` clause is a **hypothesis, not a constraint**: it needs no *(completed)*
      escalation and is amended **in place** by the work that first exercises it, which then
      **promotes its marker**. Anchor: same section.
- [x] Obligation 4 — the **split-record edit contract**: "an updated marker" means editing the *(completed)*
      decision file's **one-line reduced marker** — keeping its value vocabulary
      (`<instance>` / `partially, <instance> — <clauses>` / `none yet`) and its evidence pointer
      — **and** appending a dated
      `## <ISO date> — <Newly exercised | Extended | Amended | Re-measured> by <instance>` entry
      to the **paired evidence file** under `docs/book-convention-evidence/`. Anchors:
      `docs/book-convention-evidence/README.md`, "Ruling 5's file-split mechanics paragraph",
      with the marker and evidence-file templates in that same README's "Reduced marker template
      (Ruling 3)" and "Evidence file template" sections; append-only is mechanically enforced by
      `books/scripts/check-evidence-append-only.sh` (blocking).
- [x] Obligation 5 — **no new artifact and no register**: the ruling lands in the task's existing *(completed)*
      `.decisions.json`, proposals are **transient**, and **the marker is the status**. Anchors:
      Decision 17's "**No new artifact**" paragraph ("the marker is the status ... an amended
      clause is the resolution"); the **no-register rule** ("the harness computes and proposes;
      it never decides"; "Nothing tracks a proposal between its emission and its triage") in
      `docs/book-evidence.md`'s "The review protocol" section, with the triage vocabulary
      **revise now / defer / reject**.
- [x] Obligation 6 — **citations are durable anchors** (a file path, a `file:line`, a decision *(completed)*
      number, a script name) and **never a task number in the record**; and **every backtick
      citation must survive an edit**. Anchors: `rules/no-task-references-in-deliverables.md`;
      `books/scripts/check-citation-inventory.sh`'s zero-citation-loss **multiset** guarantee (a
      span moving between files passes; a span disappearing from the set entirely fails).
- [x] Obligation 7 — **the convention version line bumps**, classified against Decision 19's *(completed)*
      bump table, and the extension's pin **is then stale and says so**. Write this
      **unconditionally** (see Research Integration finding 1): cite Decision 19's clause 2 table,
      clause 3's three declarations, and clause 5's required `CHANGELOG.md` `## [Unreleased]`
      bullet; name the pin's locations (`manifest.json`'s `convention_version` /
      `measured_at_commit`, and the corpus `README.md`'s "Convention version pin and staleness
      comparison" section); and state that the pin leg is **advisory, never blocking**
      (`check-convention-version.sh` CHECK4), because the extension deploys on its own schedule.
- [x] Close with a short **Scope Boundary** section (mirroring `rules/books.md`'s own closing *(completed)*
      section): this rule governs *editing* the record, not the record's substance; point to
      `context/project/books/patterns/record-maintenance.md` for the diagnostics and to
      `rules/books.md` for book-directory and book-module non-negotiables.
- [x] Verify the file invents nothing: every obligation sentence traces to text in a cited *(completed)*
      anchor. Where the live record's wording differs from this plan's paraphrase, **the record
      wins** — re-read the anchor and match it.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: seven obligations, a preamble and a Scope Boundary section fit under 70
lines. Basis: `rules/books.md` fits six obligations plus a Scope Boundary in 69 lines (measured,
source store, 2026-10-05). Confirm at implementation time with
`wc -l agent-system/extensions/books/rules/book-convention-record.md`; if over, trim elaboration
and prose, **never an obligation and never an anchor**.

**Files to modify**:

- `agent-system/extensions/books/rules/book-convention-record.md` - new; frontmatter `paths:`,
  preamble, seven anchored obligations, Scope Boundary

**Verification**:

- `wc -l` on the new file reports **< 70**.
- The frontmatter `paths:` array matches the three globs above, character for character.
- Seven numbered items are present; each ends in or contains a parenthetical/backticked source
  anchor naming a file, a decision number, a section heading or a script name.
- Obligation 7 is unconditional (no "once Decision 19 exists" / "when that decision lands"
  hedging).
- `bash .claude/scripts/check-task-references.sh` reports zero findings for this file.
- Each cited anchor resolves: `grep` the quoted section heading in the named file under
  `~/Projects/Logos/Verification` and confirm a hit.

---

### Phase 2: The record-maintenance diagnostics map [COMPLETED]

**Goal**: `agent-system/extensions/books/context/project/books/patterns/record-maintenance.md`
exists and names where the diagnostics live, the order to run them, and what each certifies —
with zero statements about convention substance.

**Tasks**:

- [x] Re-read, before writing, the live header comment blocks of *(completed)*
      `~/Projects/Logos/Verification/books/scripts/lint-validated-by.sh`,
      `check-citation-inventory.sh`, `check-evidence-append-only.sh` and
      `check-convention-version.sh`, and take the blocking/advisory split from **them**, not from
      this plan or from the research report (see Research Integration findings 4 and 5 for why).
- [x] `lint-validated-by.sh` — twelve checks. **Blocking**: CHECK 1 (marker presence and *(completed)*
      well-formedness), CHECK 2 (instance liveness), and — once `docs/book-convention/` exists —
      CHECK 5 (cross-link integrity), CHECK 6 (anchor liveness), CHECK 7 (index/content
      agreement), CHECK 8 (orphaned-decision detection), CHECK 9 (decision status), CHECK 10
      (clause-list resolution), CHECK 11 (record currency). **Advisory** (printed, never changes
      the exit code): CHECK 3 (marker promotion owed), CHECK 4 (unescalated departure), CHECK 12
      (currency signals). State *why* the split is where it is, in the script's own terms: the
      blocking checks are fully mechanical exact-text checks against a confirmed-green baseline,
      so a false positive would be a bug in the script; the advisory ones are heuristics over
      free text and dates, so "the lint detects, the repository owner rules".
- [x] `check-citation-inventory.sh` — the zero-citation-loss **multiset** guard: a span moving *(completed)*
      from one file to another is a pass; a span disappearing from the set entirely is a FAIL.
- [x] `check-evidence-append-only.sh` — the append-only guard over *(completed)*
      `docs/book-convention-evidence/NN-*.md` (README.md excluded, being the directory's
      migration-contract document). Every finding blocking; append-only is a property of **each
      commit**, not of the end state, so a rewritten entry is caught exactly like a dropped one;
      no reachable `.git` yields one INFO line and exit 0, reported rather than treated as green.
- [x] `check-convention-version.sh` — the three-surface comparison. Blocking: CHECK1 (record *(completed)*
      line), CHECK2 (generated manual binding), CHECK3 (record-vs-manual mismatch), CHECK5
      (amendment ↔ `CHANGELOG.md` bullet). **Advisory**: CHECK4, the extension-pin leg, with the
      reason (the extension deploys from another repository on its own schedule, so its lag is a
      deploy event there, not a defect in the consuming repository); an absent corpus is one INFO
      line.
- [x] **The order to run them**, and what each certifies — cheapest and most structural first, *(completed)*
      so a structural break is found before a currency heuristic is read:
      `lint-validated-by.sh` → `check-citation-inventory.sh` → `check-evidence-append-only.sh` →
      `check-convention-version.sh`. State plainly that a green run of all four certifies marker
      and structural integrity, citation survival, evidence append-only history and version
      lockstep — and certifies **nothing** about whether a ruling was correct.
- [x] **The snapshot probe and the observer.** The extension ships **no** snapshot probe *(completed)*
      ("PROBE OWNERSHIP BOUNDARY (D3)"): `scripts/books-observe.sh` tests for an executable
      `books/tool/book-snapshot.sh` **in the consuming repository** and invokes it
      (`--diff <before> <after> --json`). The observer is `books-observe.sh` itself —
      topic/`task_type`-keyed, advisory, non-blocking.
- [x] **`/books` sub-mode boundaries**: `/books --review` is **strictly read-only** (it never *(completed)*
      proposes, never writes, never creates a task, never edits the convention, never advances a
      watermark — `patterns/books-review-submode.md`); `/books --revise` **never edits the
      record** (it proposes tasks; the tasks do the work — `patterns/books-revise-submode.md`).
- [x] **"The repository owns probes"**: the extension owns the **join**, not the probe — the *(completed)*
      observer joins `issues.jsonl`/`metrics.jsonl` with books-specific facts and invokes a probe
      that lives in the consuming repository.
- [x] **Where the records live**: SNAPSHOT — `specs/books-evidence/snapshot-{ISO_DATE}.json` (one *(completed)*
      file per snapshot, append-only directory); RUN — `specs/books-evidence/runs.jsonl` (one
      shared append-only log); OBSERVATION — `specs/{NNN}_{SLUG}/book.observation.json` (one per
      task, beside `.decisions.json`), plus the append-only digest log
      `specs/books-evidence/observations.jsonl` (one line per run).
- [x] Follow the corpus's own stated conventions: every figure carries a date and a measured *(completed)*
      marker; paths are always full; cross-references are plain backticked paths, never eager
      `@`-imports; citations are durable anchors.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: `lint-validated-by.sh` carries **twelve** checks with the split blocking 1,
2, 5-11 / advisory 3, 4, 12, and the record-maintenance diagnostic set is **four** scripts
(measured from the live script headers in `~/Projects/Logos/Verification/books/scripts/`,
2026-10-05). Both figures supersede the dispatch's and the research report's "CHECK 5 through 8"
and three-tool framing. Confirm at implementation time by re-reading the four script headers and
`grep -c '^#   CHECK [0-9]' lint-validated-by.sh` plus `ls books/scripts/`; if the live figures
differ again, the live script wins and this plan's numbers are stale.

**Files to modify**:

- `agent-system/extensions/books/context/project/books/patterns/record-maintenance.md` - new;
  the four diagnostics with their blocking/advisory split, the run order, the probe/observer
  ownership boundary, the sub-mode read-only facts, and the three record locations

**Verification**:

- All four scripts are named by full path, each with its blocking/advisory split stated.
- The `lint-validated-by.sh` split reads **blocking 1, 2, 5–11; advisory 3, 4, 12** — a file
  still saying "CHECK 5 through 8" has copied the stale figure and fails this check.
- `/books --review` read-only and `/books --revise` never-edits are both stated with their
  source file cited.
- All three record locations are present with their exact paths.
- **Negative check** (the MUST NOT): `grep` the file for convention-substance tokens —
  `book_layer`, `book.toml`, `@[book_export]`, `book.cert.json`, `binding`, `partially`,
  `none yet`, `escalat` — and confirm each hit is either absent or a bare mechanical reference
  (e.g. naming what CHECK 1 parses), never a restatement of what the clause *means* or of the
  escalation protocol's steps. Those live in the rule file and the record.
- `bash .claude/scripts/check-task-references.sh` reports zero findings for this file.

---

### Phase 3: Registration in the books extension [NOT STARTED]

**Goal**: both new files are declared by the extension and discoverable through its own
navigation, with `EXTENSION.md` still at or under 60 lines.

**Tasks**:

- [ ] `manifest.json`: add `"book-convention-record.md"` to `provides.rules` (now
      `["books.md", "book-convention-record.md"]`). Required — Rule H *fails* on a rule file on
      disk that is absent from `provides.rules`. `provides.context` already covers the new
      context file via its directory-level `"project/books"` reference; no change there.
- [ ] `index-entries.json`: add one entry for `project/books/patterns/record-maintenance.md`,
      matching the on-demand majority pattern used by nineteen of the twenty-one existing
      entries: `"on_demand": true`, `"load_when": {"agents": [], "task_types": []}`,
      `"domain": "project"`, `"subdomain": "books"`, a `topics` array, a one-sentence `summary`,
      and a `keywords` array. Set `line_count` to the real `wc -l` value (Phase 5's
      `generate-context-line-counts.sh --write` is the authority; do not hand-maintain it).
      Keep within `index.schema.json`'s closed field set (Rule T): required
      `path`/`domain`/`summary`/`line_count`; optional `subdomain`/`topics`/`keywords`/
      `load_when`/`on_demand`; **no** `description`, `tags` or `tier` keys.
- [ ] `EXTENSION.md`: add a pointer to the new rule and a pointer to the new context file, at
      **zero net line growth**. Fold them into existing sentences rather than adding a new `###`
      section — the `### Book Directory Layout (flattened)` section's closing sentence already
      says "See `rules/books.md` for the full non-negotiable set" and is the natural host for the
      second rule; the `### Context Pointers` bullet is the natural host for the context file.
      Offset any wrap-induced growth with a trim in the same file; `### Book Directory Layout
      (flattened)` is the best trim candidate because its substance is already `rules/books.md`
      item 3 and the section is a pointer, not content.
- [ ] `EXTENSION.md`: update the `### Context Pointers` bullet's "(twenty docs)" count to match
      the corpus's new document count.
- [ ] `context/project/books/README.md`: add one row to the `## Navigation` table for
      `patterns/record-maintenance.md` (Subject: where the record-editing diagnostics live, their
      blocking/advisory split, and the probe-ownership boundary; Read this when: amending the
      convention record, or deciding which check certifies what), and reconcile the two
      self-describing counts — the corpus's own "twenty-row table" phrasings in the
      `index-entries.json` `summary` for `project/books/README.md`. *Rationale for adding the row
      now rather than deferring*: this README states "This README is the only entry point," so a
      registered-but-unnavigable document contradicts the corpus's own stated invariant; the row
      is prose, not a mechanism, so it stays inside this task's scope boundary; and the corpus
      rework task that would otherwise absorb it is on `[HOLD]`.
- [ ] Do **not** touch `convention_version` or `measured_at_commit`. Obligation 7 describes the
      bump; this task performs none.

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Scope Hypothesis**: `EXTENSION.md` is at **exactly 60 lines** (measured, source store,
2026-10-05) against Rule U's 60-line cap — zero slack. The hypothesis is that the two pointers
plus the count edit can be absorbed by folding into existing sentences, with the
`### Book Directory Layout (flattened)` section as the fallback trim. Confirm at implementation
time with `wc -l agent-system/extensions/books/EXTENSION.md` **and** a `check-extension-docs.sh`
run; if still over, trim further in the same file rather than relaxing the addition.

**Files to modify**:

- `agent-system/extensions/books/manifest.json` - add `book-convention-record.md` to
  `provides.rules`
- `agent-system/extensions/books/index-entries.json` - add the `record-maintenance.md` entry;
  update the `project/books/README.md` entry's `summary` row count
- `agent-system/extensions/books/EXTENSION.md` - two folded pointers and the corpus doc count, at
  zero net line growth
- `agent-system/extensions/books/context/project/books/README.md` - one navigation-table row

**Verification**:

- `wc -l agent-system/extensions/books/EXTENSION.md` reports **≤ 60**.
- `jq '.provides.rules' manifest.json` includes `book-convention-record.md`.
- `jq '.entries[] | select(.path == "project/books/patterns/record-maintenance.md")'
  index-entries.json` returns exactly one entry, and `jq -e` confirms `path`, `domain`, `summary`
  and `line_count` are all present.
- `python3 -c "import json; json.load(open(...))"` (or `jq .`) parses both JSON files — no
  trailing-comma or quoting damage.
- The `## Navigation` table row count and every self-describing count in `EXTENSION.md`,
  `context/project/books/README.md` and the `index-entries.json` summaries agree with each other.
- `bash .claude/scripts/check-extension-docs.sh` reports no Rule H, Rule R, Rule T or Rule U
  finding for the `books` extension. (`books` is not a loaded extension in this repository, so
  the deployed-drift rules — F, I, L, S — are skipped by design; the source-side rules above are
  the live ones.)

---

### Phase 4: The lean4 README pointer line [NOT STARTED]

**Goal**: exactly one line in the lean extension's `lean4/README.md` points at
`record-maintenance.md`, and the lean extension's own index `line_count` stays accurate.

**Tasks**:

- [ ] Add **one** bullet under `## Key Files` in
      `agent-system/extensions/lean/context/project/lean4/README.md`, in the same style as the
      existing rows (`- \`path\` - description`), pointing at the books extension's
      `context/project/books/patterns/record-maintenance.md` and naming when it applies (a
      dispatch amending `docs/book-convention*`). No new section heading — the file's `## Key
      Files` list is flat.
- [ ] Keep it to one physical line, under the file's ~100-character working width if possible; if
      the line must wrap, it still counts as one bullet but adds a second physical line, which
      the `line_count` update below must reflect.
- [ ] Update `agent-system/extensions/lean/index-entries.json`'s `project/lean4/README.md` entry
      `line_count` from `29` to the new real value (Phase 5's `--write` sweep is the authority).
- [ ] Record, in the phase's own notes rather than in any deliverable file, that the pointer only
      reaches live `lean4` dispatches after a redeploy — the deployed `.claude/` tree is already
      flagged stale for `lean`. Remedy is `bash .claude/scripts/deploy-headless.sh`, an operator
      action. Do **not** hand-patch `.claude/**` as a substitute.

**Timing**: 0.25 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: `lean4/README.md` is 29 lines and its `index-entries.json` entry declares
`line_count: 29` (both measured, source store, 2026-10-05); one added bullet makes both 30.
Confirm with `wc -l` and a `check-extension-docs.sh` Rule R check. The entry is **eagerly**
loaded (`load_when.task_types: ["lean4"]`), which is precisely the mechanism that makes the
pointer reach a `lean4`-typed books task — confirm that `load_when` block is left unchanged.

**Files to modify**:

- `agent-system/extensions/lean/context/project/lean4/README.md` - one bullet under
  `## Key Files` pointing at `record-maintenance.md`
- `agent-system/extensions/lean/index-entries.json` - `project/lean4/README.md` entry
  `line_count` 29 → new value

**Verification**:

- `grep -c 'record-maintenance' agent-system/extensions/lean/context/project/lean4/README.md`
  returns exactly `1`.
- `git diff --stat` on `lean4/README.md` shows a single-line insertion and no deletion.
- The declared `line_count` equals `wc -l` of the file.
- `bash .claude/scripts/check-task-references.sh` reports zero findings for the file.

---

### Phase 5: Full gate sweep and count reconciliation [NOT STARTED]

**Goal**: every declared count is machine-derived rather than hand-typed, and the full gate set
is green.

**Tasks**:

- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` so
      every `index-entries.json` `line_count` touched by Phases 2–4 is derived, not typed. Review
      its diff: it should touch only the `books` `record-maintenance.md` and `README.md` entries
      and the `lean` `project/lean4/README.md` entry.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and resolve every finding attributable
      to this task (Rules H, R, T, U in particular). Pre-existing findings in unrelated
      extensions are out of scope — report them, do not fix them here.
- [ ] Run `bash .claude/scripts/check-task-references.sh` and confirm **zero** task-number
      findings across both new files and all four modified files.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` as the task-closing full gate.
- [ ] Re-confirm the acceptance criteria one by one against the files on disk: rule under 70
      lines; every obligation carries its anchor; obligation 7 is unconditional (see Research
      Integration finding 1 — this plan deliberately satisfies the dispatch's *tightened* form,
      not its conditional fallback); the context file names the diagnostics and their
      blocking/advisory split without restating convention substance; `lean4/README.md` carries
      exactly one pointer line; both files are registered.
- [ ] Record any gate collision, deviation or unusually smooth result via
      `bash .claude/scripts/issue-record.sh` as it happens, per the dispatch's Issue Log section.

**Timing**: 0.25 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: this task's total footprint is **eight paths** - two new files and six
modified files, enumerated under `## Artifacts & Outputs`. Confirm at implementation time with
`git status --short`; any ninth path is either an unplanned deviation to record via
`issue-record.sh` or a stray concurrent-session edit that must NOT be staged with this task's
commits.

**Files to modify**:

- `agent-system/extensions/books/index-entries.json` - machine-derived `line_count` corrections
- `agent-system/extensions/lean/index-entries.json` - machine-derived `line_count` correction

**Verification**:

- `bash .claude/scripts/check-extension-docs.sh` exits 0, or every remaining finding is
  demonstrably pre-existing and unrelated to this task's eight files.
- `bash .claude/scripts/check-task-references.sh` reports zero findings.
- `bash .claude/scripts/verify-deploy.sh` exits 0 (the `full` tier's complete gate set).
- `git status --short` shows exactly the eight expected paths (two new, six modified) and nothing
  under `.claude/**`.

## Testing & Validation

- [ ] `wc -l agent-system/extensions/books/rules/book-convention-record.md` < 70.
- [ ] `wc -l agent-system/extensions/books/EXTENSION.md` ≤ 60.
- [ ] Seven numbered obligations present, each with a resolving source anchor.
- [ ] Obligation 7 contains no conditional hedging about Decision 19's existence.
- [ ] `record-maintenance.md` states the live `lint-validated-by.sh` split (blocking 1, 2, 5–11;
      advisory 3, 4, 12) and names `check-citation-inventory.sh`,
      `check-evidence-append-only.sh` and `check-convention-version.sh`.
- [ ] `record-maintenance.md` restates no convention substance (negative grep, Phase 2).
- [ ] `grep -c record-maintenance .../lean4/README.md` == 1.
- [ ] `jq '.provides.rules'` on the books manifest includes the new rule file.
- [ ] Both `index-entries.json` files parse and declare accurate `line_count`s.
- [ ] `bash .claude/scripts/check-extension-docs.sh` green for `books` and `lean`.
- [ ] `bash .claude/scripts/check-task-references.sh` green.
- [ ] `bash .claude/scripts/verify-deploy.sh` green.
- [ ] No file under `.claude/**` was written.

## Artifacts & Outputs

New:

- `agent-system/extensions/books/rules/book-convention-record.md`
- `agent-system/extensions/books/context/project/books/patterns/record-maintenance.md`

Modified:

- `agent-system/extensions/books/manifest.json`
- `agent-system/extensions/books/index-entries.json`
- `agent-system/extensions/books/EXTENSION.md`
- `agent-system/extensions/books/context/project/books/README.md`
- `agent-system/extensions/lean/context/project/lean4/README.md`
- `agent-system/extensions/lean/index-entries.json`

Plus `specs/341_record_editing_guardrails_convention_pointer/summaries/02_*-summary.md` at
implementation close.

## Rollback/Contingency

Every change is additive text in a source-store tree, with no mechanism, no hook and no
repo-side write, so rollback is a plain revert of the eight paths — no state, cache or deployed
artifact is mutated by this task.

- **Per-phase**: each phase's files are disjoint from the other phases' except for the two
  `index-entries.json` files, which Phase 5 regenerates mechanically. A phase that goes wrong is
  undone by reverting its own named paths; the `check-extension-docs.sh` and
  `check-task-references.sh` gates are the detectors.
- **Whole task**: `git revert` the task's commits, or `git checkout HEAD -- <the eight paths>` on a
  tree with nothing else uncommitted. Deleting the two new files plus removing the
  `provides.rules` entry and the `index-entries.json` entry restores the pre-task state exactly;
  no migration or regeneration step is owed on the way back.
- **If a rollback must discard uncommitted work**, take a durable checkpoint first with
  `bash .claude/scripts/git-snapshot.sh --no-revert` rather than the default reverting form; for
  a genuine whole-tree rollback see `context/contracts/recovery.md`'s rollback rung for the
  exact invocation shape, including its out-of-scope override flag.
- **Partial-completion posture**: Phases 1 and 2 are independently valuable and independently
  revertible. If Phase 3 cannot fit `EXTENSION.md` within Rule U, the correct outcome is a
  `[BLOCKED]` phase with the measured line counts recorded — not an unregistered rule file, which
  fails Rule H and is worse than no rule file at all.
