# Implementation Plan: Task #374

- **Task**: 374 - Diagnose and fix the silent staging drop in git-commit-scoped.sh
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: specs/374_diagnose_silent_staging_drop_in_git_commit_scoped/reports/01_silent-staging-drop-diagnosis.md
- **Artifacts**: plans/01_silent-staging-drop-loud-failure.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research phase ruled out three of the four candidate mechanisms by direct code reading and
reproduced the symptom under the fourth (two concurrent writers naming a shared path while the
`specs/.commit-lock` mutex is in its documented fail-open state). It also established the
load-bearing git fact that makes the whole class possible: `git commit -- <pathspec>` re-reads
working-tree content for each named path at commit time, so the script's existing V7 per-path
index verification proves only that staging *could* succeed, never what the commit actually
snapshotted. This plan therefore implements the research's mechanism-agnostic fix rather than a
narrow patch against one concurrency precondition: a **pre-commit intent snapshot** taken before
`git add`, compared against post-commit `HEAD`, with a loud `V8` diagnostic and a new dedicated
exit code `5` whenever a named positive pathspec did not land. The fixture is built first so it
is observed red against the unmodified script, the false-positive dimensions the research flagged
(staged deletions, directory pathspecs carrying ignored/ephemeral files, benign no-ops) are pinned
as separate regression cases, and the work closes with a source-store redeploy so dispatches
actually run the fixed version.

### Research Integration

Four findings from `reports/01_silent-staging-drop-diagnosis.md` shape this plan directly:

1. **Three mechanisms are ruled out by code, not inference** — the ephemeral-`:(exclude)`
   injection loop (never reached; the real commit named no bare `specs/{NNN}_*/` directory
   pathspec), the `--task` contention-claim lease (a strict no-op when `--task` is omitted, and
   the standard phase-commit template omits it), and a `.gitignore`/`git check-ignore`
   interaction (`git check-ignore -v` reports "not ignored" for every affected fragment). The
   plan does not revisit them.
2. **`zigzag.typ` structurally could only be V2 case 1 ("matched")** — present on disk and
   already tracked — so no existing gate (V2/V6/V7) could ever have classified it as a drop.
   This is why detection has to live *after* the commit, not anywhere in the staging path.
3. **`git commit -- <pathspec>` re-reads the working tree at commit time.** Undocumented in the
   script's own V2–V7 header and load-bearing: it is the reason a correct `git add` plus a
   correct index verification still yields a wrong tree. Phase 4 records it.
4. **A post-commit integrity gate satisfies the acceptance bar regardless of root cause.** The
   research's own ruling carries an explicit caveat (it could not confirm a second writer was
   live during the real 2026-10-08 14:28 window), and recommendation 1 is deliberately built to
   be correct even if that ruling is later revised.

Two research recommendations are **deliberately not adopted as task scope**, both recorded as
flagged follow-ups rather than silently dropped (see Goals & Non-Goals):

- Making the `specs/.commit-lock` mutex fail *closed* on acquire timeout (research
  recommendation 3). The research itself says this is "a behavior change beyond 'make the failure
  loud' and should be a planning-phase decision". Decision: **not in this task** — the dispatch's
  own framing is "a correct narrow commit plus a loud failure", and a fail-closed mutex can refuse
  commits outright, which is a far larger blast radius than this task is scoped for. What *is*
  adopted is correcting the fail-open branch's now-falsified safety comment (Phase 4).
- Making callers branch on the new exit code. Every current call site uses the
  `cmd || echo "NOTE: ..."` idiom, which swallows any nonzero code; the same residual is already
  recorded for V6 in `context/standards/git-staging-scope.md`. Decision: **not in this task** —
  scope item 3's bar is on the script ("a caller must not be able to *receive* exit 0 for a
  partial commit"), and rewiring ~11 commit sites is its own change.

**One design divergence from the research, stated explicitly.** Recommendation 1 describes the
snapshot as `git hash-object` against "the working-tree file" per pathspec. That shape only works
for a pathspec that names exactly one regular file; it cannot handle a directory pathspec
(`specs/{NNN}_{slug}/`, which real callers pass and the existing suite's U6/W4 cases exercise),
a glob, or the interaction with `:(exclude)` entries. Phase 2 therefore keeps the research's
hash-comparison *semantics* but lets **git's own pathspec resolver** enumerate the intended file
set, which also makes the gate robust against a concurrent sibling rewriting a named file between
the snapshot and the commit — a real condition in this repository's multi-agent model.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in this dispatch (`roadmap_path` absent, `roadmap_flag` not set),
so no roadmap review or update phases are included.

## Goals & Non-Goals

**Goals**:
- A deterministic regression fixture in the script's own suite that fails against the current
  script (named positive pathspec absent from the commit, exit 0, no diagnostic) and passes once
  the gate lands (scope item 4).
- A post-commit integrity gate (`V8`) in `git-commit-scoped.sh` that makes the failure loud: a
  marked `ERROR:` naming every path asked for but not carried, and a new dedicated exit code `5`
  on the path where the commit itself succeeded (scope item 3).
- Zero false positives on the shapes the existing gates already handle correctly: V2 case-2
  already-staged deletions, V7's fully-staged-deletion acceptance, directory pathspecs carrying
  ignored/ephemeral files, and the benign "nothing to commit" no-op.
- The ruling on the mechanism recorded with its evidence (the research report holds it; Phase 4
  records the git-semantics fact the script header is missing and corrects the fail-open comment
  the research falsified).
- The deployed tree for this repository refreshed so dispatches run the fixed script, with
  consumer-repo staleness surfaced rather than assumed.

**Non-Goals**:
- Widening any pathspec, relaxing the over-staging prohibitions in `rules/git-workflow.md`, or
  any change that makes callers stage more broadly (explicitly out of scope per the dispatch).
- Making `specs/.commit-lock` fail closed on acquire timeout (flagged follow-up; see Research
  Integration for the decision and its rationale).
- Rewiring call sites to branch on exit `5` (flagged follow-up; same residual already recorded
  for exit `4`).
- Deploying into the eight registered consumer repositories. Regeneration there is manual by
  design (`context/patterns/regeneration-is-manual-only.md`); Phase 5 surfaces staleness via
  `--consumer-report` and stops there.
- Re-opening the three mechanisms the research ruled out by code inspection.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The research's reproduction is probabilistic (3/20, 1/10 trials; figures carried from `reports/01_...md`), so a fixture built on it would be flaky in a 103-suite CI battery | H | H | Phase 1 requires a **deterministic** injection and names a primary candidate (a planted `pre-commit` hook mutating the partial `GIT_INDEX_FILE` git builds for a pathspec commit) with the two-writer harness as an env-gated, non-default fallback. A flaky assertion is not an acceptable Phase 1 outcome |
| The gate false-positives on a correct staged deletion or a rename's source half, refusing commits that are already right | H | M | Phase 3 pins each shape as its own case *before* Phase 5 closes; the snapshot records an explicit "absent" sentinel so correct absence compares as a match, exactly as V2/V7 already special-case it |
| The gate false-positives on an ignored file swept up implicitly inside a directory pathspec (the residual blind spot V7's header already documents) | M | M | Enumeration uses `--exclude-standard` so ignored paths never enter the intended set; pinned as a Phase 3 case |
| A concurrent sibling rewrites a named file between the snapshot and the commit, so `HEAD` differs from the recorded intent without a drop having occurred | M | M | Treated as a true positive by design (the content you staged is not what landed), but the diagnostic distinguishes "absent from HEAD" from "present with different content" so the caller can tell the two apart. Recorded in Phase 4's documentation, not left to a reader to infer |
| Phase 2 edits the single commit path every dispatch in the system runs; a regression breaks committing everywhere, including this task's own commits | H | L | Phase 2 declares `full` verification despite being non-final, and Phase 1's fixture plus the suite's 13 existing cases run before the edit is committed |
| Sibling task 349 is dispatched this same cycle on this shared tree with no declared `file_scope` | M | M | Re-read each target file immediately before editing; stage only this task's own explicit file list (never a directory or glob add); never run `git-snapshot.sh` in its reverting default mode; report any foreign commit or modification rather than dismissing it |
| Editing `.claude/**` instead of the source store silently loses the work to the next deploy | H | L | Every file target below is under `agent-system/extensions/core/`; Phase 5's deploy is what populates `.claude/` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Deterministic Red Fixture for the Silent Drop [COMPLETED]

**Goal**: A new case in `test-git-commit-scoped.sh` that deterministically produces the incident's
exact shape — a named, on-disk, tracked, non-ignored positive pathspec absent from the resulting
commit while the script exits 0 — and asserts the loud outcome the fix must produce. Observed
**red** against the unmodified script before any production edit is made.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` and reuse its
      established idioms verbatim: the `build_repo covered` helper, `run_commit`, the
      `pass()`/`fail()`/`info()` counters, and the suite's convention of asserting via
      `git log`/`git show --name-only`/`git rev-list --count` rather than exit code alone.
      *(completed)*
- [x] Implement the drop injection deterministically. Primary candidate: plant a `pre-commit`
      hook in the scratch repo that rewrites the partial index git builds for a
      `git commit -- <pathspec>` invocation (the hook runs with `GIT_INDEX_FILE` pointing at that
      temporary index), reverting one named path to its `HEAD` blob via `git update-index`.
      Confirm by direct probe that the hook actually reaches and mutates that index on the
      installed git version before building assertions on it.
      *(completed: direct probe confirmed GIT_INDEX_FILE points at the temp index and
      git update-index --cacheinfo mutates it; the X1 case built on it is 100% deterministic)*
- [ ] If the primary candidate does not reproduce, fall back to the research's two-writer
      forced-fail-open harness (Appendix of `reports/01_...md`): plant a long-lived foreign holder
      in `specs/.commit-lock` so both writers take the documented fail-open branch, then run two
      real concurrent invocations each naming one unique file plus one shared file. Gate it behind
      an opt-in environment variable so the default suite run stays deterministic, and record in
      the test's own comment why it is not a default case.
      *(deviation: skipped — primary candidate reproduced deterministically; fallback not needed,
      see progress/phase-1-progress.json)*
- [x] Add the assertions the fix must satisfy: the script's exit status is nonzero (specifically
      `5`), its stderr carries a marked `ERROR:` naming the dropped path, and the drop is
      independently confirmed by comparing `git show HEAD:<path>` against the working-tree file.
      *(completed)*
- [x] Run the suite and **record the red result** — the new case must fail, and all pre-existing
      cases must still pass. A green run at this point means the injection is not reproducing the
      defect and the phase is not done.
      *(completed: X1's first assertion fails exactly as expected — rc=0 not 5, no V8 ERROR — and
      all 37 other assertions, including every pre-existing T/U/V/W case, pass: 37 passed, 1
      failed)*
- [x] Record an issue-log entry for which injection mechanism reproduced and which did not, via
      the dispatch's `issue-record.sh` call.
      *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The edit is confined to one test file with no production surface, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh`
runs exactly the suite that file belongs to.

**Scope Hypothesis**: Two hypotheses to confirm at implementation time, neither assumed.
(a) That a `pre-commit` hook can deterministically mutate the temporary partial index of a
`git commit -- <pathspec>` invocation on the installed git version — confirm by a direct probe in
a scratch repo (print `GIT_INDEX_FILE` and `git ls-files --stage` from inside the hook) before
writing assertions against it; if it cannot, the fallback bullet above applies.
(b) The drop-rate figures "3/20 and 1/10 trials, 0/20 control" are **carried** from
`reports/01_silent-staging-drop-diagnosis.md` and are not re-derived here; they are cited only as
the reason a probabilistic harness is rejected as the default fixture, and nothing in this phase
depends on their exact values.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - add the new red case
  (one new test block in the suite's existing style, plus a planted-hook or two-writer helper
  alongside `build_repo`/`build_repo_tracked_ignored`)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh`
  exits nonzero, with the failure attributable to the new case only and every pre-existing case
  still passing (read the per-case `[PASS]`/`[FAIL]` lines, not the aggregate exit code alone).
- The new case's failure output shows the script exited `0` and HEAD did not carry the named
  path — i.e. the defect itself, reproduced, not a harness error.
- `bash -n` and `shellcheck` clean on the edited test file.

---

### Phase 2: Pre-Commit Intent Snapshot and the V8 Post-Commit Integrity Gate [COMPLETED]

**Goal**: `git-commit-scoped.sh` records what each surviving positive pathspec was *intended* to
carry before staging, verifies after the commit attempt that `HEAD` actually carries it, and fails
loudly when it does not — turning the incident's silent exit 0 into a named, non-zero outcome.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/git-commit-scoped.sh` immediately before
      editing (sibling task 349 is live on this tree).
      *(completed: no sibling changes to this file; git log confirmed unmodified since task 325)*
- [x] Insert the **intent snapshot** after the V2/V3 classification completes (so it sees
      `filtered_pathspecs`, with case-3 drops already excluded) and *before* the `git add` block.
      Enumerate the intended file set with git's own resolver over the full pathspec array
      (positives and `:(exclude)` entries together, so exclusion magic is honored by git rather
      than reimplemented): the union of `git ls-files`, `git diff --name-only HEAD`, and
      `git ls-files --others --exclude-standard`, each restricted to that pathspec array. For each
      enumerated file record either its `git hash-object` of the working-tree content, or an
      explicit `absent` sentinel when the file is absent from the working tree (the correct
      intended post-state for a V2 case-2 or V7 fully-staged deletion).
      *(completed)*
- [x] Add the **V8 gate** after the existing V6 gate and after `echo "$commit_output"`. For each
      snapshot entry, resolve the post-commit state from `HEAD` (`git rev-parse HEAD:<file>`, or
      confirmed absence) and compare against the recorded intent. Classify each mismatch as either
      `absent from HEAD` (a drop) or `present with different content` (landed, but not what was
      staged) so the two are distinguishable in the diagnostic.
      *(completed: implemented as a pure comparison placed BEFORE the V6 gate's own `exit 4`
      textually, rather than strictly after it, so V8's diagnostic is never suppressed when V6
      also fires for the same invocation — the actual exit-code DECISION, which is what the task
      list's own wording is about, still happens last, after both gates have run; see Key
      Decisions in the phase-2 handoff)*
- [x] On any mismatch, print one marked `ERROR:` block labelled as Verified Finding V8, naming
      every mismatching path with its classification, and stating plainly that the commit is
      partial. Then:
      - when `commit_exit` is `0` (a commit was created), **exit 5** — a new dedicated code
        outside the existing 0–4 range, never folded into `commit_exit`, because the defining
        feature of this defect is that `commit_exit` is 0;
      - when `commit_exit` is nonzero, emit the same diagnostic but **preserve the existing exit
        code** (`1`, or V6's `4`). Rationale to record in the code comment: those paths are
        already nonzero and already covered by existing contract and existing suite cases, and
        changing them would break pinned behavior for no gain in the bar this task must meet.
      *(completed)*
- [x] Keep the gate fail-safe in the direction that cannot block work: any error *inside* the
      snapshot or the comparison (an unresolvable `HEAD` on a first commit, a `git` plumbing
      failure) emits a stderr `WARN:` and falls through to the pre-existing exit path — the
      integrity check must never become the reason a commit cannot be reported at all. This
      mirrors the `--honest-index-rows` block's existing failure tolerance.
      *(completed)*
- [x] Guard every array expansion for `set -u` (`${#arr[@]}` test before expansion, matching the
      existing `dropped_pathspecs` handling), and use the script's established `-e`-exempt
      `if VAR=$(cmd); then ... else rc=$?; fi` capture idiom for every plumbing call whose nonzero
      exit is a routine outcome.
      *(completed)*
- [x] Re-run Phase 1's fixture and confirm it now passes, then run the whole suite.
      *(completed: 38/38 in test-git-commit-scoped.sh, 129 passed/1 failed in the full run-all.sh
      -- see Verification below for the one failure's attribution)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Tier Justification**: This edits the single sanctioned commit path that every dispatch in the
system runs and that 13 other suites under `scripts/tests/` exercise indirectly (via postflight,
the git guards, and the scoped-commit lints), so no suite subset or gate subset covers the
regression surface — a defect here breaks committing system-wide, including this task's own
commits.

**Scope Hypothesis**: The claim that enumerating via `git ls-files` + `git diff --name-only HEAD`
+ `git ls-files --others --exclude-standard` over the pathspec array reproduces git's own
resolution of a **directory** pathspec with `:(exclude)` entries is a hypothesis, not a fact.
Confirm it at implementation time by running the enumeration against the existing suite's U6 and
W4 repo shapes (a directory pathspec in a covered repo with ephemeral paths present, and an
in-scope directory move) and checking the enumerated set matches the file list the resulting
commit actually carries, before relying on it for the comparison.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - add the intent snapshot before
  the `git add` block; add the V8 gate after the V6 gate; extend the header's exit-code table
  with `5` (the full header V8 narrative lands in Phase 4)

**Verification**:
- Phase 1's new case passes; all 13 pre-existing cases in `test-git-commit-scoped.sh` still pass.
  *(confirmed: 38/38 assertions pass, including X1 and every T/U/V/W case)*
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` completes with no NEW failures
  relative to the pre-change baseline (capture the baseline before editing; an all-EXPECTED
  failure set exits 0 by that runner's own contract, so read the per-suite lines).
  *(confirmed: 129 passed, 1 failed -- `test-verify-deploy-context-budget.sh`'s own "baseline
  fixture is not clean" case, which never references git-commit-scoped.sh and is sensitive to
  ambient repo dirtiness from concurrently-dispatched sibling tasks on this shared tree, not to
  this phase's edit; see the phase-2 handoff and the issue-record.sh entry)*
- `bash .claude/scripts/verify-deploy.sh` runs its complete gate set green, including Gate 8's
  full shell-suite battery, Gate 17's scoped-commit boundary lint, and the doc-lint gates. Not
  `--skip-slow` and not `--only-gate`: a narrowed pass is not evidence for a phase declaring
  `full`. (The deployed-tree copy this reads is refreshed in Phase 5; if `.claude/` is stale at
  this point, run `deploy-headless.sh` first and note it, rather than reading a stale tree.)
  *(ran via deploy-headless.sh since .claude/ was stale: 32 of 34 checks passed; Gate 17 (scoped-
  commit boundary lint, directly relevant to this task) PASSED. The 2 failures (doc-lint Gate 3,
  manifest-verification Gate 5) are both confirmed, by direct inspection, to name sibling task
  349's own in-flight, not-yet-deployed approvals-extension scripts (approve-classify.sh,
  approve-guard.sh, approve-paths.sh) -- zero relation to git-commit-scoped.sh or
  test-git-commit-scoped.sh. Not a narrowed pass by flag; narrowed by attribution evidence
  instead, recorded via issue-record.sh rather than silently treated as green. Gate 8 confirmed
  separately via the full `run-all.sh` run above.)*
- `bash -n` and `shellcheck` clean on the edited script.
  *(confirmed: shellcheck output identical to the pre-change baseline -- same 3 pre-existing
  info-level SC1091/SC2329 notices, zero new findings)*
- Exit-code contract checked by hand against a scratch repo: `0` on a clean full commit, `1` on a
  benign no-op, `2`/`3`/`4` unchanged on their existing refusal paths, `5` only on the
  commit-created-but-partial path.
  *(confirmed by direct hand-check for 0, 1, 2, 4, 5 against a fresh scratch repo; 3 already
  covered by the V1-V7 contended-path suite cases)*

---

### Phase 3: False-Positive Dimension Tests [NOT STARTED]

**Goal**: Pin, as separate regression cases, every shape where absence from a tree is the
*correct* post-state — so the V8 gate cannot start refusing commits whose index was already
exactly right.

**Tasks**:
- [ ] Add a case for a **V2 case-2 already-staged deletion** (`git rm` already applied, path named
      in the pathspec list): the commit lands, exit `0`, no V8 diagnostic.
- [ ] Add a case for the **V7 fully-staged-deletion acceptance** — the source half of a directory
      move, modelled on the suite's existing T10/W4 shape: both halves land, exit `0`, no V8
      diagnostic.
- [ ] Add a case for a **directory pathspec in a covered repo with all four ephemeral paths
      present** (the U6 shape): the commit lands, the ephemeral paths are absent from it, and
      their absence does **not** trigger V8.
- [ ] Add a case for a **newly-created ignored file** named inside a directory pathspec (the U5
      shape): silently skipped by `git add` as documented, and not reported by V8.
- [ ] Add a case for the **benign "nothing to commit" no-op**: exit `1` unchanged, no V8
      diagnostic.
- [ ] Add a case pinning that **V6's exit `4`** path still reports as `4`, not `5`, when a
      genuine drop coincides with no commit being produced.
- [ ] Add a case distinguishing the two V8 mismatch classes: a path **absent** from `HEAD` versus
      a path **present with different content**, asserting the diagnostic names the right class.
- [ ] Run the full suite and confirm green.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: The edit is confined to one test file with no production surface, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh`
runs exactly the suite that file belongs to.

**Scope Hypothesis**: The seven dimensions enumerated above are a hypothesis about what the V8
gate can false-positive on, derived from the Risks table of
`reports/01_silent-staging-drop-diagnosis.md` plus the V2/V7 header cases in the script itself.
Confirm at implementation time by walking the script's header V2–V7 narrative and the existing
suite's T/U/V/W case list, and add any shape those name that this list missed rather than
treating seven as a target.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - add the false-positive
  dimension cases alongside Phase 1's red case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh`
  exits 0 with every case reporting `[PASS]`, including Phase 1's.
- Each new case is confirmed to be a real guard, not a tautology: temporarily inverting the V8
  predicate makes the relevant case fail. Record that the inversion probe was run and reverted.
- `bash -n` and `shellcheck` clean on the edited test file.

---

### Phase 4: Record the Ruling, the Git Semantics, and the Corrected Fail-Open Comment [NOT STARTED]

**Goal**: The script's own header and the scoped-commit standard carry V8, the exit code `5`, the
undocumented `git commit -- <pathspec>` working-tree-reread fact, and a corrected version of the
fail-open safety comment the research falsified — so a future reader is not left to re-derive any
of it.

**Tasks**:
- [ ] Add a **V8** entry to `git-commit-scoped.sh`'s header "Safety gates" block, in the same voice
      as V2–V7: what the defect was (a named, matched, non-ignored positive pathspec absent from
      the resulting commit while the script exited 0 and printed nothing), why no earlier gate
      could catch it (such a path is structurally V2 case 1), what the gate does (pre-commit
      intent snapshot versus post-commit `HEAD`), and the deliberate asymmetry on the nonzero
      `commit_exit` path (diagnostic only, existing code preserved).
- [ ] Add the git-semantics note to the same header: `git commit -- <pathspec>` re-reads
      working-tree content for each named path at commit time and does not simply commit what
      `git add` last staged, so the V7 index verification establishes only that staging *could*
      succeed. This is the Context Extension Recommendation from the research report.
- [ ] Add `5` to the header's "Exit codes" table.
- [ ] Correct the `specs/.commit-lock` fail-open branch's inline comment. The current claim
      ("Worst case is the safe index.lock race, not commit misattribution, since this commit is
      still path-scoped") was falsified by the research for the shared-path shape: two concurrent
      committers naming an overlapping path *can* drop that path from one of their commits even
      though each commit is individually path-scoped. State the corrected worst case and point at
      V8 as what now detects it.
- [ ] Update `agent-system/extensions/core/context/standards/git-staging-scope.md`'s "Exit-Code
      Contract and Safety Gates" section: add the `5` row to the exit-code table and a **V8** gate
      label in the same voice as the existing V2/V3/V5/V6 labels. Keep it a mirror of the script
      header, as that section's own preamble states it is.
- [ ] Record the two flagged follow-ups in that same section's residual language, alongside the
      existing "no caller branches on this exit code today" note: (a) no caller branches on exit
      `5` either; (b) the `.commit-lock` fail-closed option, with the research's falsification of
      the fail-open comment as its evidence and the reason it was held out of this change.
- [ ] Verify no task-number references leaked into either file (both are outside `specs/**`).

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: Every hunk is a comment or markdown edit with no executable surface;
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh`
covers the script-header half (catching an edit that crosses out of the comment region), and
because `git-staging-scope.md` has no mapped suite (`suite_selection_select` returns
`__FULL_SWEEP__` for it), its honest covering check is
`bash .claude/scripts/verify-deploy.sh --only-gate 3,4` plus a diff read-through.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - header V8 entry, the git-semantics
  note, exit code `5` in the table, corrected fail-open comment (comment regions only; the
  executable change is Phase 2's)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - exit-code table row for
  `5`, V8 gate label, the two residual notes

**Verification**:
- Diff read-through confirms every changed hunk in the `.sh` file lies inside a comment region.
- `bash -n` and `shellcheck` clean on the script (proving no hunk crossed out of a comment).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh`
  exits 0, unchanged from Phase 3.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` exits 0 (doc-lint and task-reference
  lint), checked by exit status, not by diffing captured output against a baseline.
- The exit-code table in the script header and the one in `git-staging-scope.md` are compared
  row-by-row and agree.

---

### Phase 5: Deploy and Run the Full Gate Set [NOT STARTED]

**Goal**: The fix is the version dispatches actually run, and the complete gate set is green on
the deployed tree.

**Tasks**:
- [ ] Confirm nothing was hand-edited under `.claude/**`: every change from Phases 1-4 lives under
      `agent-system/extensions/core/`.
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` to regenerate this
      repository's `.claude/` tree from the source store.
- [ ] Confirm the deployed `.claude/scripts/git-commit-scoped.sh` and
      `.claude/scripts/tests/test-git-commit-scoped.sh` match their source-store originals
      (byte comparison), and that the deployed `git-staging-scope.md` carries the V8 label.
- [ ] Run the full suite **from the deployed tree** so the fixture exercises the copy dispatches
      actually invoke, not only the source-store copy.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` — the complete gate set, no `--skip-slow` and no
      `--only-gate` — and record it green. A narrowed pass does not discharge this phase.
- [ ] Run `bash .claude/scripts/deploy-headless.sh --consumer-report` (or
      `check-consumer-freshness.sh --stale-only` directly) and record which of the eight
      registered consumer repositories are now stale with respect to this change. Report the list;
      do not deploy into them (manual by design).
- [ ] Record a wins/issues entry for the phase via the dispatch's `issue-record.sh` call, and
      attest explicitly if there is genuinely nothing to record.

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: full

**Files to modify**:
- None in the source store. This phase regenerates `.claude/**` via `deploy-headless.sh`; the
  deployed tree is a build artifact, never hand-edited.

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 with its complete gate set green — Gate 8's
  full shell-suite battery, Gate 12-14, Gate 17's scoped-commit boundary lint, Gate 18-21, and
  the doc-lint and task-reference-lint gates — not `--skip-slow`, not `--only-gate`.
- `bash .claude/scripts/tests/run-all.sh` green from the deployed tree, with
  `test-git-commit-scoped.sh` among the suites that ran (verified by name in the output, not
  assumed).
- `diff` confirms the deployed script and test file are byte-identical to the source-store copies.
- An end-to-end smoke check in a scratch repo built from the deployed tree: a correct full commit
  exits `0` silently, and the injected-drop fixture shape exits `5` with the V8 `ERROR:`.
- The consumer-freshness report is captured in the phase record with the stale repositories named.

## Testing & Validation

- [ ] The new fixture fails against the unmodified script (observed red in Phase 1) and passes
      after Phase 2 — both results recorded, not inferred.
- [ ] All 13 pre-existing cases in `test-git-commit-scoped.sh` still pass unchanged.
- [ ] Every false-positive dimension in Phase 3 passes, and each is confirmed non-tautological by
      a predicate-inversion probe.
- [ ] Exit codes `0`, `1`, `2`, `3`, `4` behave exactly as documented before this change; `5`
      appears only on the commit-created-but-partial path.
- [ ] `bash .claude/scripts/verify-deploy.sh` green on the deployed tree with no narrowing flags.
- [ ] No file under `.claude/**` was hand-edited; no task-number reference landed outside
      `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — intent snapshot, V8 gate, exit
  code `5`, header documentation, corrected fail-open comment
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — the deterministic red
  fixture plus the false-positive dimension cases
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — exit-code row, V8 gate
  label, residual notes
- A regenerated `.claude/` deploy tree for this repository, plus a recorded consumer-freshness
  report naming the stale consumer repositories
- `specs/374_diagnose_silent_staging_drop_in_git_commit_scoped/summaries/01_*-summary.md` at
  completion

## Rollback/Contingency

- The change is additive and confined to three source-store files. To revert, drop the V8 gate and
  the intent snapshot from `git-commit-scoped.sh`, remove the new test cases, revert the two
  documentation hunks, and redeploy — the exit-code contract returns to `0`-`4` with no caller
  change needed, because no caller branches on `5`.
- If Phase 1 cannot produce a deterministic reproduction by either the primary or the fallback
  mechanism, do **not** ship a flaky fixture. Record the non-reproduction with what it rules out,
  implement Phases 2-5 anyway (the gate is mechanism-agnostic and the acceptance bar for scope
  item 3 does not depend on the fixture), and close the phase as
  `[COMPLETED WITH EXCLUSIONS]` with scope item 4 enumerated as the exclusion and a follow-up
  task proposed for the fixture. This is the one place where a partial outcome is acceptable, and
  it must be stated explicitly rather than quietly narrowed.
- If the V8 gate proves to false-positive in real dispatch use after deployment, the fail-safe
  direction built into Phase 2 (any internal error warns and falls through) means the gate can be
  disabled by a single early `return`/flag rather than reverting the commit, keeping the
  documentation and fixture in place for a corrected second attempt.
