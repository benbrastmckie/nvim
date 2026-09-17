# Implementation Plan: Fix scoped commit dropping staged deletions

- **Task**: 226 - Fix scoped commit dropping staged deletions
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/226_fix_scoped_commit_dropping_staged_deletions/reports/01_scoped-commit-staged-deletions.md
- **Artifacts**: plans/01_scoped-commit-staged-deletions.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, context/standards/shell-strict-mode.md, context/standards/shell-script-testing.md, rules/source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`git-commit-scoped.sh`'s V2 safety gate drops any positive pathspec that is absent from both the
working tree and the index. A staged deletion (`git rm`, or the delete half of a `git mv`) is
exactly that shape, so the gate warns and discards it, the deletion never reaches `git commit --`,
and the script exits 0 having committed only the additions. The fix is a three-way classification
in that gate — matched / already-staged-deletion / genuinely unmatched — plus decoupling the
`git add` pathspec set from the `git commit --` pathspec set, because an already-staged deletion
must be committed but must NOT be handed to `git add` (verified: one such entry aborts the whole
single-invocation `git add`). Work is red-first: the three acceptance-shape regression tests land
and fail before the script is touched.

### Research Integration

The research report confirmed the dispatch's survey by direct reproduction in scratch repos and
added the decisive finding the survey did not have: widening the gate's match condition alone is
not merely insufficient, it is actively harmful, because `git add "${pathspecs[@]}"` is a single
all-or-nothing call that exits 128 on a path absent from both disk and index — converting today's
silent partial drop into a loud whole-commit failure for every mixed add+delete path set. The
report's verified fix design (two arrays; `git cat-file -e "HEAD:$p"` as the sufficient
staged-deletion signal, HEAD-existence-guarded; `git diff --cached` not independently needed) is
adopted verbatim below. The report also resolved the dispatch's open out-of-scope-deletion
question against `context/standards/git-staging-scope.md`'s existing "under-stage, never
over-stage" fail-safe direction: preserve current silent-ignore behavior, add no refuse logic.
This is a documented decision, not a `user_decision` item.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- A scoped commit whose path set includes a staged deletion commits that deletion.
- A scoped rename with both halves in the path set commits as one complete rename.
- Three regression tests (deletion-only, deletion-mixed-with-additions, in-scope rename) that
  demonstrably fail against the current script and pass after the fix.
- `T7` (genuinely nonexistent pathspec still dropped with `WARN`) keeps passing unchanged.
- Header safety-gate documentation describes the corrected three-way V2 behavior.
- `shellcheck` clean per `context/standards/shell-strict-mode.md`; deployed `.claude/` tree
  refreshed from the source store.

**Non-Goals**:
- Any refuse/detect behavior for deletions outside the declared path scope (decision recorded:
  preserve current silent-ignore).
- Consumer-repo deploy propagation (filed separately in this topic).
- Pathspec-magic support (globs, `:(exclude)` entries) in the new HEAD-presence test — a
  pre-existing limitation of the current `-e "$p"` test, unchanged here.
- Any change to `orchestrator-postflight.sh`'s `modified_files` staging; it is a caller that the
  script-level fix already repairs.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Case-2 paths left in the `git add` array reintroduce the verified `git add` exit-128 whole-batch abort — worse than the current bug | H | M | Phase 1's mixed deletion+modification test (acceptance shape 2) is the case that exposes a wrongly-scoped `git add` array most directly; it must be written before the fix and must assert BOTH paths land in one commit |
| `git cat-file -e "HEAD:$p"` on a repo with no commits yet errors noisily | M | L | Guard with `git rev-parse --verify -q HEAD` first; fall through to case 3 (drop with `WARN`), mirroring the script's existing failure-tolerant `--honest-index-rows` handling |
| Over-matching turns a genuinely nonexistent path into a "staged deletion" and re-admits it | M | L | `T7` is preserved unchanged as the regression guard and must stay green in every phase's verification |
| Redeploy regenerates the whole `.claude/` tree and picks up unrelated pending source-store edits | M | M | `.claude/` is gitignored and untracked here, so a redeploy produces nothing to commit; verify by `git status --short` after Phase 4 |
| The script under repair is the same script the implementer's own commits go through | M | M | Commit each phase only after its verification is green; if a phase's own commit drops a path, that is itself a reportable finding, not a silent retry |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Red-first regression tests for the three acceptance shapes [NOT STARTED]

**Goal**: Extend `test-git-commit-scoped.sh` with T8/T9/T10 covering the three ACCEPTANCE shapes,
and record that each fails against the unpatched script.

**Tasks**:
- [ ] Read `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` in full; reuse
      its `build_repo covered` / `run_commit` / `git show --name-status --format=""` pattern and
      its `pass()`/`fail()`/`info()` counter idiom (Class B `set -uo pipefail`; do NOT add `-e`).
- [ ] T8 — deletion only: in a `covered` repo, `git rm specs/999_probe/file.txt`, invoke with
      `specs/999_probe/file.txt` as the sole positive pathspec. Assert a commit landed and
      `git show --name-status` reports `D specs/999_probe/file.txt`. Record the current-script
      outcome in the failure message (research predicts the V3 post-filter refusal, exit 2, since
      filtering leaves zero positive entries) rather than asserting on exit code alone.
- [ ] T9 — deletion mixed with a modification: add a second tracked file to the probe repo (or
      create+commit `keep.txt` inside the test case), `git rm` one and modify the other, pass both
      paths as positive pathspecs. Assert ONE commit carries both `D` and `M`, and that
      `git status --short` is clean for both paths afterwards. This is the case that catches a
      wrongly-scoped `git add` array — it must not be reduced to an exit-code check.
- [ ] T10 — in-scope rename: `git mv old.txt new.txt` with both paths passed as positive
      pathspecs. Assert the commit carries the delete half and the add half (accept either
      `D`+`A` or a detected `R100` in `git show --name-status`), and `git status --short` is clean
      afterwards.
- [ ] Run the suite against the unpatched script and capture the output showing T1-T7 green and
      T8/T9/T10 red. Paste that evidence into the phase's completion note.
- [ ] `shellcheck` the test file.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: three new cases (T8/T9/T10) in exactly one file,
`agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`, with no other file
touched. Confirm at implementation time with `git status --short` before committing; if a helper
change to `build_repo` proves necessary for T9/T10, that is still the same file and does not widen
scope, but it MUST be additive so T1-T7 keep passing unchanged.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - add T8, T9, T10;
  leave T1-T7 untouched.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` runs to completion
  and reports T1-T7 PASS, T8/T9/T10 FAIL (red-first evidence for the ACCEPTANCE criterion).
- `shellcheck agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` is clean.

---

### Phase 2: Three-way V2 classification and decoupled `git add` set [NOT STARTED]

**Goal**: Make the V2 gate classify each positive pathspec into matched / already-staged-deletion /
unmatched, and pass only the first class (plus exclude entries) to `git add` while `git commit --`
keeps the full matched set.

**Tasks**:
- [ ] In the V2 loop (`agent-system/extensions/core/scripts/git-commit-scoped.sh:174-188`), build a
      second array `add_pathspecs` alongside `filtered_pathspecs`.
- [ ] `:(exclude)...` entries: append to BOTH arrays, unchanged (the loop already `continue`s past
      them explicitly; they are not subject to classification).
- [ ] Case 1 — `[ -e "$p" ]` or `git ls-files --error-unmatch -- "$p"` succeeds: append to BOTH
      arrays (current behavior preserved byte-for-byte).
- [ ] Case 2 — neither holds, but HEAD resolves (`git rev-parse --verify -q HEAD`) AND
      `git cat-file -e "HEAD:$p"` succeeds: append to `filtered_pathspecs` ONLY. This is an
      already-staged deletion: it is fully reflected in the index and needs no `git add`; handing
      it to `git add` aborts the entire single-invocation add (verified exit 128).
- [ ] Case 3 — neither: drop with the existing `WARN` message, unchanged.
- [ ] Change `git add "${pathspecs[@]}"` (line 228) to use the `add_pathspecs` array. Handle the
      case where `add_pathspecs` has zero positive entries (a deletion-only commit): skip the
      `git add` call entirely rather than invoking `git add` with an empty or exclude-only list.
- [ ] Leave both `git commit -m "$full_message" -- "${pathspecs[@]}"` invocations (lines 283, 293)
      unchanged — they must keep receiving the full matched set.
- [ ] Leave the V3 post-filter gate operating on `filtered_pathspecs` (a deletion-only commit now
      legitimately has one positive entry, so V3 must not fire on it).
- [ ] Add a short inline comment at the case-2 branch stating why the path is deliberately absent
      from the `git add` set, so a future editor does not "fix" it back.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: the change is confined to the V2 loop and the `git add` invocation in
`agent-system/extensions/core/scripts/git-commit-scoped.sh` — two regions, one file, no new
external dependency. Confirm with `git diff --stat` before committing; a diff touching the commit
invocations or the V3 gate's predicate means the fix drifted from this design and must be
re-examined against the research report's verified reproduction.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - V2 loop gains the third branch
  and the `add_pathspecs` array; `git add` uses the new array and is skipped when that array has
  no positive entries.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` reports all cases
  PASS, including T8/T9/T10 (previously red) and T7 (unchanged guard against over-matching).
- `shellcheck agent-system/extensions/core/scripts/git-commit-scoped.sh` is clean per
  `context/standards/shell-strict-mode.md` (Class A, `set -euo pipefail` retained).
- The full repository gate set for this phase's class runs before the phase closes.

---

### Phase 3: Header documentation and recorded out-of-scope ruling [NOT STARTED]

**Goal**: Bring the script's own V2 documentation in line with the three-way behavior and record
the out-of-scope-deletion decision where a future reader will find it.

**Tasks**:
- [ ] Update the `V2` bullet in the header safety-gate comment block
      (`git-commit-scoped.sh:45-48`), which currently documents only two-way match/drop, to
      describe the three outcomes and to state that an already-staged deletion is committed
      without being re-added.
- [ ] Add one sentence to the same block recording the ruling: a staged change (deletion included)
      for a path NOT named in the caller's pathspec list is silently left out of the commit,
      uniformly with every other out-of-scope change type, per
      `context/standards/git-staging-scope.md`'s "under-stage, never over-stage" fail-safe
      direction. No refuse logic is added.
- [ ] Do not restate the reasoning in `git-staging-scope.md`; reference it.

**Timing**: 0.25 hours

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - header comment block only.

**Verification**:
- Diff read-through confirms every changed hunk lies inside the leading `#` comment block and no
  executable line moved.
- `shellcheck` still clean; the test suite still all-PASS (comment-only edits must not perturb it).

---

### Phase 4: Refresh the deployed tree and close the gates [NOT STARTED]

**Goal**: Regenerate this repo's `.claude/` deploy tree so the live pipeline copy carries the fix,
and confirm parity with the source store.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` (default non-destructive
      resync mode; do NOT use `--wipe`).
- [ ] Verify parity: `diff agent-system/extensions/core/scripts/git-commit-scoped.sh
      .claude/scripts/git-commit-scoped.sh` produces no output.
- [ ] Confirm `.claude/` is still gitignored and untracked (`git check-ignore -v
      .claude/scripts/git-commit-scoped.sh`), so the refresh contributes nothing to any commit and
      no `.claude/**` path is ever staged.
- [ ] If `deploy-headless.sh` cannot run in this environment, mark the phase `[BLOCKED]` and report
      it. Do NOT hand-copy or hand-edit any file under `.claude/**`
      (`rules/source-store-deploy-boundary.md`).
- [ ] Re-run the full test suite once more against the refreshed tree and record the final
      all-PASS result.

**Timing**: 0.25 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- None under version control. `.claude/**` is regenerated by the deploy engine and is gitignored.

**Verification**:
- `diff` between source-store and deployed `git-commit-scoped.sh` is empty.
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` reports zero
  failures.
- `git status --short` shows no `.claude/**` entries.

---

## Testing & Validation

- [ ] T8 (deletion-only scoped commit) fails before Phase 2 and passes after.
- [ ] T9 (deletion mixed with additions/modifications in one path set) fails before Phase 2 and
      passes after, with both paths in a single commit and a clean `git status --short` afterwards.
- [ ] T10 (rename with both halves in scope) fails before Phase 2 and passes after, with the
      delete half present in the commit.
- [ ] T1-T7 pass unchanged throughout; T7 in particular still drops a genuinely nonexistent
      pathspec with `WARN`.
- [ ] `shellcheck` clean on both modified shell files.
- [ ] Deployed `.claude/scripts/git-commit-scoped.sh` is byte-identical to the source-store copy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` (fixed V2 gate, decoupled `git add`
  set, updated header documentation)
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` (T8/T9/T10 added)
- Refreshed `.claude/` deploy tree (untracked, not committed)
- `specs/226_fix_scoped_commit_dropping_staged_deletions/summaries/01_*-summary.md` at completion

## Rollback/Contingency

Both edited files are tracked and every phase commits separately, so reverting is a per-phase
`git revert` of the phase commit followed by a redeploy. If Phase 2's change is reverted, Phase 1's
tests correctly go red again — that is the intended signal, not a broken suite; do not delete the
tests to make the suite green. If a regression surfaces only in the deployed tree, re-run
`deploy-headless.sh` rather than hand-editing `.claude/**`.
