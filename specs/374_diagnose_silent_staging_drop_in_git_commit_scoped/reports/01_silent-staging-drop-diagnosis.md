# Research Report: Task #374

> **Relocated** 2026-10-08 from `~/Projects/Logos/Verification` (task 252 there) after research.
> Evidence cited below (commits `fc9f786e`/`96986be6`, `specs/224_...`, `typst/manual/...`) lives in
> that repository's history, not this one.

**Task**: 374 - Diagnose and fix the silent staging drop in git-commit-scoped.sh
**Started**: 2026-10-08T22:41:00-07:00
**Completed**: 2026-10-08T23:10:00-07:00
**Effort**: ~1 session (research only)
**Dependencies**: None
**Sources/Inputs**: - Codebase (`git-commit-scoped.sh`, `task-lock.sh`, `test-git-commit-scoped.sh`), git history/log of the incident commits (`fc9f786e`, `96986be6`), `specs/224_review_and_refactor_fragile_gate_infrastructure/issues.jsonl`, controlled scratch-repo reproduction experiments against the real script
**Artifacts**: - `specs/374_diagnose_silent_staging_drop_in_git_commit_scoped/reports/01_silent-staging-drop-diagnosis.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Reproduced** the exact symptom (a named, on-disk, tracked, non-ignored positive pathspec
  silently absent from a `git-commit-scoped.sh` commit that still exits 0) in a controlled
  scratch-repo harness, under one specific precondition: two concurrent invocations of the script
  both naming the *same* shared path, while the `specs/.commit-lock` mutex that is supposed to
  serialize them is in its own documented fail-open state (acquire timeout / stale-reclaimed
  holder). 3/20 and 1/10 trials dropped a named path under this condition; a control batch with
  the mutex acquiring normally produced 0/20 drops.
- **Ruled out**, by direct code reading plus targeted empirical tests against the live
  repository and a scratch copy of the real script, three of the four candidate mechanisms named
  in the dispatch: the ephemeral-exclude injection loop (never triggered — the real commit named
  no bare task-directory pathspec), the `--task` contention-claim lease (strictly a no-op when
  `--task` is omitted, and the standard phase-commit template never passes it), and a
  `.gitignore`/`git check-ignore` interaction (none of the ten `components/*.typ` fragments,
  including `zigzag.typ`, are gitignore-matched in the live repository).
- The fourth candidate — "a concurrent writer's index interaction" — is the only one left
  standing and the only one I could make reproduce; however I could **not** independently confirm
  that a second, concurrently-committing writer was actually active during task 224 phase 5's real
  commit window (every commit in that hour carries the same session id). The ruling below is
  therefore the best-supported, code-grounded mechanism, not a fully closed case.
- Recommended fix (independent of final root-cause confirmation): add a **post-commit integrity
  gate** that compares a pre-recorded content hash for every named positive pathspec against what
  actually landed in `HEAD` after the commit, and exits loudly/nonzero on any mismatch — this
  directly satisfies the "a caller must not be able to receive exit 0 for a partial commit"
  acceptance bar regardless of which concurrency precondition ultimately produced the drop.
- The two-writer, forced-fail-open reproduction harness built during this research (see Appendix)
  is directly reusable as the required failing-without-fix/passing-with-fix fixture for
  `test-git-commit-scoped.sh`.

## Context & Scope

Task 224's phase 5 (2026-10-08) regenerated ten stale Typst fragments plus two metadata files and
committed them in one `git-commit-scoped.sh` call (commit `fc9f786e`). One of the ten,
`typst/manual/generated/components/zigzag.typ`, was named in the call's pathspec and present on
disk with the correct regenerated content, yet the resulting commit did not carry it — `HEAD`
kept a much older, stale snapshot. The script exited 0 and printed nothing that flagged the
omission to the caller; it was found only by a later `git status` sweep and patched with a
follow-up commit (`96986be6`). This research's job (per the dispatch) is to rule on the mechanism
grounded in the script's own code (not inference from the symptom alone), reproduce it or explain
why it resists reproduction, and recommend both a loud-failure fix and a regression fixture. It
does **not** implement the fix — that is this task's planning/implementation phase's job.

The four candidate mechanisms named in the dispatch were treated as hypotheses to test against
the actual script (`agent-system/extensions/core/scripts/git-commit-scoped.sh`, resolved via
`.claude-extensions.json`'s `core` extension `source_dir`), not assumed.

## Findings

### Codebase Patterns

`git-commit-scoped.sh` is already heavily hardened against several *other* empirically-discovered
defects, each labeled V2 through V7 in its own header comment (classification of unmatched
pathspecs into matched/staged-deletion/genuinely-unmatched; refusal of degenerate exclude-only
pathspec lists; the `--task` contention-claim lease; the "nothing to commit" vs. "something was
dropped" ambiguity; and `git add`'s unreliable exit code against gitignore-matched tracked paths).
Walking each of these against the actual incident:

- **V2 case 3 ("genuinely unmatched") / V6**: requires a path to be absent from disk, untracked,
  *and* absent from `HEAD` at the moment the script runs (lines 341–374 of the script). `zigzag.typ`
  was present on disk with the correct regenerated content and already tracked (from its stale
  `HEAD` snapshot), so it structurally can only ever be classified as **case 1 ("matched")** —
  V2/V6 cannot be the mechanism. Confirmed by a 12-file baseline reproduction (ten
  `components/*.typ`-shaped fragments + two metadata files, modeled directly on the real commit's
  file set): the unmodified real script committed all twelve correctly, byte-for-byte, with zero
  drops.
- **V5 (`--task`/contention-claim lease)**: the entire block (lines 265–324) is gated behind
  `if [ -n "$contention_task_number" ]`, i.e. it is a strict no-op whenever the caller omits
  `--task`. The documented standard phase-commit invocation template
  (`context/processes/implementation-workflow.md` lines 138–142) never passes `--task`. Ruled out.
- **V7 (`.gitignore`/`git check-ignore` interaction)**: directly tested against the live
  repository — `git check-ignore -v` reports "not ignored" for all ten
  `typst/manual/generated/components/*.typ` fragments, including `zigzag.typ`. Ruled out.
- **Ephemeral-exclude injection loop**: only fires when a positive pathspec literally matches
  `specs/[0-9][0-9][0-9]_*/` (a bare task-directory pathspec ending in `/`, lines 240–263). The
  real commit's diff touches exactly two `specs/224_.../` files by their full, specific names
  (`progress/phase-5-progress.json`, `plans/01_gate-infrastructure-inventory-and-two-repairs.md`),
  not a directory sweep — the injection path was never reached. Ruled out.

None of the four match the facts once checked against the script's actual control flow and the
live repository's state.

### Git-level semantics discovered during reproduction

An isolated, single-process experiment established a fact about `git commit -- <pathspec>` that
is not stated anywhere in the script's own documentation and is load-bearing for the mechanism
below: **`git commit -- <pathspec>` re-reads the current working-tree content for each named path
at commit time — it does not simply commit whatever `git add` most recently staged.** Staging a
file, then changing its working-tree content again before running `git commit -- <that file>`,
commits the *second* content, not the staged one. This means `git-commit-scoped.sh`'s own `git
add` step (and its V7 per-path staged-state verification) establishes only that staging *can*
succeed at the moment it runs — it is not what the subsequent `git commit` actually snapshots for
case-1 paths.

### Reproduction: concurrent writers + commit-lock fail-open

Building on that, I constructed a scratch-repo harness (copying the real `git-commit-scoped.sh`,
`deploy-root-guard.sh`, `task-lock.sh`, and the two `lib/*.sh` it sources — the same approach the
existing `test-git-commit-scoped.sh` suite uses) with two files unique to each of two "writers"
plus one **shared** file both writers name in their own pathspec list, mirroring the real
incident's shape (nine fragments unique to the regeneration pass, one — `zigzag.typ` — potentially
also touched by something else). Each writer runs the real, unmodified
`git-commit-scoped.sh` concurrently.

- With the `specs/.commit-lock` mutex acquiring normally (the ordinary case — each writer waits
  for the other, then proceeds serialized), **0 drops in 20 trials**: the mutex does what its
  comment claims.
- With the mutex pre-occupied by a planted, long-lived foreign holder — forcing *both* writers
  through the script's own documented fail-open branch ("WARNING: failed to acquire
  specs/.commit-lock mutex ... proceeding unserialized ... Worst case is the safe index.lock race,
  not commit misattribution, since this commit is still path-scoped") — **the shared path was
  silently dropped from one writer's own commit in 3/20 and 1/10 trials**, with that writer's
  script exiting 0 and reporting a normal successful commit of its *other* named path only. The
  fail-open branch's own safety comment is therefore incorrect for this shape: "commit
  misattribution" of exactly the kind this incident exhibited *is* possible once two concurrent
  committers name an overlapping path and the mutex does not actually serialize them, even though
  each commit is individually path-scoped.

In the reproduction, the dropped content was not permanently lost — in every observed case the
*other* writer's own commit happened to also carry the shared path's final content, because that
writer had also named it. In the real incident, nothing else ever committed the correct
`zigzag.typ` content, so if the same mechanism occurred there, the regenerated content would have
been stranded exactly as observed: correct on disk, stale in `HEAD`, no diagnostic, exit 0.

### Unresolved: was a second writer actually active in the real incident?

Checking `git log --all --since="2026-10-08 14:00" --until="2026-10-08 15:00"` for task 224's
real commit window: every commit in that hour carries the identical session id
(`sess_1791479482_660bdf` — task 224's own session). No other task's commit landed between phase 4
(14:25:54) and phase 6 (14:30:09). This does not confirm the reproduced mechanism occurred in the
real incident — it only confirms no *other git-commit-scoped.sh caller's own commit* is visible in
that window. It does not rule out a non-committing concurrent actor (a stray interactive `git add`
from another terminal, a maintenance script touching the index without going through
`git-commit-scoped.sh`, or a writer whose own commit landed just outside the sampled window but
whose staging activity still overlapped). No artifact available to this research pass (no
persisted command transcript, no surviving `specs/.commit-lock`/`.contention-manifest` state from
that time) can confirm or refute this further.

## Decisions

- **Ruling**: of the four candidate mechanisms named in the dispatch, three are ruled out by
  direct code inspection plus live-repository and scratch-repo tests (ephemeral-exclude injection,
  `--task` contention-claim lease, `.gitignore`/`check-ignore` interaction). The fourth —
  concurrent-writer index interaction — is the only one that is both grounded in the script's own
  code (the `specs/.commit-lock` mutex's documented fail-open branch) and independently
  reproducible against the real, unmodified script; it is adopted as the working mechanism for
  the planning phase, with the caveat above that direct confirmation a second writer was active
  during the specific 2026-10-08 14:28 window is not available.
- **Decision**: the fix should not depend on first achieving certainty about root cause. A
  post-commit integrity gate (verifying what actually landed in `HEAD` against what was named,
  independent of *why* a mismatch occurred) satisfies the acceptance bar
  ("a caller must not be able to receive exit 0 for a partial commit") regardless of whether the
  concurrency precondition above, or some other as-yet-unidentified mechanism, produced a future
  instance.
- **Decision**: the two-writer forced-fail-open harness built during this research is the
  recommended shape for the required regression fixture (scope item 4) — it fails today (drops a
  named path, exits 0) against the unmodified script and is deterministic (the fail-open branch is
  forced via a planted mutex holder, not left to timing luck), unlike a bare concurrent-run test
  which only hits the race probabilistically.

## Recommendations

1. **Post-commit integrity gate (the loud-failure fix, scope item 3).** Before the script's final
   `exit "$commit_exit"`, and regardless of `commit_exit`'s value, verify every positive pathspec
   that survived classification (i.e. every entry in `filtered_pathspecs` minus
   `dropped_pathspecs`) actually landed in the post-commit `HEAD`:
   - Record each such path's pre-commit intended content hash (via `git hash-object` against the
     working-tree file for the matched/case-1 shape, or a "deleted" sentinel for the case-2
     staged-deletion shape) *before* the `git add`/`git commit` sequence runs.
   - After the commit attempt, re-hash the same path from `HEAD` (`git show HEAD:"$p" |
     git hash-object --stdin`, or confirm absence for the deletion shape) and compare.
   - On any mismatch, print a loud, clearly-labeled diagnostic (a new "Verified Finding" entry,
     e.g. V8) naming every path that was asked for but did not land, and exit a new, dedicated
     nonzero code distinct from the existing 0–4 range (e.g. 5) — never silently fold this into
     the existing `commit_exit`-based reporting, since the defining feature of this bug is that
     `commit_exit` is 0.
   - This check is cheap (one `git show`/`git hash-object` pair per named path) and catches the
     drop *regardless of which underlying git/concurrency mechanism produced it* — it does not
     require first resolving the open question in Findings above.
2. **Do not widen the pathspec or relax any staging contract** to work around this (explicitly out
   of scope) — the fix is detection, not a broader `git add`.
3. **Optional, follow-up-worthy (flag for the planner, not required by this task's scope)**:
   revisit the `specs/.commit-lock` mutex's fail-open comment itself ("Worst case is the safe
   index.lock race, not commit misattribution") now that this research has falsified it for the
   shared-path case. A stronger fix would make the mutex fail *closed* (refuse to commit rather
   than proceed unserialized) when its acquire times out, mirroring `specs/.scope-lock`'s existing
   fail-closed posture (`context/standards/git-staging-scope.md`'s and `task-lock.sh`'s own
   comments note `.scope-lock` already fails closed on timeout, unlike `.commit-lock`). This is a
   behavior change beyond "make the failure loud" and should be a planning-phase decision, not
   assumed here.
4. **Regression fixture (scope item 4)**: add a new case to
   `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` built on the two-writer,
   forced-fail-open harness from this research (see Appendix for the exact shape): two concurrent
   real invocations of the script, each naming one unique file plus one shared file, with
   `specs/.commit-lock` pre-occupied by a planted long-lived foreign holder so the fail-open branch
   is forced deterministically (not left to real-world timing luck). Assert, via `git log -p`/
   `git show --name-only` (never exit code alone, matching this suite's existing convention), that
   **both** writers' named shared-file content is actually reachable from `HEAD` after both
   finish — this fails against the current script (the drop reproduces) and should pass once
   recommendation 1 is implemented and acted on by the caller, or once the shared file genuinely
   lands via whichever writer is forced to retry/escalate under the post-commit gate.

## Risks & Mitigations

- **Risk**: a post-commit integrity gate adds `git show`/`git hash-object` calls per named
  pathspec, a small latency cost on every commit. **Mitigation**: the cost is O(paths), using
  cheap plumbing commands already used elsewhere in the script; negligible next to the existing
  15-second mutex-acquire budget.
- **Risk**: the gate could produce false positives for the already-documented case-2
  (staged-deletion) and "fully-staged deletion via `git add`" (V7 second-accepted-shape) paths,
  where "absence from a tree" is the *correct* post-state, not a drop. **Mitigation**: the
  pre/post comparison must special-case these exactly as V2/V7 already do (a path that is
  correctly absent from both the pre-commit snapshot's intended state and post-commit `HEAD`
  should compare as a match, not a mismatch) — this should be an explicit test dimension in the
  new fixture, not just the concurrent-drop case.
- **Risk**: root cause remains only probabilistically confirmed (see "Unresolved" above); a fix
  aimed narrowly at the commit-lock fail-open branch could miss a different mechanism if the real
  incident's cause was something else entirely. **Mitigation**: recommendation 1 (detect-and-fail-
  loud at the post-commit level) is deliberately mechanism-agnostic, so it remains correct and
  useful even if the concurrency ruling above is eventually revised.

## Context Extension Recommendations

- **Topic**: `git commit -- <pathspec>` re-reads the working tree fresh for named paths at commit
  time rather than relying on whatever `git add` most recently staged.
- **Gap**: this is not documented anywhere in `git-commit-scoped.sh`'s own extensive header
  comment (which already documents six other empirically-discovered git pathspec quirks, V2–V7)
  nor in `context/standards/git-staging-scope.md`.
- **Recommendation**: add this as a short, dated note (or a V8 entry, if recommendation 1 above is
  adopted) to the script's header comment alongside V2–V7, since it is exactly the kind of
  "empirically discovered" git quirk that section exists to record, and it is load-bearing for
  reasoning about this whole class of bug.

## Appendix

### Search queries / investigation steps used

- Located the real script via `.claude-extensions.json`'s `core` extension `source_dir`
  (`~/.config/nvim/agent-system/extensions/core/scripts/git-commit-scoped.sh`) and its test suite
  (`scripts/tests/test-git-commit-scoped.sh`).
- `grep -rl "claim-acquire\|commit-lock"` across the source store to locate `task-lock.sh`'s
  `commit-acquire`/`commit-release`/`claim-acquire`/`claim-release` implementations.
- `git log --all --oneline | grep -i "fc9f786e\|96986be6"`, `git show --stat/--name-status` on
  both incident commits, and `specs/224_.../issues.jsonl` / `progress/phase-5-progress.json` to
  recover the exact file set and the agent's own contemporaneous account.
- `git check-ignore -v` against all ten `typst/manual/generated/components/*.typ` fragments in the
  live repository.
- `git log --all --since="2026-10-08 14:00" --until="2026-10-08 15:00" --pretty="%h %ad %s%n%b"`
  to check for any other session's commit interleaved with task 224's phase 5.
- Three scratch-repo reproduction harnesses (baseline 12-file fidelity test; a 40-iteration
  realistic-timing concurrent race attempt, abandoned for being too slow under the real 15s mutex
  budget; and a reduced-budget scratch copy of the scripts used for the final forced-fail-open
  experiment, 20+10 trials each for the forced and control conditions).

### Reproduction harness shape (for the fixture author)

1. Copy `git-commit-scoped.sh`, `deploy-root-guard.sh`, `task-lock.sh`, `lib/common.sh`,
   `lib/task-lookup-lib.sh` into a scratch repo's `.claude/scripts/` (matches
   `test-git-commit-scoped.sh`'s existing `build_repo` helper).
2. Commit a baseline with `fileA.txt`, `fileB.txt`, `shared.txt`.
3. Pre-occupy `specs/.commit-lock` with a planted holder (`mkdir specs/.commit-lock`; write
   `claimed_at` = now, `stale_sec` = a large number) so neither writer's `commit-acquire` call can
   succeed within its budget.
4. Modify `fileA.txt` + `shared.txt` (content "W1"), launch
   `git-commit-scoped.sh --message writer1 --session sessW1 -- fileA.txt shared.txt` in the
   background; modify `fileB.txt` + `shared.txt` (content "W2"), launch the writer2 equivalent
   immediately after, also backgrounded.
5. Wait for both; assert (via `git log -p`/`git show --name-only`, not exit code) that the shared
   file's final, correct content is reachable from `HEAD`, and that each writer's own commit
   message is associated with the files it should have carried.
