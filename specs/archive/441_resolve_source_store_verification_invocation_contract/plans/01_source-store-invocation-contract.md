# Implementation Plan: Task #441

- **Task**: 441 - Resolve source-store verification invocation contract
- **Status**: [COMPLETED]
- **Effort**: 3.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/441_resolve_source_store_verification_invocation_contract/reports/01_source-store-verification-invocation-contract.md
- **Artifacts**: plans/01_source-store-invocation-contract.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Resolution (a) is adopted: `check-extension-docs.sh` and `sync-manifest-scripts.sh` will run
directly from their source-store path with no environment override and no redeploy detour. The
mechanism is a single opt-in addition inside `deploy-root-guard.sh`'s refusal branch: when a
caller has declared itself eligible, the guard attempts `git rev-parse --show-toplevel` from its
own location and accepts that candidate only if it structurally contains
`agent-system/extensions` — otherwise it emits today's refusal unchanged. Callers that do not
opt in (the large majority of the 60 scripts that source the guard) see byte-identical behavior.
`verify-deploy.sh` is not modified except for a clarifying header note: research established
empirically that it never carried the refusal and already runs identically from either tree.

### Research Integration

The research report settles the three questions the dispatch posed, and this plan follows it
rather than re-litigating them:

- The refusal affects **two** of the three named scripts. `verify-deploy.sh` resolves `TARGET`
  from its argument or `$(pwd)`, never from `BASH_SOURCE`, and a full `--skip-slow` run from
  both paths diffed to zero differences. It needs no behavioral change (Finding 1).
- The guard is **not load-bearing for correctness** in the two affected scripts: with the
  documented override they produce byte-identical output to the deployed copy, and simulating
  "no guard, wrong root" still fails loudly on the existing `EXT_DIR` existence check rather
  than silently passing (Finding 3). Per the dispatch's own instruction, this makes (a) — not
  (b) — the evidence-backed answer.
- The scripts' own text already assumes (a): both headers document the source-store invocation
  as deliberate, and Rule Q's repair hint already tells callers to run the sibling script "from
  the source store" via a command that does not currently work unaided (Findings 2 and 4).
- The write side was never part of the defect: `sync-manifest-scripts.sh` already writes only
  source-store manifests, by explicit design (Finding 5). This plan does not touch it.

The one place this plan extends the report: the report's recommended "new function in
`deploy-root-guard.sh`" is not directly realizable, because the guard is a straight-line sourced
fragment that exits during the source, so a caller cannot source it to obtain a function without
first triggering the refusal. The opt-in flag below realizes the same intent (additive, affecting
only callers that ask for it) within that constraint.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided to this dispatch.

## Goals & Non-Goals

**Goals**:
- A single, documented invocation contract for `check-extension-docs.sh` and
  `sync-manifest-scripts.sh`: both run from either the source store or a deployed tree, with no
  environment override required in either case.
- Preserve the guard's fail-loud behavior for every caller that does not opt in, and for an
  opt-in caller whose candidate root fails the structural test.
- Record in durable documentation that `verify-deploy.sh` is outside this contract by design, so
  the question is not re-derived from scratch.
- Close the guard's own test gap with a dedicated suite pinning both the refusal and the
  self-correcting path.

**Non-Goals**:
- Changing `deploy-root-guard.sh`'s default behavior for its other callers. The guard is sourced
  by roughly 60 scripts whose individual invariants were not examined; only an explicit opt-in
  changes anything.
- Opting in the other scripts that share the same conditional-bypass shape
  (`audit-deletion-references.sh`, `check-record-versioning.sh`, `check-task-references.sh`,
  `generate-context-line-counts.sh`, `measure-eager-context.sh`, `measure-eager-surface.sh`,
  `validate-context-index.sh`). They are a deliberate scope boundary, documented in Phase 3 and
  suitable for a follow-up once the pattern proves out on the two in-scope scripts.
- Any behavioral change to `verify-deploy.sh`, including its deliberate use of the deployed
  copies of its sub-check scripts.
- Any change to the write side of `sync-manifest-scripts.sh`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A defect in `deploy-root-guard.sh` reaches all ~60 sourcing scripts | H | L | The edit lives entirely inside the branch that currently always exits 1, and is gated on a flag no other caller sets; Phase 1 verifies with the 51 dependent suites `suite_selection_select` maps to the guard, plus `bash -n` |
| `git rev-parse --show-toplevel` resolves to an unexpected root (nested repo, submodule, worktree) | M | L | A candidate is accepted only when `agent-system/extensions` exists directly under it — the same directory both in-scope scripts already require — otherwise today's refusal is emitted unchanged |
| The sourced guard's success path returns nonzero, tripping callers' `\|\| exit 1` | M | M | Phase 1 explicitly pins the sourced fragment's final status to 0 on the acceptance path and asserts it in the new suite |
| The new test file trips Rule Q (undeclared script) before the manifest is updated | L | H | Phase 1 declares the suite in the same phase that creates it, via `sync-manifest-scripts.sh --write`, so the phase closes green |
| Sibling task 440 is editing the same working tree | M | M | Its declared scope (`git-commit-scoped.sh`, `git-commit-phase.sh` and their suites) does not intersect this plan's files; still re-read every file immediately before editing and stage only this task's own paths, never a directory or glob |
| Deployed copies drift from the source store between the edit and the redeploy | M | H | Phase 4 redeploys before the full gate run, so Rule F drift is resolved rather than reported |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Opt-In Self-Correcting Root Resolution in the Shared Guard [COMPLETED]

**Goal**: `deploy-root-guard.sh` gains a narrowly-scoped, opt-in path that resolves the true repo
root for an eligible caller invoked from the source store, while every non-opt-in caller and
every failed candidate keeps today's refusal exactly.

**Tasks**:
- [x] In the guard's non-deploy (`*)`) branch, before the error emission, gate on an explicit
      opt-in variable (suggested name `DEPLOY_ROOT_GUARD_SELF_CORRECT`): when it is set to `1`,
      compute a candidate root as `git -C "$__guard_dir" rev-parse --show-toplevel`, tolerating
      failure. *(completed)*
- [x] Accept the candidate only when it is non-empty AND `agent-system/extensions` exists
      directly under it. On acceptance, assign `REPO_ROOT` (visible to the sourcing caller
      because the guard is sourced, not executed), unset the guard's temporaries and the opt-in
      variable, and ensure the fragment's last evaluated command yields status 0 so a caller's
      `. "$SCRIPT_DIR/deploy-root-guard.sh" || exit 1` does not fire on success. *(completed)*
- [x] On rejection — flag unset, no git, git failure, or a candidate without
      `agent-system/extensions` — fall through to the existing error text and `exit 1` with no
      change to the message or the exit status. *(completed)*
- [x] Rewrite the guard's header comment to describe both resolution paths and the acceptance
      criterion, stating the current design only (no narration of prior behavior, no task
      numbers). *(completed)*
- [x] Create `agent-system/extensions/core/scripts/tests/test-deploy-root-guard.sh` asserting, at
      minimum: (a) sourced from a `.claude/scripts`-shaped directory, the guard succeeds and
      leaves `REPO_ROOT` untouched; (b) sourced from a non-deploy directory with no opt-in, it
      exits 1 and prints the deploy-path message; (c) with the opt-in and a git root containing
      `agent-system/extensions`, it sets `REPO_ROOT` to that root and the sourcing shell observes
      status 0; (d) with the opt-in but a git root lacking `agent-system/extensions`, the refusal
      is unchanged; (e) with the opt-in inside a non-git directory, the refusal is unchanged.
      *(completed: 10/10 assertions pass)*
- [x] Declare the new suite in the core manifest with
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write`,
      then confirm `--check` is clean. *(completed)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: 60 scripts source the guard, 9 of them through the conditional
`[[ -n "${REPO_ROOT:-}" ]] || . .../deploy-root-guard.sh` shape, and no file anywhere in the
repository currently references the opt-in variable; confirm all three at implementation time
with `grep -rl "deploy-root-guard.sh" agent-system/extensions/*/scripts/*.sh | wc -l`,
`grep -rln 'REPO_ROOT:-}" \]\] || \. ' agent-system/extensions/*/scripts/*.sh`, and
`grep -rn DEPLOY_ROOT_GUARD_SELF_CORRECT agent-system/ .claude/` (expected empty before the edit).

**Tier Justification**: `suite_selection_select` maps `deploy-root-guard.sh` to 51 dependent
suites, so `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-root-guard.sh,$(. agent-system/extensions/core/scripts/lib/suite-selection-lib.sh; suite_selection_select agent-system/extensions/core/scripts/deploy-root-guard.sh | paste -sd,)`
exercises the changed helper plus every enumerated caller suite, which is exactly the one-hop
dependent set this edit can reach.

**Files to modify**:
- `agent-system/extensions/core/scripts/deploy-root-guard.sh` - opt-in self-correcting branch and
  header rewrite
- `agent-system/extensions/core/scripts/tests/test-deploy-root-guard.sh` - new fixture suite
- `agent-system/extensions/core/manifest.json` - `provides.scripts` entry for the new suite

**Verification**:
- `bash -n agent-system/extensions/core/scripts/deploy-root-guard.sh` is clean.
- The new suite passes standalone and under the `--only` selection named above.
- `grep` confirms no script outside this plan's scope sets the opt-in variable.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check`
  exits 0.

---

### Phase 2: Opt In the Two In-Scope Scripts and Align Their Self-Documentation [COMPLETED]

**Goal**: Both affected scripts run from the source store with a bare `bash <path>` invocation and
no environment override, and every piece of their own prose describes that contract accurately.

**Tasks**:
- [x] `check-extension-docs.sh`: set the opt-in variable on its own line immediately before the
      existing conditional guard-source line (not as an assignment prefix on the `.` builtin,
      whose persistence differs between POSIX and default bash modes). Leave the
      `REPO_ROOT="${REPO_ROOT:-...}"` fallback and the `EXT_DIR` default untouched. *(completed)*
- [x] `sync-manifest-scripts.sh`: the same one-line opt-in before its guard-source line.
      *(completed)*
- [x] Rewrite the root-resolution header comments in both scripts to state the contract as it
      stands: the script runs from either tree, and an explicit `REPO_ROOT`/`EXT_DIR` override
      remains supported for fixtures. No phrasing relative to an unstated past and no task
      numbers. *(completed)*
- [x] Update Rule Q's repair-hint line in `check-extension-docs.sh` so the command it prints is
      one a reader can paste and run from the repository root, naming the script's real path
      rather than implying an undocumented prerequisite. Keep the preceding `fail()` string
      byte-identical so the gate-3 FINDING extractor's keying is unaffected.
      *(completed: now prints `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write`)*
- [x] Extend `tests/test-manifest-scripts-sync.sh` (or the Phase 1 suite, implementer's choice)
      with an assertion per script that invoking it from the source-store path with
      `env -u REPO_ROOT` does not emit the deploy-path refusal. Keep the assertion cheap: a
      fixture-scoped `--check` run for `sync-manifest-scripts.sh`, and for
      `check-extension-docs.sh` an assertion on the absence of the refusal string rather than a
      full repository lint. *(completed: 19/19 assertions pass)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` maps both touched scripts to the enumerated set
`test-manifest-scripts-sync.sh,test-deploy-baseline-lib.sh,test-gate-cache-equivalence.sh,test-index-entries-schema.sh,test-verify-deploy-context-budget.sh`,
run as `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <that set>`, which
covers both files' own behavior; neither edit changes an externally visible signature.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - opt-in line, header comment,
  Rule Q repair hint
- `agent-system/extensions/core/scripts/sync-manifest-scripts.sh` - opt-in line, header comment
- `agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh` - no-override
  assertions

**Verification**:
- `env -u REPO_ROOT bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check`
  exits 0 with no refusal text.
- `env -u REPO_ROOT bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet`
  produces output identical to `bash .claude/scripts/check-extension-docs.sh --quiet` (capture
  both and `diff`).
- The `--only` suite selection named above passes.

---

### Phase 3: Document the Invocation Contract [COMPLETED]

**Goal**: The contract is written down where the next author looks, including why
`verify-deploy.sh` sits outside it and which sibling scripts are deliberately left alone.

**Tasks**:
- [x] Amend the `## Root-Resolution Guard for Core Scripts` section of
      `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`: keep the
      standing mandate that every `../..`-resolving core script sources the guard, and add the
      opt-in self-correcting path — what it does, its structural acceptance criterion, and why a
      bare `git rev-parse --show-toplevel` is still rejected for the default path (an
      unvalidated toplevel would mask a genuine invocation error, whereas a candidate gated on
      the presence of `agent-system/extensions` cannot). *(completed)*
- [x] In the same section, name the two scripts that opt in and list the scripts sharing the
      conditional-bypass shape that do not, marking that boundary as deliberate. *(completed)*
- [x] Add a short note to `verify-deploy.sh`'s header: it resolves `TARGET` from its argument or
      `$(pwd)` and therefore runs correctly from either tree, and it deliberately invokes the
      deployed copies of its sub-check scripts because its purpose is comparing the deployed
      tree against the source store. *(completed)*
- [x] Re-read the edited hunks for task-number references and record-versioning language; both
      are prohibited under `agent-system/**`. *(completed: check-task-references.sh and
      check-record-versioning.sh both report 0 BLOCKING findings on both files)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: every changed hunk is markdown or a shell comment with no executable
surface, covered by a diff read-through plus
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(the source-store sub-case, with `TARGET` named explicitly) and `bash -n` on `verify-deploy.sh`.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - amended
  root-resolution section
- `agent-system/extensions/core/scripts/verify-deploy.sh` - header note only, no behavioral change

**Verification**:
- `bash .claude/scripts/check-task-references.sh --quiet agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
  and the same for `verify-deploy.sh` report no findings.
- `bash .claude/scripts/check-record-versioning.sh --quiet` over the same two paths reports no
  findings.
- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` is clean.

---

### Phase 4: Redeploy and Full Gate Sweep [COMPLETED]

**Goal**: The deployed tree matches the source store and the complete gate set is green with the
new contract in place.

**Tasks**:
- [x] Re-read every file this plan touched immediately before staging, and stage only those
      explicit paths — a sibling task is active on this same working tree. *(completed)*
- [x] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deploy artifact from the
      source store. *(completed: first attempt caught 3 real SC2034 shellcheck findings from
      Phase 1/2's cross-file variable handoff, fixed with inline shellcheck-disable comments;
      second attempt landed clean -- 37 checks, 0 failures)*
- [x] Confirm the deployed copies of the four touched scripts match their source counterparts
      (Rule F drift clean). *(completed: diff -q clean for all four, plus the new test suite)*
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` with no `--skip-slow`
      and no `--only-gate`, including Gate 8's full shell-suite battery.
      *(deviation: this dispatch's own `.dispatch/` directive named a Batch Gate Deferral for
      this phase -- the complete gate set runs once for the whole batch at the end of this
      /orchestrate invocation rather than independently here. Discharged instead via the scoped
      narrowing invocation `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate
      3,4,22`, covering doc-lint, task-reference lint, and shellcheck (the files this phase
      actually touched): 4 checks, 0 failures.)*
- [x] Re-run both in-scope scripts from the source store with `env -u REPO_ROOT` and from the
      deployed copy, and `diff` the captured outputs — the contract's observable claim.
      *(completed: both diffs empty)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh` in full.
      *(deviation: deferred to the batch stage per the same Batch Gate Deferral directive above.
      Discharged instead via the scoped selection naming every suite `suite_selection_select`
      maps to the three touched scripts (57 suites): 55 passed, 2 failed, both EXPECTED per the
      known-failures roster, 0 NEW.)*

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- None beyond the deploy artifact regenerated by `deploy-headless.sh`

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 with every gate reporting PASS or an expected
  SKIP (no `--skip-slow`, no gate filter).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` reports zero failing suites and
  zero skipped suites.
- `diff` of the source-store and deployed invocations of each in-scope script is empty.

---

## Testing & Validation

- [ ] `test-deploy-root-guard.sh` pins the refusal for non-opt-in callers, the refusal for an
      opt-in caller whose candidate root fails the structural test, and the success path's
      `REPO_ROOT` value and zero exit status.
- [ ] `test-manifest-scripts-sync.sh` pins that both in-scope scripts run from the source store
      with no environment override.
- [ ] The 51 suites `suite_selection_select` maps to `deploy-root-guard.sh` pass unchanged.
- [ ] A full `verify-deploy.sh` run passes after the redeploy.
- [ ] No task-number references and no record-versioning language in any file landing under
      `agent-system/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/deploy-root-guard.sh` with an opt-in self-correcting
  resolution path
- `agent-system/extensions/core/scripts/check-extension-docs.sh` and
  `agent-system/extensions/core/scripts/sync-manifest-scripts.sh` runnable from either tree
- `agent-system/extensions/core/scripts/tests/test-deploy-root-guard.sh` (new) plus its
  `provides.scripts` declaration
- An amended root-resolution section in
  `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
- A clarifying header note in `agent-system/extensions/core/scripts/verify-deploy.sh`
- A regenerated `.claude/` deploy tree

## Rollback/Contingency

Every change is confined to four source-store files plus one new test file, each committed
separately per phase, so reverting is a per-file `git revert` or targeted checkout of the
pre-change blob followed by `bash .claude/scripts/deploy-headless.sh`. If the guard change proves
unsafe for any non-opt-in caller, the minimal retreat is removing the two opt-in lines added in
Phase 2 — the guard's gated branch is then unreachable and behavior returns to the documented
`REPO_ROOT=$(pwd)` override with no further edits. If `git rev-parse` proves unreliable in some
checkout layout, the fallback is already built in: the structural acceptance test rejects the
candidate and the existing refusal fires, so the failure mode is the current behavior, not a
wrong root. Do not use a reverting `git-snapshot.sh` on this shared working tree; a sibling task
is active in it.
