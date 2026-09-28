# Implementation Plan: Inline terminal status in agent contracts

- **Task**: 257 - Inline terminal status in agent contracts
- **Status**: [COMPLETED]
- **Effort**: 10 hours
- **Dependencies**: None (blocking). Shares one extraction prerequisite with task 258
  (recovery-decline-attribution, currently `not_started`): Phase 1 below performs that
  extraction, so 258 consumes the library rather than re-deriving it.
- **Research Inputs**: specs/257_inline_terminal_status_in_agent_contracts/reports/01_terminal-status-vocabulary.md
- **Artifacts**: plans/01_inline-terminal-status-contracts.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

**SOURCE STORE IS THE EDIT TARGET**: every write in this plan lands under
`agent-system/extensions/`. Never hand-author under `.claude/**` — see
`.claude/rules/source-store-deploy-boundary.md`.

## Overview

A research dispatch wrote `"status": "completed"` into `.return-meta.json`;
`orchestrate-recover-outcome.sh`'s success `case` arm accepts only `researched|planned|implemented`,
so a fully successful phase was charged as a failure. The root cause is structural, not
agent-specific: 20 dispatchable agent files show the model either a bare `"artifacts": [...]`
fragment with no status key, or a pipe-alternatives placeholder that is not a literal vocabulary
member. This plan brings all 20 files (22 edit sites) up to the shape the 19 already-protected
agents use, extracts the canonical 8-value vocabulary out of `validate-return-meta.sh` into a
sourced library so the validator, the recovery arm, and a new lint check all read one definition,
and adds Check E to `lint-agent-contracts.sh` to stop the examples drifting again. Done means:
every dispatchable agent outside an explicit, reasoned exclusion list carries a concrete inline
terminal status; the lint enforces it; `run-all.sh` is green.

### Research Integration

The research report (`reports/01_terminal-status-vocabulary.md`) verified every factual claim in
the task description by direct file read and settled all five open design questions. This plan
adopts its decisions verbatim:

- **Count**: **20 files / 22 edit sites** is authoritative (the description's headline "24" is a
  superseded earlier-audit figure; its own enumerated sub-lists sum to 20). Independently
  re-confirmed during this planning pass by a per-file audit of status-key and MUST-NOT-bullet
  presence across all 20 files — the results match the report's Category A/B/C split exactly.
- **Pipe-placeholder shape** (open question 2): **FAIL** it in the lint and rewrite every
  instance to a concrete value. The two hard-twin placeholders are in the
  `.orchestrator-handoff.json` block, not `.return-meta.json` — `handoff-schema.md:190-199`
  states that file's status enum is sourced from the same normative table, so both blocks are
  fixed identically and those two files need **two edit sites each**.
- **Lint scope** (open question 1): an **explicit recorded-exclusion list**, sibling to
  `EXCLUDED_ARTIFACTS_TEMPLATE_RELATIVE_PATHS`. The research falsified the routing-derived
  alternative: `routing_agents` membership does **not** predict canonical-vocabulary use —
  `filetypes/*`, `slidev-assembly-agent` (`assembled`) and `legal-analysis-agent` (`consulted`,
  with no conformant value anywhere) are all registered phase-routing targets using intentional
  non-canonical vocabularies.
- **Vocabulary source**: extract from `validate-return-meta.sh:175-183`. **Never**
  `scripts/lib/status-vocabulary.sh` — that is the 12-value *task-level* enum and it contains
  `"completed"` as a legitimate member, so sourcing it yields a lint that accepts the exact value
  this task exists to forbid.
- **Runtime wiring** (the RUNTIME HOLE): explicitly **out of scope**, split to a follow-up — see
  Goals & Non-Goals and Deferred Follow-Up Tasks for the recorded decision and its ordering
  constraint.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Every one of the 20 unprotected agent files carries a concrete, copyable inline terminal status
  in its `.return-meta.json` (and, for the two hard implementation twins, its
  `.orchestrator-handoff.json`) fenced example.
- The never-use-`"completed"` MUST-NOT bullet is present in every one of the 20 files, reusing
  `general-research-agent.md:433`'s existing wording — not a newly invented form.
- One sourced library defines the canonical 8-value `.return-meta.json` status vocabulary and its
  3-value success subset; `validate-return-meta.sh` and `orchestrate-recover-outcome.sh` consume
  it instead of each carrying a private copy.
- `lint-agent-contracts.sh` Check E fails any non-excluded dispatchable agent lacking a
  conformant inline status, and fails any `"status": "completed"` key/value pair in an agent body.
- `run-all.sh` and `lint-agent-contracts.sh` both pass clean at the end.

**Non-Goals**:

- **Wiring `validate-return-meta.sh` into the dispatch path.** Recorded decision: out of scope,
  split to a follow-up (see Deferred Follow-Up Tasks). Rationale — the validator's 8-value
  *rejection* would newly break `legal-analysis-agent`'s `"consulted"`, `grant-agent`'s
  `"drafted"`, `slidev-assembly-agent`'s `"assembled"` and every `filetypes/*` vocabulary, all of
  which work today. The follow-up must resolve the recovery-arm *acceptance* question first.
- **Widening `orchestrate-recover-outcome.sh`'s success arm** to admit `consulted`/`converted`/
  `assembled`. Phase 3's refactor is strictly semantics-preserving; the widening question is
  recorded, not acted on.
- **Deciding whether `"drafted"` should join the canonical vocabulary.** `grant-agent` keeps it
  as an agent-local value (the minimal, non-breaking choice); the question is recorded as a named
  follow-up.
- Changing `orchestrate-recover-outcome.sh` to **accept** `"completed"` as a success synonym —
  explicitly out of scope per the task description; that would re-import the stop-behavior hazard.
- Touching the already-protected 19 agents, or the two Check F exclusions
  (`code-reviewer-agent.md`, `literature-agent.md`), which write no `.return-meta.json` at all.
- Editing anything under `.claude/**`, or running a deploy.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Check E lands before the content fixes, failing 20 files the same commit does not repair | H | M | Phase 8 depends on Phases 4-7; the wave table enforces the ordering, and Phase 8's verification re-runs the lint over the whole source store |
| Check E's `"completed"` detector false-positives on legitimate prose (the MUST-NOT bullets themselves say `"completed"`, `project-agent.md` says "Mark completed items") | H | H | Match only the quoted key/value pair `"status"\s*:\s*"completed"`, never the bare word — mirroring Check F's `has_artifacts_object_shape` window-and-key-set precedent rather than a loose grep. Phase 8 adds an explicit negative fixture for a file containing the MUST-NOT bullet but no `"status": "completed"` pair |
| Adding Check E silently breaks two existing test assertions | M | H | **Confirmed live during planning**: `test-lint-agent-contracts.sh:289` and `:315` assert that `compliant-agent.md` and `check-f-conforming-agent.md` produce *no* FAIL line, and neither fixture carries an inline status. Phase 8 is `atomic-batch` precisely so the fixtures and the check land in one commit |
| Twin-file discipline: a one-sided edit between `lean`/`cslib` base and `-hard` agents is a recorded recurring defect class | M | M | Phase 6 handles all four hard twins together in one phase, locating each site by content (the enclosing `### Stage N` heading), never by line symmetry between the two files |
| Sourcing the wrong vocabulary file (`lib/status-vocabulary.sh`) yields a lint that accepts `"completed"` | H | M | Phase 1's library header states the trap explicitly and names the correct source; Phase 1's test asserts `"completed"` is **not** a member |
| Refactoring `orchestrate-recover-outcome.sh` (hot dispatch path) introduces a regression | H | L | Phase 3 is semantics-preserving only, gated on `test-orchestrate-recover-outcome.sh`; the source-store edit has no live effect until a deploy, so no in-flight orchestration is affected |
| Sibling task 259 is editing core scripts this same cycle | M | M | 259's declared `file_scope` (orchestrate-cycle-plan.sh, orchestrate-cycle-postflight.sh, skill-base.sh, plan-format.md, status-markers.md, handoff-schema.md + 4 tests) has **zero overlap** with this plan's file set. Still: re-read every file immediately before editing, stage only this task's own hunks with an explicit file list (never `git add -A`, a directory, or a glob), and never run `git-snapshot.sh` in its reverting default mode |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4, 5, 6, 7 | -- |
| 2 | 2, 3, 8 | 1 (for 2, 3); 1, 4, 5, 6, 7 (for 8) |
| 3 | 9 | 2, 3, 8 |

Phases within the same wave can execute in parallel. Phases 4-7 are pure prose edits on disjoint
file sets and never touch a file another phase touches.

---

### Phase 1: Extract the shared return-meta status vocabulary library [COMPLETED]

**Goal**: One sourced, executable definition of the canonical 8-value `.return-meta.json` status
vocabulary, its explicit `"completed"` prohibition, and its 3-value success subset — so the
validator, the recovery arm, the new Check E, and task 258 all read the same list.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lib/return-meta-status-vocabulary.sh`, *(completed)*
      modeled on `scripts/lib/phase-heading-patterns.sh` and `scripts/lib/status-vocabulary.sh`:
      no side effects at source time, source-able from either the deployed
      (`.claude/scripts/lib/`) or source-store copy.
- [x] Export `RETURN_META_STATUS_VALUES=(in_progress researched planned implemented *(completed)*
      needs_research partial failed blocked)` — copied verbatim from
      `validate-return-meta.sh:175`, not re-derived.
- [x] Export `RETURN_META_FORBIDDEN_STATUS="completed"` plus the exact rejection message already *(completed)*
      used at `validate-return-meta.sh:183` ("explicitly forbidden (triggers Claude stop
      behavior) -- use 'implemented' instead"), so consumers never re-word it.
- [x] Export `RETURN_META_SUCCESS_STATUSES=(researched planned implemented)` — the subset *(completed)*
      `orchestrate-recover-outcome.sh:242` currently hardcodes — with a comment naming it as a
      deliberate subset, not a second vocabulary.
- [x] Add predicates `is_return_meta_status <value>` and `is_return_meta_success_status <value>`. *(completed)*
- [x] Write the file header to state the vocabulary trap explicitly: *(completed)* `lib/status-vocabulary.sh`
      is the 12-value **task-level** enum for `state.json .active_projects[].status`, contains
      `"completed"` by design, and MUST NOT be sourced for return-meta purposes. Name
      `context/formats/return-metadata-file.md`'s status table as the prose source of truth.
- [x] Create `agent-system/extensions/core/scripts/tests/test-return-meta-status-vocabulary.sh` *(completed)*
      modeled on `tests/test-status-vocabulary.sh`, asserting: all 8 members present and in
      order; `"completed"` is NOT a member; `is_return_meta_success_status` accepts exactly the
      3 subset values and rejects `in_progress`/`completed`; and a **drift assertion** that the
      array matches the list literally present in `validate-return-meta.sh` (so the two cannot
      diverge before Phase 2 lands).
- [x] `chmod +x` the new test *(completed)* — `run-all.sh` reports a non-executable suite as a loud `[SKIP]`,
      never a pass.
- [x] Register both new paths in `agent-system/extensions/core/manifest.json`'s scripts list, *(completed)*
      preserving the existing ordering convention (`lib/return-meta-status-vocabulary.sh` after
      `lib/return-meta-artifacts-lib.sh`; `tests/test-return-meta-status-vocabulary.sh` in the
      tests block).

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/return-meta-status-vocabulary.sh` - NEW
- `agent-system/extensions/core/scripts/tests/test-return-meta-status-vocabulary.sh` - NEW
- `agent-system/extensions/core/manifest.json` - register both new script paths

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-return-meta-status-vocabulary.sh` exits 0
- `bash -n` clean on the new library; sourcing it twice in one shell is idempotent and produces
  no output
- `jq empty agent-system/extensions/core/manifest.json` passes and both new paths appear exactly once

---

### Phase 2: Make validate-return-meta.sh consume the library [COMPLETED]

**Goal**: Remove the private 8-value copy from the validator so the extraction has a real
consumer and cannot silently drift.

**Tasks**:
- [x] Source `lib/return-meta-status-vocabulary.sh` in `validate-return-meta.sh`, following the *(completed)*
      same lib-resolution idiom the file already uses for `lib/return-meta-artifacts-lib.sh`.
- [x] Replace the hardcoded `valid_statuses=(...)` array (`:175`) with *(completed)*
      `RETURN_META_STATUS_VALUES`, and the hardcoded `"completed"` comparison and message
      (`:183`) with the library constants.
- [x] Leave every pass/fail message string byte-identical to what it prints today *(completed)* — the test
      suite and the deferred runtime-wiring follow-up both key off this wording.
- [x] Drop Phase 1's temporary drift assertion from *(completed)*
      `test-return-meta-status-vocabulary.sh` (the literal list is gone from the validator) and
      replace it with an assertion that the validator sources the library.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-return-meta.sh` - source the lib, delete the
  private vocabulary copy
- `agent-system/extensions/core/scripts/tests/test-return-meta-status-vocabulary.sh` - swap the
  drift assertion for a sourcing assertion

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` exits 0
- `bash agent-system/extensions/core/scripts/tests/test-return-meta-status-vocabulary.sh` exits 0
- Manual spot-check: running the validator against a fixture carrying `"status": "completed"`
  still prints the same forbidden-value message it printed before the refactor

---

### Phase 3: Make orchestrate-recover-outcome.sh's success arm read the same definition [COMPLETED]

**Goal**: The third consumer named in the task description reads the shared definition instead of
a fourth private copy — strictly semantics-preserving.

**Tasks**:
- [x] Re-read `orchestrate-recover-outcome.sh` in full before editing; *(completed)* it is a hot dispatch-path
      script with a deliberate "does not source skill-base.sh" posture documented inline. Sourcing
      a side-effect-free constants library does not violate that posture (which is about
      artifacts *normalization*), but record that reading in the commit message.
- [x] Source `lib/return-meta-status-vocabulary.sh` and restructure the `case "$status"` at `:242` *(completed)*
      into an equivalent `if is_return_meta_success_status "$status"` / `elif` chain, preserving
      every existing arm's behavior exactly — including the `in_progress` arm and the `*` default
      that emits `STATUS_NOT_SUCCESS`.
- [x] Add a comment at the arm naming the recorded deferral: *(completed)* the success set is deliberately the
      3-value subset, and widening it to admit intentional non-canonical extension vocabularies
      (`consulted`, `converted`, `assembled`) is the follow-up task's first question — not this
      task's change.
- [x] Leave the `ARTIFACTS_SHAPE_MISMATCH` detector and the raw-read block untouched. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` - source the lib, convert
  the success arm, add the deferral comment

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-recover-outcome.sh` exits 0
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-recover-message-findings.sh`
  exits 0
- `bash -n` clean; `git diff` shows no behavioral change beyond the arm restructure (no new or
  removed emitted signal names)

---

### Phase 4: Category B content fix — 10 fully-bare extension agents [COMPLETED]

**Goal**: The files structurally closest to the observed incident (zero `"status"` occurrences
anywhere, and no MUST-NOT bullet) gain both the inline status and the warning. `typst-research-agent.md`
— the file that produced the real incident — is in this set.

**Tasks**:
- [x] For each file below: read its terminal-metadata section, then wrap the existing bare *(completed)*
      `"artifacts": [...]` fenced fragment in a full JSON object whose **first** key is the
      concrete status for that agent's phase, matching `lean-research-agent.md:321-337`'s
      existing structure (status, artifacts, metadata). Do not invent a new template shape.
- [x] Add the MUST-NOT bullet to each file's "MUST NOT" list, reusing *(completed)*
      `general-research-agent.md:433`'s exact wording: `Use status value "completed" (triggers
      Claude stop behavior)`.
- [x] Research agents take `"status": "researched"`; implementation agents take *(completed)*
      `"status": "implemented"`.
- [x] Files: `latex/agents/latex-research-agent.md`, `latex/agents/latex-implementation-agent.md`, *(completed)*
      `python/agents/python-research-agent.md`, `python/agents/python-implementation-agent.md`,
      `rust/agents/rust-research-agent.md`, `rust/agents/rust-implementation-agent.md`,
      `typst/agents/typst-research-agent.md`, `typst/agents/typst-implementation-agent.md`,
      `z3/agents/z3-research-agent.md`, `z3/agents/z3-implementation-agent.md`.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: 10 files, one edit site each, all sharing an identical bare-fragment shape
(verified during planning: each has exactly 0 `"status":` occurrences and 0 MUST-NOT bullets).
Confirm per file at implementation time by reading the terminal section before editing — do not
apply a uniform blind patch; if any file's shape differs from the other nine, treat it
individually and say so in the summary.

**Files to modify**:
- The 10 files enumerated above - wrap the artifacts fragment in a status-carrying object; add
  the MUST-NOT bullet

**Verification**:
- Each file now yields exactly one `"status": "researched"` or `"status": "implemented"` line
  inside its `.return-meta.json` fenced block
- Each file now carries the MUST-NOT bullet verbatim
- Every edited fenced block is valid JSON once its `{N}`/`{NN}` placeholders are substituted
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` still passes (Check F
  must not regress — wrapping is safe because Check F extracts only the required key set)

---

### Phase 5: Category A content fix — core lifecycle agents and email [COMPLETED]

**Goal**: Close the two highest-blast-radius files in the system. `planner-agent.md` is the
default plan agent for **every** task type and its only complete JSON example today is the
`needs_research` **failure** path; `general-research-agent.md` is the default research agent for
`general`/`meta`/`markdown`.

**Tasks**:
- [x] `core/agents/planner-agent.md` — **do this file first**. *(completed)* Wrap the bare `"artifacts": [...]`
      at `:410` in a full object opening with `"status": "planned"`, so the happy path finally has
      a complete worked example alongside the existing `needs_research` one at `:434`. Leave the
      `needs_research` block and the prose at `:401` unchanged; the MUST-NOT bullet is already
      present at `:530` — do not duplicate it.
- [x] `core/agents/general-research-agent.md` — wrap the bare fragment at `:384` *(completed)* with
      `"status": "researched"`. Prose and the MUST-NOT bullet (`:433`) are already correct; add
      nothing else.
- [x] `core/agents/spawn-agent.md` — wrap the bare fragment at `:212` *(completed)* with
      `"status": "researched"`, matching the prose at `:203`. MUST-NOT bullet already present at
      `:248`.
- [x] `email/agents/email-implementation-agent.md` — wrap the bare fragment at `:164` *(completed)* with
      `"status": "implemented"`. MUST-NOT bullet already present at `:228` in its own local
      wording — leave it as-is rather than re-wording it.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: 4 files, one edit site each, all already carrying the MUST-NOT bullet (so
this phase adds inline JSON only, never a duplicate warning). Verified during planning by a
per-file bullet/status-key audit. Confirm each file's bullet presence by grep before editing.

**Files to modify**:
- `agent-system/extensions/core/agents/planner-agent.md` - status `planned` at the happy-path block
- `agent-system/extensions/core/agents/general-research-agent.md` - status `researched`
- `agent-system/extensions/core/agents/spawn-agent.md` - status `researched`
- `agent-system/extensions/email/agents/email-implementation-agent.md` - status `implemented`

**Verification**:
- `planner-agent.md` now contains `"status": "planned"` in its Stage 6b block, and still contains
  exactly one `"status": "needs_research"` block
- No file gained a second copy of the MUST-NOT bullet (`grep -c` unchanged from the pre-edit count)
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` still passes

---

### Phase 6: Hard-mode twins — 4 files, 6 edit sites [COMPLETED]

**Goal**: Close the `-hard` twins of four agents whose base versions are already protected.
Fixing a base agent and leaving its twin unprotected **is** the recorded recurring twin-file
defect class; all four are done together, in one phase.

**Tasks**:
- [x] `lean/agents/lean-research-hard-agent.md` — wrap the bare fragment at `:348` *(completed)* with
      `"status": "researched"`.
- [x] `cslib/agents/cslib-research-hard-agent.md` — wrap the bare fragment at `:315` *(completed)* with
      `"status": "researched"`.
- [x] `lean/agents/lean-implementation-hard-agent.md` — **two sites**: *(completed)* (a) the
      `.orchestrator-handoff.json` block at `:305`, rewriting the pipe placeholder
      `"implemented | partial | blocked"` to the concrete `"implemented"`, covering
      `partial`/`blocked` in surrounding prose as `handoff-schema.md` itself does; (b) the Stage 8
      `.return-meta.json` block at `:630`, wrapping the bare artifacts fragment with
      `"status": "implemented"`.
- [x] `cslib/agents/cslib-implementation-hard-agent.md` — **two sites**: *(completed)* (a) the
      `.orchestrator-handoff.json` block at `:324`, same pipe-to-concrete rewrite; (b) Stage 7
      (`:387` onward), whose fenced block currently carries only a `verification` object and no
      status or artifacts at all — add a status-carrying `.return-meta.json` example there,
      matching `cslib-implementation-agent.md`'s protected base shape.
- [x] Locate every site **by content** *(completed)* (the enclosing `### Stage N` heading and the target
      filename named just above each fence), never by line symmetry between the two files — the
      two twins' stage numbering already differs (Stage 8 vs Stage 7).
- [x] MUST-NOT bullets are already present in all four *(completed)* (`lean-implementation-hard` via its base
      conventions, `cslib-implementation-hard-agent.md:460`,
      `cslib-research-hard-agent.md:385`) — verify per file, add only where genuinely absent.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: 4 files / 6 edit sites, with the two implementation twins needing two sites
each and the two research twins one each. Confirm at implementation time by grepping each file
for `"status"` and `"artifacts"` occurrences and reading the enclosing heading of every hit before
deciding which block is which — the handoff and return-meta blocks are easy to confuse.

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-research-hard-agent.md`
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`
- `agent-system/extensions/cslib/agents/cslib-research-hard-agent.md`
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`

**Verification**:
- Zero pipe-alternatives placeholders remain in any of the four files' fenced `"status"` values
- Each of the four files carries a concrete inline status in its `.return-meta.json` block; both
  implementation twins additionally carry one in their `.orchestrator-handoff.json` block
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` still passes

---

### Phase 7: Category C — pipe-placeholder rewrites, including grant-agent's bespoke case [COMPLETED]

**Goal**: Replace the two remaining pipe-alternatives placeholders with concrete, copyable values
— without flattening `grant-agent`'s genuinely workflow-conditioned terminal states.

**Tasks**:
- [x] `web/agents/web-implementation-agent.md:396` — rewrite *(completed)*
      `"status": "implemented|partial|failed"` to the concrete `"status": "implemented"`, moving
      `partial`/`failed` into adjacent prose. MUST-NOT bullet already present; do not duplicate.
- [x] `present/agents/grant-agent.md:413` — **do not collapse *(completed)* to a single value.** Its Stage 6
      already documents a `workflow_type -> status` table at `:437-439`
      (`funder_research -> researched`; `proposal_draft`/`budget_develop -> drafted`). Replace the
      single pipe-joined fence with one concrete primary example carrying `"status": "researched"`
      (its canonical branch), plus explicit prose cross-referencing the existing table for the
      `drafted` branches. Do not delete or weaken the table.
- [x] Add a note in `grant-agent.md` near the table recording *(completed)* that `"drafted"` is an agent-local
      value outside the canonical 8-value vocabulary, and that whether it should be promoted (or
      moved to a distinct `workflow_status` sub-field) is an open follow-up question — not
      decided here.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: 2 files, one edit site each, both already carrying a MUST-NOT bullet
(`web`, `grant-agent.md:641`). Confirm before editing; if `grant-agent`'s table at `:437-439` has
moved or changed shape, follow the table as found rather than the line numbers quoted here.

**Files to modify**:
- `agent-system/extensions/web/agents/web-implementation-agent.md` - concrete `implemented`
- `agent-system/extensions/present/agents/grant-agent.md` - concrete `researched` primary example
  + prose cross-reference to the workflow table + recorded open question

**Verification**:
- Neither file contains a pipe character inside a fenced `"status"` value
- `grant-agent.md` still contains its `workflow_type -> status` table intact, and now contains a
  conformant `"status": "researched"` example
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` still passes

---

### Phase 8: Add Check E to lint-agent-contracts.sh, with fixtures [COMPLETED]

**Goal**: The regression guard. Check E fails any non-excluded dispatchable agent whose
terminal-metadata example carries no vocabulary-member status, and fails any
`"status": "completed"` key/value pair anywhere in an agent body.

**Tasks**:
- [x] Source `lib/return-meta-status-vocabulary.sh` (Phase 1) in `lint-agent-contracts.sh` *(completed)* — the
      accepted values are never hardcoded in the lint, mirroring Check C/F's read-from-source
      discipline.
- [x] Add `EXCLUDED_TERMINAL_STATUS_RELATIVE_PATHS`, a second bash array sibling to *(completed)*
      `EXCLUDED_ARTIFACTS_TEMPLATE_RELATIVE_PATHS`, with the same per-entry "confirmed by reading
      each file's full terminal-metadata behavior" comment discipline. Seed it with the
      research-confirmed set: `core/agents/meta-builder-agent.md` (own vocabulary; not a
      `routing_agents` entry anywhere); `filetypes/agents/{filetypes-router-agent,
      filetypes-spreadsheet-agent, presentation-agent, scrape-agent, docx-edit-agent, sheet-agent,
      document-agent}.md`; `present/agents/{pptx-assembly-agent, slidev-assembly-agent}.md`;
      `founder/agents/legal-analysis-agent.md` (no conformant value anywhere in the file); plus
      the two existing Check F exclusions (`code-reviewer-agent.md`, `literature-agent.md`), which
      write no `.return-meta.json` at all. Record in the comment **why** the routing-derived
      alternative was rejected: `routing_agents` membership does not predict canonical-vocabulary
      use.
- [x] Do **not** exclude `founder/agents/project-agent.md` or `present/agents/grant-agent.md`: *(completed)*
      Check E tests for *presence* of a conformant value plus *absence* of a literal
      `"status": "completed"` pair, not that every status literal in the file is canonical. Both
      already carry (or, after Phase 7, will carry) a passing `"researched"` example.
- [x] Implement `check_e_terminal_metadata_presence()` at the existing named insertion point *(completed)*
      (`:409-415`), reusing `enumerate_dispatchable_agents`/`is_dispatchable_agent` rather than
      re-deriving the detector — exactly as that comment instructs. Leave the Check D deferral
      comment in place and intact.
- [x] Detector A (presence): pass a file that contains at least one fenced-block line matching *(completed)*
      `"status"\s*:\s*"<member>"` for some member of `RETURN_META_STATUS_VALUES` **other than**
      `in_progress` — an `in_progress`-only file (the `grant-agent`-before-fix shape) must not
      satisfy the terminal-status requirement.
- [x] Detector B (prohibition): fail on `"status"\s*:\s*"completed"` *(completed)* (tolerating absent/multiple
      spaces). Match the quoted key/value **pair only**, never the bare word `completed` — the
      MUST-NOT bullets in ~30 agent bodies contain that word legitimately.
- [x] Reject the pipe-alternatives shape by construction: *(completed)* `"implemented | partial | blocked"` is
      not a literal member, so Detector A's exact-match fails it. Add a comment saying this is the
      decided treatment (fail, rewrite to concrete), not an accident.
- [x] Wire `check_e_terminal_metadata_presence` into `main()` after `check_f_artifacts_template`, *(completed)*
      and add the `E.` line to the `--help` check list.
- [x] Update `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh`: *(completed)*
      - **Required fixture repair** — add a conforming inline status to the `compliant-agent.md`
        and `check-f-conforming-agent.md` fixtures, or their existing "produces no FAIL line
        against it" assertions (`:289`, `:315`) break the moment Check E lands.
      - Positive fixture: an agent with an artifacts template but no status at all → fails Check E.
      - Positive fixture: an agent carrying `"status": "completed"` → fails Check E by name.
      - Positive fixture: an agent carrying only `"status": "in_progress"` → fails Check E.
      - Positive fixture: an agent carrying a pipe-alternatives value → fails Check E.
      - **Negative fixture**: an agent carrying a conformant status **and** the MUST-NOT bullet
        (whose prose contains the word `completed`) → passes Check E, proving Detector B does not
        false-positive on prose.
      - Negative fixture: a file on the exclusion list → produces a named `[INFO] skipped` line,
        never a FAIL.

**Timing**: 2 hours

**Depends on**: 1, 4, 5, 6, 7

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: the exclusion list is expected to hold 13 entries (11 new + the 2 existing
Check F exclusions). This is a hypothesis, not a fact: confirm it at implementation time by
running the new check over the whole source store **before** finalizing the list, and add an entry
only for a file whose full terminal-metadata behavior was read and found to use a legitimate
extension-local vocabulary. A file that is merely *unfixed* gets fixed, never excluded.
*(deviation: altered — live re-verification found only 5 entries genuinely need exclusion; the 7
`filetypes/*` agents and `founder/agents/legal-analysis-agent.md` all already carry a legitimate
`"failed"`/`"partial"` canonical status for their error path and pass Detector A on their own
merit, so they were correctly left off the list rather than force-excluded to match the
hypothesis)*

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - Check E, exclusion list,
  `main()` wiring, `--help` text
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` - fixture repair +
  6 new fixtures/assertions

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` exits 0 over
  the real source store, with **zero** Check E failures — every one of the 73 dispatchable agents
  either passes or is a named, commented exclusion
- `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` exits 0, with the
  pre-existing assertions still passing unchanged in meaning
- A scratch agent file containing only the MUST-NOT bullet's prose (`Use status value "completed"
  (triggers Claude stop behavior)`) and a conformant status passes Check E — the false-positive
  guard, asserted by fixture, not by eye
- `bash lint-agent-contracts.sh --help` lists Check E

---

### Phase 9: Full gate, and record the deferred follow-ups [COMPLETED]

**Goal**: Whole-suite green, and the two deliberately-deferred decisions recorded where the next
reader will find them rather than left as silent gaps.

**Tasks**:
- [x] Run the full gate: `bash agent-system/extensions/core/scripts/tests/run-all.sh`. *(completed:
      90 passed, 4 failed, 0 skipped, 94 total. The 4 failing suites --
      test-gate-out-repair-reporting.sh, test-lint-json-channel-discipline.sh,
      test-orchestrate-cycle-postflight.sh, test-verify-deploy-context-budget.sh -- are
      confirmed pre-existing/out-of-scope by `git log`: three were last touched by unrelated
      historical tasks (13/142/189/206/235), and the fourth (test-orchestrate-cycle-postflight.sh)
      correlates with sibling task 259's concurrent orchestrate-cycle-postflight.sh edit, not
      any file this plan touches. None reference lint-agent-contracts.sh,
      validate-return-meta.sh, orchestrate-recover-outcome.sh,
      return-meta-status-vocabulary.sh, or any of the 20 agent files this plan edited. This
      task's own 4 suites (test-return-meta-status-vocabulary.sh, test-validate-return-meta.sh,
      test-orchestrate-recover-outcome.sh, test-lint-agent-contracts.sh) all PASS)*
- [x] Run `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` once more over *(completed)*
      the whole source store and confirm the summary shows 0 failures.
- [x] Confirm the new test suite is discovered by `run-all.sh` and reported as `[PASS]`, not *(completed)*
      `[SKIP]` (exec bit intact).
- [x] Extend the Check D/E deferral comment block in `lint-agent-contracts.sh` so it now records: *(completed)*
      Check D still deferred; Check E **implemented** by this task; and the two follow-up
      questions below, each named so a future reader can find them.
- [x] Record the follow-ups in this plan's "Deferred Follow-Up Tasks" section (below) and in the *(completed)*
      implementation summary, so `/todo`'s harvest and any later `/task` creation can pick them up.
- [x] Confirm no file under `.claude/**` was modified: *(completed)* `git status --short` shows changes only
      under `agent-system/` and `specs/`.

**Timing**: 0.75 hours

**Depends on**: 2, 3, 8

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - update the deferral
  comment block only

**Verification**:
- `run-all.sh` exits 0 with zero `[FAIL]` and zero unexpected `[SKIP]` lines
- `lint-agent-contracts.sh` exits 0
- `git status --short` shows no `.claude/**` modifications
- Both follow-up questions appear, by name, in the lint's deferral comment

---

## Deferred Follow-Up Tasks

Recorded decisions, not omissions. Each should become its own task.

1. **Wire a return-meta status validator into the dispatch read path.**
   `validate-return-meta.sh` already rejects `"completed"` with exactly the right message and has
   **zero** runtime callers — it would have caught the observed incident outright and did not run.
   The two live, currently-unguarded chokepoints are `orchestrate-recover-outcome.sh:208` and
   `skill-base.sh`'s `skill_read_metadata()` (the base-mode path, which the task description's
   "at or before the recovery read" phrasing does not cover). **Ordering constraint, and the
   reason this is not in scope here**: wiring the 8-value *rejection* in today would newly break
   `legal-analysis-agent`'s `"consulted"`, `grant-agent`'s `"drafted"`,
   `slidev-assembly-agent`'s `"assembled"` and every `filetypes/*` vocabulary. The follow-up must
   first resolve item 2.

2. **Widen `orchestrate-recover-outcome.sh`'s success acceptance set.** Its 3-value arm
   (`researched|planned|implemented`) is narrower than the set of intentionally-designed success
   vocabularies used by *bona fide* registered phase-routing targets. Any of those agents
   dispatched under `orchestrator_mode: true` has a genuinely successful outcome misclassified as
   `STATUS_NOT_SUCCESS` today — the same defect class as the typst incident, triggered by an
   intentional value instead of an accidental one. Resolve by widening the arm or by formalizing a
   per-extension accepted-status registry. Phase 1's `RETURN_META_SUCCESS_STATUSES` is the seam
   this work would extend.

3. **Decide `"drafted"`'s status** (small, low-urgency): promote it to the canonical vocabulary,
   move workflow-conditioned outcomes to a distinct `workflow_status` sub-field, or leave it
   agent-local as today. Phase 7 leaves it agent-local — the minimal, non-breaking choice.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0 with zero
      failures across all 73 dispatchable agents
- [ ] `bash agent-system/extensions/core/scripts/tests/test-return-meta-status-vocabulary.sh` exits 0
- [ ] `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` exits 0
- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` exits 0
- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-recover-outcome.sh` exits 0
- [ ] All 20 agent files carry a concrete inline terminal status; zero pipe-alternatives values
      remain in any fenced `"status"` value across `agent-system/extensions/*/agents/`
- [ ] Zero `"status": "completed"` key/value pairs anywhere under `agent-system/extensions/*/agents/`
- [ ] No file under `.claude/**` modified

## Artifacts & Outputs

**New files**:
- `agent-system/extensions/core/scripts/lib/return-meta-status-vocabulary.sh`
- `agent-system/extensions/core/scripts/tests/test-return-meta-status-vocabulary.sh`

**Modified — tooling (5)**:
- `agent-system/extensions/core/manifest.json`
- `agent-system/extensions/core/scripts/validate-return-meta.sh`
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh`
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh`

**Modified — agent contracts (20 files / 22 edit sites)**:
- `agent-system/extensions/core/agents/planner-agent.md`
- `agent-system/extensions/core/agents/general-research-agent.md`
- `agent-system/extensions/core/agents/spawn-agent.md`
- `agent-system/extensions/email/agents/email-implementation-agent.md`
- `agent-system/extensions/lean/agents/lean-research-hard-agent.md`
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` (2 sites)
- `agent-system/extensions/cslib/agents/cslib-research-hard-agent.md`
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` (2 sites)
- `agent-system/extensions/latex/agents/latex-research-agent.md`
- `agent-system/extensions/latex/agents/latex-implementation-agent.md`
- `agent-system/extensions/python/agents/python-research-agent.md`
- `agent-system/extensions/python/agents/python-implementation-agent.md`
- `agent-system/extensions/rust/agents/rust-research-agent.md`
- `agent-system/extensions/rust/agents/rust-implementation-agent.md`
- `agent-system/extensions/typst/agents/typst-research-agent.md`
- `agent-system/extensions/typst/agents/typst-implementation-agent.md`
- `agent-system/extensions/z3/agents/z3-research-agent.md`
- `agent-system/extensions/z3/agents/z3-implementation-agent.md`
- `agent-system/extensions/web/agents/web-implementation-agent.md`
- `agent-system/extensions/present/agents/grant-agent.md`

**Also produced**: `specs/257_inline_terminal_status_in_agent_contracts/summaries/01_*-summary.md`
at implementation completion.

## Rollback/Contingency

Every phase is independently revertible and commits separately (Phase 8 as one pre-declared
atomic batch), so rollback is per-phase `git revert` of that phase's commit — no snapshot
needed for the ordinary case.

- **Phases 4-7** (prose only) are the safest to revert; reverting any one leaves the others and
  the tooling intact, at the cost of Check E failing that file — so if one of these is reverted,
  Phase 8's exclusion list is **not** the remedy; re-apply the fix instead.
- **Phase 3** is the highest-risk change (hot dispatch path). If
  `test-orchestrate-recover-outcome.sh` fails and the cause is not immediately obvious, revert
  Phase 3 alone: it is a pure refactor with no dependents, and dropping it costs only the
  single-definition property for that one consumer, leaving Phases 1, 2 and 8 fully valid.
- **Phase 8** reverts as a unit (lint + fixtures together); reverting it restores a clean lint
  while leaving all content fixes in place.
- If a genuine whole-tree rollback is ever needed, take a snapshot first per
  `context/contracts/recovery.md`'s rollback rung, including its out-of-scope override flag. Never
  emit `git-snapshot.sh` in its default reverting mode as a routine checkpoint; an ordinary
  defensive checkpoint before risky work uses `--no-revert`.
- **Concurrency**: sibling task 259 is dispatched this same cycle on this same working tree. Stage
  only this task's own files, by explicit file list — never `git add -A`, a directory pathspec, or
  a glob. If a foreign commit or foreign uncommitted modification appears, stop and report it
  after checking `git log`, rather than proceeding.
