# Implementation Plan: Task #461

- **Task**: 461 - Rule on and close the V7 refusal of a positive directory pathspec for a `git rm --cached` untracking whose content is still on disk
- **Status**: [NOT STARTED]
- **Effort**: 8 hours
- **Dependencies**: 328, 430, 435, 446, 448 (SERIALIZATION-only or OPERATOR-LIFTABLE per the task's territory edges; none contests the ruling)
- **Research Inputs**: specs/461_v7_refuses_cached_untracking_pathspec/reports/01_v7-cached-untracking-ruling.md
- **Artifacts**: plans/01_cached-untracking-commit-path.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The ruling is **option (2)**: the `--cached` untracking gets its **own narrow carve-out**, kept
textually and mechanically distinct from the existing fully-staged-deletion (directory-move)
carve-out, so neither premise is blurred. Options (1) and (3) are both rejected with reasons
recorded below. The carve-out is **not** sited in the V7 post-add verification loop the task
description frames as the fix site, and it is not a single predicate change either: a plan-phase
probe established that the untracking shape needs handling at three separate points in
`git-commit-scoped.sh` — pre-add classification (V2), the commit invocation itself, and the V8
pre-commit intent snapshot. The script's V7 exact-exit-code discrimination (1 / 0 / 128) is left
completely untouched, which satisfies the first HARD CONSTRAINT by construction rather than by
careful predicate surgery.

### Premise Re-Validation (Carried-Figure Discipline)

Every flagged line of the dispatch description was checked against live state in this dispatch.

1. **"SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/**`"** — CONFIRMED
   unchanged. `.claude-extensions.json` is present at the project root; every file this plan
   edits is named at its source-store path, and the deployed `.claude/` tree is written only by
   the redeploy in the final phase.
2. **LIVE SYMPTOM, exit 2** — the refusal mechanism is CONFIRMED (the research report reproduced
   it empirically in a scratch repo, and the refusal site is verified live at
   `git-commit-scoped.sh`'s `genuinely_failed_adds` block). The **"500 files"** figure remains
   CARRIED-UNVERIFIED from the originating repository's entry and is not re-derivable here; it is
   load-bearing only for the enumeration-cost risk below, not for any phase's correctness.
3. **Citations in THE TENSION section** — both re-derived, and both line numbers have MOVED as
   the description warned. `rules/git-workflow.md`'s directory-or-glob `git add` forbiddance is at
   **line 89** (description said ~89-92: still accurate). The
   "its own internal `git add` runs as a subprocess, never as the literal top-level
   `tool_input.command` the hook observes" passage in `context/standards/git-staging-scope.md` is
   at **line 537**, not ~423 as the description states. The substance of the tension is
   unchanged; only the citation drifted.
4. **"the `git diff --cached HEAD` exit code is read EXACTLY — 1 / 0 / >1 (notably 128)"** —
   CONFIRMED verbatim in the live script's own comment at the carve-out site, including the
   explicit warning that a `! git diff ...` boolean test would wrongly accept the 128 case. This
   plan changes neither that comment nor that predicate.
5. **"Pin the two cases the predicate must keep refusing"** — CONFIRMED as still-necessary and
   scheduled in the test phase. Note that the out-of-repo (128) case never reaches the V7
   predicate in the first place: the V9 repository-containment guard, evaluated earlier in the
   V2 loop, drops it first. The pin is still correct and cheap; it just pins a different gate
   than the description implies.

### Research Integration

The research report's two load-bearing findings are adopted:

- The gitignored **refusal** and the non-gitignored **silent revert** are one defect with two
  gitignore-dependent symptoms, and only a **pre-`git add`** intervention can address both. A
  literal option (1) (widening the V7 post-add carve-out's `[ ! -e "$p" ]` conjunct) cannot
  touch the non-gitignored case, because by the time V7 runs the revert has already happened.
- The predicate must be **enumerate-and-verify** ("every file HEAD tracks under this pathspec is
  staged as a pure deletion"), never a cheap existence test, or a partially-untracked directory
  would wrongly match. This plan's probe confirmed the predicate's discrimination directly: on a
  fully untracked directory `git ls-files -- <dir>` is empty and
  `git diff --cached --name-status HEAD -- <dir>` is all `D` lines; on a partially untracked
  directory with one file restored to the index and another modified, `git ls-files -- <dir>`
  still lists the survivor, so the predicate rejects.

**One research recommendation is superseded by a plan-phase finding.** The report recommends a
V2-sited carve-out as *the* fix. That is necessary but **not sufficient**: four scratch-repo
variants probed in this dispatch show that **no pathspec-scoped `git commit -- <paths>` form can
carry a `--cached` untracking whose content remains on disk.** A directory pathspec, an explicit
HEAD-tracked file list, and `git commit --only -- <files>` all exit 1 ("nothing to commit") with
HEAD unmoved; only a bare `git commit` (whole index) lands the deletion. The cause is the same
`--only` working-tree re-read the script's own header already documents as the reason V8 exists:
the named path exists on disk and is untracked, so git finds nothing to commit for it. A V2-only
fix therefore stops the silent revert (an improvement worth landing on its own) but still leaves
the untracking uncommittable — which would not satisfy the REQUIRED OUTCOME.

A second plan-phase finding: once the commit does land, the **V8 pre-commit intent snapshot would
false-positive**. Its third listing, `git ls-files --others --exclude-standard`, enumerates the
now-untracked, still-present, **non-gitignored** files and records their working-tree content
hash as the intended post-state; after a correct untracking commit `HEAD:<file>` is absent, so
V8 reports "absent from HEAD" and the script exits 5. (The gitignored symptom is unaffected:
`--exclude-standard` filters those files out, so V8's snapshot is empty for that pathspec.)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's context; no roadmap consultation was performed
and no roadmap phases are included.

## The Ruling (the task's required explicit disposition)

**Ruling: (2) — its own narrow carve-out, deliberately kept distinct from the directory-move
case.** Reasoning, recorded as the task requires:

- **Why not (1) — widen the existing fully-staged-deletion predicate's first conjunct.**
  Rejected on two independent grounds. (a) Sited where it is (post-`git add`), it structurally
  cannot reach the non-gitignored symptom, where `git add` has already reverted the untracking
  before V7 runs. (b) Even if relocated, merging the two shapes into one predicate blurs two
  opposite premises — the directory-move carve-out's premise is "content gone from the working
  tree", the untracking's is "content present on disk" — and the task's third HARD CONSTRAINT
  explicitly forbids conflating them in the NOTE output. A shared predicate with a divergent
  NOTE would be a worse structure than two predicates.
- **Why not (3) — a documented explicit-file-list recipe instead of a code change.** Rejected on
  evidence, not preference. The probe shows an explicit file list behaves **identically** to the
  directory pathspec: `git commit -- sub/a.txt sub/b.txt` on a staged `--cached` deletion with
  content present exits 1 and does not advance HEAD. Pathspec granularity is irrelevant, because
  the hazard lives in `--only` commit semantics and in `git add`'s behavior toward
  already-staged-deleted, disk-present content — not in directory-vs-file tokens. There is no
  recipe expressible with the current script that commits an untracking without relocating
  content out of the repository, so (3) cannot satisfy the REQUIRED OUTCOME.
- **Why the directory pathspec is not itself the fault.** The tension the task asks to be ruled
  on resolves as follows: `rules/git-workflow.md`'s forbiddance governs a **literal top-level**
  `git add` command, which is what `hooks/guard-destructive-git.sh` observes; it has never
  governed a pathspec handed to `git-commit-scoped.sh`, whose internal `git add` runs as a
  subprocess (`context/standards/git-staging-scope.md`, line 537, which positively sanctions
  passing `${task_dir}/` to this very script). So "a directory pathspec was used, therefore the
  refusal is correct" is rejected: the refusal is a genuine defect in the script's handling of a
  legitimate pathspec, not correct enforcement of the call-site rule.

**The deliverable that satisfies REQUIRED OUTCOME** is therefore the fixed script plus its
documentation: after this plan lands, the sanctioned way to commit an untracking is exactly
`git rm -r --cached <dir>` followed by an ordinary `git-commit-scoped.sh ... -- <dir>` — no
relocation, no special recipe, no manoeuvre. The documentation phase records that sentence in
`context/standards/git-staging-scope.md` so a future agent does not re-derive the workaround.

## Goals & Non-Goals

**Goals**:

- Make `git-commit-scoped.sh` commit a `git rm --cached` untracking whose content remains on
  disk, correctly and loudly, in both the gitignored and non-gitignored cases, without relocating
  any file out of the working tree.
- Keep the two deletion shapes (directory move vs. untracking) separately classified and
  separately named on stderr.
- Refuse — never widen — for a partially-untracked pathspec, an unstaged-difference pathspec, and
  an out-of-repository pathspec.
- Leave a durable record of the ruling and of the sanctioned untracking recipe in
  `context/standards/git-staging-scope.md`.

**Non-Goals**:

- Changing V7's `git diff --cached HEAD` exact-exit-code discrimination, its gitignore-advisory
  tolerance, or its `add_exclude_pathspecs` handling (all three explicitly out of scope).
- Reopening the settled bare-directory-pathspec policy or its lint.
- Touching `scripts/git-commit-phase.sh` or `scripts/tests/test-git-commit-phase.sh` (task 430's
  and 446's territory). This plan's recipe routes through `git-commit-scoped.sh` directly and
  makes no claim about `git-commit-phase.sh`'s post-commit `files_touched` completeness check.
- Any change to `hooks/guard-destructive-git.sh` or to `rules/git-workflow.md`'s forbiddance.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The new commit path is a bare `git commit`, which commits the whole index — exactly the hazard this script exists to prevent | H | M | It is taken ONLY when at least one pathspec classified as the untracking shape, and only after proving the index is exactly the declared scope: `git diff --cached --name-only HEAD` must equal `git diff --cached --name-only HEAD -- "${filtered_pathspecs[@]}"` (git's own resolver, honoring `:(exclude)` entries). Any discrepancy is a loud refusal, never a wider commit. It runs inside the already-held `specs/.commit-lock` mutex, so it is no less serialized than today's commit. |
| Inserting a new case ahead of V2's case-1 existence test changes behavior for an unanticipated pathspec shape | H | L | The predicate requires HEAD-tracked files to exist under the pathspec AND every one of them to be absent from the index AND every staged entry under it to be a `D` line AND `git ls-files -- "$p"` to be empty. Any ordinary path (present and tracked, present and untracked, modified, partially staged) fails at the first or second conjunct. The existing T8/T9/T10/U1-U6/W1-W4 cases are the concrete regression check and run in every phase below. |
| Concurrent siblings (423, 499) share this working tree, so a foreign staged entry could appear between the index-equivalence check and the commit | M | L | The check runs inside the commit mutex, immediately before the commit, which is the narrowest window available. A foreign entry that slips in is still caught after the fact by the existing V8 post-commit integrity gate. Neither sibling's declared `file_scope` includes any file this plan touches. |
| Enumerating `git ls-tree -r` per directory pathspec is slow on a large tree (the reported incident cited 500 files) | L | M | This is the same enumeration cost the existing V8 gate already pays on every commit (`git ls-files` + `git diff --name-only HEAD` + `git ls-files --others`), so it adds no new complexity class. Accepted deliberately; do not trade the enumeration for a cheap existence test, which is what makes the predicate safe. |
| `context/standards/git-staging-scope.md` is contested territory with task 446 | M | M | Re-read the file immediately before editing, append a sibling section rather than rewriting any existing one, and merge rather than overwrite if 446 has landed changes in the interim. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases within the same wave can execute in parallel. This plan is strictly sequential: each
phase's verification depends on the previous phase's behavior change being present.

---

### Phase 1: Classify the `--cached` untracking shape before `git add` [NOT STARTED]

**Goal**: stop the non-gitignored silent revert and the gitignored refusal at their shared
source, by recognizing the untracking shape in the V2 classification loop and keeping it out of
`add_pathspecs` entirely — the same two-array mechanism the existing case 2 already uses.

**Tasks**:

- [ ] Re-read the V2 classification loop in
  `agent-system/extensions/core/scripts/git-commit-scoped.sh` (currently the `for p in
  "${pathspecs[@]}"` loop; case 1's `[ -e "$p" ] || git ls-files --error-unmatch` test, case 2's
  already-staged-deletion branch, and case 3's unmatched drop). Line numbers in this plan are
  indicative only — re-derive before editing.
- [ ] Add a helper function (near the script's other helpers, not inline in the loop) that
  returns 0 only for the untracking shape. All four conjuncts are required: HEAD exists;
  `git ls-tree -r --name-only HEAD -- "$p"` is non-empty; every file it lists fails
  `git ls-files --error-unmatch`; `git ls-files -- "$p"` is empty; and
  `git diff --cached --name-status HEAD -- "$p"` is non-empty with **every** line a `D` entry
  (no `M`/`A`/`R`/`C`/`T`). Write it `set -e`-safe (capture rather than test bare failing
  assignments, matching the script's existing `-e`-exempt capture idiom).
- [ ] Insert the new case in the positive-pathspec branch **after** the V9 repository-containment
  guard and the V10 containment guard, and **before** case 1's existence test — the ordering is
  load-bearing: case 1 would otherwise claim a content-present directory first, and V9 must keep
  dropping an out-of-repository path before any enumeration runs.
- [ ] Route a matching pathspec into `filtered_pathspecs` only, **never** `add_pathspecs`, and
  record it in a new dedicated ledger array (e.g. `cached_untracking_pathspecs`). Do **not**
  append it to `dropped_pathspecs` — V6 must not see it as a drop.
- [ ] Add a block comment at the new case stating its premise explicitly ("index deletions WITH
  content still present on disk"), contrasted against case 2's and the V7 carve-out's premise
  ("content gone from the working tree"), so a future reader cannot conflate them.
- [ ] Verify `bash -n` on the edited script, then run the scratch probe below.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-claude-refresh-matcher.sh,test-git-commit-phase.sh,test-git-commit-scoped.sh,test-guard-destructive-git.sh,test-guard-git-push.sh,test-handoff-dispatch-identity.sh,test-lint-directory-pathspec-boundary.sh,test-lint-scoped-commit-boundary.sh,test-orchestrate-conclusion-aggregate.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-unwind-dispatch.sh,test-redeploy-checkpoint-promotion.sh` is the exact covering set `suite_selection_select` returns for this phase's single touched path, and it exercises every existing V2/V7 classification case the insertion could regress.

**Scope Hypothesis**: this phase is hypothesized to touch exactly one file and to need exactly
one new helper function plus one new `if` branch in the V2 loop. Confirm by re-deriving the loop
structure before editing; if the branch cannot be inserted ahead of case 1 without restructuring
the surrounding `case`/`if` nesting, record that in the phase notes rather than silently
restructuring more than one branch.

**Files to modify**:

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - new untracking-shape helper
  predicate, new V2 case ahead of case 1, new `cached_untracking_pathspecs` ledger array.

**Verification**:

- `bash -n agent-system/extensions/core/scripts/git-commit-scoped.sh` exits 0.
- The suite subset named in the Tier Justification above runs green.
- Scratch probe (two repos, built the way `test-git-commit-scoped.sh`'s `build_repo` does — the
  script plus its runtime dependencies copied into `<scratch>/.claude/scripts/`): `git rm -r
  --cached sub` with content left on disk, then the script invoked with `-- sub`. In BOTH the
  gitignored and non-gitignored repos, assert `git ls-files -- sub` is **empty** afterward (the
  staged deletions survive; the non-gitignored revert is gone) and that the script no longer
  exits 2 with `not present in the index at all`. The commit itself is expected NOT to land yet
  (exit 1, "nothing to commit") — that is this phase's known, documented intermediate state,
  closed by Phase 2.

---

### Phase 2: Commit the untracking, and keep V8 from false-positiving on it [NOT STARTED]

**Goal**: make the untracking actually land in HEAD. Add a guarded commit path for the untracking
shape that is provably equivalent in scope to the pathspec-scoped commit it replaces, and correct
the V8 pre-commit intent snapshot so a correctly committed untracking is not reported as a
partial commit.

**Tasks**:

- [ ] Re-read the commit invocation (`git commit -m "$full_message" -- "${pathspecs[@]}"`,
  including its index.lock retry) and the V8 pre-commit intent snapshot block.
- [ ] Add the index-equivalence guard, evaluated only when `cached_untracking_pathspecs` is
  non-empty: compare `git diff --cached --name-only HEAD` against
  `git diff --cached --name-only HEAD -- "${filtered_pathspecs[@]}"` (both sorted). Equal means
  the staged set is exactly the declared scope, honoring `:(exclude)` entries via git's own
  resolver. Unequal means foreign staged content — refuse with `exit 2` and a message textually
  distinct from both the V7 refusal and the V3 refusal, naming the staged paths that fall outside
  the declared pathspec set.
- [ ] When the guard passes, commit with a **bare** `git commit -m "$full_message"` (no `--
  pathspecs`), preserving the existing `-e`-exempt capture idiom, the `commit_exit` semantics,
  and the one bounded index.lock retry. Leave the unchanged `git commit -- "${pathspecs[@]}"`
  path in place for every invocation with no untracking pathspec — this is an alternate branch,
  not a replacement.
- [ ] Add a block comment recording why the pathspec-scoped form cannot express this shape:
  `git commit -- <pathspec>` has `--only` semantics and re-reads the working tree for each named
  path, so a path present on disk but staged as deleted yields "nothing to commit"; this was
  verified for a directory pathspec, an explicit HEAD-tracked file list, and an explicit
  `--only` invocation alike.
- [ ] Correct the V8 intent snapshot: for every enumerated file that lies under a pathspec in
  `cached_untracking_pathspecs`, record the `absent` sentinel instead of a
  `git hash-object` of its working-tree content. Use git's own resolver to decide membership
  (e.g. enumerate `git ls-tree -r --name-only HEAD -- "${cached_untracking_pathspecs[@]}"` once
  and test membership against it), never a string prefix match. Leave the fail-safe behavior,
  the `absent`-for-missing-file branch, and the post-commit comparison logic untouched.
- [ ] Emit the distinct NOTE when `cached_untracking_pathspecs` is non-empty, alongside (never
  merged into) the existing fully-staged-deletion NOTE: name the count, name the paths, state
  that every file HEAD tracks under them is staged as a pure deletion with content still present
  on disk, and state explicitly that this is **not** the source half of a directory move.
- [ ] Verify `bash -n`, then run the scratch probes below.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-claude-refresh-matcher.sh,test-git-commit-phase.sh,test-git-commit-scoped.sh,test-guard-destructive-git.sh,test-guard-git-push.sh,test-handoff-dispatch-identity.sh,test-lint-directory-pathspec-boundary.sh,test-lint-scoped-commit-boundary.sh,test-orchestrate-conclusion-aggregate.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-unwind-dispatch.sh,test-redeploy-checkpoint-promotion.sh` is the exact covering set `suite_selection_select` returns for this phase's single touched path, and its X-series V8 cases plus W-series deletion cases are precisely the gates the commit-path branch and the intent-snapshot change could regress.

**Scope Hypothesis**: hypothesized to touch exactly one file, in three regions (the V8 intent
snapshot, the commit invocation, the NOTE emission block), with no change to the V7 loop at all.
Confirm by re-reading those three regions before editing; if the V7 loop turns out to need a
change after all, stop and record why rather than editing it silently — the first HARD
CONSTRAINT makes that loop a deliberate no-touch zone.

**Files to modify**:

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - index-equivalence guard, bare
  commit branch for the untracking shape, V8 intent-snapshot `absent` correction, distinct NOTE.

**Verification**:

- `bash -n agent-system/extensions/core/scripts/git-commit-scoped.sh` exits 0.
- The suite subset named in the Tier Justification runs green.
- Scratch probes, asserted via `git log`/`git show --name-status` (never exit code alone), in
  both a gitignored and a non-gitignored repo: HEAD advances by exactly one commit; the commit
  records every file under the pathspec as `D`; `git ls-files -- sub` is empty; every file is
  **still present on disk**; no exit 5 (the V8 false positive is gone); and the new NOTE appears
  on stderr while the "source half of a directory move" NOTE does **not**.
- Negative probe: with a foreign staged file outside the declared pathspec set, the invocation
  refuses with the new exit-2 message and HEAD does not advance.

---

### Phase 3: Pin the shape, and pin what must keep refusing [NOT STARTED]

**Goal**: add the regression coverage the task's VERIFY section requires, plus the silent-revert
pin the research phase's new finding makes necessary, using the suite's own conventions.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`'s existing
  `W1-W4` section and its `build_repo`/`build_repo_movable` harness helpers, and confirm the
  letter-cluster inventory before choosing a prefix (`Y` was free at planning time: the file's
  live clusters are `T`, `U`, `V`, `W`, `X`, `Z`).
- [ ] Add a harness helper that builds a repo, commits content, then runs `git rm -r --cached`
  on a subdirectory leaving content on disk — parameterized on whether that subdirectory is
  gitignored, so the gitignored and non-gitignored symptoms share one builder.
- [ ] The headline regression case (gitignored): the invocation exits 0, HEAD advanced by one,
  `git show --name-status HEAD` records every file as `D`, the files remain on disk, and the
  index no longer tracks them.
- [ ] The silent-revert pin (non-gitignored): same assertions, plus an explicit assertion that
  the files are **not** re-tracked in the index afterward — this is the case that would silently
  pass against the pre-fix script while the untracking never happened.
- [ ] The NOTE-distinctness case: stderr carries the new untracking NOTE and does **not** carry
  the "source half of a directory move" wording.
- [ ] The partial-untracking refusal: one file under the directory restored to the index (or
  modified on disk), so the predicate must reject and the script must refuse rather than commit
  — this is the concrete check for the "do NOT let a widened predicate accept a
  genuinely-unstaged directory" constraint.
- [ ] The out-of-repository (128) refusal pin: an absolute pathspec resolving outside the
  repository still refuses. Note in the case comment that this is dropped by the V9 containment
  guard before classification, not by the V7 predicate.
- [ ] The foreign-staged-content refusal: a staged file outside the declared pathspec set makes
  the untracking invocation refuse, proving the bare commit can never widen scope.
- [ ] Confirm `W1` and `W3` (directory-move pair and pure deletion) are present and **unchanged**
  — the explicit regression guard the task's VERIFY section asks for.
- [ ] Demonstrate the FAILS-before property without ever committing a red suite: extract the
  pre-fix script with `git show <pre-Phase-1 sha>:agent-system/extensions/core/scripts/git-commit-scoped.sh`
  into a scratch directory, point the new cases' harness at that copy, observe and record the
  failures in the phase notes, then confirm the same cases pass against the fixed script.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-claude-refresh-matcher.sh,test-git-commit-phase.sh,test-git-commit-scoped.sh,test-lint-scoped-commit-boundary.sh,test-orchestrate-unwind-dispatch.sh` is the exact covering set `suite_selection_select` returns for this phase's single touched path, and a green run of it is the whole deliverable of this phase.

**Scope Hypothesis**: hypothesized as seven new cases in one new letter cluster, in exactly one
file, with zero edits to any existing case. Confirm the cluster letter is still unused and that
`W1`/`W3` need no modification; if an existing case must change to accommodate the new helper,
record that deviation explicitly — silently editing an existing pin would destroy the regression
guard this phase exists to provide.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - new harness helper and
  new case cluster covering the untracking shape and its refusal boundaries.

**Verification**:

- Every new case passes; `W1`-`W4`, `U1`-`U6`, `X1`-`X8` and `T8`-`T10` still pass.
- The scoped narrowing is used: `run-all.sh --only <suite list>`, never the full aggregator
  (the full battery runs once, in the final phase).
- Every new case asserts the landed commit via `git log`/`git show --name-status`, never exit
  code alone, matching the suite's stated discipline.

---

### Phase 4: Record the untracking shape and the sanctioned recipe [NOT STARTED]

**Goal**: leave a durable, discoverable record so no future agent re-derives the
relocate-the-directory workaround, and so the new carve-out's premise is documented beside the
directory-move carve-out's rather than inside it.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/context/standards/git-staging-scope.md` immediately
  before editing — this file is contested territory with task 446, which may have landed changes.
  Append a sibling section; merge, never overwrite.
- [ ] Add a new section modeled on the existing "Rename and Directory-Move Staging" section's
  structure (Rule / Failure mode this rule prevents / Why no existing gate catches it /
  Canonical illustration), covering the `--cached` untracking shape: index deletions with content
  still present on disk.
- [ ] State the sanctioned recipe in one unambiguous sentence: `git rm -r --cached <dir>`, then
  an ordinary `git-commit-scoped.sh --message ... -- <dir>`. State explicitly that relocating
  content out of the working tree is **not** required and should not be used.
- [ ] Document both gitignore-dependent symptoms the fix closes (the refusal and the silent
  revert) so a reader encountering either in an older log can identify it, and document that an
  explicit file list is **not** a workaround for an unfixed script, since the hazard is in
  `--only` commit semantics rather than pathspec granularity.
- [ ] Note the two premises side by side — directory move: content gone from the working tree;
  untracking: content present — and cross-reference the script's two distinct NOTE strings so a
  stderr reader can map a note to a shape.
- [ ] Add a brief entry to the script's own header finding list describing the untracking case,
  consistent with how the existing V-findings are summarized there.
- [ ] Check the edited prose against `rules/no-task-references-in-deliverables.md` and
  `rules/no-record-versioning-in-deliverables.md`: no task numbers, and no "previously /
  no longer / used to" framing — state the current design only.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-claude-refresh-matcher.sh,test-git-commit-phase.sh,test-git-commit-scoped.sh,test-guard-destructive-git.sh,test-guard-git-push.sh,test-handoff-dispatch-identity.sh,test-lint-directory-pathspec-boundary.sh,test-lint-scoped-commit-boundary.sh,test-orchestrate-conclusion-aggregate.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-unwind-dispatch.sh,test-redeploy-checkpoint-promotion.sh,test-todo-move-pair-staging.sh` is the exact covering set `suite_selection_select` returns for this phase's two touched paths together, and the script hunk is comment-only (confirmed by `bash -n` plus a diff read-through showing every hunk inside the header comment block).

**Scope Hypothesis**: hypothesized as one new section in `git-staging-scope.md` plus one
header-comment entry in the script, touching two files and no executable line. Confirm by diff
read-through that the script hunk lies entirely inside its header comment block; if the header
entry cannot be added without touching code, treat that as a scope change and record it.

**Files to modify**:

- `agent-system/extensions/core/context/standards/git-staging-scope.md` - new sibling section
  documenting the untracking shape, both symptoms, and the sanctioned recipe.
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - header finding-list entry
  (comment only).

**Verification**:

- The suite subset named in the Tier Justification runs green; `bash -n` on the script exits 0.
- Diff read-through confirms every script hunk lies inside the header comment region.
- `bash .claude/scripts/check-task-references.sh` (or the equivalent repo-wide lint entry point
  that resolves) reports no new occurrence under `agent-system/**`.
- The new section's recipe sentence is checkable by a reader against Phase 3's headline test
  case: the documented invocation is the one the test actually runs.

---

### Phase 5: Redeploy and run the full gate set [NOT STARTED]

**Goal**: regenerate the deployed `.claude/` tree from the source store and prove the whole change
green against the complete repository gate battery.

**Tasks**:

- [ ] Re-read every file this plan changed, confirming no sibling task has modified them since
  the phase that edited them.
- [ ] Redeploy the source store with `bash .claude/scripts/deploy-headless.sh` (non-destructive
  resync mode), and confirm the deployed `.claude/scripts/git-commit-scoped.sh`,
  `.claude/scripts/tests/test-git-commit-scoped.sh`, and
  `.claude/context/standards/git-staging-scope.md` carry this plan's changes.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (no `--only-gate`
  narrowing), including Gate 8's full shell-suite battery.
- [ ] Confirm the end-to-end outcome against the task's REQUIRED OUTCOME, using the deployed
  script in a scratch repo: an untracking commits without any file leaving the working tree.
- [ ] Record any gate collision, deviation, or notable smoothness in this task's issue log as it
  arises.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree deploy regeneration via
  `deploy-headless.sh`, which rewrites the entire deployed `.claude/` tree.

**Verification**:

- `bash .claude/scripts/deploy-headless.sh` completes without error, and the three changed files
  are present in the deployed tree with this plan's content.
- `bash .claude/scripts/verify-deploy.sh` runs the complete gate set and exits 0 — every gate,
  no `--only-gate` narrowing, no suite subset.
- A final scratch-repo run against the **deployed** script confirms the REQUIRED OUTCOME: a
  `git rm -r --cached <dir>` untracking commits via a plain `git-commit-scoped.sh` invocation,
  with every file still on disk and no relocation at any point.

---

## Testing & Validation

- [ ] A `git rm -r --cached <dir>` untracking with content on disk commits successfully, in both
  the gitignored and non-gitignored cases, with the deletion recorded in HEAD.
- [ ] The files remain on disk and the index no longer tracks them after the commit.
- [ ] The non-gitignored silent revert is pinned as impossible (files are not re-tracked).
- [ ] A partially-untracked pathspec is refused, not accepted.
- [ ] A pathspec present on disk with unstaged content differences is refused (unchanged V7
  behavior).
- [ ] An out-of-repository pathspec is refused (unchanged V9 behavior; the 128 case).
- [ ] A foreign staged entry outside the declared pathspec set makes the untracking invocation
  refuse rather than commit wider.
- [ ] `W1` and `W3` (directory-move pair, pure deletion) pass unchanged.
- [ ] The untracking NOTE and the directory-move NOTE are textually distinct and never both
  emitted for the same pathspec.
- [ ] No exit 5 (V8 false positive) on a correct untracking commit.
- [ ] The complete gate set is green after redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — untracking classification,
  guarded commit path, V8 intent correction, distinct NOTE, header entry.
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — new case cluster.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — new sibling section
  documenting the shape and the sanctioned recipe.
- Regenerated deployed `.claude/` tree.
- This plan, as the durable record of the ruling and its reasoning.

## Rollback/Contingency

Each phase is one commit scoped to its own named files, so reverting is a per-phase
`git revert` of that commit — no snapshot-and-reset is needed, and none should be taken in the
reverting default mode on this shared working tree. If Phase 2's guarded bare commit proves
unacceptable on review, Phase 1 alone is independently valuable and safe to keep: it removes the
non-gitignored silent revert (the worse of the two symptoms) without changing the commit
invocation at all, and the task would then fall back to ruling (3) with the honest documented
limitation that an untracking cannot be committed by this script — which is a materially weaker
outcome and should be adopted only if Phase 2's index-equivalence guard cannot be made sound.
If Phase 4's documentation edit collides with task 446's landed changes, re-read and merge; do
not overwrite that file's existing sections.
