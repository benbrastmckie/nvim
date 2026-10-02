# Implementation Plan: Task #324

- **Task**: 324 - Whitelist scheduled_tasks.lock in orphan detection
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: None (task 323 is a concurrent sibling; disjoint file scope)
- **Research Inputs**: specs/324_whitelist_scheduled_tasks_lock_in_orphan_detection/reports/01_whitelist-scheduled-tasks-lock.md
- **Artifacts**: plans/01_whitelist-scheduled-tasks-lock.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

`verify-deploy.sh` gate 13 (whole-tree orphan detection) false-positives on
`.claude/scheduled_tasks.lock`, a session-acquired runtime lock file (contents: `sessionId`,
`pid`, `acquiredAt`) written by the external Claude Code scheduled-task harness at execution
time and never by this repo's copy engine. That is precisely the class `is_runtime_artifact()`
already whitelists, but no branch matches it. The fix is one exact-match branch in
`verify.lua`, one row extension in the companion exclusion-classes table in the source store,
and one planted-file regression assertion so "lock present -> gate still green" is durable
rather than a one-time manual observation. Done when gate 13 reports no finding for a
`scheduled_tasks.lock` that is actually present on disk.

### Research Integration

The research report settled the three open questions the dispatch raised:

- **Pattern shape**: `rel` is already relative to `target_dir`, so a bare root-level match
  (`rel == "scheduled_tasks.lock"`) is correct and needs no prefix or wildcard — the same shape
  as the existing `rel == "RESUME.md"` branch.
- **Sibling locks (dispatch step 2)**: surveyed; none exist. No script under `agent-system/**`
  or `lua/**` creates any `*.lock` at the `.claude/` root. The `*.lock` files this repo does
  create live under `specs/` and serve a different mechanism entirely. Decision: **exact match,
  not a glob** — there is no observed naming family to generalize over, and the exclusion doc's
  own stated discipline forbids adding a speculative class.
- **Task-250 cross-reference**: re-confirmed and it is a *different* file. The phrase "a sandbox
  orphan tmp file" lives in task 317's archived artifacts, not task 250's, and names
  `tmp/noop-bash-count-...`, unrelated to `scheduled_tasks.lock`. This is a paper-trail
  correction to record in the summary; it changes nothing about the fix, and
  `tmp/noop-bash-count-*` is explicitly out of scope here.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap path was supplied in this dispatch and no roadmap flag was set; ROADMAP.md was not
consulted and is not modified by this plan.

## Goals & Non-Goals

**Goals**:
- `is_runtime_artifact()` classifies `scheduled_tasks.lock` as a runtime artifact, so gate 13
  no longer reports it.
- The exclusion-classes table in the source-store copy of `deploy-orphan-detection.md` records
  the new exclusion, keeping whitelist and documentation in step.
- A regression assertion proves exclusion with the lock file **present**, planted deliberately —
  not merely absent during a manual run.

**Non-Goals**:
- Gate 3 (doc-lint / core manifest desync), the other half of the FAIL-2-of-33 regression — that
  is the concurrent sibling task's scope.
- Any change to `tmp/noop-bash-count-*` handling or any new exclusion for it.
- Any `.gitignore` change for `scheduled_tasks.lock` (orthogonal to gate 13's deploy-tree scan;
  noted in research as an unfiled aside).
- Generalizing the pattern to a glob over a hypothetical lock-file family.
- Any edit to `.claude/**` (deploy artifact) or to `verify-deploy.sh`'s gate 13 call site.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing the deployed `.claude/context/patterns/deploy-orphan-detection.md` instead of the source store | M | M | Both paths identified explicitly; Phase 2 names the source-store path only and its verification greps that `.claude/` copy is untouched |
| A glob pattern silently swallows a future real orphan | H | L | Exact match `rel == "scheduled_tasks.lock"` per the research decision; revisit only on empirical evidence of a naming family |
| Declaring gate 13 green while the lock file happens to be absent (false confidence) | H | M | Phase 3 plants the file deliberately in the scratch tree and asserts exclusion; Phase 4 re-runs the real gate with a planted lock present |
| Concurrent sibling task edits collide in the working tree | M | L | File scopes are disjoint (sibling owns `agent-system/extensions/core/manifest.json` and `README.md`); re-read before edit, stage only this task's own paths, never a directory or glob `git add` |
| Doc edit introduces a task-number reference outside `specs/**` | L | L | `no-task-references-in-deliverables.md` applies to the `agent-system/**` edits; cite the filename/behavior, never the task number |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Add the scheduled_tasks.lock exclusion branch [COMPLETED]

**Goal**: `is_runtime_artifact()` returns true for `scheduled_tasks.lock`.

**Tasks**:
- [x] Re-read `lua/neotex/plugins/ai/shared/extensions/verify.lua` around the
      `is_runtime_artifact()` definition (currently ~lines 869-884) to confirm current content
      before editing — a sibling task is live on this tree.
- [x] Insert a branch immediately after the existing `rel == "RESUME.md"` branch:
      `if rel == "scheduled_tasks.lock" then return true end`.
- [x] Add a one-line comment above it in the style of the existing literature-venv comment,
      stating the file is a session-acquired lock (sessionId/pid/acquiredAt) written by the
      scheduled-task mechanism at execution time, never by the copy engine. Do **not** mention a
      task number — this file is outside `specs/**`.
- [x] Confirm the exact-match form (not a glob) is what landed.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` - add one exact-match branch plus comment to `is_runtime_artifact()`

**Verification**:
- `luac -p` / `nvim --headless -c 'luafile ...'`-equivalent syntax check on the edited module, or
  `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.verify')" -c qa` loading
  cleanly with no error output.
- Diff shows exactly one added branch and one added comment line; no other hunk in the file.
- `grep -n 'scheduled_tasks' lua/neotex/plugins/ai/shared/extensions/verify.lua` returns the new
  branch inside `is_runtime_artifact()`.

---

### Phase 2: Register the exclusion in the companion doc [COMPLETED]

**Goal**: The exclusion-classes table documents the new whitelist entry, so whitelist and doc
stay in step.

**Tasks**:
- [x] Re-read the **Runtime artifact** row (currently ~line 65) of
      `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md`.
- [x] Add `scheduled_tasks.lock` to that row's Examples cell.
- [x] Extend the row's explanation with a clause parallel to the existing
      `tmp/workflow-active-*` clause, e.g. "`scheduled_tasks.lock` is a session-acquired lock
      file written by the scheduled-task mechanism (sessionId/pid/acquiredAt), never by the copy
      engine."
- [x] If the row's trailing claim "All of these are `.gitignore`d at the project root" would
      become inaccurate for the new entry (research observed `scheduled_tasks.lock` is **not**
      currently gitignored at the project root), adjust that sentence so it does not assert
      something false — do not silently inherit the claim. *(deviation: altered — re-verified
      directly with `git check-ignore -v .claude/scheduled_tasks.lock`, which shows the file IS
      caught by the blanket `/.claude/` gitignore rule, contradicting the research report's
      aside. The trailing claim remains accurate, so rather than changing its truth value I
      added a parenthetical clarifying the mechanism, satisfying "do not silently inherit"
      without asserting a falsehood.)*
- [x] Verify the deployed copy `.claude/context/patterns/deploy-orphan-detection.md` was NOT
      modified.

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` - extend the Runtime-artifact exclusion row (source store only)

**Verification**:
- `grep -n 'scheduled_tasks.lock' agent-system/extensions/core/context/patterns/deploy-orphan-detection.md`
  returns the new Examples entry and the new explanation clause.
- `git status --short -- .claude/context/patterns/deploy-orphan-detection.md` is empty (deployed
  copy untouched).
- Diff read-through confirms every changed hunk is markdown table/prose; the table still parses
  as a well-formed row (same pipe count as its siblings).
- No task number appears in the added text (`no-task-references-in-deliverables.md`).

---

### Phase 3: Add the planted-lock regression assertion [COMPLETED]

**Goal**: A durable test proves gate 13's classifier excludes a `scheduled_tasks.lock` that is
actually present.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh`, specifically
      the planting block (~lines 130-170) and the assertion block (~lines 180-208).
- [x] In the planting block, alongside scenario B, plant
      `$TARGET/.claude/scheduled_tasks.lock` with placeholder JSON content shaped like the real
      lock (`sessionId`, `pid`, `acquiredAt`), labelled as a new scenario E. *(deviation: altered
      — re-reading the file surfaced that letter E is already used by the pre-existing
      no-false-positive baseline assertion (`Assertion E: unmodified scratch regenerate
      baseline`, lines ~110-128), which the plan's line-number estimate did not account for.
      Used letter F for the new scenario/assertion instead of E to avoid colliding with an
      existing label; recorded this in the header comment so the mismatch is self-documenting.)*
- [x] In the assertion block, add Assertion E mirroring Assertion B's shape: fail if
      `ORPHAN_FINDING orphan file: scheduled_tasks.lock` appears in `$planted_output`, pass
      otherwise. *(deviation: altered — implemented as Assertion F, same shape as Assertion B,
      for the reason above.)*
- [x] Update the harness's header comment and any "Assertions A/B/C/D" literal strings to cover
      E, so the progress messages do not understate what ran. *(deviation: altered — updated to
      cover F, not E, consistent with the letter-collision correction above.)*
- [x] Run the harness and confirm all assertions pass, including the new one.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase assumes exactly one file changes
(`test-deploy-orphans.sh`) and that Assertion B's plant/assert template transfers with only a
path and message substitution. Confirm at implementation time by re-reading the planting and
assertion blocks before editing; if the harness's "A/B/C/D" literals turn out to appear in more
places than the two blocks named above, widen the edit within this same file rather than
deferring. If a second file genuinely needs changing, stop and record why.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` - add scenario E plant plus Assertion E, update A/B/C/D literals and header comment

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` exits 0 and its
  summary line reports one more passing assertion than before, with Assertion E among the
  passes.
- Deliberate negative control: temporarily revert Phase 1's branch (or stub it), re-run, and
  confirm Assertion E **fails** — proving the assertion is actually wired to the new exclusion
  and not vacuously passing. Restore Phase 1's branch immediately afterward and re-run to green.
- The harness resolves the Lua module from the live `~/.config/nvim` runtimepath, so Phase 1's
  in-place `verify.lua` edit is exercised without a redeploy; confirm this holds by observing
  the negative control above actually flips the result.

---

### Phase 4: Confirm gate 13 green with a lock present [COMPLETED]

**Goal**: The real gate, not only the scratch harness, is green with `.claude/scheduled_tasks.lock`
on disk — satisfying dispatch acceptance criterion 4.

**Tasks**:
- [x] Note whether `.claude/scheduled_tasks.lock` is currently present. If absent, create a
      placeholder with realistic JSON content so the gate runs against the present case.
      (Absent; placeholder created with `sessionId`/`pid`/`acquiredAt` JSON content.)
- [x] Run `verify-deploy.sh` (the `--skip-slow` form the regression was measured with) and
      capture gate 13's result.
- [x] Confirm gate 13 reports no finding for `scheduled_tasks.lock`. (Gate 13: PASS — "no
      deployed-but-undeclared files or ghost context/index.json rows", lock file present on disk
      during the run.)
- [x] Record the overall FAIL count and confirm it moved from 2-of-33 to 1-of-33, with the one
      remaining failure being gate 3 (the concurrent sibling's scope) — not a new or different
      failure introduced here. *(deviation: altered — observed count is 2-of-33, not 1-of-33 or
      0-of-33, and the Scope Hypothesis calls this out explicitly as needing investigation rather
      than rounding. Investigated: the two failures are gate 3 (doc-lint, unchanged, the sibling
      task's scope as hypothesized) and gate 5 (manifest-driven parity: "Content differs from
      source" for `deploy-orphan-detection.md` and `test-deploy-orphans.sh`, plus "Missing
      scripts: scripts/migrate-state-legacy-fields.sh"). Gate 13 itself — this task's actual
      target — is PASS. The gate-5 "content differs" findings are the expected, transient
      source-vs-deploy drift from this task's own Phase 2/3 source-store edits, not yet
      propagated to the live `.claude/` tree; per
      `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`'s two
      "Automated Exception" sections, redeploying the live tree is sanctioned ONLY at specific
      orchestrator postflight call sites (`command-gate-out.sh`'s `rc == 6` branch,
      `commands/implement.md` Step 4) driven by this task's own reported `modified_files` — not
      by this implementation agent directly — so it is correctly left unresolved here and will
      self-heal once postflight's completion-deploy gate runs. The "Missing scripts" finding is
      confirmed via `git log --oneline -- agent-system/extensions/core/manifest.json` to be
      concurrent sibling task 323's own in-flight, not-yet-redeployed manifest declaration
      (commit `ffa70bd9e task 323 phase 1: declare the script in provides.scripts`) — not
      something this task caused. Neither finding reflects a defect in this task's own change.)*
- [x] Remove any placeholder lock file created purely for this check, so no artificial file is
      left behind or committed. (Removed; `.claude/scheduled_tasks.lock` confirmed absent again,
      `git status --short` shows no stray lock file.)
- [x] Record the task-250-vs-317 paper-trail correction (the "sandbox orphan tmp file" note
      names `tmp/noop-bash-count-...`, a different file) in the implementation summary.

**Timing**: 0.25 hours

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the gate count moves from FAIL 2-of-33 to FAIL 1-of-33.
That is a hypothesis measured before the concurrent sibling's work landed; confirm the actual
before/after counts at implementation time and report what was observed. If the sibling task has
already fixed gate 3 by then, 0-of-33 is the expected result and is not a discrepancy. A count
other than those two needs investigating, not rounding.

**Files to modify**:
- none planned (verification-only phase; a transient placeholder lock file is created and removed, never committed)

**Verification**:
- `verify-deploy.sh --skip-slow` output shows gate 13 PASS with the lock file present on disk at
  the time of the run.
- No `ORPHAN_FINDING` line mentions `scheduled_tasks.lock`.
- `git status --short` shows no stray placeholder lock file left in the tree.

## Testing & Validation

- [x] `bash agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` exits 0 with the
      new Assertion E passing. *(deviation: altered — implemented as Assertion F, not E; see
      Phase 3 annotations. Harness exits 0, 6 passed/0 failed.)*
- [x] Negative control performed: Assertion E demonstrably fails without the `verify.lua` branch.
      *(deviation: altered — Assertion F; confirmed FAIL with the branch stubbed out, then
      restored to green.)*
- [x] `verify-deploy.sh --skip-slow` gate 13 PASS with `.claude/scheduled_tasks.lock` present.
- [x] Gate 13's behavior on a genuine orphan is unchanged: Assertion A (planted
      `scripts/orphan-test-canary.sh`) still reports a finding.
- [x] No modification to any file under `.claude/`.
- [x] No task-number reference introduced in any file outside `specs/**`.

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/extensions/verify.lua` - one new exclusion branch in `is_runtime_artifact()`
- `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` - extended Runtime-artifact exclusion row
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` - new planted-lock regression assertion
- `specs/324_whitelist_scheduled_tasks_lock_in_orphan_detection/summaries/01_*-summary.md` - implementation summary, including the task-250-vs-317 paper-trail correction

## Rollback/Contingency

All three edits are additive and independently revertible; each phase commits separately, so a
single `git revert` of the offending commit restores prior behavior without touching the others.
No snapshot-then-rollback of uncommitted work is anticipated. If a destructive rollback of
uncommitted changes does become necessary, follow `context/contracts/recovery.md`'s rollback rung
for the correct invocation shape rather than improvising a reset. If the exact-match pattern
later proves too narrow (a genuine lock-file family appears empirically), the remedy is a
follow-up task widening the pattern with measured evidence — not a speculative glob added here.
