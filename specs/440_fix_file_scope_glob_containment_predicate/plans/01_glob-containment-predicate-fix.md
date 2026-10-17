# Implementation Plan: Task #440

- **Task**: 440 - Fix file_scope glob containment predicate
- **Status**: [NOT STARTED]
- **Effort**: 3.5 hours
- **Dependencies**: None (task 425 checked and confirmed non-overlapping — see Overview)
- **Research Inputs**: specs/440_fix_file_scope_glob_containment_predicate/reports/01_glob-containment-predicate-fix.md
- **Artifacts**: plans/01_glob-containment-predicate-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two independently copy-pasted containment predicates — `is_contained_v10()` in
`git-commit-scoped.sh` and its ported twin `is_contained()` in `git-commit-phase.sh` — quote the
file_scope entry variable inside a `case` pattern, which disables glob interpretation of the
asterisks the entry's own *value* carries. A `/**`-suffixed entry therefore only matches a path
containing two literal asterisk characters, so deep-prefix containment never fires at either
site. The fix adds exactly one narrowly-guarded branch per function: strip a literal trailing
`/**` with escaped-asterisk parameter expansion (`${entry_norm%/\*\*}`), and when something was
stripped, test exact-or-slash-bounded prefix containment against the stripped base. Every
pre-existing branch is left byte-identical, so no non-`/**` entry's behaviour changes. Test
coverage is then added to both existing suites proving the four behaviours the task scope
names, and the source store is redeployed.

All edits land in the source store (`agent-system/extensions/core/scripts/`), never under
`.claude/**`, per `rules/source-store-deploy-boundary.md`.

### Research Integration

The research report supplies and validates the complete fix, so this plan transcribes rather
than re-derives it. Key findings carried forward:

- **Root cause confirmed at both sites**, with exact line anchors: `git-commit-scoped.sh:526-539`
  and `git-commit-phase.sh:244-255`. The mechanism is identical at both; the twin additionally
  lacks site 1's trailing-slash normalization, a pre-existing difference deliberately left alone.
- **The fix was run in a bash scratch harness against nine probes, all passing** — including the
  two critical non-widening negatives (`core-other`, `coreX` must NOT be contained by
  `agent-system/extensions/core/**`). Those two negatives are the proof that the fix does not
  over-permit, which the task scope explicitly demands.
- **No shared helper exists.** `grep` across `scripts/lib/*.sh` finds no `is_contained`-family
  function; both predicates are self-contained by the deliberate "ported, not reinvented"
  pattern each carries in its own header comment. Extracting a shared helper is therefore a
  larger refactor this fix does not attempt.
- **Site 2 is deliberately redundant, not load-bearing.** `git-staging-scope.md`'s "Three
  Containment sites, not one" section already records that `git-commit-scoped.sh`'s V10 gate
  structurally subsumes `git-commit-phase.sh`'s self-check for every caller forwarding `--task`
  (which the phase wrapper always does). Site 1 is therefore the fix that actually stops files
  being dropped; site 2's fix stops the redundant layer emitting spurious drop-warnings and
  `scope excursion` issue-log entries. The plan does not re-derive this rationale — it cites it.
- **Task 425 is independent; no `dependencies[]` edge is needed.** Its predicate is a `jq`
  `startswith` test over literal non-glob paths in `orchestrate-cycle-postflight.sh`; different
  file, different language, no glob syntax involved at all, and its declared `file_scope`
  (`orchestrate-cycle-postflight.sh` plus that script's own test file) is disjoint from this
  task's four files. Verified independently against `specs/state.json` while writing this plan.
- **Zero existing coverage** for a `/**`-suffixed entry in either suite; the richest adjacent
  harnesses are `test-git-commit-scoped.sh`'s `Z1`-`Z10` block (via `build_repo_with_scope`) and
  `test-git-commit-phase.sh`'s `Case 7`/`Case 8` pair (via `write_progress`). Both give a
  ready-made shape to extend rather than invent.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in this dispatch.

## Goals & Non-Goals

**Goals**:
- A `/**`-suffixed `file_scope` entry contains its direct children and every deeper descendant,
  at both predicate sites.
- Containment for every entry form that does not end in `/**` (exact path, bare directory
  ancestor, either direction) is byte-for-byte unchanged.
- A path that merely shares a textual prefix with a `/**` entry's base, without a `/` boundary,
  is NOT contained.
- Both existing test suites carry cases that fail against the current code and pass against the
  fixed code.
- The deployed `.claude/**` tree carries the fix after a redeploy.

**Non-Goals**:
- Extracting a shared containment helper used by both sites (deliberately rejected; see
  Research Integration).
- Evaluating brace expansion or any other glob syntax in `file_scope` entries. The live
  `agent-system/extensions/{present,formal,...}/**` entry in `specs/state.json` is, and remains
  after this fix, matched only as one literal string. Expanding arbitrary task-authored strings
  as shell syntax is a correctness and safety hazard far larger than this defect.
- Fixing `orchestrate-cycle-postflight.sh`'s own excursion predicate (task 425's territory).
- Normalizing site 2's missing trailing-slash handling to match site 1.
- Documenting the supported `file_scope` entry grammar in `git-staging-scope.md` (a worthwhile
  follow-up the research flags, but outside this task's declared `file_scope`).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A "clever" rewrite widens containment (e.g. treats a bare trailing `*` like `/**`, or matches a same-prefix sibling). This predicate gates commit staging scope, so over-permissiveness is worse than the present bug. | H | M | Transcribe the validated fix verbatim; add exactly one branch guarded by `[ "$entry_base" != "$entry_norm" ]`; leave every existing branch untouched. Phase 2 and Phase 3 each include an explicit same-prefix-sibling negative case. |
| Only one of the two sites is fixed, leaving the twin silently broken and still emitting spurious `scope excursion` entries. | M | M | Phase 1 edits both sites and declares `Commit Mode: atomic-batch` so the two edits land as one commit; its verification requires both function bodies re-read and both suites green before closing. |
| A sibling task is editing the same working tree this cycle (task 441 holds `verify-deploy.sh`, `check-extension-docs.sh`, `sync-manifest-scripts.sh`, `test-manifest-scripts-sync.sh`). | M | M | Those four paths are disjoint from this task's four. Re-read each target file immediately before editing; stage only this task's explicit file list (never a directory or glob pathspec); treat a failure in a file outside this `file_scope` as possibly a sibling's in-flight edit. |
| New tests pass vacuously (green against unfixed code), proving nothing. | M | L | Each test phase requires running the new cases against the *pre-fix* predicate behaviour at least once — by `git stash`-free means: temporarily reverting the function body in a scratch copy, or confirming the case fails if the new branch is commented out — and recording that red observation in the phase's verification notes. |
| The source-store fix lands but the deployed tree is never refreshed, so the live `.claude/**` copies stay broken. | H | L | Phase 4 runs `deploy-headless.sh` and requires `RESULT=landed_verify_clean` plus a direct grep of the deployed copies for the new branch. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix the Containment Predicate at Both Sites [NOT STARTED]

**Goal**: `/**`-suffixed `file_scope` entries perform deep-prefix containment at both
`is_contained_v10()` and its ported twin `is_contained()`, with no behaviour change for any
other entry form.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/git-commit-scoped.sh` around the
      `is_contained_v10` definition immediately before editing (sibling task 441 is live on this
      same working tree).
- [ ] In `is_contained_v10`, add `entry_base` to the `local` declaration list.
- [ ] Immediately after the existing `[ "$path" = "$entry_norm" ] && return 0` exact-match test
      and before the two existing `case` branches, insert:
      `entry_base="${entry_norm%/\*\*}"`, then an `if [ "$entry_base" != "$entry_norm" ]; then`
      block whose body is `case "$path" in "$entry_base"|"$entry_base"/*) return 0 ;; esac`.
- [ ] Add a short comment above the new branch explaining that the entry ends in a literal `/**`
      and that this is deep-glob prefix containment: the base directory itself, its direct
      children, and every deeper descendant, and nothing outside it.
- [ ] Extend `is_contained_v10`'s header comment so it names the `/**` deep-glob form alongside
      the exact-match and directory-ancestor forms it already documents.
- [ ] Re-read `agent-system/extensions/core/scripts/git-commit-phase.sh` around the
      `is_contained` definition.
- [ ] Apply the identical branch to `is_contained`, using `$entry` (this twin has no
      `entry_norm`) and keeping this site's existing no-trailing-slash-normalization untouched.
- [ ] Run `bash -n` on both scripts, then `shellcheck` each, confirming no new findings.
- [ ] Confirm by reading the diff that no pre-existing branch in either function was modified,
      reordered, or re-indented.
- [ ] No task-number references and no record-versioning language in either file.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: atomic-batch

**Scope Hypothesis**: Two files, one function each, approximately five added lines per function
and no removed lines. Confirm at implementation time by reading the staged diff: if either
function's hunk removes or rewrites a pre-existing branch, or if a third file is touched, the
hypothesis is wrong and the edit has over-reached — stop and re-scope rather than proceeding.

**Tier Justification**: Both edits are confined to one self-contained function per file with no
signature or call-site change, and the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh,test-git-commit-phase.sh`,
the two suites `suite_selection_select` resolves for exactly these two touched paths.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - add the `/**` deep-glob branch
  to `is_contained_v10`, extend its header comment
- `agent-system/extensions/core/scripts/git-commit-phase.sh` - add the identical branch to the
  ported `is_contained` twin

**Verification**:
- `bash -n` clean and `shellcheck` finding-free on both scripts.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh,test-git-commit-phase.sh`
  passes — both suites still green against their existing cases (no regression from the new
  branch).
- A scratch bash probe sourcing each fixed function body against the entry list
  `("agent-system/extensions/core/**" "specs/TODO.md" "agent-system/extensions/nix")` returns
  contained for `agent-system/extensions/core/manifest.json`,
  `agent-system/extensions/core/scripts/lib/foo.sh`, `specs/TODO.md`,
  `agent-system/extensions/nix`, and `agent-system/extensions/nix/sub/file.nix`; and NOT
  contained for `agent-system/extensions/core-other/x.sh`,
  `agent-system/extensions/coreX/x.sh`, and `agent-system/extensions/lean/x.lean`.
- The staged diff touches exactly the two files above and adds no new task-number reference.

---

### Phase 2: Deep-Glob Coverage in test-git-commit-scoped.sh [NOT STARTED]

**Goal**: The `Z`-series proves, at the load-bearing site, that a `/**` entry contains a direct
child and a deeply nested descendant, excludes a same-prefix sibling, and leaves non-glob entry
behaviour intact.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`, in
      particular `build_repo_with_scope` (around line 246) and the `Z1`-`Z10` block (from around
      line 1428) so the new cases match the established fixture and assertion idiom.
- [ ] Append `Z11`: a `/**` entry (e.g. `["specs/999_probe/**"]`) contains a direct child —
      the commit lands that path with no drop WARN.
- [ ] Append `Z12`: the same `/**` entry contains a deeply nested descendant (at least two
      directory levels below the base) — the commit lands it with no drop WARN.
- [ ] Append `Z13`: the same `/**` entry does NOT contain a same-prefix sibling whose path
      shares the base's text but not its `/` boundary (the `core` vs `core-other` shape) — that
      path is dropped with the existing out-of-scope WARN while an in-scope path still lands.
      This is the non-widening proof.
- [ ] Append `Z14`: a `/**` entry alongside a plain non-glob entry in the same `file_scope` —
      the non-glob entry's exact-match and directory-ancestor behaviour is unchanged.
- [ ] Keep each new case inside the existing `task-ref-ok` block covering the `--task 999`
      literals, or extend that block's range so the new cases are covered by it.
- [ ] Observe each new case RED at least once against pre-fix predicate behaviour (comment out
      the Phase 1 branch in a scratch copy, or run the case against the function body as it was),
      and record that observation in the phase notes — a case that passes before the fix proves
      nothing.
- [ ] Run `shellcheck` on the suite, confirming no new findings.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Four new `Z`-series cases appended to one file, no existing case modified.
Confirm at implementation time: if landing the four cases requires changing `build_repo_with_scope`
or any of `Z1`-`Z10`, the hypothesis is wrong — report the required change rather than silently
editing a passing case.

**Tier Justification**: The edit is confined to one test file with no production-code surface,
and its covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh`,
the suite this file IS.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - append `Z11`-`Z14`
  deep-glob containment cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh`
  passes with four more cases than before.
- Each of `Z11`-`Z14` was observed failing against pre-fix predicate behaviour at least once,
  noted in the phase record.
- `shellcheck` on the suite reports no new findings.

---

### Phase 3: Deep-Glob Coverage in test-git-commit-phase.sh [NOT STARTED]

**Goal**: The phase-wrapper suite proves the same deep-glob containment behaviour at the ported
twin site, including the non-widening negative.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`, in
      particular `write_progress` (around line 94) and `Case 7`/`Case 8` (around lines 293 and
      326), so the new cases reuse the established fixture mechanics.
- [ ] Append `Case 10`: a `/**` `file_scope` entry whose declared `files_touched` includes both a
      direct child and a deeply nested descendant of the base — both land in the phase commit
      with no drop warning and no `scope excursion` issue-log entry.
- [ ] Append `Case 11`: the same `/**` entry with a `files_touched` set containing one in-scope
      descendant and one same-prefix sibling outside the base — the sibling is dropped with the
      existing warning and left uncommitted on disk, the in-scope descendant lands.
- [ ] Keep the numbering contiguous with the existing `Case 9` and follow the file's
      `info "=== Case N: ..." ==="` / `pass` / `fail` idiom exactly.
- [ ] Observe each new case RED at least once against pre-fix predicate behaviour and record it.
- [ ] Run `shellcheck` on the suite, confirming no new findings.

**Timing**: 0.75 hours

**Depends on**: 1

**Scope Hypothesis**: Two new `Case` entries appended to one file, no existing case modified.
Confirm at implementation time by diff: a change to `write_progress` or to `Case 1`-`Case 9`
falsifies the hypothesis and should be reported, not absorbed.

**Verification Tier**: local

**Tier Justification**: The edit is confined to one test file with no production-code surface,
and its covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-phase.sh`,
the suite this file IS.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - append `Case 10` and
  `Case 11` deep-glob containment cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-phase.sh`
  passes with two more cases than before.
- Both new cases were observed failing against pre-fix predicate behaviour at least once, noted
  in the phase record.
- `shellcheck` on the suite reports no new findings.

---

### Phase 4: Redeploy and Full Gate Verification [NOT STARTED]

**Goal**: The deployed `.claude/**` tree carries the fixed predicates, and the complete gate set
is green across the whole repository.

**Tasks**:
- [ ] Confirm Phases 1-3 are committed and the working tree holds no partial edits from this
      task.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` and confirm it reports
      `RESULT=landed_verify_clean`.
- [ ] Grep the deployed `.claude/scripts/git-commit-scoped.sh` and
      `.claude/scripts/git-commit-phase.sh` for the new `entry_base` branch, confirming both
      deployed copies carry it.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (no `--skip-slow`, no
      `--only-gate`), including Gate 8's full `run-all.sh` battery.
- [ ] Distinguish any failure from the known pre-existing baseline (see
      `agent-system/extensions/core/scripts/tests/known-failures.txt`); a failure not on that
      list is a real regression and blocks phase closure.
- [ ] Sanity-check the live effect: a `file_scope` entry ending in `/**` drawn from
      `specs/state.json` now resolves its real descendant paths as contained under the deployed
      predicate.

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- None planned — this phase redeploys and verifies; the deployed `.claude/**` tree is a
  generated artifact of `deploy-headless.sh`, never hand-edited.

**Verification**:
- `bash .claude/scripts/deploy-headless.sh` prints `RESULT=landed_verify_clean`.
- `bash .claude/scripts/verify-deploy.sh` exits 0 with every gate green, or with only failures
  already present in the recorded baseline, each named explicitly.
- Both deployed script copies contain the `entry_base` deep-glob branch.

## Testing & Validation

- [ ] A `/**` entry contains a direct child (proven at both sites: `Z11`, `Case 10`).
- [ ] A `/**` entry contains a deeply nested descendant (`Z12`, `Case 10`).
- [ ] A `/**` entry does NOT contain a same-prefix sibling outside the base (`Z13`, `Case 11`) —
      the non-widening requirement.
- [ ] Non-glob entry forms (exact path, bare directory ancestor, both directions) behave exactly
      as before (`Z14`, plus the unchanged `Z1`-`Z10` and `Case 1`-`Case 9`).
- [ ] Both suites green under `run-all.sh --only test-git-commit-scoped.sh,test-git-commit-phase.sh`.
- [ ] Full `verify-deploy.sh` gate set green (or baseline-only failures, named).
- [ ] Every new test case observed red against pre-fix behaviour at least once.

## Artifacts & Outputs

- Fixed `is_contained_v10()` in `agent-system/extensions/core/scripts/git-commit-scoped.sh`.
- Fixed `is_contained()` in `agent-system/extensions/core/scripts/git-commit-phase.sh`.
- Four new `Z`-series cases in
  `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`.
- Two new `Case` entries in
  `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`.
- Redeployed `.claude/**` tree carrying both fixes.
- An implementation summary under
  `specs/440_fix_file_scope_glob_containment_predicate/summaries/`.

## Rollback/Contingency

Each phase commits separately (Phase 1 as a declared atomic batch of its two files), so any
phase can be reverted with a targeted `git revert` of its own commit without disturbing the
others. The predicate change is purely additive — one guarded branch per function — so reverting
Phase 1 restores exactly the present behaviour, including the known bug. If the new branch is
found to widen containment for any non-`/**` entry form, revert Phase 1 immediately (the
over-permissive state is worse than the bug it replaces), re-run the Phase 1 scratch probe to
locate the widening case, and re-apply with the offending case added to the suite first. If
`deploy-headless.sh` fails mid-run, the source store remains the authority; re-run the deploy
after resolving the gate failure rather than hand-editing anything under `.claude/**`.
