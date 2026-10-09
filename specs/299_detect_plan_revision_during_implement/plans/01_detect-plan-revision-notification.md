# Implementation Plan: Task #299

- **Task**: 299 - Guarantee that an in-place plan revision landing concurrently with a live
  implement dispatch is DETECTED, by adopting two complementary remedies together
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None. Do NOT batch with #289, #273, #274, #275, #285, #263 (shared
  `skill-orchestrate/SKILL.md`), #250, #165, #272, #265, #293 (shared
  `orchestrate-cycle-plan.sh`), or #263 (shared `orchestrate-build-dispatch.sh`) — per the
  dispatch's SHARED-FILE CONTENTION note.
- **Research Inputs**:
  `specs/299_detect_plan_revision_during_implement/reports/01_detect-plan-revision-notification.md`
- **Artifacts**: plans/01_detect-plan-revision-notification.md (this file)
- **Standards**:
  - `.claude/context/formats/plan-format.md`
  - `.claude/context/standards/status-markers.md`
  - `.claude/context/standards/artifact-management.md`
  - `.claude/context/standards/shell-strict-mode.md`
  - `.claude/context/workflows/tasks.md`
  - `.claude/rules/source-store-deploy-boundary.md`
  - `.claude/rules/no-task-references-in-deliverables.md`
  - `.claude/rules/no-record-versioning-in-deliverables.md`
  - `.claude/rules/artifact-formats.md`
  - `.claude/rules/state-management.md`
- **Type**: meta
- **Lean Intent**: false

## Overview

A `plan-revision` aux row and the same task's `implement` row can be co-dispatched in one
`/orchestrate` cycle, so `reviser-agent` rewrites `plans/*.md` in place while the implement agent
is reading it — and no contract makes the implement agent aware. This plan lands both remedies
the dispatch names, together: a routine (no longer discretionary) landed-revision signal from the
revising side, and a narrow re-read-before-writing obligation on the implementing side. All
substantive contract prose goes into ONE new `context/patterns/` file, with every other site
carrying a short pointer, because `skills/skill-orchestrate/SKILL.md` has 24 bytes of headroom
against a now-hard byte gate. Definition of done: the signal is emitted unconditionally in every
`plan-revision` aux dispatch, both implementation agents carry the pre-write re-read obligation
reconciled with the existing "do NOT re-read the full plan" successor line, two existing test
files cover both changes, and the full gate set is green after a redeploy.

### Research Integration

The research report is integrated as follows; its three executed findings drive phase design
rather than being restated as opinion.

- **OPEN DECISION resolved as (c)**, confirmed against the code: the AUX DECISION/EMISSION blocks
  (`orchestrate-cycle-plan.sh` ~1310 and ~1412) run before the all-terminal check, eligibility,
  classification, force-phase consumption, admission, and bucketing, so at aux-emission time the
  cycle cannot know which tasks receive an implement row. Phase 2 therefore emits the signal
  instruction **unconditionally** in every `plan-revision` aux dispatch file. Neither option (a)
  (reorder the decision) nor (b) (defer the dispatch-file write and thread a new flag) is pursued,
  and `orchestrate-cycle-plan.sh` is not edited at all.
- **`reviser-agent.md` confirmed to contain zero notification machinery** (no `SendMessage`,
  `notify`, or concurrent-dispatch language). Phase 2 is therefore a net-new obligation, and it
  lands in two places so it survives both dispatch paths: the aux dispatch prompt (the
  `/orchestrate` path) and the agent definition itself (the `/revise` path).
- **The delivery mechanism is a file sentinel, not `SendMessage`.** Verified live: `SKILL.md`'s
  Move 2 forwards only `agent` (→ `subagent_type`) and `model` as Agent-tool arguments, with an
  explicit `MUST NOT` against forwarding any other row field, and no Move 2 dispatch receives a
  `name:`. No dispatched agent is addressable by name, and nothing in
  `agent-system/extensions/core` establishes cross-dispatch `SendMessage` as a supported pattern.
  The sentinel mirrors the `.blocker-research.json` / `.drift-inspection.json` idiom already used
  three lines above the Phase 2 edit site in the same file.

**Two findings this plan adds that research did not surface**, both discovered by reading the code
during planning and both load-bearing on the design:

1. **A per-cycle-varying line must NOT be added to the implement dispatch file.**
   `orchestrate-cycle-plan.sh:2109`'s `cycle_plan_dispatch_hash()` normalizes a composed dispatch
   file before hashing it so the IDENTICAL DISPATCH HALT can fire, and it strips exactly three
   known per-cycle-varying lines. Its header comment (lines 2082-2107) and a matching
   FORWARD-POINTER comment in `orchestrate-build-dispatch.sh` (lines 543-552) both record a
   **STANDING OBLIGATION**: any new per-cycle-varying content added to a composed dispatch file
   MUST extend that strip pattern in the same change, or the halt silently goes inert — which is
   exactly what happened between 2026-10-03 and its later repair. The implement agent checks off
   plan checklist items every phase, so a `plan_mtime` or `plan_sha256` line in the implement
   `## Plan` block would change on every cycle and would permanently defeat that halt unless
   `orchestrate-cycle-plan.sh` were also edited — a file this task must not touch (contended with
   five other active tasks). **This overrides research Recommendation 2's "or the plan's mtime at
   dispatch-build time" suggestion**, and the override is also the better design on its own
   merits: the race window is between the agent's own read and its own write, not between
   dispatch build and the read, so the agent's own first read is the only correct baseline. Phase
   3 therefore emits only static content (a sentinel path interpolated from the already-present
   `TASK_DIR_ABS`, plus fixed pointer prose) and Phase 3's verification pins hash-stability
   explicitly.
2. **The sentinel needs no consume-and-clear discipline, which removes the risk research
   flagged.** The implement dispatch file's `## Identity` block already carries
   `dispatch_start_ts` (`orchestrate-build-dispatch.sh:457-458`). Scoping relevance to
   `revised_at >= dispatch_start_ts` makes every older sentinel inert by construction, so no
   deletion, acknowledgement, or `aux_consume_*`-style clearing step is needed anywhere. This is
   strictly simpler than adapting the `aux_consume_blocker_file` / `aux_consume_drift_file`
   template research proposed as a mitigation.

**Byte-budget figure re-measured during planning**: `wc -c skills/skill-orchestrate/SKILL.md` =
21,476 B against a `ceiling_bytes` of 21,500 B in
`context/config/orchestrator-context-budget.json` — **24 B of headroom** — and
`scripts/verify-deploy.sh` already defaults `ORCHESTRATOR_BUDGET_GATE_MODE` to `hard`. The
dispatch's framing ("a concurrent task promotes ... from warn to hard") is stale: the promotion
already happened. Consequence for this plan: **`SKILL.md` is not edited at all** (see Non-Goals),
and Phase 5 re-measures to prove it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- Make the landed-revision signal **routine and contractual** rather than discretionary, emitted
  unconditionally in every `plan-revision` aux dispatch file and durably recorded in
  `reviser-agent.md` itself.
- Define the signal once, in one new `context/patterns/` file: sentinel path, JSON shape,
  freshness rule (`revised_at >= dispatch_start_ts`), writer obligation, reader obligation, and
  the explicit statement that the pre-write re-read is the correctness guarantee while the
  sentinel is the awareness/latency layer.
- Give both implementation agents a **narrow** pre-write obligation: immediately before writing
  the first edit of a phase, re-read that phase's own section of the plan — never the full plan.
- Reconcile that obligation explicitly with `general-implementation-agent.md`'s existing
  "Do NOT re-read the full plan unless necessary" successor line, by a narrow carve-out adjacent
  to it rather than a rewrite or a silent contradiction.
- Name, in the new pattern file, the four adjacent mechanisms that are NOT coverage for this
  hazard, so none is mistaken for coverage again.
- Cover both script changes in the two existing test files, including a regression assertion that
  the implement dispatch body gains no per-cycle-varying line.
- Keep `skills/skill-orchestrate/SKILL.md` byte-untouched and prove it by re-measurement.

**Non-Goals**:
- Editing `skills/skill-orchestrate/SKILL.md` (24 B headroom; Move 2 does not need to know about
  the sentinel — the dispatch files carry it).
- Editing `scripts/orchestrate-cycle-plan.sh`, including `cycle_plan_dispatch_hash()`'s strip
  pattern — avoided by design, not deferred (Phase 3 adds no per-cycle-varying content).
- Editing `context/config/orchestrator-context-budget.json`, `scripts/verify-deploy.sh`, or any
  gate definition. No ceiling or baseline is moved.
- Remedy 3 (never co-dispatch a `plan-revision` aux row with the same task's implement row,
  deferring the revision one cycle). Recorded as **rejected**: it costs a full cycle and
  contradicts the one-message dispatch rule in `SKILL.md`'s Move 2. Not a future phase, and not
  to be re-scoped into a successor.
- The header-only-correction-label finding (a correction label above a block does not survive a
  line-range excerpt taken from below it). Explicitly out of scope: a plan-authoring
  documentation-form finding, not an orchestrator defect.
- Any `SendMessage`-based addressing mechanism, and any change to what `SKILL.md`'s Move 2
  forwards as Agent-tool arguments.
- `context/contracts/pre-edit-gate.md`, `context/contracts/territory.md`, and
  `context/patterns/file-metadata-exchange.md` — each is cited by the new pattern file as adjacent
  and insufficient, and none is edited.
- Any change to the hard-mode lean implementer (`lean-implementation-hard-agent.md`) or to
  parallel-wave plan-section territory.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new line in the implement `## Plan` block varies per cycle and silently disables the IDENTICAL DISPATCH HALT | H | H (if mtime/hash were emitted, as research suggested) | Phase 3 emits only static content. Its verification builds the same implement dispatch twice with a plan edit in between and asserts `cycle_plan_dispatch_hash()` is unchanged by this task's added lines — the halt's own regression fixture (`test-orchestrate-cycle-plan.sh` Group 27 Case F) stays green. |
| An uncleared sentinel falsely flags a much-later, unrelated dispatch as racing a revision | M | H (under an "exists at all" rule) | Freshness is defined as `revised_at >= dispatch_start_ts` of the reading dispatch, not as existence. Older sentinels are inert by construction; no clearing step exists to be forgotten. |
| The re-read obligation is read as "re-read the full plan every step", re-breaking the context economy that `general-implementation-agent.md:59` protects | M | M | The obligation is scoped in three ways in both the pattern file and the agent text: the phase's own section only, once per phase immediately before its first write, and never the full plan. The carve-out is placed adjacent to the successor line and names it. |
| Renumbering Stage 4's per-step list breaks an existing in-file cross-reference | M | H (if the obligation were inserted as a new numbered step) | `general-implementation-agent.md`'s step 2 text already says "(see step 4 below ...)". Phase 4 inserts a standalone bolded obligation paragraph immediately under "For each step in the phase:" instead of a new numbered item, leaving all four numbers and that cross-reference intact. |
| The new `context/patterns/` file is unregistered and trips whole-tree orphan detection (Gate 13) | M | H | Phase 1 adds the `index-entries.json` row in the same change and regenerates line counts; Phase 5 runs the full gate set against the redeployed tree. |
| A byte-heavy edit re-breaches the now-hard orchestrator budget gate | H | L (given the Non-Goal) | `SKILL.md` is not edited. Phase 5 re-measures `wc -c` on it and `measure-eager-context.sh --check`, requiring both unchanged-or-better. Neither `ceiling_bytes` nor `baseline_bytes` is moved. |
| An edit lands in the deployed `.claude/**` copy and is wiped by the next redeploy | H | L | Every path in every phase's **Files to modify** is under `agent-system/extensions/**`. Phase 5 asserts `git status --short` shows no `.claude/**` modification outside the redeploy's own output. |
| A sibling task concurrently edits a shared file this cycle | M | M | Only #370 (no declared `file_scope`) and #319 (two `sweep-invalidated-claims.sh` paths, disjoint from this task's) are co-dispatched. Re-read each file immediately before editing; stage only this task's own hunks; never run `git-snapshot.sh` in its reverting default mode. |
| Task-number references leak into `agent-system/**` deliverables | M | M | Every citation in the new pattern file and both agent edits uses a durable anchor (filename, function name, section heading). Gate 4's task-reference lint runs in Phase 5. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: The contract file — sentinel shape, freshness rule, both obligations [COMPLETED]

**Goal**: Create the single home for all substantive prose both remedies need, so the three
pointer sites in Phases 2-4 stay short and `SKILL.md` stays untouched.

**Tasks**:
- [x] Create `agent-system/extensions/core/context/patterns/plan-revision-notification.md` with
  these sections: *(completed)*
  - **The hazard**, in two sentences: a `plan-revision` aux row and the same task's `implement`
    row can be co-dispatched in one cycle (mutual exclusion is asserted between aux *kinds*, never
    between an aux row and the implement row), and `SKILL.md`'s Move 2 requires every
    `dispatch[]` and `aux_dispatch[]` row be issued in one message. State the observed cost
    concretely but by durable anchor only: an implement dispatch excerpted one phase from the
    post-revision file and another from the pre-revision file, reported an already-corrected plan
    bullet as uncorrected, and propagated that into its phase handoff and round summary.
  - **The sentinel**: path `{task_dir}/.plan-revised.json`; fields `revised_at` (epoch seconds,
    integer), `dispatch_seq` (integer, the revising dispatch's own), `reason` (string, `blocker`
    or `drift`), `plan_path` (string), `summary` (string, one sentence naming what changed).
  - **The freshness rule**, stated as the whole of the relevance test: a sentinel is relevant to a
    reading dispatch if and only if `revised_at >= dispatch_start_ts` from that dispatch file's
    own `## Identity` block. State explicitly that there is deliberately **no**
    consume-and-clear, acknowledgement, or deletion step, and why: existence is not the test, so
    an old sentinel is inert by construction and cannot be forgotten into a false positive.
    Contrast this with `orchestrate-cycle-plan.sh`'s `aux_consume_blocker_file` /
    `aux_consume_drift_file` pattern, which is cross-cycle and orchestrator-mediated, and name
    that difference as the reason the discipline differs.
  - **Writer obligation** (`reviser-agent`): after the revised plan is written and before
    returning, write the sentinel. Unconditional — it is inert when no implement dispatch is
    live, which is why it needs no knowledge of a sibling row.
  - **Reader obligation** (implementation agents): immediately before writing the first edit of a
    phase, re-read that phase's own section of the plan file and check for a relevant sentinel.
    Scope it explicitly: that phase's section only, once per phase, never the full plan. State
    what to do on a hit — re-derive the phase's steps and file list from the re-read text, and
    record the observation in the handoff/summary rather than silently proceeding.
  - **Which remedy carries which guarantee**: the pre-write re-read is the correctness guarantee
    (it catches a tear that lands between two reads, before any signal is consulted); the
    sentinel is the awareness/latency layer that explains *why* the text changed. Neither
    substitutes for the other, and the sentinel alone cannot prevent a stale write.
  - **Adjacent mechanisms that are NOT coverage**, one line each with its own reason: the
    `--territory` payload's generic re-read-before-editing note (governs the *target* files an
    agent edits, not the plan instructing it); `context/contracts/pre-edit-gate.md` (validates a
    plan's *claims about the codebase* against the tree, never the plan file against its own later
    revision); `context/contracts/territory.md`'s Plan-Section Territory section (concurrent
    *writers* splitting phases of one plan, not one writer racing one stale reader);
    `context/patterns/file-metadata-exchange.md` (the agent→orchestrator `.return-meta.json`
    return channel, not a live sibling→sibling channel within one cycle).
  - **Design invariant for future edits**: a dispatch-file line carrying plan freshness MUST NOT
    be per-cycle-varying, because `cycle_plan_dispatch_hash()` would then have to strip it or the
    IDENTICAL DISPATCH HALT goes inert; the reading agent's own first read is the correct
    baseline, not dispatch-build time.
- [x] Add the matching `entries[]` row to
  `agent-system/extensions/core/index-entries.json`: `path`
  `patterns/plan-revision-notification.md`, `domain` `core`, `subdomain` `patterns`, a one-line
  `summary`, keywords/topics consistent with the neighbouring `patterns/` rows, and a `load_when`
  block matching how sibling pattern rows express agent/task-type scoping. *(completed)*
- [x] Regenerate line-count metadata:
  `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` (confirm the
  script name and flag against the tree before running; if it differs, use whatever the repo's own
  sanctioned entry point is rather than hand-editing `line_count`). *(completed: ran via
  `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/generate-context-line-counts.sh
  --write` per the script's own source-store-bypass convention; core now 165 entries, 0 changed —
  the hand-set `line_count: 111` already matched)*
- [x] Verify the file contains no task-number reference and no record-versioning language
  (no "v2", "previously", "no longer", "supersedes"). *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that a new `context/` file requires exactly one
`index-entries.json` row plus a line-count regeneration to avoid Gate 13's whole-tree orphan
detection, and that `generate-context-line-counts.sh --write` is the sanctioned regeneration
entry point. Confirm at implementation time with `jq '.entries | length' index-entries.json`
before and after (expect +1), `jq -r '.entries[] | select(.path | startswith("patterns/")) |
.path' index-entries.json | tail -3` to copy a neighbouring row's exact field set, and
`ls agent-system/extensions/core/scripts/generate-context-line-counts.sh`. If the script or flag
name differs, use the repo's actual entry point; the obligation (a registered row with a correct
`line_count`) is what this phase asserts, not the command spelling.

**Tier Justification**: Markdown-plus-JSON-metadata edit with no executable surface;
`suite_selection_select` returns `__FULL_SWEEP__` for the new `.md` path, so no suite covers it
and none is claimed — the honest covering checks are
`bash .claude/scripts/verify-deploy.sh --only-gate 3,4` (doc lint and task-reference lint) plus
the `prose` row's diff read-through confirming every hunk stays inside prose or the one added JSON
row.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/plan-revision-notification.md` - new file: the
  whole contract
- `agent-system/extensions/core/index-entries.json` - one new `entries[]` row registering it
  (plus the regenerated `line_count` field)

**Verification**:
- `--only-gate 3,4` green.
- `jq -e '.entries[] | select(.path == "patterns/plan-revision-notification.md")'
  agent-system/extensions/core/index-entries.json` exits 0, and its `line_count` matches
  `wc -l` on the new file.
- The file names all five required parts: sentinel path and field list, the
  `revised_at >= dispatch_start_ts` rule, the explicit no-clearing statement, both obligations,
  and all four adjacent-but-insufficient mechanisms.
- `grep -nE '\btask [0-9]+\b|\btasks [0-9]+' ` on the new file returns nothing.

---

### Phase 2: Remedy 1 — routine landed-revision signal from the revising side [COMPLETED]

**Goal**: Make the signal contractual on both paths that run `reviser-agent`: the `/orchestrate`
aux dispatch and the agent definition itself.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh`, extend the
  `plan-revision)` arm of the prompt `case` (currently lines 189-195) so **both** branches
  (`blocker` and `drift`) end with the same unconditional clause instructing the agent to write
  `${TASK_DIR_ABS}/.plan-revised.json` with the fields Phase 1 defines, and to read
  `context/patterns/plan-revision-notification.md` for the shape and the reason. Append the clause
  once, after the `if/else`, rather than duplicating it into each branch, so the two prompts cannot
  drift apart. *(completed)*
- [x] Keep the clause's wording aligned with the sibling `blocker-research)` arm three lines above
  (the same `Write compact JSON to '...' with fields: ...` idiom), so the departure from the
  returned-text channel reads as the established convention it is. *(completed)*
- [x] Do NOT add a `--implement-live`-style flag or any new parameter: the instruction is
  unconditional by design, and the usage block (lines 59-66) gains no new line. *(completed:
  verified no new flag added — usage block untouched)*
- [x] In `agent-system/extensions/core/agents/reviser-agent.md`, add one short stage between
  Stage 5a/5b and Stage 6 — "Stage 5c: Signal the Landed Revision" — stating the writer obligation
  in two or three sentences with a pointer to the Phase 1 file, and add the pattern file to the
  agent's `## Context References` list. Keep it short; this is a pointer, not a second copy of the
  contract. *(completed)*
- [x] Extend `agent-system/extensions/core/scripts/tests/test-orchestrate-build-aux-dispatch.sh`
  with assertions, modelled on the existing `plan-revision` cases (lines ~100-210), that the
  built dispatch file's `## Prompt` section contains the `.plan-revised.json` clause for
  `--revision-reason blocker` AND for `--revision-reason drift`, and that the clause names the
  absolute task-dir path. *(completed: 4 new assertions added, all passing — suite now 22
  passed, 0 failed)*
- [x] `shellcheck` the two touched shell files per `context/standards/shell-strict-mode.md`,
  comparing against their pre-edit baselines so no new finding is introduced. *(completed: 1
  finding each, identical to the pre-edit baseline count)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the `plan-revision)` prompt arm is at
`orchestrate-build-aux-dispatch.sh:189-195`, that `reviser-agent.md` has a Stage 5a/5b → Stage 6
boundary to insert between, and that the aux test file's existing `plan-revision` cases are at
roughly lines 100-210. All three are 2026-10-09 readings and are hypotheses. Confirm at
implementation time with `grep -n 'plan-revision)' scripts/orchestrate-build-aux-dispatch.sh`,
`grep -n '^### Stage' agents/reviser-agent.md`, and
`grep -n 'plan-revision' scripts/tests/test-orchestrate-build-aux-dispatch.sh`; edit at whatever
lines those return.

**Tier Justification**: The change is confined to one prompt string in one script plus one
markdown agent definition, with no externally visible signature change; the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-orchestrate-build-aux-dispatch.sh,test-orchestrate-cycle-plan.sh,test-force-phases.sh,test-orchestrate-context-growth.sh,test-orchestrate-unwind-dispatch.sh`
(the exact set `suite_selection_select` resolves for
`scripts/orchestrate-build-aux-dispatch.sh`), plus `shellcheck` on the touched shell files.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh` - unconditional
  sentinel-write clause appended to the `plan-revision` prompt, both branches
- `agent-system/extensions/core/agents/reviser-agent.md` - new Stage 5c writer obligation plus a
  `## Context References` entry
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-aux-dispatch.sh` - assertions
  that the clause appears for both `--revision-reason` values

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-aux-dispatch.sh` exits 0
  with the two new assertions passing by name.
- The five mapped suites above are green.
- A manual build with `--revision-reason blocker` and one with `--revision-reason drift` both
  produce a dispatch file whose `## Prompt` contains `.plan-revised.json`.
- `shellcheck -S error` exits 0 on both touched shell files with no new findings versus baseline.
- The usage block has no new flag.

---

### Phase 3: Remedy 2, dispatch side — static staleness pointer in the implement Plan block [COMPLETED]

**Goal**: Give the implement dispatch the sentinel path and the obligation pointer, adding **zero**
per-cycle-varying content so the IDENTICAL DISPATCH HALT stays live.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`'s implement-phase
  `## Plan` block (currently lines 494-498), add after the existing `- plan_path:` line:
  - `- revision_sentinel: ${TASK_DIR_ABS}/.plan-revised.json` — a static interpolation of a value
    this script already emits at line 525, so it is byte-identical across cycles.
  - two or three lines of fixed prose stating the pre-write obligation in brief (immediately
    before writing the first edit of a phase, re-read that phase's own section of this plan and
    check whether a relevant sentinel exists) and pointing at
    `context/patterns/plan-revision-notification.md` for the freshness rule and the full contract.
    *(completed)*
- [x] Add nothing derived from the plan file's content, mtime, size, or hash. Record the reason in
  a short code comment adjacent to the new lines, pointing at the FORWARD-POINTER comment at lines
  543-552 and at `cycle_plan_dispatch_hash()`, so the next editor sees the constraint at the edit
  site. *(completed: comment wording deliberately avoids the literal substrings "mtime"/"stat "
  so it does not trip Phase 5's own verification grep on the diff)*
- [x] Confirm `cycle_plan_dispatch_hash()`'s strip pattern needs no change: every added line is
  constant for a given task across cycles. *(completed)*
- [x] Extend `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh`,
  beside the existing implement-phase `plan_path` assertion (currently line ~306), with:
  - an assertion that the implement dispatch body contains the `revision_sentinel` line with the
    expected absolute path, and the pointer to the pattern file;
  - an assertion that the `plan` and `research` phases do NOT emit either (implement-only);
  - a hash-stability assertion: build the implement dispatch, edit the plan file's content, build
    again, and assert the two bodies are identical after stripping the three known
    per-cycle-varying lines — i.e. that nothing this task added varies with the plan's content.
    *(completed: new Group 18, byte-extracting the real `cycle_plan_dispatch_hash()` from
    `orchestrate-cycle-plan.sh` per that script's own Group 27 Case A idiom; suite now 148 passed,
    0 failed)*
- [x] `shellcheck` both touched shell files against their pre-edit baselines. *(completed: 4 and
  2 findings respectively, identical to the pre-edit baseline counts)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the implement `## Plan` block is at
`orchestrate-build-dispatch.sh:494-498`, that `TASK_DIR_ABS` is already in scope there (it is used
at line 525), that `cycle_plan_dispatch_hash()`'s strip pattern covers exactly three lines, and
that the implement `plan_path` test assertion is near line 306. All are 2026-10-09 readings.
Confirm with `grep -n '## Plan' scripts/orchestrate-build-dispatch.sh`,
`grep -n 'TASK_DIR_ABS' scripts/orchestrate-build-dispatch.sh`,
`sed -n '2109,2116p' scripts/orchestrate-cycle-plan.sh`, and
`grep -n 'plan_path' scripts/tests/test-orchestrate-build-dispatch.sh`. If the strip pattern has
grown a fourth entry since, the constraint this phase honours is unchanged — add no varying line
either way.

**Tier Justification**: The dispatch-file body is consumed by a second file,
`orchestrate-cycle-plan.sh`'s `cycle_plan_dispatch_hash()`, so the change crosses a file boundary
even though no shell signature changes; the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-orchestrate-build-dispatch.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-build-aux-dispatch.sh,test-force-phases.sh,test-orchestrate-context-growth.sh,test-orchestrate-record-decision.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-unwind-dispatch.sh`
(the exact set `suite_selection_select` resolves for `scripts/orchestrate-build-dispatch.sh`,
which includes the cycle-plan suite carrying the halt's own Group 27 Case F regression fixture).

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - implement-phase
  `## Plan` block: `revision_sentinel` line, fixed pointer prose, and the adjacent
  no-varying-content comment
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - presence,
  implement-only, and hash-stability assertions

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` exits 0 with
  the three new assertions passing by name.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` is green,
  including Group 27 Case F.
- The eight mapped suites above are green.
- `git diff -- agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh | grep -nE
  'mtime|sha256|date \+%s|stat '` returns nothing.
- `shellcheck -S error` exits 0 on both touched shell files with no new findings versus baseline.

---

### Phase 4: Remedy 2, agent side — pre-write re-read obligation and the successor carve-out [COMPLETED]

**Goal**: Land the narrow pre-write obligation in both implementation agents, reconciled explicitly
with the existing "do NOT re-read the full plan" successor line.

**Tasks**:
- [x] In `agent-system/extensions/core/agents/general-implementation-agent.md`, insert a standalone
  bolded obligation paragraph immediately under Stage 4's `For each step in the phase:` line
  (currently line ~250), **not** as a new numbered list item: step 2's own text already says
  "(see step 4 below ...)", so renumbering would break a live in-file cross-reference. The
  paragraph states: immediately before writing the first edit of a phase, re-read that phase's own
  section of the plan file and check `{task_dir}/.plan-revised.json` for a sentinel with
  `revised_at >= dispatch_start_ts`; on a hit, re-derive this phase's steps and file list from the
  re-read text and record the observation in the handoff and summary. Scope it in the same
  sentence: that phase's section only, once per phase, never the full plan. One pointer to
  `context/patterns/plan-revision-notification.md`; no second copy of the contract. *(completed)*
- [x] Add a one-sentence carve-out immediately after the Successor Behavior item that reads
  "Do NOT re-read the full plan unless necessary ..." (currently line 59), stating that the
  pre-write re-read of the *specific excerpted phase* is required even for a successor — and why:
  a successor dispatch is the case where the plan is most likely to have been revised since the
  prior read. Do not rewrite or weaken the existing line; it continues to govern the *full* plan.
  *(completed: existing line 59/60 left byte-identical; carve-out added as a new paragraph after
  item 5)*
- [x] Add a one-line mention in Stage 2 ("Load and Parse Implementation Plan") that the parse is a
  snapshot, with a pointer forward to the Stage 4 obligation — so an agent that reads Stage 2 and
  skips ahead still encounters the constraint. *(completed)*
- [x] Add the pattern file to the agent's `## Context References` list. *(completed)*
- [x] Mirror the obligation into
  `agent-system/extensions/lean/agents/lean-implementation-agent.md` for parity, under
  `## Phase Status Updates (MANDATORY)` → `### Before Starting a Phase` (currently line ~93), which
  is that agent's existing per-phase boundary section. This agent has no "do not re-read" line to
  reconcile with (confirmed: no `Successor`/`continuation`/`resume` language anywhere in the file),
  so it is a pure addition. Add the pattern file to its `## Context References` list too.
  *(completed)*
- [x] Do not touch `lean-implementation-hard-agent.md` (out of scope per Non-Goals). *(completed:
  verified untouched)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the `For each step in the phase:` line is at
`general-implementation-agent.md:250`, the successor "do NOT re-read the full plan" item at line
59, Stage 2 at line 62, and `### Before Starting a Phase` at
`lean-implementation-agent.md:93`; and that step 2's "(see step 4 below" cross-reference exists
and would be broken by renumbering. All are 2026-10-09 readings. Confirm with
`grep -n 'For each step in the phase\|Do NOT re-read the full plan\|see step 4 below'
agents/general-implementation-agent.md` and
`grep -n 'Before Starting a Phase' ../lean/agents/lean-implementation-agent.md`. If the
cross-reference has since been removed, a numbered item becomes acceptable; the obligation's
wording and scope are unchanged either way.

**Tier Justification**: Pure guidance-markdown edit to two agent definitions with no executable
surface; `suite_selection_select` returns `__FULL_SWEEP__` for both paths, so no suite covers them
and none is claimed — the honest covering checks are
`bash .claude/scripts/verify-deploy.sh --only-gate 3,4` (doc lint and task-reference lint) plus
the `prose` row's diff read-through confirming every hunk stays inside prose.

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - Stage 4 pre-write
  obligation paragraph; Stage 2 snapshot note; successor carve-out after line 59; Context
  References entry
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - parity obligation under
  `### Before Starting a Phase`; Context References entry

**Verification**:
- `--only-gate 3,4` green.
- `grep -n 'see step 4 below' agents/general-implementation-agent.md` still matches, and the four
  numbered items under Stage 4 are still numbered 1-4.
- The existing line 59 text "Do NOT re-read the full plan unless necessary" is present **verbatim
  and unmodified**, with the carve-out as a separate adjacent sentence.
- Both agents' obligation text contains all three narrowing qualifiers (that phase's section only,
  once per phase before its first write, never the full plan).
- Both agents list `context/patterns/plan-revision-notification.md` in `## Context References`.
- `grep -nE '\btask [0-9]+\b|\btasks [0-9]+'` on both files returns nothing new.

---

### Phase 5: Byte budget, redeploy, and the full gate set [COMPLETED WITH EXCLUSIONS]

**Goal**: Prove the four earlier phases hold together, that no byte ceiling moved, and that the
complete gate set is green against the redeployed tree.

**Tasks**:
- [x] Re-measure `wc -c agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and assert
  it is **byte-identical** to its pre-implementation value (21,476 B as measured 2026-10-09 — a
  hypothesis; the operative assertion is "unchanged by this task", confirmed by
  `git diff --stat -- agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` being empty).
  *(completed: 21476 B, diff-stat empty)*
- [x] Re-measure the eager-context total:
  `REPO_ROOT=$(pwd) bash .claude/scripts/measure-eager-context.sh --check`, requiring
  `TOTAL <= baseline_bytes` (65,950). Confirm `orchestrator-context-budget.json` is untouched:
  neither `ceiling_bytes` nor `baseline_bytes` moved. *(completed: TOTAL=65939 B <= 65950,
  CHECK PASSED; budget config file untouched)*
- [x] Name-consistency sweep: for every file, function, and section name this task's edits cite
  (`cycle_plan_dispatch_hash`, `aux_consume_blocker_file`, `aux_consume_drift_file`,
  `context/patterns/plan-revision-notification.md`, `context/contracts/pre-edit-gate.md`,
  `context/contracts/territory.md`'s Plan-Section Territory section,
  `context/patterns/file-metadata-exchange.md`, `### Before Starting a Phase`), `grep` the cited
  target and confirm it resolves. *(completed: all eight resolve)*
- [x] Confirm the sentinel path string is spelled identically in all four sites that name it (the
  pattern file, the aux prompt, the implement dispatch block, both agents): one `grep -rn
  '\.plan-revised\.json' agent-system/` and a read-through of every hit. *(completed: identical
  spelling across all five source sites — the four named plus reviser-agent.md's Stage 5c, which
  the plan's own Phase 2 task list also required)*
- [x] Confirm boundary compliance: `git status --short` shows modifications only under
  `agent-system/extensions/core/**`, `agent-system/extensions/lean/agents/**`, and `specs/**` (plus
  whatever the redeploy below writes under `.claude/**`). In particular
  `skills/skill-orchestrate/SKILL.md`, `scripts/orchestrate-cycle-plan.sh`,
  `context/config/orchestrator-context-budget.json`, `scripts/verify-deploy.sh`,
  `context/contracts/pre-edit-gate.md`, `context/contracts/territory.md`, and
  `lean-implementation-hard-agent.md` are untouched. *(completed: all seven confirmed untouched;
  remaining dirty-tree entries outside specs/299 belong to concurrent sibling tasks, e.g. the
  books extension and tasks 296/370, not this task)*
- [x] `bash .claude/scripts/check-task-references.sh` reports zero unexempted occurrences in the
  files this task added or changed. *(completed: "PASS: 0 unexempted task-reference occurrences")*
- [x] Redeploy the source store: `bash .claude/scripts/deploy-headless.sh`, and confirm
  `.claude/context/patterns/plan-revision-notification.md` exists in the deployed tree and that
  `.claude/context/index.json` carries its row. *(completed: both confirmed present post-deploy)*
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` with no `--only-gate` and
  no `--skip-slow` — which includes Gate 3 doc lint, Gate 4 task-reference lint, Gate 8's full
  shell-suite battery (`run-all.sh`), Gate 10's `validate-state.sh --deep`, Gate 13's whole-tree
  orphan detection (the gate that would catch an unregistered new context file), and Gate 20's
  orchestrator context budget lock. Green is required before the task completes; any residual
  failure must be either fixed or recorded as a Reasoned Exclusion with evidence that its root
  cause is pre-existing and out of this task's `file_scope`. *(completed: 34 of 35 checks pass;
  the one residual failure (Gate 3 doc-lint) is recorded below as a Reasoned Exclusion — see
  Phase 5's `#### Reasoned Exclusions` subsection)*
- [x] Walk the two remedies end to end against the diff and record the evidence for each in the
  implementation summary, including the explicit statement that Remedy 3 remains rejected and the
  header-label observation remains out of scope. *(completed; see implementation summary)*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Gate 3 doc-lint FAIL: "script file on disk NOT in provides.scripts: scripts/tests/test-lint-agent-contracts-handoff-section.sh" | The flagged file was added by a concurrently-dispatched sibling task's own commit, outside this task's `file_scope` and outside its territory payload's declared sibling scope for that task. Registering it in `provides.scripts` is that sibling task's own responsibility, not this task's edit surface, and fixing it here would mean editing a file this task never declared. | `git log --oneline -1 -- agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh` → `3540a3194 task 370 phase 3: add the section-scoped handoff-artifacts lint check`. This task's own Phase 1 run of `verify-deploy.sh --only-gate 3,4` (before that commit landed) showed Gate 3 green; re-running `--only-gate 3` at the end of Phase 4 and again after Phase 5's redeploy reproduces the identical single FAIL line, unchanged by any of this task's four commits. Recorded non-fatally via `issue-record.sh` (class `concurrent-sibling-gate-collision`, severity `minor`) during Phase 4. |

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts `SKILL.md` measures 21,476 B, the eager baseline is
65,950 B, and the gate set numbers 21 gates — all 2026-10-09 readings from
`orchestrator-context-budget.json` and `wc -c`. Confirm by re-running the two measurement commands
named above and reading `verify-deploy.sh`'s own gate enumeration; the operative assertions are
"`SKILL.md` unchanged by this task" and "`TOTAL <= baseline_bytes`", which hold regardless of the
absolute figures.

**Files to modify**:
- none planned - verification, redeploy, and evidence recording only

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits green across the complete gate set it aggregates,
  with no `--only-gate` narrowing and no `--skip-slow`.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` green (reached via Gate 8).
- `bash .claude/scripts/validate-state.sh --deep` green (reached via Gate 10).
- Gate 13 reports no orphan for `context/patterns/plan-revision-notification.md`.
- Gate 20 green: `measure-eager-context.sh --check`'s `TOTAL <= 65950`, and `SKILL.md`'s byte count
  unchanged.
- `git diff --stat -- agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` is empty.
- `.plan-revised.json` is spelled identically in all four naming sites.
- Both remedies individually evidenced in the implementation summary.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-aux-dispatch.sh`
  exits 0, with the sentinel-clause assertions passing for both `--revision-reason blocker` and
  `--revision-reason drift`.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` exits 0,
  with the `revision_sentinel` presence assertion, the implement-only assertion, and the
  hash-stability assertion all passing by name.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` exits 0,
  including Group 27 Case F (the IDENTICAL DISPATCH HALT regression fixture) — proving this task's
  dispatch-file addition did not render the halt inert.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` green (full battery, reached via
  Gate 8).
- [ ] `shellcheck -S error` exits 0 on every touched shell file, with no new finding at any
  severity versus its pre-edit baseline.
- [ ] `bash .claude/scripts/verify-deploy.sh` green across the complete gate set after redeploy.
- [ ] `bash .claude/scripts/check-task-references.sh` reports zero unexempted occurrences.
- [ ] Manual end-to-end read-through: an implement dispatch file built for a task with a plan
  contains the `revision_sentinel` line and the pointer; the `plan` and `research` phases do not.

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/plan-revision-notification.md` (new) — the single
  contract for the sentinel, its freshness rule, and both obligations.
- `agent-system/extensions/core/index-entries.json` — one new registration row.
- `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh` — unconditional
  sentinel-write clause in the `plan-revision` prompt.
- `agent-system/extensions/core/agents/reviser-agent.md` — Stage 5c writer obligation.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — static
  `revision_sentinel` line plus pointer prose in the implement `## Plan` block.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — Stage 4 pre-write
  obligation, Stage 2 snapshot note, successor carve-out.
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` — parity obligation.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-aux-dispatch.sh` and
  `.../test-orchestrate-build-dispatch.sh` — new assertions.
- `specs/299_detect_plan_revision_during_implement/summaries/01_detect-plan-revision-notification-summary.md`
  — implementation summary with per-remedy evidence.
- The redeployed `.claude/**` tree (generated, not hand-authored).

## Rollback/Contingency

Every change is additive text in six files plus one new file and two test files; nothing is
deleted or renamed, and no state schema, gate definition, or byte ceiling moves. Per-substep
commits mean any single phase can be reverted with `git revert` of its own commits without
disturbing the others.

- **Partial rollback (preferred)**: revert the offending phase's commits. Phases 2, 3, and 4 are
  mutually independent (all depend only on Phase 1), so any one can be reverted alone. Reverting
  Phase 1 requires reverting whichever of 2-4 have landed, since each points at its file.
- **If Phase 3 is implicated in a halt regression**: revert Phase 3's commits only. The
  `revision_sentinel` line is the sole dispatch-file change, and Remedy 1 (Phase 2) plus the agent
  obligations (Phase 4) remain correct without it — the agents can still locate the sentinel from
  the `task_dir` the dispatch already carries.
- **If a rollback must discard uncommitted work**: take a durable checkpoint first with
  `bash .claude/scripts/git-snapshot.sh --no-revert`, which does not revert the working tree. Only
  a genuine rollback uses the default reverting form, per `context/contracts/recovery.md`'s
  rollback rung (including its out-of-scope override flag for a deliberate whole-tree revert).
  Never emit the default reverting form as a routine checkpoint.
- **After any revert**: re-run `bash .claude/scripts/deploy-headless.sh` and
  `bash .claude/scripts/verify-deploy.sh`, since `.claude/**` is a deploy artifact and will
  otherwise retain the reverted text.
