# Implementation Plan: Task #306

- **Task**: 306 - Make ROADMAP.md a generated artifact: extend the format into a generation contract and add regenerate and prune modes
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None (wave 1 in `specs/TODO.md`'s Dependency Waves table; `dependencies: []` in `specs/state.json`)
- **Research Inputs**: `specs/306_roadmap_generated_artifact/reports/01_roadmap-generated-artifact.md`
- **Artifacts**: plans/01_roadmap-generation-contract.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`specs/ROADMAP.md` is hand-derived today, and its own `## Goal` says so ("it is hand-derived
until **306** makes it generated"). This plan makes the mechanically-derivable half of the file
generated and names the authored half explicitly: it rewrites
`context/formats/roadmap-format.md` from a stale 65-line parse spec into a generation contract
grounded in the file's measured current shape, builds a new
`scripts/roadmap-integration.sh` with `--print` / `--regenerate` / `--prune` modes that consume
`generate-task-order.sh --print` plus a small jq pass over `state.json`, and rewrites
`context/patterns/roadmap-update.md` into the caller contract for the two modes. Done means: a
regenerate run reproduces `## Open work` exactly from state, leaves every authored section
byte-identical, is idempotent, and is proven by a registered test suite.

### Research Integration

The research report (`reports/01_roadmap-generated-artifact.md`) changed three of the dispatch's
premises, and this plan is written against the report, not the dispatch's literal wording:

1. **The dispatch's field list does not exist.** No `**Status**` / `**Milestones**` /
   `**Blocked by**` / `**Topics**` / `**Run**` bold field appears in `specs/ROADMAP.md` or in any
   of the three successive rewrites inspected. The contract is grounded in the measured section
   list instead (Phase 1 re-measures it before anything is written).
2. **`scripts/roadmap-integration.sh` is not a live two-mode script.** It is 944 lines quarantined
   at `scripts/deprecated/roadmap-integration.sh`, retired because its `## Phase N:` /
   checkbox / table parser reports `phases=0, checkboxes=0, table_rows=0, parseable=false` against
   the live file. Its parse/annotate body is replaced, not extended; only its CLI shape and its
   always-present machine-readable stderr marker convention carry over.
3. **No mechanical batch-suggestion capability exists or is reachable.** `MAX_TASKS=8` truncation
   in `commands/orchestrate.md` is the only batching mechanism; real next-batch suggestion is task
   274's unbuilt scope. So `## Next`'s curated Run blocks are retained-and-pruned, with a
   generated coverage appendix for uncovered tasks — not clobbered by naive chunking.

Also carried from research and acted on here: `hold` is fully schema-supported (so
`roadmap-format.md`'s old claim to the contrary is deleted, not repaired); `EXT-BLOCKED` has no
schema support and stays an authored annotation; `read_existing_goal` is the house pattern for
retaining authored prose across regeneration.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch and `roadmap_flag` is not set, so no
roadmap-review/roadmap-update phases are added and `specs/ROADMAP.md` is **not** written by this
task. The file is read as the measurement subject only. `specs/ROADMAP.md`'s own `## Open work`
lists this task as `306 ready  make ROADMAP.md a generated artifact   <- priority`, and task 313
(`blocked:306,328,344`) is the downstream consumer of the Run-block grammar this contract fixes.

## Goals & Non-Goals

**Goals**:

- Rewrite `context/formats/roadmap-format.md` into a generation contract: the measured section
  list, the per-task line grammar with its status-token vocabulary, the Run-block grammar, an
  explicit per-section authored-vs-generated table, and the retention keys a regenerate pass uses
  to preserve authored text.
- Deliver `scripts/roadmap-integration.sh` with three modes — `--print` (read-only), `--regenerate`
  (rebuild the generated sections in place), `--prune` (remove terminal tasks and drop a Run line
  once every task it names is terminal) — reusing `generate-task-order.sh --print` for wave data
  and `scripts/lib/status-vocabulary.sh` for the status enum.
- Make the authored/generated split mechanically enforced, not just documented: a regenerate pass
  must leave every authored section byte-identical, and must be idempotent.
- Rewrite `context/patterns/roadmap-update.md` into the caller contract (who calls which mode,
  when, and what each mode promises), replacing its stale `/review` Step 2.5 annotation process.
- Register the new script and the two rewritten context files so the deploy's doc and index lints
  stay green.

**Non-Goals**:

- **Wiring `/todo` or `/review` to call the new modes.** Neither `skills/skill-todo/SKILL.md` nor
  `commands/review.md` is in this task's `file_scope`; the dispatch assigns that wiring to
  dependent tasks. See Risks (R1) for the sequencing note this task leaves behind instead.
- **Writing `specs/ROADMAP.md` itself.** Modes are exercised against fixtures and `--dry-run`;
  committing a generated roadmap is the consumer tasks' call, not this task's.
- **Touching `generate-task-order.sh`, `generate-todo.sh`, `state-schema.json`, or
  `orchestrate-predispatch-review.sh`** — all in concurrent siblings 271's and 272's declared
  `file_scope` this same cycle. Consuming `--print`'s stdout instead of modifying the script is
  precisely what keeps this task free of a dependency on 271.
- **The three "belongs with 306" observations** in `specs/ROADMAP.md`'s `## Unfiled observations`
  (missing `title` keys caught by a null-only check; `SKILLVALIDATEFIXES` punctuation stripping;
  the `**Goal**:` line that cannot survive regeneration). Research verified all three name fix
  sites inside 271's or 272's `file_scope`. They are cross-references, not line items.
- **Schema support for cross-repository blockers (`EXT-BLOCKED`).** Research recommends the
  prose-only option for this task to stay clear of 271's territory.
- **A next-admissible-batch suggestion engine** (task 274) and **regenerating `## Gate state`**,
  whose dated bullets come from running checks, not from reading state.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| R1: A new script with zero live callers is quarantined by house convention, exactly as its predecessor was | H | M | Ship a registered test suite (Phase 5) so the script is exercised by gate 8; document the caller contract in `roadmap-update.md` (Phase 6); report the 313/328 sequencing gap in the handoff so a wiring follow-up is filed |
| R2: `roadmap-format.md` is an `@`-import in three agent files, so growing it raises their eager-context load | M | H | Cap the contract at ~180 lines; measure `validate-context-budgets.sh` before and after and record the delta (Phases 1, 7). Note: this validator is **not** a `verify-deploy.sh` gate and already reports pre-existing violations, so this is a budget-discipline constraint, not a gate |
| R3: `index-entries.json` is already dirty from concurrent sibling work; a bulk `--write` would stage their hunks | H | H | Never run `generate-context-line-counts.sh --write`; use `--check` to read the correct values and hand-edit only this task's two entries (Phase 7) |
| R4: A regenerate pass silently eats authored prose | H | M | `--dry-run` prints a diff and writes nothing; all writes land on a staging copy `mv`d into place only after success; the test suite asserts authored sections are byte-identical across a regenerate |
| R5: Implementing the dispatch's literal field names produces a contract matching no version of the file | H | M | Phase 1 re-measures and the contract cites the measurement; the divergence is recorded in this plan's Research Integration section |
| R6: `specs/ROADMAP.md`'s shape changes again between planning and implementation (three rewrites in recent history) | M | M | Phase 1 is a hard gate: if the measured section list differs from this plan's, stop and reconcile the contract before writing the script |
| R7: Parsing `generate-task-order.sh --print` couples this script to another task's output format | M | M | Parse the narrowest possible surface — only the `**Dependency Waves**:` table rows for wave membership; take topic, title, status and dependencies straight from `state.json`. Fail loudly with a named error if the table header is absent |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5, 6 | 4 |
| 6 | 7 | 5, 6 |

Phases within the same wave can execute in parallel.

### Phase 1: Re-measure the live artifacts and record the baseline [COMPLETED]

**Goal**: Confirm (or correct) every figure this plan carries from research before any file is
written, per `specs/ROADMAP.md` Standing rule 5 ("re-measure before acting on it").

**Tasks**:
- [x] Record `grep -n '^## ' specs/ROADMAP.md` and `wc -l specs/ROADMAP.md`; compare the section
      list against the nine sections this plan assumes (Goal, Gate state, Next, Open work, Checks
      before and after every call, Settled decisions, Standing rules, Unfiled observations, plus
      the `# Roadmap` title and its italic preamble) *(completed: 422 lines, 8 sections, exact match)*
- [x] Record `wc -l` for `context/formats/roadmap-format.md` and `context/patterns/roadmap-update.md` *(completed: 65 and 100 lines, exact match)*
- [x] Confirm `bash .claude/scripts/generate-task-order.sh --print` exits 0 and emits a
      `**Dependency Waves**:` table; capture its header row and one data row verbatim as the parse
      target *(completed: exit 0, 5-wave table, matches plan assumption)*
- [x] Confirm `scripts/roadmap-integration.sh` does **not** exist under
      `agent-system/extensions/core/scripts/` and that the quarantined copy is at
      `scripts/deprecated/roadmap-integration.sh` *(completed: confirmed, 944 lines)*
- [x] Capture baselines to compare against in Phase 7: `bash .claude/scripts/check-extension-docs.sh --quiet`
      exit code and finding count, `bash .claude/scripts/generate-context-line-counts.sh --check`
      output for the two context files, and `validate-context-budgets.sh`'s rows for
      `planner-agent`, `reviser-agent` and `general-research-agent` *(completed: reviser-agent has no tracked cap entry, noted in measurements-01.md)*
- [x] Write the measurements to `specs/306_roadmap_generated_artifact/measurements-01.md` *(completed)*
- [x] **Gate**: if the measured section list differs from this plan's, stop and reconcile Phase 2's
      contract against the measurement before proceeding *(completed: no divergence found, proceeding as planned)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This plan carries these figures from the research report and from
plan-time measurement; each is re-derived here and any mismatch is reconciled before Phase 2:
`specs/ROADMAP.md` is 422 lines with 8 `## ` sections under a `# Roadmap` title;
`roadmap-format.md` is 65 lines and `roadmap-update.md` is 100 lines; the quarantined
`roadmap-integration.sh` is 944 lines; `generate-task-order.sh --print` currently emits a 5-wave
table; `validate-context-budgets.sh` currently reports 10 violations including
`planner-agent OVER:8920` and `general-research-agent OVER:16496`. Confirm by the commands in the
task list above; record pass/fail per figure in `measurements-01.md`.

**Files to modify**:
- `specs/306_roadmap_generated_artifact/measurements-01.md` - new; the measurement record (task-directory artifact, not a deliverable)

**Verification**:
- `measurements-01.md` exists and carries one line per figure above with its measured value
- Every mismatch against this plan is named explicitly, with the reconciliation decision recorded

---

### Phase 2: Rewrite roadmap-format.md as a generation contract [NOT STARTED]

**Goal**: Replace the stale parse spec with a generation contract that a script can be written
against and a reader can check the live file against.

**Tasks**:
- [ ] Delete the entire existing body: `## Phase {N}: {Title} ({Priority})` headers, the checkbox
      table, the `| **{Component}** | {STATUS} | {Location} |` status-table format, priority
      markers, the `*(Completed: Task {N}, {DATE})*` annotation, the Section Types table and the
      Parsing Strategy list. None of it matches any version of the live file
- [ ] Drop the lengthy header/introduction/narrative framing per the task description; keep a
      one-line `**Purpose**` and go straight to structure
- [ ] Write `## Placement`: the file is `specs/ROADMAP.md`; ordering/gates/rulings only; task
      detail lives in `specs/TODO.md`; finished work is removed, not archived
- [ ] Write `## Section Order` as the canonical list with a regex per section header
- [ ] Write `## Authored vs. Generated` as a per-section table with columns
      Section / Class / Retention key, where Class is one of `generated`, `authored-verbatim`,
      `authored-retained`, `measured-by-hand`
- [ ] Write `## Open work` grammar: `**{Topic Title} ({count})**` block header, fenced block, one
      line per task `{N} {token}  {description}[   <- {annotation}]`, with the regex, the column
      rule, topic ordering from `state.json`'s `active_topics` plus the append-extras rule for
      undeclared topics, and within-block ordering (token class, then task number ascending)
- [ ] Write `## Status Tokens` as a closed vocabulary with a precedence rule:
      `HOLD` > `IN FLIGHT` > `BLOCKED` > `PARTIAL` > `blocked:N[,M...]` > `ready`, derived from
      `state.json` `status` plus `dependencies[]` filtered to non-terminal tasks; `EXT-BLOCKED` is
      an authored annotation with no schema support, named as such
- [ ] Write `## Next` grammar: fenced block, one `/orchestrate {tasks}` line per batch with an
      optional trailing `# {authored rationale}` comment; the `**{Why this order}**` prose below it
      is authored; the generated coverage appendix is chunked per wave at `MAX_TASKS=8`
- [ ] Write `## Generation` naming the script, its three modes, and the reuse ledger
      (`generate-task-order.sh --print` for wave membership; `state.json` for topic/title/status/
      dependencies/`hold_reason`; `scripts/lib/status-vocabulary.sh` for the status enum)
- [ ] Write `## Parsing Patterns Summary` as a single regex table, mirroring
      `context/formats/task-order-format.md`'s section of the same name
- [ ] Remove the stale claim that `hold` is unsupported wherever it survives in this file
- [ ] Keep the `## Related` cross-reference to `roadmap-update.md`, and add one to
      `task-order-format.md` as the structurally parallel sibling contract

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: The rewritten file is asserted to land at or below ~180 lines, to keep the
three agents that `@`-import it from absorbing a large eager-context increase (R2). Confirm with
`wc -l` at the end of this phase and with the budget delta recorded in Phase 7; if it overshoots,
cut the regex table's prose commentary rather than the grammar itself.

**Files to modify**:
- `agent-system/extensions/core/context/formats/roadmap-format.md` - full rewrite: parse spec to generation contract

**Verification**:
- Every section in Phase 1's measured section list appears in the Authored vs. Generated table
  with exactly one class
- The status-token vocabulary is closed and its precedence rule is unambiguous for a task that is
  simultaneously `hold` and has open dependencies
- No occurrence of `## Phase N:`, the checkbox table, the status-table format, or the
  `*(Completed: Task N, DATE)*` annotation remains
- `grep -c '' ` on the file is at or below ~180 lines, or the overshoot is justified in the commit
- Modeled on `task-order-format.md`: Placement, Structure, Parsing Patterns Summary, Generation,
  Related all present

---

### Phase 3: Build the derivation layer and --print mode [NOT STARTED]

**Goal**: A read-only `scripts/roadmap-integration.sh --print` that emits the generated sections
exactly as Phase 2's contract specifies, mutating nothing.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/roadmap-integration.sh` fresh (the `file_scope`
      path). Do **not** restore or patch `scripts/deprecated/roadmap-integration.sh`; its
      `## Phase N:` python parser is replaced wholesale
- [ ] House preamble: `#!/usr/bin/env bash`, `set -euo pipefail`, a usage header documenting all
      three modes and the stderr marker, `source lib/common.sh`, `common_repo_root`,
      `. deploy-root-guard.sh`, `source lib/status-vocabulary.sh`
- [ ] Arg parsing: `--print` (default), `--regenerate`, `--prune`, `--roadmap PATH`,
      `--state PATH`, `--dry-run`, `--max-tasks N` (default 8, matching `commands/orchestrate.md`'s
      `MAX_TASKS`), `--help`. Reject more than one mode flag with a named error
- [ ] Wave data: invoke `generate-task-order.sh --print` as a subprocess (it cannot be sourced —
      it runs `build_graph`/`compute_waves` unconditionally at file scope) and parse **only** the
      `**Dependency Waves**:` table rows into `wave_of[task]`. If the header is absent, fail with a
      named error rather than silently producing an empty map
- [ ] Task data: one jq pass over `state.json` for `project_number`, `status`, `title`, `topic`,
      `dependencies`, `hold_reason`; exclude the terminal set (`completed`, `abandoned`,
      `expanded`), documenting `lib/status-vocabulary.sh` as the enum anchor
- [ ] Status tokens: one-pass derivation per the contract's precedence rule — `dependencies[]`
      intersected with the non-terminal task set; empty means `ready`, else
      `blocked:` plus the sorted comma list. This mirrors `get_active_tasks()`'s one-line jq shape
      and is **not** a second wave/DAG implementation
- [ ] Render `## Open work`: topic blocks in `active_topics` order, append-extras for undeclared
      topics with a one-time stderr warning per topic (mirroring `task-order-format.md`'s rule 7),
      counts in the block header, column-aligned task lines
- [ ] Render the `## Next` coverage appendix: dispatchable tasks not named by any retained Run
      line, chunked per wave at `--max-tasks`
- [ ] Always-on stderr marker, reusing the quarantined script's one salvageable convention:
      `<!-- roadmap-generation mode=M tasks=N topics=T runs=R pruned=P retained=A -->`
- [ ] `--print` writes to stdout only; assert via `md5sum` in the phase verification that neither
      `specs/ROADMAP.md` nor `specs/state.json` changes
- [ ] `chmod +x`; `bash -n`; `shellcheck`

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - new script: derivation layer and `--print`

**Verification**:
- `bash -n` clean and `shellcheck` reports no new findings
- `bash agent-system/extensions/core/scripts/roadmap-integration.sh --print` exits 0 and emits an
  `## Open work` section whose per-task token for every currently-open task matches
  `specs/ROADMAP.md`'s hand-written token for that task (spot-check all `HOLD`, `IN FLIGHT` and
  `blocked:` lines; `EXT-BLOCKED` is expected to differ, since it is authored-only)
- `md5sum specs/ROADMAP.md specs/state.json` is unchanged across the run
- `--help` documents all three modes; two mode flags together produce a named error, not a silent
  last-wins

---

### Phase 4: Add retention, --regenerate and --prune [NOT STARTED]

**Goal**: In-place rewriting of only the generated sections, with every authored section preserved
byte-identically and both modes idempotent.

**Tasks**:
- [ ] Retention parser: read the existing `specs/ROADMAP.md` and extract, keyed as the contract
      specifies — authored sections verbatim (`## Goal`, `## Gate state`, `## Checks before and
      after every call`, `## Settled decisions`, `## Standing rules`, `## Unfiled observations`),
      the `## Next` Run lines with their trailing `#` rationale comments, the "why this order"
      prose, per-task `<- {annotation}` suffixes keyed by task number, and per-task authored
      description overrides keyed by task number. This copies `read_existing_goal`'s
      read-existing-then-retain mechanism; it does not import the function
- [ ] Section replacement: replace content between a `^## {Section}$` header and the next `^## `
      header, mirroring `generate-task-order.sh --update-todo`'s awk approach (a local helper —
      there is no shared section-replace library in `scripts/lib/`)
- [ ] Atomicity: every write lands on a staging copy; the original is `mv`d into place only after
      the full render succeeds, so a mid-run failure leaves `specs/ROADMAP.md` byte-identical
- [ ] `--regenerate`: rebuild `## Open work` wholly from derived data; rebuild the `## Next`
      coverage appendix; retain every authored value above. Per-task description falls back to
      `state.json` `title` truncated per the contract when no authored override exists
- [ ] `--prune`: narrow mode — drop terminal tasks from `## Open work` and from Run lines, and drop
      a whole Run line once every task it names is terminal. Touch no other authored prose and do
      not re-render the coverage appendix
- [ ] `--dry-run` (composable with both write modes): print a unified diff to stdout, write nothing
- [ ] Idempotency: a second consecutive `--regenerate` produces a byte-identical file
- [ ] Preserve the file's trailing-newline and fence conventions exactly

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - add retention parser, section replacement, `--regenerate`, `--prune`, `--dry-run`

**Verification**:
- `--regenerate --dry-run` against the live `specs/ROADMAP.md` leaves it byte-identical
  (`md5sum` before and after) and its diff touches only `## Open work` and `## Next`
- Against a temp-copy fixture: `--regenerate` run twice yields byte-identical output
- Against a temp-copy fixture: every authored section is byte-identical before and after
  `--regenerate` and after `--prune`
- A fixture whose Run line names only terminal tasks has that whole line removed by `--prune`
- A simulated mid-run failure leaves the fixture byte-identical (staging-copy behavior)

---

### Phase 5: Register a test suite [NOT STARTED]

**Goal**: Lock the contract mechanically so the script cannot rot into quarantine the way its
predecessor did.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh`. Glob
      discovery in `tests/run-all.sh` picks up `test-*.sh` automatically, so **no edit to
      `run-all.sh`** is needed — that file is concurrent sibling 366's territory this cycle
- [ ] Follow the house harness convention in `context/standards/shell-script-testing.md`
      (read-only; the file is sibling 366's territory): isolated temp root, no dependence on
      `specs/` live state, explicit per-case pass/fail lines, nonzero exit on any failure
- [ ] Build a small synthetic `state.json` fixture covering every status token: `ready`,
      `blocked:N`, `blocked:N,M`, `IN FLIGHT`, `HOLD`, a terminal task that must be excluded, a
      task with an undeclared topic, and a task whose only dependency is terminal (must read
      `ready`, not blocked)
- [ ] Build a synthetic `ROADMAP.md` fixture carrying authored prose in every authored section,
      authored `<- annotation` suffixes, an authored `EXT-BLOCKED` token, and Run lines with
      trailing rationale comments
- [ ] Cases: token derivation per status; terminal exclusion; terminal-dependency-reads-ready;
      topic ordering plus append-extras warning; authored sections byte-identical across
      `--regenerate`; authored annotations and `EXT-BLOCKED` survive; `--regenerate` idempotent;
      `--prune` drops an all-terminal Run line; `--dry-run` writes nothing; the stderr marker is
      present in every mode; absent `--roadmap` target is handled as a supported state, not a crash
- [ ] Confirm the suite is discovered: `bash agent-system/extensions/core/scripts/tests/run-all.sh`
      with the narrowest selection available lists and passes it

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: local

**Scope Hypothesis**: The case list above is asserted to be ~11 cases over 2 fixtures; confirm the
actual count at implementation time and state it in the suite header. The claim that
`tests/run-all.sh` discovers suites by glob (and so needs no edit) was measured at plan time —
re-confirm it before relying on it, since `run-all.sh` is sibling 366's active territory this
cycle and may have changed.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - new test suite

**Verification**:
- The suite exits 0 standalone and is picked up by `run-all.sh`'s discovery without any edit to
  `run-all.sh`
- Every case prints an explicit pass/fail line; a deliberately broken assertion makes the suite
  exit nonzero
- The suite touches nothing under `specs/` (verify with `md5sum specs/state.json
  specs/ROADMAP.md` before and after)

---

### Phase 6: Rewrite roadmap-update.md as the caller contract [NOT STARTED]

**Goal**: Replace the stale `/review` Step 2.5 annotation process with the contract the two write
modes expose to their callers.

**Tasks**:
- [ ] Delete the stale body: the Update Trigger (`/review` Step 2.5), Completion Detection data
      sources, the exact/title/file matching strategy, confidence levels, the
      `- [ ]` to `- [x] *(Completed: Task N, DATE)*` annotation process, Goal Identification, Task
      Recommendations with its scoring table, Language Inference and User Interaction. All of it
      describes machinery that is quarantined and a file format that no longer exists
- [ ] Write the responsibility split the task description names: **prune** is the `/todo`-shaped
      operation (remove terminal tasks, drop a fully-terminal batch); **regenerate** is the
      `/review`-shaped operation (rebuild the generated sections, including each batch's and
      topic block's brief description)
- [ ] Write the caller contract per mode: invocation, what it promises, what it never touches,
      exit codes, the stderr marker, and `--dry-run` as the review-before-write path
- [ ] State plainly that the authored-vs-generated split lives in `roadmap-format.md` and is not
      duplicated here, so the two files cannot drift
- [ ] Record that the script has **no live caller yet**, name the dependent work that will wire it
      (`/todo` prune, `/review` regenerate, and task 313's lint over hand-authored batch
      proposals), and state the safe interim invocation: `--dry-run` by hand
- [ ] Keep `## Related` pointing at `roadmap-format.md` and the script

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/roadmap-update.md` - full rewrite: stale annotation process to mode caller contract

**Verification**:
- No reference remains to `/review` Step 2.5, the checkbox annotation format, or the confidence/
  scoring tables
- Every flag the Phase 3/4 script actually accepts is documented, and no flag is documented that
  the script does not accept (diff the `--help` output against this file)
- The authored-vs-generated split is cross-referenced, not restated

---

### Phase 7: Registration, cross-references and the full gate [NOT STARTED]

**Goal**: Leave the deploy's lints green and the new script discoverable.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/index-entries.json` immediately before editing — it is
      concurrently dirty from sibling work this cycle
- [ ] Run `bash .claude/scripts/generate-context-line-counts.sh --check` to read the correct
      values, then **hand-edit only** the `formats/roadmap-format.md` and
      `patterns/roadmap-update.md` entries: corrected `line_count`, a `summary` describing the
      generation contract rather than the old parse spec, and keywords. **Never run `--write`** —
      it rewrites every extension's index-entries.json and would stage siblings' hunks (R3)
- [ ] Add a one-line entry for `roadmap-integration.sh` to
      `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` (no lint enforces
      this; it is how a standalone script stays findable)
- [ ] Add one cross-reference line to `agent-system/extensions/core/scripts/deprecated/README.md`'s
      `roadmap-integration.sh` entry noting that the live script at `scripts/roadmap-integration.sh`
      is a fresh replacement, not a restoration, so the name collision cannot be misread as a
      revival of the quarantined parser
- [ ] Stage file-by-file with an explicit path list (never a directory or glob pathspec, never
      `git add -A`), review `git status --short` and `git diff --staged` first, and commit only
      this task's hunks
- [ ] Run the full gate set: `bash .claude/scripts/verify-deploy.sh`
- [ ] Record the `validate-context-budgets.sh` delta for `planner-agent`, `reviser-agent` and
      `general-research-agent` against Phase 1's baseline

**Timing**: 0.75 hours

**Depends on**: 5, 6

**Verification Tier**: full

**Scope Hypothesis**: Four registration edits are asserted here (two `index-entries.json` entries,
one inventory line, one deprecated-README line). Confirm by diffing the staged paths against this
list; a fifth required registration discovered at implementation time is a finding to report, not
a silent addition.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - corrected `line_count` and refreshed `summary` for the two rewritten context entries only
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - one entry for the new script
- `agent-system/extensions/core/scripts/deprecated/README.md` - one cross-reference line distinguishing the live script from the quarantined one

**Verification**:
- `bash .claude/scripts/generate-context-line-counts.sh --check` reports no mismatch for either
  rewritten context file
- `bash .claude/scripts/check-extension-docs.sh --quiet` finding count is no worse than Phase 1's
  baseline, and `STRICT_CORE_DEPLOY=1` adds no new failure
- `bash .claude/scripts/verify-deploy.sh` completes (budget ~10 minutes; do not cap it at 540s)
  and introduces **zero** new failures against Phase 1's baseline. Gate 8 (`tests/run-all.sh`) is
  known-red on five suites owned by tasks 351/352/353 and reads red regardless; the new suite from
  Phase 5 must appear in the `EXPECTED`/`NEW` split as a pass, never as a `NEW` failure
- `git diff --staged` shows only this task's hunks in `index-entries.json`
- The budget delta for the three affected agents is recorded in the commit body or the summary

---

## Testing & Validation

- [ ] `bash -n` and `shellcheck` clean on `scripts/roadmap-integration.sh` and the new test suite
- [ ] `test-roadmap-generation.sh` passes standalone and is auto-discovered by `tests/run-all.sh`
- [ ] `--print` output's status token matches `specs/ROADMAP.md`'s hand-written token for every
      currently-open task (`EXT-BLOCKED` excepted, being authored-only)
- [ ] `--regenerate` is idempotent (second run byte-identical) and leaves every authored section
      byte-identical
- [ ] `--prune` drops terminal tasks and all-terminal Run lines and touches nothing else
- [ ] `--dry-run` leaves `specs/ROADMAP.md` and `specs/state.json` byte-identical (`md5sum`)
- [ ] `generate-context-line-counts.sh --check` and `check-extension-docs.sh --quiet` no worse
      than the Phase 1 baseline
- [ ] `verify-deploy.sh` introduces zero new failures against the Phase 1 baseline

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/roadmap-format.md` — rewritten as the generation contract
- `agent-system/extensions/core/context/patterns/roadmap-update.md` — rewritten as the mode caller contract
- `agent-system/extensions/core/scripts/roadmap-integration.sh` — new, with `--print` / `--regenerate` / `--prune` / `--dry-run`
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` — new test suite
- `agent-system/extensions/core/index-entries.json` — two corrected entries
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — one new entry
- `agent-system/extensions/core/scripts/deprecated/README.md` — one cross-reference line
- `specs/306_roadmap_generated_artifact/measurements-01.md` — Phase 1 measurement record
- `specs/306_roadmap_generated_artifact/summaries/01_*-summary.md` — implementation summary

## Rollback/Contingency

Every phase commits independently, so rollback is per-phase revert of a committed phase rather
than a working-tree discard. All edits are additive or confined to three files whose prior content
is fully recoverable from git; `specs/ROADMAP.md` is never written by this task, so no roadmap
content can be lost.

If a phase must be abandoned mid-edit with uncommitted changes present, take a durable,
non-reverting checkpoint first (`bash .claude/scripts/git-snapshot.sh 306 --no-revert`) and leave
the phase `[PARTIAL]`. Only a genuine rollback — deliberately discarding this task's uncommitted
work — uses the reverting default; see `context/contracts/recovery.md`'s rollback rung for that
invocation shape, including its out-of-scope override flag. Never discard uncommitted changes to
reach a passing gate.

Contingency if Phase 3's parse of `generate-task-order.sh --print` proves brittle (R7): fall back
to deriving wave membership with a local Kahn pass is **not** permitted (it rebuilds what the
dispatch forbids rebuilding). Instead, narrow the parse further — take only the wave number per
task and derive everything else from `state.json` — and report the brittleness as a finding for a
future task that gives `generate-task-order.sh` a machine-readable output mode.

## Notes for the Orchestrator

- **Sequencing gap to file as a follow-up** (not fixable inside this task): tasks 307 and 308,
  which were to wire `/todo` prune and `/review` regenerate, were abandoned into task 328 on
  2026-10-03. Task 328 carries their substance but has **no dependency edge on 306**, and task 313
  (`blocked:306,328,344`) lints the Run-block grammar this contract defines. The modes this task
  ships therefore have no live caller when it completes. A wiring follow-up should be filed.
- **Cross-references out of scope**, per research Finding 7: the three "belongs with 306"
  observations in `specs/ROADMAP.md` name fix sites inside concurrent siblings 271's and 272's
  `file_scope`. They belong on 271's and 272's backlogs.
