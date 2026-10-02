# Implementation Plan: Task #277

- **Task**: 277 - Make an unresolvable pathspec a hard error in git-commit-scoped.sh instead of a silent WARN-and-drop
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None (the Move 2 isolation-forwarding edge was dropped together with part (a))
- **Research Inputs**: specs/277_git_commit_scoped_worktree_targeting/reports/01_pathspec-drop-hard-error.md
- **Artifacts**: plans/01_pathspec-drop-hard-error.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close the one remaining false-success path in `git-commit-scoped.sh`: a *partial* pathspec drop
whose surviving pathspecs contribute no diff, which today is indistinguishable at the exit-code
level from the ordinary, benign "nothing changed" no-op. The fix adds a dropped-pathspec ledger
to the existing V2 three-way classification loop and a new, narrowly-scoped refusal gate (labeled
**V6**, continuing the script's existing V2/V3/V5 numbering) that emits a fresh exit code `4` and
a loud `ERROR:` naming every dropped path when, and only when, at least one pathspec was
genuinely dropped **and** the commit attempt produced no commit. Regression tests are landed in
two directions: the hard constraint (all-pathspecs-resolve callers, and legitimate partial-drop
callers whose survivors *do* have a diff) is pinned by tests that pass against the *unchanged*
script before any edit, and the new posture is pinned by a dedicated case afterwards.

### Research Integration

The research report changes the shape of this task materially and the plan is built on its
findings, not on the dispatch's premise:

- **The task's literal premise is already fixed.** A V3 post-filter gate
  (`git-commit-scoped.sh:318-326`, added by commit `94256557d`) already refuses with `exit 2`
  when *every* positive pathspec drops. This was reproduced empirically in scratch repos, not
  inferred from comments. Option (c) read literally ("fatal only when EVERY pathspec dropped")
  would therefore implement behavior that already exists and leave the real gap open.
- **The real residual gap** is: some-but-not-all pathspecs drop, and the survivors happen to have
  no working-tree diff. `git commit` then legitimately reports "nothing to commit" (exit 1) —
  byte-identical stdout and exit code to the fully benign zero-drop no-op, differing only in one
  stderr WARN line that no caller inspects.
- **Option (a) is rejected**: the parent-directory-exists heuristic would *not* have caught the
  historical incident, because the discriminating entries are `specs/{NNN}_{slug}/`-shaped and
  their parent `specs/` exists in any scaffold-bearing repo — including the wrong-tree repository
  the incident actually hit. More logic, narrower payoff.
- **Option (b) is rejected**: an opt-in optional-pathspec marker means touching or knowingly
  auditing ~50 call sites (3 live scripts, ~47 documented SKILL.md/agent snippets) for a payoff
  identical to corrected (c), which needs no CLI-contract change at all.
- **Adopted: corrected option (c)** — refuse when `dropped_count > 0 AND the commit attempt
  produced no commit`. Smallest and most auditable refusal surface of the three: one array, one
  predicate, one new exit code, zero caller-contract changes.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Add a dropped-pathspec ledger to the V2 classification loop, incrementing **only** in the
  case-3 (genuinely-unmatched) branch.
- Add the V6 refusal gate: distinct exit code `4` plus a loud `ERROR:` naming every dropped path,
  fired only when at least one pathspec dropped and no commit was produced.
- Document exit code `4` and the V6 gate in the script's own header tables, alongside V2/V3/V5.
- Pin the chosen posture, and both halves of the hard constraint, as explicit named test
  assertions in `test-git-commit-scoped.sh` verified via `git log`/`git show`, never exit code
  alone.
- Record the caller-escalation scope decision explicitly in this plan and in the standards doc,
  so the known residual is a documented choice rather than an unnoticed omission.

**Non-Goals**:
- Changing any caller to branch on the new exit code. See the scope decision below — this is a
  deliberate, recorded exclusion, not an oversight.
- Changing behavior for any caller whose pathspecs all resolve (the dispatch's HARD CONSTRAINT).
- Changing the `--` pathspec invocation shape, the V2 deletion handling, the V3 or V5 gates, or
  the ephemeral-exclude injection.
- Any write to `.claude/**` (a disposable deploy tree) or to the BimodalLogic repository (read-only
  historical evidence).

### Scope Decision: Callers Are NOT Changed In This Task

The research names this as the one open question, and it is resolved here explicitly rather than
left implicit.

**Decision: fix the script and its tests; do not change any caller.**

Rationale:
1. The task's declared `file_scope` is exactly `git-commit-scoped.sh` and
   `tests/test-git-commit-scoped.sh`. The dispatch's HARD CONSTRAINT is phrased about *the
   script's* behavior.
2. Every caller wraps the invocation as `cmd || echo "WARN: ...(non-blocking)"`. Because `A || B`
   yields `B`'s status, any nonzero exit — 1, 2, 3, or the new 4 — already collapses to 0 for the
   caller's control flow. A caller-side `$?` branch is therefore a *separate* change with its own
   blast radius across the live scripts, not a finishing touch on this one.
3. One of the recipe-bearing files a caller-side change would most naturally touch
   (`skills/skill-git-workflow/SKILL.md`) is in a concurrent sibling's declared `file_scope` this
   same cycle. Editing it here would be a territory collision.

**Acknowledged residual**: with callers unchanged, the fix's practical effect is a loud, named
`ERROR:` on stderr (replacing today's indistinguishable generic `NOTE:`) plus a machine-readable
exit code that no caller yet reads. That is a real improvement in observability and a correct,
pinned script-level contract — but it does **not** by itself halt a caller mid-flight. Phase 4
records this in the standards doc so a future caller-escalation task inherits the finding instead
of rediscovering it.

### Design Decision: The V6 Predicate Stays Deliberately Small

The V6 predicate keys off `commit_exit != 0 AND dropped_count > 0`. It deliberately does **not**
try to distinguish "nothing to commit" from "git commit genuinely failed" by parsing
`commit_output`. Rationale: the ranking criterion in the dispatch is *how small and auditable the
refusal surface is*. Both sub-cases are already nonzero, already loud, and already swallowed
identically by every current caller, so splitting them buys nothing and adds an output-parsing
dependency on git's wording. The `ERROR:` message states both facts (a drop occurred; no commit
was produced) so a reader loses no information.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Ledger increments in the V2 **case-2** (already-staged-deletion) branch instead of case-3 only, spuriously failing routine `git rm`/`git mv` commits | H | M | Phase 2 touches only the case-3 `else` branch. Phase 3 re-runs T8/T9/T10 (deletion-only, mixed delete+modify, in-scope rename) as the explicit guard; these must stay green. |
| Reusing exit code 1, 2, or 3 makes the new condition indistinguishable from an existing documented meaning | M | L | Use `4`, previously unused (3 is reserved by the V5 contended-path refusal), and document it in the header table in the same phase. |
| Empty-array expansion under `set -euo pipefail` (`"${dropped[@]}"` on an empty array) aborts the script on bash < 4.4 | H | M | Guard every expansion behind a `[ "${#dropped[@]}" -gt 0 ]` test; never expand the array unguarded. Phase 3's full-suite run exercises the zero-drop path on every T-case. |
| The hard constraint silently regresses (an all-resolve caller starts seeing exit 4) | H | L | Phase 1 lands the constraint-pinning tests *before* the script is touched and proves they pass against the unchanged script, so a Phase 2 regression is attributable, not ambiguous. |
| Line numbers cited from research have shifted | L | M | Every phase re-reads the target region immediately before editing (also required by the cycle's concurrency note); anchor edits on the V2/V3 comment labels and the `commit_exit` assignment, not on line numbers. |
| An edit lands in `.claude/**` (disposable deploy tree) and is silently wiped | H | L | All edit targets in this plan are `agent-system/extensions/core/**` source-store paths. Verified against `.claude/rules/source-store-deploy-boundary.md`. |
| A task-number reference leaks into a deliverable file outside `specs/**` | M | M | Script, test, and doc edits cite durable anchors only — the gate label `V6`, exit code `4`, filenames. Never "task 277". Enforced by `validate-no-task-references.sh` at write time. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is fully sequential: each phase's
verification is the precondition for the next phase's meaningfulness.

### Phase 1: Pin the Hard Constraint Before Touching the Script [COMPLETED]

**Goal**: Land two regression cases in `test-git-commit-scoped.sh` that pass against the
**unchanged** script, pinning both halves of the dispatch's HARD CONSTRAINT so any Phase 2
regression is unambiguous. These are the dispatch's test items (iii) and the research's cases A
and C.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` immediately
      before editing (concurrency note), confirming the T-series still ends at T10 and the
      `build_repo` / `add_ephemeral` / `run_commit` / `pass` / `fail` harness is as described. *(completed)*
- [x] Add **T11** (research case A — existing V3 behavior, previously untested): a `covered`
      scratch repo where **every** positive pathspec is unmatched (e.g.
      `specs/998_absent_task/` plus `specs/998_absent_task/report.md`). Assert `rc == 2`, HEAD
      unchanged (`rev-list --count` identical before/after), and stderr matching the V3
      `zero positive pathspec entries remain` ERROR. This is a regression guard for behavior that
      already exists and must survive Phase 2 untouched. *(completed)*
- [x] Add **T13** (research case C — the legitimate partial drop that must keep succeeding): a
      `covered` scratch repo where one pathspec is unmatched (a not-yet-produced artifact file,
      e.g. `specs/999_probe/plans/01_absent.md`) but a survivor **does** have a real diff
      (append a line to `specs/999_probe/file.txt`). Assert `rc == 0`, HEAD advanced by exactly 1,
      `git show --name-only HEAD` contains `specs/999_probe/file.txt`, and a `WARN:` names the
      dropped path. Verified via `git log`/`git show`, never exit code alone, per the suite's own
      stated bar. *(completed)*
- [x] Number the new cases T11 and T13 (leaving T12 for Phase 3's new-posture case, so the
      three new cases read in the research's A/B/C order), following the existing
      `# =====` header-comment idiom and `pass`/`fail` message style verbatim. *(completed)*
- [x] Run the suite: `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`.
      T11 and T13 must **pass against the unchanged script**. If either fails, stop — the
      premise of Phase 2's constraint is wrong and the plan needs revision before proceeding.
      *(completed: 25 passed, 0 failed, including T11 and T13)*
- [x] Commit this phase's single file with an explicit file pathspec (never a directory or glob). *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes the T-series currently ends at **T10**, that the V-series
(`V1`-`V8`, the `--task` contended-path cases) follows it, and that `build_repo covered` seeds
exactly `specs/999_probe/file.txt` as its one tracked file. Confirm by re-reading the file's case
headers (`grep -n '^# [TV][0-9]*:'`) and the `build_repo` body before adding cases; if the
numbering has moved, continue from the actual highest T-number rather than forcing T11/T13.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - add cases T11 and T13

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` exits 0, and its
  summary line shows two more passes than before this phase with zero failures.
- T11's and T13's `[PASS]` lines are present in the output by name.
- `git diff --staged` shows changes confined to the one test file.

---

### Phase 2: Add the Dropped-Pathspec Ledger and the V6 Refusal Gate [COMPLETED]

**Goal**: Implement corrected option (c) in `git-commit-scoped.sh`: record every genuinely-dropped
pathspec, and refuse with a new exit code `4` and a loud `ERROR:` when a drop occurred and no
commit was produced. Leave every all-resolve path byte-identical.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/git-commit-scoped.sh` immediately before
      editing (concurrency note), locating the V2 classification loop by its `Case 3 — genuinely
      unmatched` comment and the commit attempt by its `commit_exit` assignments. *(completed)*
- [x] Declare `dropped_pathspecs=()` alongside the existing `filtered_pathspecs=()` /
      `add_pathspecs=()` declarations. *(completed)*
- [x] In the V2 loop's **case-3 branch only** (the `else` carrying the existing
      `WARN: ... dropping unmatched pathspec` message), append `$p` to `dropped_pathspecs`.
      Do **not** touch the case-1 or case-2 branches — a one-line misplacement into case 2 breaks
      the already-staged-deletion path the V2 three-way split exists to protect. *(completed)*
- [x] Add the V6 gate immediately after the existing
      `if [ "$commit_exit" -ne 0 ]; then echo "NOTE: Nothing to commit..."` block, before the
      final `exit "$commit_exit"`:
      - Fire only when `[ "$commit_exit" -ne 0 ] && [ "${#dropped_pathspecs[@]}" -gt 0 ]`.
      - Emit a loud `ERROR: git-commit-scoped.sh refuses to report success ...` line stating both
        facts (one or more pathspecs were dropped as unmatched; the commit attempt produced no
        commit) and naming **every** dropped path.
      - `exit 4`.
      - Guard the array expansion behind the `${#dropped_pathspecs[@]}` test so `set -u` never
        sees an unguarded empty-array expansion. *(completed)*
- [x] When `${#dropped_pathspecs[@]}` is zero, fall through to the existing `exit "$commit_exit"`
      with today's exact `NOTE: Nothing to commit or git commit failed (non-blocking)` wording —
      the hard constraint, unchanged. *(completed)*
- [x] Add `4` to the script header's **Exit codes** table, describing the V6 condition and noting
      that it is nonzero-but-non-blocking under every current caller's `|| echo WARN` idiom. *(completed)*
- [x] Add a `V6` entry to the header's **Safety gates** block, in the same voice as V2/V3/V5,
      stating the posture, why the drop-count-alone framing is insufficient (V3 already covers the
      all-dropped case), and why the predicate deliberately does not parse `commit_output`. *(completed)*
- [x] Cite durable anchors only in all new comments — the gate label `V6`, exit code `4`,
      filenames. No task-number references (this file is outside `specs/**`). *(completed)*
- [x] Run `bash -n` on the script, then
      `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`: T1-T10,
      T11, T13 and V1-V8 must all still pass. *(completed: 25 passed, 0 failed)*
- [x] Reproduce the gap case manually in a scratch repo (mirroring the research's method: a
      `mktemp -d` repo with the script plus `deploy-root-guard.sh`, `task-lock.sh`,
      `lib/common.sh` copied into `.claude/scripts/`): one dropped pathspec, survivors with no
      diff. Confirm exit `4` and the `ERROR:` naming the dropped path. Confirm the zero-drop
      no-diff case still exits `1` with today's `NOTE:` wording. *(completed: verified in a mktemp -d scratch repo)*
- [x] Commit this phase's single file with an explicit file pathspec. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Research locates the V2 loop at lines 283-316, the V3 post-filter at
318-326, the commit attempt at 428-443, and the exit-code table at 53-62 of a 451-line file, and
asserts exit codes 0-3 are the only ones currently spoken for. Confirm all five by re-reading the
file and `grep -n 'exit [0-9]'` before editing; anchor every edit on the surrounding comment
labels rather than on these line numbers, which may have shifted.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - `dropped_pathspecs` ledger in the
  V2 case-3 branch; V6 gate after the commit attempt; exit code `4` and the V6 entry added to the
  two header tables

**Verification**:
- `bash -n agent-system/extensions/core/scripts/git-commit-scoped.sh` is clean.
- The full suite exits 0 with zero failures; T8, T9, T10 (deletion, mixed delete+modify, rename)
  are explicitly among the passes — the case-2 misplacement guard.
- Scratch-repo repro: partial drop + no survivor diff exits `4` with the `ERROR:` naming the
  dropped path; zero drop + no diff exits `1` with the unchanged `NOTE:`; a normal all-resolve
  commit exits `0`.
- `git diff --staged` shows changes confined to the one script file.

---

### Phase 3: Pin the V6 Posture and Re-Verify the Boundary Lint [NOT STARTED]

**Goal**: Add the dedicated assertion for the newly-implemented posture (the dispatch's test items
(i) and (ii), the research's case B) and confirm the adjacent boundary lint is still green.

**Tasks**:
- [ ] Re-read the test file immediately before editing.
- [ ] Add **T12** (research case B — the gap this task closes): a `covered` scratch repo where one
      positive pathspec is unmatched (e.g. `specs/999_probe/plans/01_absent.md`) and the
      survivors are tracked, present, and **unmodified** (so `git commit` finds nothing). Assert
      `rc == 4`, HEAD unchanged (`rev-list --count` identical before/after, the "no commit
      created" half), the `ERROR:` line naming the dropped path, and that the generic
      `NOTE: Nothing to commit` wording is *not* the only diagnostic emitted. Verify the
      no-commit claim via `git log`, not exit code alone.
- [ ] Extend T12's header comment to name the posture it pins, so a future reader sees the V6
      contract stated in the test as well as in the script.
- [ ] Run the full suite; all of T1-T13 and V1-V8 must pass.
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh`
      (the dispatch explicitly calls out verifying this). Expected green: no code path in this
      change alters the `-- <pathspec>` invocation shape the lint checks for. If it fails,
      investigate before closing the phase — do not rationalize it as unrelated.
- [ ] Commit this phase's single file with an explicit file pathspec.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes `test-lint-scoped-commit-boundary.sh` constrains only the
`-- <pathspec>` invocation shape and therefore cannot be affected by an exit-code-only change.
Confirm by running it and, if it fails, reading its assertions before assuming the failure is a
sibling's in-flight edit rather than this change.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - add case T12

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` exits 0; the
  summary shows three more passes than the pre-Phase-1 baseline and zero failures; T11, T12, T13
  all appear by name.
- `bash agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh` exits 0.
- `git diff --staged` shows changes confined to the one test file.

---

### Phase 4: Document the Exit-Code Contract and the Recorded Residual [NOT STARTED]

**Goal**: Act on the research's Context Extension Recommendation: the exit-code contract currently
lives **only** in the script's own header, so a reader consulting the standards doc learns nothing
about V2/V3/V5/V6 or their codes. Add the table there, and record the caller-escalation residual
so a future task inherits the finding.

**Tasks**:
- [ ] Re-read
      `agent-system/extensions/core/context/standards/git-staging-scope.md`'s "Commit-Level Path
      Scoping and Cross-Process Serialization" section immediately before editing, confirming it
      still narrates the two original defects without the current gate numbering or exit codes.
- [ ] Add a short exit-code table (`0`-`4`) to that section, mirroring the script header's
      wording, plus one line per safety gate (V2, V3, V5, V6) naming what each refuses.
- [ ] Add a short, explicitly-labeled residual note: every current caller uses
      `cmd || echo "WARN: ...(non-blocking)"`, so any nonzero exit — including `4` — collapses to
      success for the caller's own control flow; a caller that wants to escalate on `4` must
      branch on `$?` rather than rely on `||`. State that this is a known, deliberate boundary of
      the script-level fix, not an undiscovered gap.
- [ ] Cite durable anchors only — the gate labels, the exit codes, the script filename. No
      task-number references (this file is outside `specs/**`).
- [ ] Confirm the file is not in any concurrent sibling's declared `file_scope` (it is not, per
      this dispatch's territory block) and that it has no foreign uncommitted modification; if it
      does, stop and report rather than proceeding.
- [ ] Commit this phase's single file with an explicit file pathspec.

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - exit-code table, the
  four gate labels, and the recorded caller-escalation residual, added to the "Commit-Level Path
  Scoping and Cross-Process Serialization" section

**Verification**:
- Diff read-through confirms every changed hunk is prose/table text inside that one section, with
  no executable or path-pattern content altered.
- The exit codes and gate descriptions in the doc match the script header verbatim in meaning
  (re-read both side by side).
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` still exits 0 (a
  doc-only phase must not perturb it; a cheap tripwire against a stray edit).
- `git diff --staged` shows changes confined to the one documentation file.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` exits 0 with
      zero failures and thirteen T-cases plus the V-series passing.
- [ ] T11 pins the existing V3 all-dropped refusal (`exit 2`, no commit) — unchanged by this task.
- [ ] T12 pins the new V6 posture: partial drop + empty resulting commit no longer reports
      success (`exit 4`, no commit, dropped path named).
- [ ] T13 pins the HARD CONSTRAINT's partial-drop half: a legitimate dropped artifact path plus a
      survivor with a real diff still commits exactly as before (`exit 0`, HEAD +1).
- [ ] The zero-drop no-diff path still exits `1` with today's exact `NOTE:` wording (scratch-repo
      check in Phase 2; the hard constraint's all-resolve half).
- [ ] T8/T9/T10 still pass, proving the ledger did not leak into the V2 case-2 already-staged-
      deletion branch.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh`
      exits 0.
- [ ] `bash -n` clean on the modified script.
- [ ] No write landed anywhere under `.claude/**`; every edit target is under
      `agent-system/extensions/core/**`.
- [ ] No task-number reference was introduced in any file outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — `dropped_pathspecs` ledger, the V6
  refusal gate, exit code `4`, and both header tables updated.
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — three new cases
  (T11, T12, T13).
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — exit-code table, gate
  labels, and the recorded caller-escalation residual.
- `specs/277_git_commit_scoped_worktree_targeting/summaries/01_*-summary.md` — implementation
  summary at task close.
- A follow-up recommendation (not a file in this task): escalate on exit `4` at the live script
  call sites (`orchestrate-cycle-postflight.sh`, `orchestrate-unwind-dispatch.sh`) by branching on
  `$?` instead of `||`. Deliberately excluded here; see the Scope Decision above.

## Rollback/Contingency

Each phase is one file and one commit, so rollback is per-phase and surgical.

- **If Phase 1's constraint tests fail against the unchanged script**: stop. The hard constraint's
  premise is wrong and the plan must be revised before any script edit. Revert the test file only.
- **If Phase 2 breaks any of T1-T10 or V1-V8**: the most likely cause is the ledger append landing
  in the V2 case-2 branch instead of case-3 (T8/T9/T10 would fail) or an unguarded empty-array
  expansion under `set -u` (widespread failures). Revert the script hunk, re-locate the case-3
  `else` by its `WARN: ... dropping unmatched pathspec` comment, and reapply.
- **If the boundary lint fails in Phase 3**: revert the script change and re-read the lint's
  assertions; do not weaken the lint to accommodate the gate.
- **General**: `git revert` the offending phase commit. No migration, no state, and no external
  system is touched, so there is nothing to unwind beyond the file contents themselves. Before any
  rollback that would discard uncommitted work, take a non-reverting checkpoint
  (`bash .claude/scripts/git-snapshot.sh 277 --no-revert`) rather than the reverting default form.
