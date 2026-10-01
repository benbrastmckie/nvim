# Implementation Plan: Task #288

- **Task**: 288 - Remove the per-dispatch worktree isolation layer and unwire every caller
- **Status**: [COMPLETED]
- **Effort**: 10 hours
- **Dependencies**: 286 (decision-record revision), 287 (co-scheduling admission rule) — both verified `completed` in `specs/state.json`; prerequisites satisfied, this plan is cleared to execute
- **Research Inputs**: `specs/288_remove_dispatch_worktree_isolation_layer/reports/01_worktree-isolation-removal-inventory.md`
- **Artifacts**: plans/01_worktree-isolation-layer-removal.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Delete `scripts/dispatch-worktree.sh` and its two dedicated test files outright, and unwire every
live caller and reference across the source store (`agent-system/extensions/core/`, never
`.claude/**`). The verdict in `specs/decisions/worktree-isolation-removal-verdict.md` is settled
and not re-openable: every dispatch runs in the single shared working tree, and build contention
(mode 2) is already closed by the landed co-scheduling admission rule. Done means the three files
are gone, no reference to `dispatch-worktree.sh` survives anywhere in the source store, a
`--dry-run` cycle plan emits dispatch rows with **no** `isolation`/`worktree_path` keys, the shell
harness shows no NEW failures against `scripts/tests/known-failures.txt`, every edited `.sh` is
shellcheck-clean, and both byte-budget gates are re-measured with the real numbers reported.

### Research Integration

The research report re-derived the footprint and materially corrected the dispatch's own
inventory. Five findings drive this plan's shape:

1. **10 of the dispatch's named files are false positives** and MUST NOT be edited (generic
   git-worktree prose or the harness's own unrelated `isolation` parameter): `assess-repo-health.sh`,
   `skill-base.sh`, `backfill-file-scope.sh`, `commands/todo.md`,
   `context/schemas/state-schema.json`, `context/reference/state-management-schema.md`,
   `context/patterns/mcp-server-ownership.md`, `docs/reference/utility-scripts-inventory.md`,
   `docs/reference/standards/agent-frontmatter-standard.md`,
   `docs/architecture/extension-system.md`. They are excluded from every phase below by name so a
   fresh grep during implementation does not reintroduce them as "still has a hit" false alarms.
2. **Four test files the dispatch never names carry real, mandatory work** (~118 references):
   `test-orchestrate-cycle-plan.sh`, `test-orchestrate-cycle-postflight.sh`,
   `test-orchestrate-build-dispatch.sh`, `test-lake-build-guard.sh`. Two of them `require_file`/`cp`
   the script being deleted, so skipping them produces hard suite-setup failures, not stale
   assertions.
3. **`task_selected_for_worktree_isolation()` is dual-purpose** and must be **renamed and narrowed,
   never deleted** — it is the sole array reader the landed build-heavy co-scheduling admission rule
   calls. Only 2 of its 4 call sites go away.
4. **Two edits are correctness fixes, not cleanup**: `build_contended_manifest()`'s exclusion of a
   build-heavy task (now a false negative that hides a real path collision from
   `git-commit-scoped.sh`), and `context/contracts/territory.md` line 136 (now factually wrong on
   two counts).
5. **The eager-load byte gate cannot improve from this removal** — none of this task's editable
   files are eager-loaded. Verified live during planning: eager-load total is **67,980 B** against a
   **65,950 B** baseline, and `measure-eager-context.sh` lists no file this task touches. The
   SKILL.md ceiling (**21,317 B** against **20,000 B**) genuinely does gain headroom. Report the two
   separately and honestly.

Additions this plan makes on top of the report:

- **Group 30 stages three stubs, not one.** `scripts/tests/test-orchestrate-cycle-plan.sh`'s Group
  30 stages `dispatch-worktree.sh`, `orchestrate-build-dispatch.sh` (with `G30_BUILD_ARGV_LOG`) and
  `update-task-status.sh` into the fixture's `.claude/scripts/`. Groups 31 **and** 32 both document
  that they reuse those persisting stubs. Deleting Group 30 wholesale therefore breaks two surviving
  groups, which the report's "Group 32 is safe to keep" note understates. Phase 6 preserves the two
  non-worktree stubs explicitly.
- **`context/patterns/batch-orchestration-guardrails.md` is in scope** despite the dispatch
  excluding it — see the Decisions note below.
- **`test-verify-deploy-context-budget.sh` is already a recorded known failure** whose stated reason
  is precisely the SKILL.md ceiling plus the eager-load baseline. This removal may change half of
  that finding set, so its `known-failures.txt` row needs reconciling (Phase 9) rather than being
  left to describe a state that no longer holds.

### Prior Plan Reference

No prior plan. `next_artifact_number` is 2, so this is round 1's plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but no `roadmap_path` was supplied in this dispatch and no roadmap flag
is set, so no roadmap review/update phases are included. The removal advances the standing
"Budgets" concern indirectly by reclaiming bytes under the `skill-orchestrate/SKILL.md` ceiling;
that is reported in Phase 9, not tracked as a roadmap edit here.

### Decisions

- **Function rename**: `task_selected_for_worktree_isolation()` becomes
  `task_is_build_heavy_implement()`. The body tests `phase == "implement"` **and** family
  membership, so the new name is exact. The report flagged the rename as a recommendation needing
  an explicit planning decision; this is that decision. Leaving the old name on a function with no
  remaining connection to worktrees would be a naming lie, and the deployed `.claude/` copy is
  regenerated, so no external caller is pinned to the old symbol (verified: the only other file
  naming the symbol is `test-dispatch-isolation-fixture.sh`, which is deleted outright).
- **`batch-orchestration-guardrails.md` is edited by this task.** The dispatch excludes it on the
  grounds that the decision-record revision "owns that file and lands first" — that exclusion was a
  concurrency guard against an in-flight sibling, and that sibling is now `completed`. The file's
  four surviving `dispatch-worktree.sh` references are each phrased as explicitly provisional
  ("remains in the tree pending a separately sequenced removal task", "this entry is that
  explanation until the removal lands"). Once the script is gone those sentences are false, and the
  ACCEPTANCE bar ("no reference to `dispatch-worktree.sh` survives anywhere in the source store")
  cannot be met while they stand. Editing them is this removal's own obligation, discharged in
  Phase 5. This is a planning judgment call, stated here so a reviewer sees it was deliberate.
- **Deleted, not neutralized.** `isolation` and `worktree_path` come out of the `jq -n` row
  templates entirely, not left pinned at `"none"`/`null`. The ACCEPTANCE criterion is absence of
  the keys.
- **The `lake-build-guard.sh` RECORDED DEAD ENDS note is kept, reworded.** The
  `git rev-parse --git-common-dir` finding is a real, reusable investigation outcome about that
  script's own `resolve_project_root()`, independent of whether `dispatch-worktree.sh` exists. Only
  the framing that names a dispatch worktree goes.

## Goals & Non-Goals

**Goals**:

- `scripts/dispatch-worktree.sh`, `scripts/tests/test-dispatch-worktree.sh` and
  `scripts/tests/test-dispatch-isolation-fixture.sh` deleted, with their three `manifest.json`
  entries.
- Zero occurrences of `dispatch-worktree` anywhere under `agent-system/` and in the repo-root
  `.gitignore`.
- A `--dry-run` cycle plan's `dispatch[]` rows carry no `isolation` and no `worktree_path` key.
- `task_is_build_heavy_implement()` survives with exactly one call site (the co-scheduling
  admission rule), and the co-scheduling rule's own tests stay green.
- The two correctness fixes land: a former build-heavy task now participates in contention
  accounting, and `territory.md` states the real posture.
- `context/standards/orchestrator-runtime-files.md` and the repo-root `.gitignore` carry no
  orphaned entries for the two retired runtime paths.
- Full shell harness run shows no NEW failures against `known-failures.txt`; shellcheck clean per
  `context/standards/shell-strict-mode.md`.
- The SKILL.md-ceiling and eager-load numbers are re-measured and reported as measured, including
  the honest statement that the eager-load overage is untouched by this task.

**Non-Goals**:

- Re-opening the removal verdict, or re-litigating how mode 2 is replaced.
- Re-implementing the build-guard-state-file `cp -al` exclusion that lives inside
  `dispatch-worktree.sh` and goes with it. Its loss is expected, not a regression (the dispatch says
  so explicitly); the lake-build-guard work's durable value is its own header conventions, recorded
  dead ends, and `test-lake-build-guard.sh` cases, all untouched.
- Editing the 10 false-positive files enumerated above.
- Moving `eager_load.baseline_bytes` in `orchestrator-context-budget.json`. That is a deliberate,
  reviewed ceiling move and this task produces no eager-load change to justify it.
- Any `.claude/**` edit. `.claude/` is a disposable deploy tree regenerated from the source store.
- Any git push, PR, or `/merge`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deleting `task_selected_for_worktree_isolation()` wholesale silently breaks the landed co-scheduling rule (its sole array reader) | H | M | Phase 2 renames-and-narrows; its verification asserts exactly one surviving call site and re-runs the co-scheduling test group |
| Deleting Group 30 wholesale strands Groups 31/32, which reuse its `orchestrate-build-dispatch.sh`/`update-task-status.sh` stubs | H | H | Phase 6 relocates those two stubs into a retained, clearly-labelled shared setup block before deleting the worktree-specific cases, and re-runs the whole suite |
| `worktree_land_blocked` left referenced after its initialization is deleted is a hard `set -u` failure on the live implement path, not a silent no-op | H | M | Phase 3 deletes the consumer branch and its body in the same edit as the initialization, and verifies with `bash -n` plus a grep for zero surviving occurrences |
| Leaving `build_contended_manifest()`'s exclusion or `territory.md` unchanged (as "just docs") leaves a live false negative and a wrong contract document | H | M | Both are called out as correctness fixes with their own tasks and verification, not folded into a cleanup bullet |
| Skipping the four unnamed test files leaves two suites unable to start (`require_file`/`cp` against a deleted script) and two asserting unreachable row shapes, producing NEW harness failures | H | M | Phases 6 and 7 cover all four with located line ranges; Phase 9 diffs the full run against `known-failures.txt` |
| The ~950 B SKILL.md trim does not by itself clear the 20,000 B ceiling (21,317 B now, leaving ~370 B over) | M | H | Phase 5 measures after the trim and, if still over, does a small in-file wording-economy pass over passages already covered by `orchestrate-state-machine.md`/`handoff-schema.md`; Phase 9 reports the real number either way |
| Claiming an eager-load improvement this task cannot produce | M | M | Verified during planning that no touched file is eager-loaded; Phase 9 reports the two gates separately and states the eager-load overage is out of this task's reach |
| Editing `batch-orchestration-guardrails.md` collides with another writer | M | L | Prerequisite task is `completed`; Phase 5 re-checks `git status` for a concurrent modification before editing and scopes its commit to named files only |
| A full 82-suite harness run is long and invites an unbounded wait | L | M | Phases 1 and 9 background the run and poll per `context/patterns/bounded-build-waiter.md` (hard timeout, `kill -0` writer liveness, one waiter per log) |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6, 7 | 2, 3, 4 |
| 4 | 8 | 2, 3, 4, 5, 6, 7 |
| 5 | 9 | 8 |

Phases within the same wave touch disjoint files and can execute in parallel.

### Phase 1: Baseline capture and footprint re-derivation [COMPLETED]

**Goal**: Establish the pre-removal measurements and the verified edit set, so Phase 9 can report
real deltas and distinguish NEW harness failures from pre-existing ones.

**Tasks**:

- [x] Confirm the source store: read `source_dir` for `core` from `.claude-extensions.json` and
      confirm it is `agent-system/extensions/core`. Every edit below is relative to it unless the
      path is explicitly the repo-root `.gitignore`.
- [x] Re-derive the literal dependency set: `grep -rln "dispatch-worktree" agent-system/` plus the
      repo-root `.gitignore`. Expect exactly the 15 source-store files named in this plan plus
      `.gitignore`. Record any file this plan does not name and stop to reconcile before editing.
- [x] Re-derive per-file counts with `grep -ci "worktree"` over each named file; note the numbers in
      the implementation summary rather than trusting the dispatch's 228/20 figures.
- [x] Record the pre-removal byte baselines: `wc -c agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
      and `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`.
      Planning-time values to diff against: 21,317 B and 67,980 B.
- [x] Capture the pre-removal harness baseline: run `scripts/tests/run-all.sh --jobs auto` in the
      background, waiting per `context/patterns/bounded-build-waiter.md`. Save the roster/tally
      output to a scratch log and record which suites fail and how each is classified against
      `scripts/tests/known-failures.txt`.
- [x] Confirm no stray tracked runtime-path instance exists:
      `git ls-files -- '**/.worktree-registry*' '.orchestrate-worktrees/**'` returns empty.

**Timing**: 0.75 hours (mostly waiting on the harness run)

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This plan asserts a 16-path edit set (15 source-store files + the repo-root
`.gitignore`) and the specific byte baselines 21,317 B / 67,980 B. Confirm all three by the greps
and measurements in this phase's tasks before any edit; a mismatch means the footprint moved and
this plan's per-phase file lists must be reconciled first.

**Files to modify**:

- none planned — this phase is measurement and re-derivation only

**Verification**:

- The literal-dependency grep returns exactly this plan's named set, with no unnamed file.
- A baseline harness result is recorded, with each failing suite classified EXPECTED or NEW against
  `known-failures.txt`.
- Both byte baselines are recorded as measured numbers.

---

### Phase 2: `orchestrate-cycle-plan.sh` — rename, narrow, and fix contention accounting [COMPLETED]

**Goal**: Remove all worktree provisioning and row-field wiring from the cycle planner while keeping
the build-heavy family predicate alive for the co-scheduling rule, and fix the now-wrong contention
exclusion.

**Tasks**:

- [x] Rename `task_selected_for_worktree_isolation()` to `task_is_build_heavy_implement()` at its
      definition (~line 1834) and at the one surviving call site (~line 1914, inside the Mode 2
      co-scheduling admission loop).
- [x] Rewrite the `BUILD_HEAVY_TASK_TYPES` hoisting comment block (~lines 1805–1832): drop the "DUAL
      meaning: (a) ... (b)" framing entirely — only the co-scheduling membership meaning remains —
      and correct the hoisting note's "plus the three pre-existing isolation call sites further down
      this function" clause to name the single surviving call site. **Keep** the
      `MUST STAY HOISTED HERE` warning itself; it is still true and still load-bearing.
- [x] Delete the dispatch-row schema documentation for `isolation`/`worktree_path` in the header
      comment block (~lines 200–251), including the `worktree_path}` entry in the row-shape sketch
      (~line 203).
- [x] Delete the `build_contended_manifest()` exclusion call (~line 2266,
      `task_selected_for_worktree_isolation "$cg" ... && continue`) and the comment above the
      function that documents it (~line 2214). **This is the correctness fix**: under a shared tree a
      former build-heavy task does share the working copy, so the exclusion produced a false negative
      that hid a real `file_scope` collision from `git-commit-scoped.sh`'s refusal check.
- [x] Delete the `--dry-run` row builder's `dry_isolation` computation (~lines 2485–2488) and remove
      the `isolation` and `worktree_path` keys from its `jq -n` template (~lines 2489–2490),
      including the now-unused `--arg iso`.
- [x] Delete the live-path provision block (~lines 2643–2671) in full: the `--worktree` header
      comment, `task_isolation`/`task_worktree_path` initialization, the
      `dispatch-worktree.sh provision` call via `run_capture_stdout`, the provision-failure
      `out_deferred_rows` branch, and `build_args+=(--worktree ...)`.
- [x] Delete the live row builder's `isolation`/`worktree_path` wiring (~lines 2857–2863): the
      comment, `task_worktree_path_json`, and both keys plus `--arg iso`/`--argjson wtp` from the
      `jq -n` template.
- [x] Grep the file for `worktree`, `isolation`, `task_selected_for_worktree_isolation`,
      `dry_isolation`, `task_isolation` — expect zero hits.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: The line numbers above are planning-time positions and will shift as earlier
edits land. Locate each site by its grep anchor (the identifier or the `jq -n` template), not by
line number, and re-grep after each edit.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - rename-and-narrow the family predicate, delete the header row-schema docs, the contention exclusion, both row builders' isolation fields, and the live provision block

**Verification**:

- `bash -n` clean; `shellcheck` clean per `context/standards/shell-strict-mode.md` (classification
  unchanged by this edit).
- `grep -ci "worktree" scripts/orchestrate-cycle-plan.sh` returns 0.
- `grep -c "task_is_build_heavy_implement" scripts/orchestrate-cycle-plan.sh` returns exactly 2
  (one definition, one call site).
- A `--dry-run` cycle plan run emits `dispatch[]` rows for which
  `jq '.dispatch[0] | has("isolation"), has("worktree_path")'` is `false, false`.
- `scripts/tests/test-orchestrate-cycle-plan.sh` is expected RED at this point (its Group 30/31
  assertions still reference the removed fields); Phase 6 closes it. Record the failure set so
  Phase 6 can confirm it clears.

---

### Phase 3: `orchestrate-cycle-postflight.sh` — delete WORK (f0) and fix the `implemented` arm [COMPLETED]

**Goal**: Remove the land/release/prune stage that can no longer have anything to land, and remove
its consumer branch so the live implement path cannot reference an uninitialized variable under
`set -u`.

**Tasks**:

- [x] Delete the entire WORK (f0) block (~lines 811–859): its `─── WORK (f0) ───` banner and header
      comment, the `worktree_land_blocked=false` / `worktree_land_reason=""` initializations, the
      `dispatch-worktree.sh path`/`land`/`release`/`prune` invocations, the blocked/fail-open
      branches, and the `[dry-run] would land/release...` notice. The block ends immediately before
      the `─── WORK (f): status transition ───` banner; keep that banner and everything after it.
- [x] In the `implemented)` status-transition arm (~lines 941–948), delete the
      `if [ "$worktree_land_blocked" = "true" ]; then` branch and its body, and promote the
      following `elif skill_gate_completion_claim ...; then` to a plain `if`. Keep the
      `skill_gate_completion_claim` comment block above it intact.
- [x] Leave the ~line 1342 comment alone: it describes the *surviving* contended-path commit refusal
      (`git-commit-scoped.sh --task`), i.e. the mechanism that replaces isolation. It names no
      deleted script. Optional one-word clarity reword is permitted but is not part of the removal.
- [x] Grep for `worktree`, `worktree_land_blocked`, `worktree_land_reason`, `dispatch-worktree` —
      expect zero hits.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: The block is asserted to span ~lines 811–859 with a single consumer at
~941–948. Confirm the exact boundaries by locating the two `───` banners and by grepping
`worktree_land_blocked` for *all* its occurrences before deleting, so no consumer is missed.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - delete the WORK (f0) land/release/prune block and the `worktree_land_blocked` branch in the `implemented` arm

**Verification**:

- `bash -n` clean; `shellcheck` clean.
- `grep -c "worktree" scripts/orchestrate-cycle-postflight.sh` returns 0 — this is the specific check
  that no surviving caller shells out to a missing script anywhere on the implement path.
- The `implemented)` arm's first conditional is a plain `if skill_gate_completion_claim`.
- `scripts/tests/test-orchestrate-cycle-postflight.sh` is expected RED here (its setup still
  `require_file`s the script); Phase 7 closes it.

---

### Phase 4: `orchestrate-build-dispatch.sh` — remove the `--worktree` flag and its section [COMPLETED]

**Goal**: Remove the flag no caller passes any more, and the dispatch-file section it rendered.

**Tasks**:

- [x] Delete the `--worktree PATH` header-comment block (~lines 80–88).
- [x] Delete the `[--worktree PATH]` usage line (~line 119).
- [x] Delete the `worktree_path=""` default (~line 155) and the `--worktree)` case arm (~line 172).
      Confirm an unrecognized `--worktree` now falls through to the script's existing
      unknown-argument handling rather than being silently ignored.
- [x] Delete the entire `if [ -n "$worktree_path" ]; then ... fi` block rendering the
      `## Isolated Working Tree` section (~lines 480–498).
- [x] Grep for `worktree` and `Isolated Working Tree` — expect zero hits.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: Four edit sites are asserted (header comment, usage line, arg parsing, render
block). Re-grep `worktree` after the edits to confirm none remains, rather than assuming the four
sites were exhaustive.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - delete the `--worktree` flag (header, usage, default, case arm) and the `## Isolated Working Tree` render block

**Verification**:

- `bash -n` clean; `shellcheck` clean.
- `grep -ci "worktree" scripts/orchestrate-build-dispatch.sh` returns 0.
- A dispatch file built for an `implement` phase contains no `## Isolated Working Tree` section and
  is otherwise byte-identical (modulo `dispatch_seq`) to one built before this phase.
- `scripts/tests/test-orchestrate-build-dispatch.sh` Group 15 is expected RED here; Phase 7 closes
  it.

---

### Phase 5: Prose and contract reconciliation [COMPLETED]

**Goal**: Bring every surviving document to the post-removal truth — delete live constraints derived
from the removed mechanism, keep genuine history as history, and fix the two factually wrong
passages.

**Tasks**:

- [x] `skills/skill-orchestrate/SKILL.md`: in the Move 2 **MUST NOT** block, **keep** the opening
      general sentence ("no field of a `dispatch[]` or `aux_dispatch[]` row is ever forwarded as an
      Agent-tool argument unless this section names it ... `agent` and `model` only") — it still has
      force for `agent`/`model` and any future row field. Delete only from "In particular, never
      forward a row's `isolation`/`worktree_path` fields..." through "...complementary rationale."
      (≈950 B).
- [x] Re-measure `wc -c skills/skill-orchestrate/SKILL.md`. If still over the 20,000 B ceiling (it
      likely will be, ~370 B over by estimate), do a small wording-economy pass **inside this same
      file** over passages already covered by `docs/architecture/orchestrate-state-machine.md` and
      `docs/architecture/handoff-schema.md`, removing no operational content. Record the final
      number; do not assume the ceiling cleared.
- [x] `scripts/lake-build-guard.sh`: at ~lines 58–60, reword to drop the now-dead
      `dispatch-worktree.sh` example while **keeping the standing convention itself** ("this guard's
      own state files must never be hardlink-shared across trees") as a rule for any future
      `cp -al`-cloning consumer. At ~lines 65–66, the claim that `dispatch-worktree.sh` "now does
      this exclusion at its own clone step" asserts a present fact about a script that will not
      exist — delete that clause. At ~lines 82–85 (RECORDED DEAD ENDS), **keep** the
      `git rev-parse --git-common-dir` finding, reworded to drop the "dispatch worktree vs. its main
      tree" framing and state it as a fact about `git rev-parse` and this script's own
      `resolve_project_root()`.
- [x] `context/contracts/territory.md` line 136: rewrite the "Working-tree or build isolation ... is
      a distinct, **unimplemented** remedy **owned elsewhere**" clause. Both halves are now wrong:
      working-tree isolation was implemented and is deliberately removed (not unimplemented), and
      build isolation (mode 2) is implemented in-repo via the co-scheduling admission rule in
      `orchestrate-cycle-plan.sh` (not owned elsewhere). State the current posture: a single shared
      working tree for every dispatch, with build contention handled by the co-scheduling admission
      rule. **This is a correctness fix** — it directly affects guidance a dispatched agent reads.
- [x] `context/standards/orchestrator-runtime-files.md`: delete the
      `.orchestrate-worktrees/<task_number>-<seq>/` row and the
      `specs/.worktree-registry/<task_number>-<seq>.json` row from the Class Table outright,
      following that file's own "Retired conventions" precedent for a zero-writer convention with no
      accumulation risk. Then edit the `specs/.contention-manifest/{session_id}.json` row to remove
      the clause "excluding any task selected for worktree isolation (it has no shared working copy
      to contend over)" — the documentation form of the same now-false exclusion fixed in Phase 2.
      Leave the rest of that row, including its `.gitignore` cross-reference, intact.
- [x] `context/patterns/batch-orchestration-guardrails.md` (see the Decisions note for why this file
      is in scope): reconcile its four `dispatch-worktree.sh` references. At ~line 1436 and in the
      `## Related Documents` entry at ~line 1612, the script and the selection predicate are
      described as superseded but "remaining in the tree pending a separately sequenced removal
      task" — rewrite to past tense: the layer was implemented and has been removed. At ~line 1464,
      the destructive-release incident row is genuine recorded history and must be **kept**, with
      only its naming of a live script reworded. At ~line 1555, the hardlink-over-symlink subsection
      is already labelled "Historical" but states "The script is not deleted by this verdict — its
      removal is a separately sequenced task"; update that sentence to record that the removal has
      landed while keeping the rationale itself. Before editing, run `git status --short` on this
      file to confirm no concurrent writer.
- [x] Across all of the above: use durable anchors (filenames, section headings, decision-record
      names) — never task numbers — per `.claude/rules/no-task-references-in-deliverables.md`, since
      every file here lives outside `specs/**`.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: Six files and the specific line anchors above are asserted, along with the
≈950 B SKILL.md trim and a ~370 B residual overage. Confirm each anchor by grep before editing, and
confirm the trim size and the residual by `wc -c` after, not by this estimate.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - trim the isolation-specific half of the Move 2 MUST NOT block; wording-economy pass if still over ceiling
- `agent-system/extensions/core/scripts/lake-build-guard.sh` - drop the dead-caller references; keep the no-hardlink-sharing convention and the reworded `git rev-parse` dead-end record
- `agent-system/extensions/core/context/contracts/territory.md` - rewrite the now-wrong working-tree/build isolation clause to the current shared-tree + co-scheduling posture
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - delete the two retired runtime-path rows; drop the false exclusion clause from the contention-manifest row
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - convert the four provisional forward-references to the landed-removal past tense, keeping the recorded incident and the hardlink rationale as history

**Verification**:

- `grep -c "dispatch-worktree" ` over each of the five files returns 0.
- `bash -n` and `shellcheck` clean on `lake-build-guard.sh`; the no-hardlink-sharing convention text
  still present (grep for it).
- `territory.md` no longer contains "unimplemented" or "owned elsewhere" in that bullet.
- `orchestrator-runtime-files.md` Class Table has no `.orchestrate-worktrees`/`.worktree-registry`
  row, and the contention-manifest row no longer contains "excluding any task selected".
- `batch-orchestration-guardrails.md` retains its destructive-release incident row and its
  hardlink-over-symlink rationale (grep for both) while naming no live `dispatch-worktree.sh`.
- `wc -c` on SKILL.md recorded; whether it is under 20,000 B stated as a measured fact.

---

### Phase 6: `test-orchestrate-cycle-plan.sh` — Group 30 removal with stub preservation [COMPLETED]

**Goal**: Remove the worktree-isolation test coverage without stranding the two surviving groups
that reuse Group 30's non-worktree stubs, and replace the deleted exclusion test with a positive
test of the corrected contention behavior.

**Tasks**:

- [x] **Before deleting anything**, extract Group 30's two non-worktree stub-staging blocks — the
      `orchestrate-build-dispatch.sh` stub with its `G30_BUILD_ARGV_LOG` (~lines 4182–4190) and the
      `update-task-status.sh` stub (~lines 4192–4196) — into a retained, clearly-labelled shared
      setup block positioned where Group 30 was, immediately above Group 31. Groups 31 and 32 both
      document that they reuse these persisting stubs; without this step both break. Rename the log
      variable to something not tied to a deleted group (e.g. `SHARED_BUILD_ARGV_LOG`) and update
      every surviving reference.
- [x] Delete Group 30 in full (~lines 4090–4282): its banner and header comment, Cases A/B/C
      (dry-run selection predicate), the inline `dispatch-worktree.sh` stub heredoc and
      `WT_ARGV_LOG` (~lines 4164–4180), Cases D/F (live provisioning and `--worktree` argv
      assertions), and Case E (provision-failure deferral).
- [x] Rewrite Group 31's header comment (~lines 4284–4288) so it references the new shared setup
      block instead of "Group 30's already-active dispatch-worktree.sh/... stubs", and drop the
      "every task number below avoids 3005, the one number Group 30's dispatch-worktree.sh stub is
      coded to fail provision for" caveat, which no longer applies.
- [x] Delete Group 31 Case E (~lines 4439–4465), which asserts the now-removed — and now incorrect —
      exclusion of an isolated task from contention.
- [x] **Add a replacement case** in its place asserting the corrected behavior: a `lean4` `implement`
      candidate's declared `file_scope` now **does** participate in contention accounting. Use a
      concrete-vs-concrete overlapping pair (not the glob-vs-concrete shape the deleted case used)
      so the pre-existing glob blind spot documented in Group 31's own header cannot mask the
      result, and assert the manifest file is written and names both tasks. Derive the exact expected
      manifest shape by running the fixture, not by assumption.
- [x] Rewrite Group 32's header comment (~lines 4520–4528): it currently says it "reuses Group 30's
      dispatch-worktree.sh/orchestrate-build-dispatch.sh/update-task-status.sh stubs" and repeats
      the 3005 caveat. Point it at the new shared setup block and drop the worktree framing. Group
      32's assertion bodies need no change (verified: they never reference worktrees, and every
      fixture already declares `"file_scope": []`).
- [x] Grep the file for `worktree`, `isolation`, `WT_ARGV_LOG`, `G30_` — expect zero hits apart from
      the suite's own unrelated sandbox-isolation naming, if any; confirm each remaining hit is
      unrelated before accepting it.

**Timing**: 1.75 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: Group 30 is asserted to span ~lines 4090–4282 and to stage exactly three
stubs, with Groups 31 and 32 depending on two of them. Confirm the stub inventory by grepping
`\.claude/scripts/` heredoc writes inside the group, and confirm the dependency by running the suite
after the extraction but before the deletion.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - extract Group 30's two non-worktree stubs into a shared setup block, delete Group 30 and Group 31 Case E, add a positive contention case for a former build-heavy task, reword Groups 31/32 headers

**Verification**:

- `bash -n` clean; `shellcheck` clean.
- The suite runs green end to end (`bash scripts/tests/test-orchestrate-cycle-plan.sh`), with
  Groups 31 and 32 passing — the direct proof the stub extraction worked.
- The new contention case passes and asserts a manifest entry naming both tasks.
- `grep -c "dispatch-worktree" ` returns 0.

---

### Phase 7: Remaining test-suite reconciliation [COMPLETED]

**Goal**: Make the three other affected suites start and pass against the removed layer.

**Tasks**:

- [x] `scripts/tests/test-orchestrate-cycle-postflight.sh`: remove `dispatch-worktree.sh` from both
      copy-lists — the top-level `require_file` loop (~line 44) and `setup_sandbox`'s `cp` loop
      (~line 69). These are hard dependencies: left in place the suite cannot start at all.
- [x] Same file: delete the `phase 7 (non-isolated regression)` micro-check (~lines 1905–1910),
      which asserts the absence of worktree notices and names the deleted script in its failure
      message.
- [x] Same file: delete the entire Phase 7 group (~lines 1912–2094): its banner and header comment,
      the `provision_worktree_fixture` and `worktree_path_for` helpers, and all three cases (clean
      land, merge conflict, `specs/**` refusal). The block ends immediately before the
      `# task-ref-ok:begin` comment that precedes Phase 9; keep that comment and everything after
      it. Check whether `commit_specs_only()` (defined inside this block) is used by any surviving
      case before deleting it.
- [x] `scripts/tests/test-orchestrate-build-dispatch.sh`: delete Group 15 in full (~lines 851–900):
      banner, header comment, Case A (section absent), Case B (section present with the flag), Case
      C (byte-identical proof), and the `NO_WORKTREE_DISPATCH_FILE`/`WORKTREE_FIXTURE_PATH`
      variables. Keep the unrelated "ISOLATION CONTRACT" sandbox-isolation naming at ~lines 15/95 —
      that is a guarantee about the test harness itself, not about this feature.
- [x] `scripts/tests/test-lake-build-guard.sh`: reword the two comments at ~lines 1018 and ~1032
      that name `dispatch-worktree.sh` while contrasting their own raw `cp -al` approach. No test
      logic changes — these cases never invoked the script.
- [x] Grep all three files for `dispatch-worktree` — expect zero hits.

**Timing**: 1.25 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: Line ranges and the claim that `test-orchestrate-build-dispatch.sh`'s only
real work is Group 15 (its other 20-odd hits being unrelated harness-isolation naming) are
assertions. Confirm by grepping each file and reading each remaining hit's surrounding context
before accepting it as unrelated.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - drop `dispatch-worktree.sh` from both copy-lists, delete the non-isolated micro-check and the whole Phase 7 worktree group with its two helpers
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - delete Group 15 (`--worktree` flag / Isolated Working Tree section) and its fixture variables
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` - reword the two comments naming `dispatch-worktree.sh`; no logic change

**Verification**:

- `bash -n` and `shellcheck` clean on all three.
- All three suites run green individually.
- `grep -c "dispatch-worktree" ` returns 0 for each.
- `test-lake-build-guard.sh`'s case count is unchanged from the Phase 1 baseline (comments only).

---

### Phase 8: Delete the three files, the manifest entries, and the `.gitignore` block [COMPLETED]

**Goal**: Perform the outright deletions once nothing references them, and remove the two retired
runtime paths from version-control bookkeeping.

**Tasks**:

- [x] Re-confirm zero remaining references before deleting:
      `grep -rln "dispatch-worktree" agent-system/` should name only the three files about to be
      deleted plus `manifest.json`.
- [x] `git rm` the three files: `scripts/dispatch-worktree.sh` (670 lines),
      `scripts/tests/test-dispatch-worktree.sh` (661 lines),
      `scripts/tests/test-dispatch-isolation-fixture.sh` (471 lines).
- [x] `manifest.json`: remove the three file-listing entries — `"dispatch-worktree.sh"` (~line 94),
      `"tests/test-dispatch-worktree.sh"` (~line 199),
      `"tests/test-dispatch-isolation-fixture.sh"` (~line 200). Validate the file still parses
      (`jq . manifest.json >/dev/null`) and that no array is left with a trailing comma.
- [x] Repo-root `/home/benjamin/.config/nvim/.gitignore` (**not** the source store — this is a
      directly-tracked repository file, distinct from
      `agent-system/extensions/core/root-files/.gitignore`): delete the four-line comment block plus
      the `/.orchestrate-worktrees/` and `**/.worktree-registry/` patterns at ~lines 55–60. Leave the
      adjacent `**/.contention-manifest/` block and everything else untouched.
- [x] Confirm `grep -rn "dispatch-worktree\|orchestrate-worktrees\|worktree-registry" agent-system/ .gitignore`
      returns nothing.

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4, 5, 6, 7

**Verification Tier**: full

**Scope Hypothesis**: Three deletions, three manifest entries, and a six-line `.gitignore` block are
asserted. Confirm the manifest entry positions by grep (not line number) and the `.gitignore` block
boundaries by reading the surrounding comment, so the neighbouring contention-manifest block is not
caught.

**Files to modify**:

- `agent-system/extensions/core/scripts/dispatch-worktree.sh` - deleted outright
- `agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh` - deleted outright
- `agent-system/extensions/core/scripts/tests/test-dispatch-isolation-fixture.sh` - deleted outright
- `agent-system/extensions/core/manifest.json` - remove the three file-listing entries for the deleted files
- `.gitignore` - delete the per-dispatch worktree-isolation comment block and its two ignore patterns

**Verification**:

- The three files are absent from the working tree and staged as deletions.
- `jq . agent-system/extensions/core/manifest.json` parses clean and contains no
  `dispatch-worktree`/`test-dispatch-isolation-fixture` entry.
- `grep -rn "dispatch-worktree\|orchestrate-worktrees\|worktree-registry" agent-system/ .gitignore`
  returns nothing — the ACCEPTANCE bar's "no reference survives anywhere in the source store".
- `git status --short` shows only this task's intended paths.

---

### Phase 9: Verification, gate re-measurement, and honest reporting [COMPLETED]

**Goal**: Prove the removal is complete and regression-free, re-measure both byte-budget gates, and
report what the removal actually produced rather than what was assumed.

**Tasks**:

- [x] Run the full shell harness: `bash scripts/tests/run-all.sh --jobs auto --fail-on-new`,
      backgrounded and polled per `context/patterns/bounded-build-waiter.md` (hard timeout,
      `kill -0` on the captured PID for writer liveness, one waiter per log — never
      `ps | grep`/`pgrep -f`). Diff the result against the Phase 1 baseline and against
      `scripts/tests/known-failures.txt`. Any NEW failure not explained by the two intentional
      behavior changes (the contention-accounting fix, the removed row fields) is a real regression
      to fix before closing.
- [x] Run `shellcheck` on every edited `.sh` per `context/standards/shell-strict-mode.md`:
      `orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`, `orchestrate-build-dispatch.sh`,
      `lake-build-guard.sh`, and the four edited test suites. No strict-mode classification changes
      from this removal, so no new Class A/B/C admission question is raised.
- [x] Confirm no surviving caller invokes a deleted subcommand:
      `grep -rn "provision\|\<land\>\|release\|prune" agent-system/extensions/core/scripts/orchestrate-*.sh`
      and confirm every hit is unrelated to the removed layer. In particular confirm
      `orchestrate-cycle-postflight.sh` shells out to no missing script anywhere on the implement
      path.
- [x] Confirm the row shape: a `--dry-run` cycle plan's
      `jq '.dispatch[0] | has("isolation"), has("worktree_path")'` is `false, false`.
- [x] Re-measure and **report** both gates:
      `wc -c agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (pre-removal 21,317 B
      against a 20,000 B ceiling) and
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
      (pre-removal 67,980 B against a 65,950 B baseline). State both numbers as measured.
- [x] Update `context/config/orchestrator-context-budget.json`'s
      `files["skills/skill-orchestrate/SKILL.md"]` `measured_bytes`, `measured_at`, and `derivation`
      with the real post-edit number and a dated note, per that file's own "measured_bytes/measured_at
      fields are informational snapshots and may be refreshed freely" convention. **Do not** move
      `ceiling_bytes`, and **do not** move `eager_load.baseline_bytes` — no touched file is
      eager-loaded, so this task produces no eager-load change, and that baseline is a deliberate,
      reviewed ceiling. Refresh `eager_load.measured_bytes`/`measured_at` only with the measured
      figure and a note recording that the overage predates and is untouched by this removal.
- [x] Reconcile `scripts/tests/known-failures.txt`'s `test-verify-deploy-context-budget.sh` row. Its
      recorded reason is exactly "SKILL.md is over its context-budget ceiling **and** the eager-load
      total is over its recorded baseline". If the SKILL.md half clears, narrow the reason to the
      surviving eager-load half; remove the row only if the suite actually runs green. Use durable
      anchors in the reason/owner fields, never a task number — this file lives under
      `agent-system/**`.
- [x] Record in the implementation summary: the re-derived reference counts, the two measured gate
      numbers with their deltas, the explicit statement that the eager-load overage is out of this
      task's reach (with the reason), the harness NEW-failure verdict, and the expected-not-a-loss
      status of the build-guard `cp -al` exclusion that went with the deleted script.

**Timing**: 1.25 hours (mostly waiting on the harness run)

**Depends on**: 8

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the pre-removal figures 21,317 B and 67,980 B and the
`known-failures.txt` roster captured at planning time. Re-measure all of them live rather than
quoting these; if the harness baseline moved between Phase 1 and here, use the Phase 1 capture as
the comparison point and say so.

**Files to modify**:

- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` - refresh `measured_bytes`/`measured_at`/`derivation` for SKILL.md and the informational eager-load snapshot; leave both ceilings unmoved
- `agent-system/extensions/core/scripts/tests/known-failures.txt` - narrow or remove the `test-verify-deploy-context-budget.sh` row according to the measured outcome

**Verification**:

- `run-all.sh --fail-on-new` reports zero NEW failures against `known-failures.txt`.
- `shellcheck` clean on all eight edited shell files.
- `jq '.dispatch[0] | has("isolation"), has("worktree_path")'` on a `--dry-run` plan is
  `false, false`.
- Both gate numbers appear as measured values in the summary, with the eager-load statement
  explicitly saying this task did not and could not move it.
- `grep -rn "dispatch-worktree" .` (excluding `.git/`, `.claude/`, and `specs/`) returns nothing.
- No task-number reference introduced in any file outside `specs/**`
  (`bash .claude/scripts/check-task-references.sh` if available).

---

## Testing & Validation

- [x] `bash scripts/tests/run-all.sh --jobs auto --fail-on-new` — zero NEW failures against
      `scripts/tests/known-failures.txt`.
- [x] `bash scripts/tests/test-orchestrate-cycle-plan.sh` green, with Groups 31 and 32 passing (the
      proof the stub extraction preserved them) and the new positive contention case passing.
- [x] `bash scripts/tests/test-orchestrate-cycle-postflight.sh` green — it can now even *start*,
      which it cannot while `dispatch-worktree.sh` is in its `require_file` list and deleted.
- [x] `bash scripts/tests/test-orchestrate-build-dispatch.sh` green.
- [x] `bash scripts/tests/test-lake-build-guard.sh` green with an unchanged case count.
- [x] `shellcheck` clean on all eight edited `.sh` files per `context/standards/shell-strict-mode.md`.
- [x] `bash -n` clean on every edited shell file.
- [x] `jq .` parses `manifest.json` and `orchestrator-context-budget.json`.
- [x] A `--dry-run` cycle plan emits `dispatch[]` rows with neither an `isolation` nor a
      `worktree_path` key.
- [x] `grep -rn "dispatch-worktree\|orchestrate-worktrees\|worktree-registry" agent-system/ .gitignore`
      returns nothing.
- [x] Exactly one call site of `task_is_build_heavy_implement()` survives, and the co-scheduling
      admission tests still pass.

## Artifacts & Outputs

- `specs/288_remove_dispatch_worktree_isolation_layer/plans/01_worktree-isolation-layer-removal.md`
  (this plan).
- `specs/288_remove_dispatch_worktree_isolation_layer/summaries/01_worktree-isolation-layer-removal-summary.md`
  — must carry the re-derived reference counts, both measured gate numbers with deltas, the
  eager-load honesty statement, and the harness NEW-failure verdict.
- Three deleted files; twelve edited source-store files; one edited repo-root `.gitignore`.
- Updated `context/config/orchestrator-context-budget.json` snapshot fields and a reconciled
  `scripts/tests/known-failures.txt` row.

## Rollback/Contingency

Every phase commits independently (Phase 6 as a declared `atomic-batch`), so the ordinary recovery
path is `git revert` of the offending phase commit — no working-tree destruction needed, and the
waves are ordered so a revert of a later phase leaves earlier phases coherent.

If an uncommitted working tree must be discarded mid-phase, that is a genuine rollback: take a
snapshot first per `context/contracts/recovery.md`'s rollback rung, then run the destructive
command. This task's declared `file_scope` does not yet include the four test files, the repo-root
`.gitignore`, `batch-orchestration-guardrails.md`, `known-failures.txt`, or
`orchestrator-context-budget.json`, so a default-mode snapshot will refuse the dirty tree by naming
those out-of-scope paths; the rollback rung's `--allow-out-of-scope` override is exactly for that
deliberate whole-tree case. Do **not** use a default-mode snapshot as a routine start-of-phase
checkpoint — for an ordinary defensive checkpoint before risky work use
`bash .claude/scripts/git-snapshot.sh 288 --no-revert`, which is durable without reverting the
working tree.

Highest-risk reversal points, in order: Phase 6 (if the stub extraction turns out to have missed a
dependency, revert and re-extract rather than patching forward), Phase 3 (a missed
`worktree_land_blocked` consumer is a hard `set -u` failure on the live implement path), and Phase 8
(the deletions — recoverable from git history, but only re-do them once the reference grep is
genuinely empty).
