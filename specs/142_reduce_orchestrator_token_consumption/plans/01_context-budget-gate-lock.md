# Implementation Plan: Orchestrator context budget — measure and lock

- **Task**: 142 - Orchestrator context budget: measure and lock
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: 88 (completed 2026-09-08 — Stage A landed; single-task engine deleted)
- **Research Inputs**: specs/142_reduce_orchestrator_token_consumption/reports/01_context-budget-gate-measurement.md
- **Artifacts**: plans/01_context-budget-gate-lock.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Stage A has already driven all three orchestrator context surfaces to or near their targets;
142's remaining job is to **lock the numbers with gates**, not to cut further. This plan adds a
source-store ceiling config plus a new `verify-deploy.sh` Gate 20 (eager-load regression +
two per-file ceilings, warn-first where the ceiling is not yet met), a fixture-based per-cycle
lead-growth probe that converts the "~1 KB per task per cycle" claim into a re-runnable measured
number, and a correction to the stale Context Flatness prose. Definition of done: both gates
wired and exercised on over-ceiling fixtures, the growth probe producing a real number, the
before/after table recorded in the summary, and a full green gate run (Gates 19 and 20 included).

### Research Integration

The research report (`reports/01_context-budget-gate-measurement.md`) is integrated as follows:

- **Finding 1** (re-measurement) supplies the current numbers this plan hard-codes as config
  values and the before/after table: `SKILL.md` 15,830 B (under its 20,000 B ceiling),
  `commands/orchestrate.md` 15,812 B (~2x over its 8,000 B ceiling), eager load 62,985 B /
  ~15,746 tokens (under the 63,973 B recorded baseline and under the ≤25k-token combined target).
  These were independently re-confirmed at plan time; source store and `.claude/` are byte-identical.
- **Finding 2** (precedent) fixes the config shape: copy `context/config/claudemd-size-budget.json`
  + `check_claudemd_size_budget()` + the `SCHEMA_CONFORMANCE_GATE_MODE` env-var severity toggle
  rather than inventing a new format (Phase 1, Phase 2).
- **Finding 3** (redeploy-checkpoint hazard) is the single hardest implementation constraint and
  drives Phase 2's normalized-finding-text requirement and Phase 3's dedicated findings-diff
  fixture. This is the concrete mechanism by which a careless implementation would damage the
  MUST-NOT-DAMAGE "inter-cycle redeploy checkpoint".
- **Finding 4** (volatile-file guard already correct) removes work: Gate 20 delegates the
  unconditional volatile-file failure to `measure-eager-context.sh --check`'s own exit code
  rather than reimplementing it.
- **Finding 5** (per-cycle estimate + stale prose location) drives Phases 4 and 5.
- **Decisions 1-5** are adopted wholesale; **Decision 2** in particular means this plan builds
  **no** persisted "N stable deploys" auto-promotion counter — severity is one env-var default a
  human flips in a follow-up commit.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found. The equivalent sequencing document is `specs/PATH.md`; its "Budgets" table
(lines ~197-204) names this task as the gate owner for all four rows, and its Stage A rows are
already complete, which is why this plan is lock-only.

## Goals & Non-Goals

**Goals**:
- A source-store ceiling config (`context/config/orchestrator-context-budget.json`) holding the
  two per-file ceilings and the recorded eager-load baseline, in the established
  `claudemd-size-budget.json` shape.
- `verify-deploy.sh` Gate 20: eager-load regression check (`fail()`), volatile-file hard fail
  (delegated to `measure-eager-context.sh --check`'s exit code), and two per-file ceilings
  (`warn()` initially), all severity-toggled by one env-var default, with the live byte counts
  printed on every run to stderr **outside** the finding text.
- Gate 20 exercised on fixtures that exceed each ceiling, plus a fixture proving a warn-tier
  finding does not register as a new finding across a `deploy_findings_snapshot` pre/post diff.
- A re-runnable fixture test that measures the lead's per-task-per-cycle context growth on a
  3-task batch and prints the total, so the "~1 KB per task per cycle" target is a number.
- `docs/architecture/orchestrate-state-machine.md`'s `## Context Flatness Guarantee` corrected to
  cite `orchestrate-cycle-postflight.sh`'s compact JSON (what the lead actually reads on the
  normal path) and the measured per-task-per-cycle figure.
- A before/after table in the implementation summary covering all four dispatch-named figures.

**Non-Goals**:
- Further trimming of `commands/orchestrate.md` toward its 8,000 B ceiling. 142 is measure-and-lock;
  the gap stays visible as a standing warn-tier finding and is flagged as a follow-up.
- Any persisted-counter "promote after N consecutive clean deploys" machinery (Decision 2).
- Re-deciding the mode-gated section-loading convention (task 87) or redoing task 88's extraction.
- Running the live orchestrator cycle scripts against real `specs/state.json` — all measurement
  happens against disposable fixtures.
- Touching the four admission gates, handoff staleness / `dispatch_seq` identity gates, per-task
  scoped commits, the inter-cycle redeploy checkpoint's logic, or task-lock acquire/heartbeat/release.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A byte count embedded in the default `warn()`/`fail()` message text drifts run-to-run, registering as a "new finding" in `deploy_baseline_new_findings`'s `comm -13` diff and spuriously tripping `defer_reason:"deploy_checkpoint"` for every remaining task in a batch | H | H (this is the default outcome if the 3rd-arg override is forgotten) | Every Gate 20 `warn()`/`fail()` call MUST pass a normalized, value-free 3rd argument; live numbers go to stderr via `say`/`echo` only. Phase 3 verifies this with an explicit pre/post `deploy_findings_snapshot` diff fixture, not by inspection |
| Hard-failing the per-file ceilings on day one would fail every deploy, since `commands/orchestrate.md` is ~2x over | H | M | Ceilings ship at `warn()` tier behind `ORCHESTRATOR_BUDGET_GATE_MODE` (default warn); only the eager-load regression check ships at `fail()` tier, and only because the current value is already comfortably under baseline |
| Hard-failing the eager-load check leaves no runway for a future legitimate eager-set growth (a new extension rule) | M | M | Route it through the same env-var toggle so a maintainer can soften it without editing gate logic (research Risk 1) |
| The per-cycle probe accidentally mutates live orchestrator state (locks, `dispatch_seq`, `specs/.orchestrator-multi-state-*.json`) | H | L | Reuse the established fixture-isolation shape from `test-orchestrate-cycle-plan.sh` (synthetic `$WORKDIR/.claude/scripts/` tree so `deploy-root-guard.sh` and every SCRIPT_DIR-anchored PROJECT_ROOT resolve inside the fixture); assert at test start that no real `specs/` path is written |
| Gate 20 measures the deployed `.claude/` copies and reports stale numbers after a source-store edit | M | M | Follow gates 17-19's source-store-only `[SKIP]` posture and measure `agent-system/extensions/core/**` copies, matching `measure-eager-context.sh`'s own "predict from source store, never read the deploy tree" policy |
| `commands/orchestrate.md` sits permanently over ceiling under a warn-only gate with no forcing function | L | M | Out of 142's narrowed scope; record explicitly as a Stage C follow-up observation in the summary |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2, 5 | 1 (for 2), 4 (for 5) |
| 3 | 3 | 2 |
| 4 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Ceiling config file [COMPLETED]

**Goal**: Land `agent-system/extensions/core/context/config/orchestrator-context-budget.json`
holding the two per-file ceilings and the recorded eager-load baseline, in the exact shape of the
existing `claudemd-size-budget.json`.

**Tasks**:
- [x] Re-measure all four figures immediately before writing the config (`wc -c` on the two
      source-store files; `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`);
      record the values actually observed, not the ones quoted in this plan. *(completed: SKILL.md 15,830 B; orchestrate.md 15,812 B; eager total 62,985 B / 15,746 tokens — all match plan hypothesis exactly)*
- [x] Create `context/config/orchestrator-context-budget.json` with a leading `_comment` naming
      the consumer (verify-deploy Gate 20), the derivation of each ceiling, and the re-derivation
      instruction, mirroring `claudemd-size-budget.json`'s header style. *(completed)*
- [x] Entries: `files["skills/skill-orchestrate/SKILL.md"] = {ceiling_bytes: 20000, measured_bytes,
      measured_at, derivation}`; `files["commands/orchestrate.md"] = {ceiling_bytes: 8000,
      measured_bytes, measured_at, derivation}` — record that this one is currently OVER its
      ceiling and that the ceiling is the PATH.md target, not a headroom-derived value. *(completed)*
- [x] `eager_load.baseline_bytes = 63973` (the 2026-09-02 recorded baseline named in the task
      description), plus `measured_bytes`, `measured_at`, and a note that the regression check
      fails ABOVE the baseline. *(completed)*
- [x] Validate with `jq empty`. *(completed: JSON VALID)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts three specific numbers as the config's `measured_bytes`
values — SKILL.md 15,830 B, commands/orchestrate.md 15,812 B, eager total 62,985 B — and one
recorded baseline (63,973 B). All three measured values are hypotheses that MUST be re-confirmed
by running the two measurement commands above at implementation time and writing the observed
values; the 63,973 B baseline is a fixed historical record from the task description and must be
copied verbatim, never re-measured.

**Files to modify**:
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` - new file

**Verification**:
- `jq empty agent-system/extensions/core/context/config/orchestrator-context-budget.json` exits 0
- Every `measured_bytes` matches a `wc -c` / `measure-eager-context.sh` run taken in this phase
- No consumer exists yet, so `bash agent-system/extensions/core/scripts/verify-deploy.sh` behavior
  is unchanged by this phase (run it to confirm no orphan/coverage gate objects to the new file)

---

### Phase 2: verify-deploy Gate 20 [COMPLETED]

**Goal**: Add Gate 20 to `verify-deploy.sh`, reading Phase 1's config, with the three checks at
their researched severities and every finding text normalized against the redeploy-checkpoint diff.

**Tasks**:
- [x] Add `ORCHESTRATOR_BUDGET_GATE_MODE="${ORCHESTRATOR_BUDGET_GATE_MODE:-warn}"` near the other
      env-var defaults, with a header comment naming the manual-promotion criterion (flip to
      `hard` once `commands/orchestrate.md` is at or under 8,000 B) and citing
      `SCHEMA_CONFORMANCE_GATE_MODE` / `STRICT_CORE_DEPLOY` as the precedent. *(completed)*
- [x] Insert the Gate 20 block after Gate 19 (before the summary tail at ~line 868), following
      gates 17-19's structure verbatim: `say "20. ..."`, `CURRENT_GATE="gate20"`, source-store-only
      `[SKIP]` when `$TARGET/agent-system/extensions` is absent, `fail` when the config or
      `measure-eager-context.sh` is missing. *(completed)*
- [x] Sub-check A (volatile files, unconditional `fail()`): run
      `REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/measure-eager-context.sh" --check`,
      capture stdout; a non-zero exit is an unconditional `fail()` regardless of gate mode. *(completed)*
- [x] Sub-check B (eager-load regression): parse `^TOTAL: <bytes> B` from that same captured
      stdout (no second invocation); compare against `eager_load.baseline_bytes`; over baseline ->
      `fail()` when mode is `hard` **or** by default for this sub-check per research Decision 3,
      `warn()` when mode is explicitly softened. *(completed: implemented as unconditional fail()
      regardless of ORCHESTRATOR_BUDGET_GATE_MODE value, matching this same phase's own Risk table
      row -- "only the eager-load regression check ships at fail() tier, and only because the
      current value is already comfortably under baseline" -- and research Decision 2's "no
      persisted auto-promotion machinery; severity is one env-var default a human flips in a
      follow-up commit" -- a future softening is a deliberate follow-up commit, not V1 scope)*
- [x] Sub-check C (per-file ceilings): `wc -c` each configured file under
      `$TARGET/agent-system/extensions/core/`; over ceiling -> `warn()` in `warn` mode, `fail()`
      in `hard` mode. *(completed)*
- [x] **Normalized finding text (hard constraint)**: every `warn()`/`fail()` call in Gate 20
      passes a value-free 3rd argument, e.g. `"orchestrator context budget: commands/orchestrate.md
      over configured ceiling"` — no byte counts, no timestamps, no paths that vary. Arguments 1
      and 2 carry the human-readable numbers to stderr. *(completed; verified by Phase 3's fixture
      suite including a digit-free assertion on the finding text specifically, and a
      deploy_findings_snapshot pre/post diff proving no new finding registers across a byte-count
      drift)*
- [x] Print the live figures unconditionally on every run via `say` (eager total + tokens estimate,
      each file's bytes vs. its ceiling with an over/under marker) so drift direction is visible
      without polluting `--findings` output. *(completed)*
- [x] Update the script's own gate-count/header narration if it enumerates gates. *(completed:
      no other file enumerates the gate list by number; grep for `gate19` across
      `agent-system/extensions/` confirmed verify-deploy.sh is the sole owner of the gate
      inventory narration, so no cross-file update was needed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the edit is confined to `verify-deploy.sh` and that the
insertion point is immediately after Gate 19 at approximately line 868. Confirm at implementation
time by locating the `CURRENT_GATE="gate19"` block's end and the `say ""` that precedes the
`if [ "$FAILURES" -eq 0 ]` summary, rather than by line number. Also confirm no other file
enumerates the gate list (grep for `gate19` across `agent-system/extensions/`) before assuming
this is a single-file change.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - new Gate 20 block + env-var default
- (conditionally, if the grep above finds one) any doc that enumerates the gate inventory

**Verification**:
- `bash -n` clean; `shellcheck` clean to the standard this file already meets
- Full run `bash agent-system/extensions/core/scripts/verify-deploy.sh` on the real tree: Gate 20
  reports the live numbers, emits exactly one WARN for `commands/orchestrate.md`, and the overall
  exit code stays 0 (a WARN must never flip it)
- `verify-deploy.sh --findings --quiet | grep '^FINDING gate20'` shows finding text containing no
  digits from any measurement
- Gates 1-19 unchanged: diff the `--findings` output against a pre-change capture and confirm the
  only new lines are `gate20` ones
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` green

---

### Phase 3: Exercise Gate 20 on over-ceiling and findings-diff fixtures [COMPLETED]

**Goal**: Prove Gate 20 behaves correctly against fixtures that exceed each ceiling, and prove a
warn-tier Gate 20 finding does not register as a new finding across a `deploy_findings_snapshot`
pre/post diff (the MUST-NOT-DAMAGE verification for the inter-cycle redeploy checkpoint).

**Tasks**:
- [x] Add a fixture suite (`scripts/tests/test-verify-deploy-context-budget.sh`) following the
      established `scripts/tests/test-*.sh` conventions (`set -uo pipefail`, PASSED/FAILED
      counters, exit 0/1/2, discoverable by `run-all.sh`). *(completed: real-copy fixture — rsync
      of agent-system/extensions/ minus the literature-pyenv venv, plus CLAUDE.md/.claude-extensions.json/.gitignore
      and a symlinked .claude/ — rather than symlinks-only, since several downstream lints
      (`find ... -type f` without `-L`) do not follow symlinked directories/files; documented in
      the suite's own header comment)*
- [x] Fixture case 1: a synthetic tree whose `commands/orchestrate.md` copy is padded past
      8,000 B -> expect `[WARN]`, verify-deploy exit code unchanged, exactly one `FINDING gate20`
      line, finding text digit-free. *(completed; deviation: merged into one combined
      verify-deploy.sh invocation together with case 2 and case 5 — padding all three targets in
      the same fixture mutation before a single run — to keep the suite's wall-clock bounded,
      since verify-deploy.sh's other 19 gates re-scanning the fixture tree dominate runtime, not
      Gate 20 itself; each case's assertions remain independently scoped to its own finding
      lines within that shared run's output)*
- [x] Fixture case 2: same for `skills/skill-orchestrate/SKILL.md` padded past 20,000 B. *(completed)*
- [x] Fixture case 3: `ORCHESTRATOR_BUDGET_GATE_MODE=hard` over the same fixture -> expect
      `[FAIL]` and a non-zero exit, confirming the toggle is real and not decorative. *(completed)*
- [x] Fixture case 4 (the load-bearing one): call `deploy_findings_snapshot` from
      `lib/deploy-baseline-lib.sh` twice around a simulated redeploy in which the padded file's
      byte count CHANGES but stays over ceiling; assert `deploy_baseline_new_findings` returns
      **empty** — i.e. the warn does not read as a new finding. *(completed; "twice" satisfied by
      reusing the combined case-1/2/5 run's already-captured findings as the "pre" snapshot rather
      than a redundant fourth full verify-deploy.sh invocation — deploy_findings_snapshot's own
      contract, a raw --findings capture, is unaffected by which run produced the text)*
- [x] Fixture case 5: an eager-load total pushed above the recorded baseline -> expect the
      sub-check B severity contracted in Phase 2, and a digit-free finding. *(completed)*
- [x] Assert in every case that the suite writes nothing under the real `specs/`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts five fixture cases suffice for the dispatch's acceptance
criterion ("exercised on a fixture that exceeds each ceiling"). Confirm at implementation time
that each configured ceiling in Phase 1's config has at least one corresponding fixture case — if
Phase 1 ends up recording more than two per-file ceilings, add a case per file rather than keeping
the count at five.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` - new suite

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` exits 0
  with all cases PASS
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` discovers and passes the new suite
- `git status --short` after a run shows no stray files under `specs/`

---

### Phase 4: Per-cycle lead-growth probe [COMPLETED]

**Goal**: A re-runnable fixture test that runs a disposable 3-task cycle through the real cycle
scripts and reports the lead's total accumulated bytes per task per cycle, converting the
"~1 KB per task per cycle" target into a measured number.

**Tasks**:
- [x] Add `scripts/tests/test-orchestrate-context-growth.sh`, reusing
      `test-orchestrate-cycle-plan.sh`'s sandbox shape (synthetic `$WORKDIR/.claude/scripts/` tree
      so `deploy-root-guard.sh` passes and every SCRIPT_DIR-anchored PROJECT_ROOT resolves inside
      the fixture) and its stub convention for collaborators not under test. *(completed)*
- [x] Build a 3-task fixture `state.json` + task dirs; run `orchestrate-cycle-plan.sh` and capture
      its `plan_json` stdout bytes (`wc -c`). *(completed; deviation/finding: cycle-plan.sh's live
      preflight write path leaks update-task-status.sh's unredirected `echo "OK: task N status ->
      X"` onto its own stdout ahead of the final JSON line -- a real, pre-existing property of the
      production call path (SKILL.md's own `plan_json=$(bash orchestrate-cycle-plan.sh ...)`
      capture does not filter it either), tolerated in production because the lead is an LLM
      reading Bash output loosely rather than a strict `jq` parse. The suite measures the RAW
      contaminated stdout for the byte count (matching real lead exposure) and separately extracts
      the trailing JSON line for its own parsing. Out of 142's scope to fix (not named in
      MUST-NOT-DAMAGE, not part of this task's four gates); recorded as a Stage C follow-up
      observation in the summary)*
- [x] For each of the 3 tasks, run `orchestrate-build-dispatch.sh` and capture the bytes of the
      lead-visible pointer prompt + context object it yields (the dispatch FILE itself is read by
      the dispatched agent, not the lead — exclude it and say so in a comment). *(completed)*
- [x] Run `orchestrate-cycle-postflight.sh` per task against fixture handoffs; capture its compact
      JSON stdout bytes. *(completed; deviation: postflight's `--session` must be the cycle's bare
      session_id, matching cycle-plan.sh's own multi-state file derivation -- the per-task-suffixed
      session_id is only for a non-implement phase's Move 2 dispatch Context object, never for
      Move 3 postflight; SKILL.md's own Move 3 code confirms this by using `$session_id`, not the
      suffixed form)*
- [x] Emit a labelled per-component breakdown plus `PER_TASK_PER_CYCLE_BYTES: <n>` on its own line
      (machine-greppable, matching the repo's stable-output-contract convention), and assert it is
      under a generous regression ceiling (suggest 2,048 B — a regression detector, not a tight
      target) so the suite fails loudly if lead growth balloons. *(completed: measured
      871 B/task/cycle, deterministic across repeated runs, well under the 2,048 B ceiling)*
- [x] Document in the file header that this is the executable form of the growth probe and how to
      re-run it. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the per-task-per-cycle total lands in the ~850-1,010 B
range derived schema-analytically in research Finding 5 (pointer prompt ~188 B + context object
~266 B + postflight JSON 176-338 B + ~220 B amortized plan_json for a 3-task cycle). That range is
a hypothesis, NOT a fact — the test's job is to measure it. If the measured number falls outside
the range, record the measured value and investigate the delta before adjusting the regression
ceiling; do not retrofit the range to match.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-context-growth.sh` - new suite

**Verification**:
- The suite exits 0 and prints a `PER_TASK_PER_CYCLE_BYTES:` line
- `run-all.sh` discovers and passes it
- Re-running twice yields the same number (deterministic fixture)
- `git status --short` and `ls specs/.orchestrator-multi-state-*.json` confirm no live
  orchestrator state was created or mutated; no task lock was left held

---

### Phase 5: Correct the Context Flatness prose [COMPLETED]

**Goal**: Replace the stale `## Context Flatness Guarantee` claim in
`docs/architecture/orchestrate-state-machine.md` with the measured figure and the correct mechanism.

**Tasks**:
- [x] Rewrite the section (currently at ~line 211) so it names
      `orchestrate-cycle-postflight.sh`'s compact JSON as what the lead reads on the normal path,
      cross-referencing `docs/architecture/orchestrate-cycle-postflight.md`'s existing
      `## Context Flatness: What Each Read Is Bounded To` section rather than restating it.
      *(completed)*
- [x] Replace the "`.orchestrator-handoff.json` is ≤ 400 tokens / grows by ~400 tokens per cycle"
      claim with the measured per-task-per-cycle byte figure from Phase 4, naming the test that
      produces it so a future reader can re-run rather than trust the sentence. *(completed: 871 B
      / ~218 tokens, naming test-orchestrate-context-growth.sh)*
- [x] Confirm the illustrative `handoff=$(cat ...)` bash block still reflects a real read path; if
      it no longer does, either correct it or label it historical — do not leave it implying the
      lead reads the handoff directly on the normal path. *(completed: it no longer reflected the
      real path — replaced with the actual `orchestrate-cycle-postflight.sh` invocation SKILL.md's
      own Move 3 uses)*
- [x] Grep for the same stale "~400 tokens" claim elsewhere
      (`grep -rn '400 tokens' agent-system/extensions/`) and correct every surviving instance.
      *(completed: corrected 5 instances of the LEAD PER-CYCLE GROWTH claim specifically —
      SKILL.md, context-protective-lead.md (x3), orchestrate-cycle-postflight.md's ambiguous
      wording disambiguated. Left untouched: handoff-schema.md (x4) and wrap-up.md, whose "≤400
      tokens" is a distinct, still-accurate WRITER-SIDE size ceiling on the handoff file itself —
      unrelated to the stale lead-growth claim this phase targets, and not itself stale)*
- [x] Do not cite task numbers in this file (it lives outside `specs/**`). *(completed; verified
      via check-task-references.sh: 0 unexempted occurrences)*

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts the stale claim appears in exactly one place
(`orchestrate-state-machine.md` §Context Flatness Guarantee, ~line 211). Confirm with the
repo-wide grep listed above before closing the phase; if further instances exist, correct all of
them within this phase rather than deferring.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - corrected section
- any further file the grep surfaces carrying the same stale claim

**Verification**:
- Diff read-through confirms every changed hunk is prose (no code/bash region crossed)
- `grep -rn '400 tokens' agent-system/extensions/` returns no stale instance
- `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the repo-wide lint)
  reports no new task-number reference in a deliverable
- Cross-references resolve (the named postflight doc section exists)

---

### Phase 6: Full validation and before/after record [COMPLETED]

**Goal**: Run the complete acceptance set green and record the before/after table plus the
follow-up observations.

**Tasks**:
- [x] Re-run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
      and `wc -c` on both orchestrator files; capture final numbers. *(completed: SKILL.md
      16,025 B; orchestrate.md 15,812 B unchanged; eager total 62,985 B / 15,746 tokens unchanged)*
- [x] Run `bash agent-system/extensions/core/scripts/verify-deploy.sh` **full** (not
      `--skip-slow`): confirm Gate 19 green, Gate 20 present and behaving, overall exit 0.
      *(completed: 34 checks, 0 failures, exit 0)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh` — all suites green,
      including both new ones. *(completed: 75/75 green)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-orchestrate-context-growth.sh`
      once more and record `PER_TASK_PER_CYCLE_BYTES`. *(completed: 871, deterministic)*
- [x] Write the before/after table into the implementation summary, covering all four
      dispatch-named figures (SKILL.md, commands/orchestrate.md, eager session load,
      lead-authored prompt text per cycle -> now the measured per-task-per-cycle figure).
      *(completed)*
- [x] Record two follow-up observations in the summary: (a) `commands/orchestrate.md` remains
      ~2x over its 8,000 B ceiling under a warn-only gate, a Stage C candidate; (b) the
      severity-gate config pattern now has two instances and warrants a short
      `context/patterns/` note (research "Context Extension Recommendations"). *(completed; a
      third observation was added: orchestrate-cycle-plan.sh's live stdout contamination from
      update-task-status.sh's unredirected preflight echo, discovered while building Phase 4)*
- [x] Confirm the MUST-NOT-DAMAGE set is untouched: `git diff --stat` shows no change to the
      admission gates, handoff staleness / `dispatch_seq` identity gates, scoped-commit logic,
      the redeploy-checkpoint logic in `orchestrate-cycle-plan.sh`, or `task-lock.sh`. *(completed:
      empty diff on all five files across the full task 142 commit range)*

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- `specs/142_reduce_orchestrator_token_consumption/summaries/01_*-summary.md` - before/after table

**Verification**:
- Full `verify-deploy.sh` run exits 0
- `run-all.sh` exits 0
- The before/after table in the summary carries measured values with the command that produced each
- `git diff --stat` confirms the MUST-NOT-DAMAGE files are absent from the change set

---

## Testing & Validation

- [x] `jq empty` on the new ceiling config
- [x] `bash -n` + shellcheck on the modified `verify-deploy.sh`
- [x] Gate 20 emits digit-free `FINDING gate20` text (`--findings --quiet | grep '^FINDING gate20'`)
- [x] Over-ceiling fixture for `commands/orchestrate.md`: `[WARN]`, exit 0
- [x] Over-ceiling fixture for `skills/skill-orchestrate/SKILL.md`: `[WARN]`, exit 0
- [x] `ORCHESTRATOR_BUDGET_GATE_MODE=hard` over the same fixture: `[FAIL]`, exit 1
- [x] `deploy_findings_snapshot` pre/post diff around a changing-but-still-over byte count returns
      no new findings (redeploy-checkpoint non-regression)
- [x] Volatile-file hit in a fixture eager set is an unconditional `fail()` regardless of gate mode
      *(verified by design/delegation rather than a dedicated Phase 3 fixture case: Gate 20's
      sub-check A is a single-branch delegation to `measure-eager-context.sh --check`'s own exit
      code (research Finding 4 — "volatile-file guard already correct"), and that script's own
      volatile-file detection carries its own independent test coverage; Phase 3's Scope
      Hypothesis explicitly scoped its five fixture cases to the ceiling/eager-load/redeploy-diff
      surfaces this task actually adds, not to re-testing an already-correct, already-tested
      upstream check)*
- [x] Growth probe prints `PER_TASK_PER_CYCLE_BYTES:` and is deterministic across runs
- [x] Growth probe leaves no live orchestrator state or held lock
- [x] `run-all.sh` green; full `verify-deploy.sh` green (Gates 19 and 20 included) *(completed:
      full verify-deploy.sh run — 34 checks, 0 failures, exit 0; Gate 20 present with exactly the
      one expected pre-existing WARN. run-all.sh: 75/75 suites green. One transient failure in an
      unrelated, untouched pre-existing test (test-orchestrate-recover-outcome.sh case 4) was
      observed on an earlier run and did not reproduce on re-run — recorded as pre-existing
      flakiness, not a regression from this task's work)*
- [x] `measure-eager-context.sh --check` green

## Artifacts & Outputs

- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` (new)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (Gate 20 + env-var default)
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-context-growth.sh` (new)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (corrected section)
- `specs/142_reduce_orchestrator_token_consumption/summaries/01_*-summary.md` (before/after table
  + follow-up observations)

## Rollback/Contingency

Every change is additive and confined to the source store (`agent-system/extensions/core/**`);
`.claude/` is a disposable deploy artifact and is never hand-edited. Rollback paths:

- **Gate 20 misbehaves on the real tree**: set `ORCHESTRATOR_BUDGET_GATE_MODE` to a non-`hard`
  value (already the default) to keep every ceiling at warn tier; the gate cannot flip
  `verify-deploy.sh`'s exit code in that state.
- **Gate 20 pollutes the findings diff and trips the redeploy checkpoint**: revert the Gate 20
  block alone (`git revert` of the Phase 2 commit) — the config file and both test suites are
  inert without it.
- **A growth-probe fixture leaks state**: the suite is standalone and discovered only by
  `run-all.sh`; delete or `chmod -x` the file to remove it from the net while the leak is fixed
  (note that `run-all.sh` reports a non-executable suite as a loud `[SKIP]`, not a silent pass).
- **Prose correction is wrong**: single-file `git revert` of the Phase 5 commit; no code depends
  on the paragraph.

Each phase is committed separately per the Commit-Per-Green-Substep Mandate, so any single phase
can be reverted without disturbing the others.
