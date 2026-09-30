# Research Report: Task #268

**Task**: 268 - lake-build-guard false-green (scope_key / cross-tree replay)
**Started**: 2026-09-30T00:00:00Z
**Completed**: 2026-09-30T00:00:00Z
**Effort**: ~1 session, empirical reproduction (no Lean project needed)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/lake-build-guard.sh` (full read, source store copy)
- `agent-system/extensions/core/scripts/dispatch-worktree.sh` (provision/release/land, source store copy)
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` (existing scope_key mutation coverage)
- `agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh` (existing `.lake/` hardlink-clone coverage, T1)
- Empirical reproduction: two git worktrees + `cp -al` + a fake `lake` binary, no Lean project, run in `/tmp`
**Artifacts**:
- This report: `specs/268_lake_build_guard_false_green_scope_key/reports/01_false_green_scope_key_defect.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Hypotheses (a) and (b) are ruled out by code reading.** `compute_scope_key()` is fed the
  identical `lake_args` vector on both the pre-lock scope-key computation in `cmd_build()` and
  the post-lock recomputation in `run_as_holder()` — no normalization gap exists between a
  scoped and a full build's argument vector. `decide_sharing()` is the *only* call site that
  makes a replay decision, and its scope-key branch correctly fails closed on an absent/empty
  `scope_key` field exactly as the header documents.
- **Hypothesis (d), taken literally ("decide_sharing legitimately matches across a cp -al
  hardlinked `.lake/`"), is REFUTED by direct reproduction.** `compute_fingerprint()`'s hashed
  pre-image embeds each file's own path string (`stat -c '%n %s %y'`, and even in `hash` mode
  `sha256sum`'s own `<hash>  <filename>` output format also embeds the filename). Two different
  worktree directories — `<root>/...` vs `<root>/.orchestrate-worktrees/<task>-<seq>/...` — can
  never hash to the same fingerprint even over byte-identical source content, so
  `decide_sharing()`'s post-fingerprint condition reliably fails across trees and a REAL build
  always reruns. Confirmed by running a real build in a worktree against a main-tree-authored
  record: no `REPLAY:` marker, the `STATUS:` line (real-build-only) appears instead.
- **A different, confirmed, reproducible false-green DOES exist, rooted in the same `cp -al`
  clone the dispatch named, but through a different exact mechanism than the literal (d)
  hypothesis.** `dispatch-worktree.sh`'s `provision` hardlinks `.lake/` (`cp -al`), which makes
  `build-guard.lock`, `.result`, `.log`, `.stdout`, and `.stderr` the SAME inode in every tree
  cloned from it. Two confirmed consequences:
  1. **Cross-tree lock serialization** (timing-confirmed): a worktree's `build` call blocks on
     the SAME `flock` the main tree's build is holding — the "build contention over one shared
     `.lake` (mode 2)" concurrency problem `dispatch-worktree.sh`'s own header says per-dispatch
     worktrees exist to remove is **not actually removed** for the build guard's own lock file.
  2. **Cross-tree record/log clobbering, exploitable as a false green via `result`** (reproduced
     end-to-end): `finalize_record()` writes via `> "$RESULT_PATH"` (truncate-in-place on the
     shared inode). After an unrelated worktree build completes, calling
     `lake-build-guard.sh result --dir <main>` (no `--expect-pid`) from the **main tree** reports
     `state=complete exit_status=0`, with `log_path`/`stdout_path` printed as the main tree's own
     absolute paths — but the actual file **contents** at those paths are the worktree's unrelated
     (differently-scoped) build's output. The main tree's own build output is gone, silently
     overwritten. `--expect-pid` correctly refuses this (exit 24) when a caller passes it, so it
     is a working, already-shipped mitigation — but it is optional, and this is exactly the
     "waiting on an in-flight guarded build, then poll `result`" pattern the header itself
     documents as a supported usage.
- **Recommendation**: fix at the `dispatch-worktree.sh` `provision` step by excluding
  `build-guard.*` from the `.lake/` hardlink clone (give each worktree fresh, independent guard
  state), not by adding a tree-identity field to the record. The exclusion fix is strictly
  stronger: it also closes the lock-contention defect, which a tree-identity field on the
  *record* alone would not touch (the lock file itself would remain a shared inode). If a
  tree-identity field is added anyway (e.g. as defense in depth), it must be sourced from `git
  rev-parse --show-toplevel` (or an equivalent per-worktree absolute path), **not**
  `--git-common-dir` as the dispatch's phrasing suggested — `--git-common-dir` is identical
  across every worktree of one repository (confirmed empirically) and would provide zero
  protection.
- No change was made to `~/Projects/BimodalLogic`; it was not touched, per the dispatch's
  read-only-fixture instruction. All reproduction used a disposable `/tmp` fixture with a fake
  `lake` binary — Lean was not required, matching the dispatch's observation that mechanism (d)
  needs no Lean project.

## Context & Scope

The dispatch (`.dispatch/3.md`) asked this research pass to determine, for a reported false
green ("Build completed successfully (1200 jobs)" replayed for a scoped build that wrote no
`.olean`), which of four candidate mechanisms explains it: (a) a `compute_scope_key` argument-
vector normalization gap, (b) a pre-scope-key record slipping past the documented fail-closed
branch, (c) misdiagnosis, or (d) cross-tree record replay via `dispatch-worktree.sh`'s `cp -al`
hardlink clone of `.lake/`. The dispatch explicitly required reproduction before assuming any of
these is real, and pointed out that (d) is reproducible with two plain git worktrees and no Lean
project at all — exactly the approach taken below. `~/Projects/BimodalLogic` was available as an
end-to-end fixture but was not needed and was not touched (read-only per the dispatch).

The source-store edit targets named by the dispatch are `lake-build-guard.sh` and
`dispatch-worktree.sh`, both under `agent-system/extensions/core/scripts/`; the deployed copies
under `.claude/scripts/` were read only for confirming which file is which, never edited.

## Findings

### (a) `compute_scope_key` argument-vector construction — no gap found

`cmd_build()` computes `current_scope_key="$(compute_scope_key "${args[@]+"${args[@]}"}")"`
(`lake-build-guard.sh:908`) from the same `args=("$@")` array that was already validated by
`validate_build_subcommand()`. After acquiring the lock, `run_as_holder()` recomputes
`scope_key="$(compute_scope_key "$@")"` (`lake-build-guard.sh:834`) from the identical argument
vector passed straight through (`run_as_holder "${args[@]}"` at line 952). Both call sites hash
the same NUL-separated join of the same vector (`compute_scope_key`, lines 448-453). A scoped
invocation (`build Foo.Bar`) and a full invocation (`build`) produce vectors of different length
and content, which always hash differently. No normalization step (trimming, sorting, flag
canonicalization) sits between the two call sites that could introduce drift. **Ruled out.**

### (b) Fail-closed branch for a missing `scope_key` — implemented and is the only read path

`get_record_field()` (`lake-build-guard.sh:459-463`) returns empty when no `^field=` line
exists (grep finds nothing, `cut` on an empty string is empty). `decide_sharing()`'s scope
condition (`lake-build-guard.sh:574-578`) is `[ -n "$record_scope_key" ] && [ "$record_scope_key"
= "$waiter_scope_key" ] || return 1` — an empty `record_scope_key` short-circuits to `return 1`
(not shareable) before the equality test ever runs. `decide_sharing()` is the *only* function
`cmd_build()` calls to decide whether to replay (line 929); there is no second, bypassing read
path for the replay decision. (The separate `result` subcommand does not consult
`decide_sharing()` at all, but that's a different exposure — see the confirmed defect below, not
this hypothesis.) **Ruled out** as the mechanism behind the original report.

### (c) Misdiagnosis — not needed; a concrete mechanism was found and confirmed

See below. Recording the real cause per the dispatch's instruction not to leave a false-green
report against this guard unexplained.

### (d) Cross-tree replay via `cp -al` — literal hypothesis refuted, but a related defect is real and reproduced

**What was tested.** Built a disposable fixture with no Lean dependency: a `/tmp` git repo
(`main`) with a `lakefile.lean` and one `.lean` file, a `git worktree add` sibling (`wt`), a fake
`lake` binary on `PATH` (via `LAKE_BUILD_GUARD_LAKE_BIN`) that just echoes its args and exits 0,
and `cp -al "$main/.lake" "$wt/.lake"` — the exact operation `dispatch-worktree.sh:293,297`
performs for `.claude/` and `.lake/` in `cmd_provision()`. Confirmed with `stat -c '%i'` that
`build-guard.result`/`.lock` are the same inode in both trees after the clone (this is the
correct, intended semantics of `cp -al` — cheap disk sharing for unchanged files).

**Literal (d) — refuted.** Running `lake-build-guard.sh build -- build Foo.Bar` inside `wt`
immediately after cloning a fresh `main`-authored `complete` record for the *same* scope produced
a REAL build (the fake `lake` actually ran, and the real-build-only `STATUS:` marker appeared —
no `REPLAY:` marker). This is because `compute_fingerprint()`'s pre-image is a sorted list of
`path size mtime` triples (`lake-build-guard.sh:432-439`) where `path` is the full resolved
project-root-relative path returned by `find "$root" ...` — and `$root` is
`<main>/...` in one tree and `<main>/.orchestrate-worktrees/<task>-<seq>/...` in the other. The
two path strings can never be equal, so the two fingerprints can never be equal, regardless of
content, in **both** `stat` and `hash` fingerprint modes (verified: `sha256sum`'s own stdout
format is `<hash>  <filename>`, so the filename enters the hashed stream even in `hash` mode).
`decide_sharing()`'s post-fingerprint condition (line 572) therefore reliably fails across trees.
This is an *incidental* protection (nobody designed the fingerprint to double as a tree-identity
check) but it is real and was directly exercised.

**What actually reproduces, end to end, with root cause confirmed:**

1. **Cross-tree lock serialization.** With a slow fake `lake` (`sleep 3` on `build`), a `build`
   started in `main` and, ~0.5s later, a `build` started in `wt` (after the `cp -al` clone) did
   **not** run concurrently — the `wt` call's wall-clock time (~6s) matches waiting out `main`'s
   remaining ~2.5s lock hold, then running its own full sleep, rather than the ~3s it would take
   running independently. `build-guard.lock` is the same inode in both trees post-clone, so
   `flock` serializes them against each other. This is exactly the "build contention over one
   shared `.lake` (mode 2)" problem `dispatch-worktree.sh`'s own header (lines 4-10) says
   per-dispatch worktree isolation exists to remove — for the guard's own lock, it is not
   removed.
2. **Cross-tree record/log clobbering, reproduced as an actual false green via `result`.**
   Sequence: `main` runs `build` (full, scope A) and gets a correct, real `complete` record.
   `.lake/` is then cloned via `cp -al` into `wt` (as `provision` does). `wt` runs `build Foo.Bar`
   (scope B, a different, real build — this part is safe, per the refutation above). Because
   `finalize_record()` writes via `> "$RESULT_PATH"` (`lake-build-guard.sh:486-507`), a plain
   truncate-and-rewrite of the shared inode, `wt`'s completion **overwrites** `main`'s own record,
   log, and captured stdout/stderr in place. A subsequent `lake-build-guard.sh result --dir
   <main>` (no `--expect-pid`) reports `state=complete exit_status=0`, `holder_pid` equal to
   `wt`'s PID (not `main`'s own build's PID), and `log_path`/`stdout_path` printed as `main`'s own
   absolute paths whose *contents* are entirely `wt`'s unrelated scope-B output — `main`'s own
   scope-A build output is gone. This is the "waiting on an in-flight guarded build, then poll
   `result`" usage the header documents as supported (lines 94-102, 157-164), and it silently
   returns a foreign tree's verdict. **Confirmed working mitigation**: re-running the same
   `result` call with `--expect-pid <main's own real PID>` correctly refuses with exit 24
   ("record belongs to holder pid ..., not the expected pid ..."). The gap is that `--expect-pid`
   is optional, not that it doesn't work.

Both effects trace to the same root cause the dispatch named — the `cp -al` hardlink clone in
`dispatch-worktree.sh:293-297` — but the exploitable path is `result`'s unguarded read and the
guard's own lock file, not `decide_sharing()`'s replay logic (which is, incidentally, safe here).

## Decisions

- **Classify the defect as "(d), amended"**: real, reproducible, rooted in the `cp -al` hardlink
  clone the dispatch identified, but manifesting through the `result` subcommand's unguarded read
  path and the shared lock file — not through `decide_sharing()`'s replay branch, which the
  fingerprint's path-embedding incidentally protects. This distinction matters for the fix and
  the regression test target (see Recommendations).
- **Recommend excluding `build-guard.*` from the `.lake/` hardlink clone** (fix option 1 from the
  dispatch) over adding a tree-identity field to the record (fix option 2), because option 1 also
  closes the lock-contention defect found above; a tree-identity field on the *record* alone
  would leave `build-guard.lock` itself as a shared inode, so cross-tree builds would still
  serialize against each other, defeating `dispatch-worktree.sh`'s own stated "mode 2" isolation
  purpose. This is a research-level technical recommendation grounded in the reproduction above,
  not a preference call — no `user_decision` is set on the metadata file for this task.
- **Correct the dispatch's `--git-common-dir` aside**: if a tree-identity field is added to the
  record anyway (e.g. as defense in depth alongside the exclusion fix), the identity source must
  be `git rev-parse --show-toplevel` (confirmed to differ per worktree: `/tmp/.../main` vs
  `/tmp/.../wt`), not `--git-common-dir` (confirmed identical across every worktree of one repo:
  both trees reported `.git`/the same resolved common-dir). `lake-build-guard.sh`'s own header
  already forbids using `git rev-parse --show-toplevel` for *project-root resolution* (a Lean
  package can be a subdirectory of a larger repo) — that constraint is about `ROOT`, a different
  purpose from a tree-identity tag on the record, and does not conflict with using
  `--show-toplevel` for the latter.

## Recommendations

1. **Primary fix, in `dispatch-worktree.sh` `cmd_provision()`** (lines 293-298): after `cp -al
   "$PROJECT_ROOT/.lake" "$worktree_path/.lake"`, remove (or never copy) the five
   `build-guard.*` files (`build-guard.lock`, `.result`, `.log`, `.stdout`, `.stderr`) so each
   worktree starts with independent (non-hardlinked) guard state while still sharing `.lake/`'s
   build-output disk blocks for everything else (the actual caching benefit `.lake/` cloning
   exists for). This closes both confirmed defects (lock serialization and record/log
   clobbering) at the root, and needs no change to `lake-build-guard.sh` itself.
2. **Regression test, hosted under `agent-system/extensions/core/scripts/tests/`** (both
   `test-lake-build-guard.sh` and `test-dispatch-worktree.sh` already exist and are the natural
   homes), following the dispatch's own suggested shape — two git worktrees, `cp -al` a `.lake/`
   between them, two guard invocations — but targeting the mechanism actually confirmed above,
   not the literal (refuted) hypothesis:
   - **Test A (regression target)**: reproduce the `result`-without-`--expect-pid` cross-tree
     clobbering end to end (as in this report's reproduction) and assert it does NOT happen after
     the fix — i.e. after excluding `build-guard.*` from the clone, `main`'s own `result --dir
     main` after a sibling worktree build must report `main`'s own build, not the worktree's.
   - **Test B (regression target)**: reproduce the lock-contention timing effect and assert that,
     post-fix, a worktree's `build` does not block on a main-tree build's lock (or vice versa).
   - **Test C (non-regression / documentation)**: keep a positive test asserting
     `decide_sharing()` correctly refuses to replay across trees even pre-fix (i.e. that the
     path-embedded-fingerprint protection for `build` mode specifically continues to hold), so a
     future change to `compute_fingerprint()` that accidentally drops path-embedding (e.g.
     switching to a pure content hash with no filename in the stream) doesn't silently reopen a
     `decide_sharing()`-level cross-tree replay that happens to not exist today only by accident.
3. Do not change `LAKE_SUBCOMMANDS`, `compute_scope_key()`, or `decide_sharing()`'s scope
   condition — (a) and (b) were ruled out by both code reading and by the existing mutation-test
   coverage in `test-lake-build-guard.sh` (mutation D already exercises disabling the scope_key
   comparison and confirms it is load-bearing).
4. No end-to-end Lean reproduction against `~/Projects/BimodalLogic` is needed to confirm this
   defect class — it was fully reproduced with a fake `lake` binary and no Lean project, per the
   dispatch's own observation. That checkout remains untouched.

## Risks & Mitigations

- **Risk**: excluding `build-guard.*` from the clone could be read as weakening the "share disk
  blocks for unchanged files" rationale for cloning `.lake/` at all.
  **Mitigation**: the guard's own state files (lock/result/log/stdout/stderr) are small,
  ephemeral runtime bookkeeping, not build output — excluding just those five named files leaves
  the actual `.lake/build/` olean cache fully shared, which is the part that matters for
  incremental-build cost.
- **Risk**: a partial fix (tree-identity field only, no exclusion) could look complete because it
  closes the `result`-read false-green path while leaving the lock-contention defect live and
  undetected (it degrades performance/concurrency, not correctness, so it could pass code review
  unnoticed without Test B above).
  **Mitigation**: Test B above specifically targets this, independent of Test A.
- **Risk**: a future edit to `compute_fingerprint()` (e.g. adopting a pure-content hash for
  performance) could silently remove the incidental path-embedding protection that currently
  keeps `decide_sharing()`'s replay branch safe across trees, reopening literal hypothesis (d).
  **Mitigation**: Test C above pins this behavior so such a change would be caught.

## Context Extension Recommendations

- **Topic**: cross-tree hazards of the `.lake`/`.claude` hardlink-clone pattern in
  `dispatch-worktree.sh`.
- **Gap**: `context/patterns/batch-orchestration-guardrails.md` documents the working-tree and
  build isolation posture decision (why per-dispatch worktrees exist, including "mode 2" build
  contention) but, as read during this research, does not document that a hardlink clone shares
  more than intended for any *runtime state file* a cloned directory contains (not just `.lake`'s
  guard files — the same hazard class would apply to any other ephemeral runtime file a future
  tool writes under a hardlink-cloned directory).
  **Recommendation**: after the fix lands, add a short note to that decision record (or to
  `lake-build-guard.sh`'s own header, which already documents `RECORDED DEAD ENDS`) naming this
  as a confirmed, fixed hazard, so a future sibling hardlink-cloned directory (the task mentions a
  hypothetical `latex-build-guard.sh`) inherits the "exclude ephemeral runtime state from the
  clone" convention by default rather than rediscovering it.

## Appendix

### Reproduction commands (representative; full sequence run interactively, `/tmp` fixture, not committed anywhere)

```bash
# main tree + worktree, no Lean required
git init main && cd main && git commit ... lakefile.lean Foo/Bar.lean
git worktree add -b wtbranch ../wt HEAD

# fake lake on PATH via LAKE_BUILD_GUARD_LAKE_BIN, echoes args, exits 0 (or sleeps 3 for timing test)

# 1) real build in main -> record with main-path-based fingerprint
lake-build-guard.sh build --dir main -- build Foo.Bar

# 2) clone .lake exactly as dispatch-worktree.sh provision does
cp -al main/.lake wt/.lake
stat -c '%i' main/.lake/build-guard.result wt/.lake/build-guard.result   # identical inode

# 3) literal (d) check: same-scope build in wt against main's record -> NO replay (STATUS:, not REPLAY:)
lake-build-guard.sh build --dir wt -- build Foo.Bar

# 4) confirmed defect: result-read clobbering
lake-build-guard.sh build --dir main -- build            # main's own full build
cp -al main/.lake wt/.lake
lake-build-guard.sh build --dir wt -- build Foo.Bar       # wt's own scoped build, overwrites shared inode
lake-build-guard.sh result --dir main                     # reports wt's verdict/log as main's own
lake-build-guard.sh result --dir main --expect-pid <main_real_pid>   # correctly refuses, exit 24

# 5) confirmed defect: lock contention (slow fake lake, sleep 3)
# build in main backgrounded; ~0.5s later build --no-share in wt; wt's own wall time (~6s)
# shows it waited out main's remaining lock hold before running, not running independently.
```

### Files read in full

- `agent-system/extensions/core/scripts/lake-build-guard.sh` (1225 lines)
- `agent-system/extensions/core/scripts/dispatch-worktree.sh` (header + provision/release/land,
  lines 1-140, 200-400, 460-630)
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` (scope_key mutation
  coverage, lines ~1090-1140)
- `agent-system/extensions/core/scripts/tests/test-dispatch-worktree.sh` (T1, `.lake/`
  hardlink-clone coverage, lines ~110-150)
