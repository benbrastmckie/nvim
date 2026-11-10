# Research Report: Task #461

**Task**: 461 - Rule on and close the V7 refusal of a positive directory pathspec for a `git rm --cached` untracking whose content is still on disk
**Started**: 2026-11-10T20:53:00Z
**Completed**: 2026-11-10T21:02:00Z
**Effort**: medium
**Dependencies**: 328, 430, 435, 446, 448 (all SERIALIZATION-only or OPERATOR-LIFTABLE per the task's territory edges; none contests the ruling itself)
**Sources/Inputs**: direct read of `agent-system/extensions/core/scripts/git-commit-scoped.sh`, `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`, `agent-system/extensions/core/context/standards/git-staging-scope.md`; four empirical reproductions against the deployed script in isolated scratch git repositories
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's root-cause narrative is CONFIRMED by direct empirical reproduction against the
  deployed script, not just by reading it: a `git rm -r --cached <dir>` followed by
  `git-commit-scoped.sh --message ... -- <dir>` exits 2 with exactly the described
  `genuinely_failed_adds` refusal, *provided* `<dir>` matches a `.gitignore` rule.
- **New finding, not in the dispatch's narrative**: when the untracked directory is *not*
  gitignored, the script does not refuse at all — it silently reverts the untracking. `git add
  <dir>` re-stages every file with identical content, `git commit` reports the documented,
  tolerated "nothing to commit" (exit 1), and `git ls-files -- <dir>` shows the files tracked
  again. This is empirically confirmed below. It is a strictly worse failure mode than the
  reported refusal (no error, no warning, the operation silently did not happen), and it occurs
  entirely inside the unconditional `git add "${add_pathspecs[@]}"` call — before the V7
  post-add verification loop the dispatch frames as the fix site ever runs.
- This sharpens the dispatch's own three-way ruling choice: the gitignored refusal and the
  non-gitignored silent revert are **one defect with two gitignore-dependent symptoms**, and only
  a **pre-`git add`** fix can address both — a post-add widening of V7's carve-out (literal
  reading of option (1)) cannot touch the non-gitignored case at all, because by the time V7 runs
  the revert has already happened and is indistinguishable from an ordinary no-op.
- Recommended ruling: **(2), but sited in the V2 pre-add classification loop (lines ~598-705),
  not the V7 post-add loop (lines ~841-911)** — a new, narrow case recognizing "every file this
  pathspec tracks in HEAD is staged as a pure deletion" independent of on-disk presence, added
  to `filtered_pathspecs` only and deliberately withheld from `add_pathspecs` (mirroring the
  existing V2 case-2 mechanism, which already uses exactly this two-array split for the
  disk-absent shape). This is sound where a literal option (1) is not, and avoids blurring the
  existing directory-move carve-out's premise, consistent with the HARD CONSTRAINTS.
- A documented explicit-file-list recipe (bare option (3)) does not, by itself, solve anything:
  listing individual files instead of the directory does not change `-e "$p"` being true for
  each of them, so the identical gitignore-dependent branching (refusal or silent revert) recurs
  per file. Option (3) is only sound in combination with *not* routing the pathspec through
  `git-commit-scoped.sh`'s `git add` step at all — which is exactly what the recommended V2
  carve-out already does internally. A hand-written recipe duplicating that logic at every call
  site would be strictly worse than fixing it once in the shared script.

## Context & Scope

Researched: the exact mechanism of the V7 refusal in `git-commit-scoped.sh`, whether the
dispatch's carried-unverified incident narrative is mechanically reproducible, what the three
ruling options actually require architecturally, and what the existing test suite's conventions
are, so the eventual plan can be scoped precisely. This is a `meta` task; the edit target is the
source store (`agent-system/extensions/core/**`), never the deployed `.claude/**` tree. No
implementation was performed — this phase is research only. Four scratch-repo reproductions were
built and run against the actual deployed script (not a mock) to verify both the reported
refusal and the newly discovered silent-revert hazard.

## Findings

### Codebase Patterns

**The exact refusal mechanism** (`git-commit-scoped.sh`, V2 classification ~line 598 and the V7
post-add loop ~line 841, current line numbers — re-derive before editing, they move):

1. V2's per-pathspec classification (`for p in "${pathspecs[@]}"`) tests
   `[ -e "$p" ] || git ls-files --error-unmatch -- "$p"` for case 1 ("matched"). For a directory
   whose content a `--cached` removal left on disk, `-e "$p"` is true, so it is classified as
   case 1 and placed in **both** `filtered_pathspecs` and `add_pathspecs` — it never reaches
   case 2 (`absent from BOTH working tree and index, present in HEAD`), which is the directory-
   move/pure-deletion carve-out's actual premise.
2. `git add "${add_pathspecs[@]}"` runs unconditionally over the full `add_pathspecs` set.
   - If the directory matches a `.gitignore` rule, `git add` refuses to re-stage it ("ignored by
     one of your .gitignore files", exit 1) and the staged deletion survives untouched.
   - If the directory does **not** match a `.gitignore` rule, `git add` re-stages every file
     with identical content, which is indistinguishable from the original tracked state — the
     staged deletion is gone.
3. V7's post-add verification loop runs `git ls-files --error-unmatch -- "$p"` per positive
   pathspec.
   - Gitignored case: fails (not in index) → falls to the local carve-out test
     `[ ! -e "$p" ] && [ staged_deletion_rc -eq 1 ] && git rev-parse --verify -q HEAD`. The first
     conjunct is false (content is on disk), so the carve-out does not match, and the pathspec is
     added to `genuinely_failed_adds` → `exit 2`. This is exactly the dispatch's reported
     symptom.
   - Non-gitignored case: succeeds (file is back in the index) → falls to the `git diff --quiet`
     residual check, which also succeeds (content matches exactly) → **no failure recorded at
     all**. The commit proceeds (or, if this was the only pathspec, `git commit` exits 1,
     "nothing to commit" — the script's own documented, tolerated case). Nothing distinguishes
     this from a benign no-op.

**Empirical confirmation** (scratch repos under
`/tmp/.../scratchpad/v7repro5` and `v7repro6`, built with the test suite's own harness
convention — `git-commit-scoped.sh` + its two runtime dependencies copied into
`<scratch>/.claude/scripts/`, matching `test-git-commit-scoped.sh`'s `build_repo()`):

- Gitignored case (`v7repro5`): `git rm -r --cached sub` then
  `git-commit-scoped.sh -- sub` against a repo whose `.gitignore` contains `sub/` →
  `EXIT=2`, stderr: `ERROR: git-commit-scoped.sh refuses to commit — git add left one or more
  staged paths genuinely unstaged ... Failing path(s): sub (not present in the index at all)`.
  Matches the dispatch's reported incident exactly.
- Non-gitignored case (`v7repro6`): identical setup, no `.gitignore` entry → `EXIT=1` ("nothing
  to commit"), and `git ls-files -- sub` afterward lists `sub/a.txt` and `sub/b.txt` as tracked
  again. The untracking was silently undone with no error and no warning.

**Why the dispatch's framing of option (1) is architecturally insufficient on its own**:
option (1) as literally stated — widen the V7 post-add carve-out's `[ ! -e "$p" ]` conjunct —
can only ever run on paths that `git add` already acted on. In the gitignored case that is fine
(the add was a no-op, the index state V7 inspects is trustworthy). In the non-gitignored case
the add has *already* silently reverted the deletion by the time V7's loop runs — there is
nothing left for a widened V7 predicate to accept or reject, because the thing it would need to
detect (a staged deletion) no longer exists. **Any sound fix must intercept the pathspec before
`git add` is called on it at all**, which means it belongs in the V2 classification loop, as a
new case that (like existing case 2) keeps the pathspec out of `add_pathspecs` while still
including it in `filtered_pathspecs`.

**What the new V2 case must test, to satisfy the HARD CONSTRAINTS**: not "is any content for
this pathspec staged as deleted" but "is **every** file git currently tracks in HEAD under this
pathspec staged as a pure deletion, with nothing else staged or modified under it" —
otherwise a directory that is only *partially* untracked (some tracked files still present and
unchanged, a mix of staged deletions and ordinary modifications) would wrongly accept, which is
exactly the "do NOT let a widened predicate accept a genuinely-unstaged directory" constraint.
A sound test enumerates `git ls-tree -r --name-only HEAD -- "$p"` (every file HEAD tracks under
the pathspec) and confirms each one is absent from `git ls-files -- "$p"` (not in the index) and
appears as a `D` line, never `M`/`A`/`R`, in `git diff --cached --name-status HEAD -- "$p"`. This
enumerate-and-verify shape mirrors the script's own existing V8 post-commit integrity-snapshot
idiom (`git ls-files` / `git diff --name-only HEAD` / `git ls-files --others --exclude-standard`,
lines ~801-806) — there is already strong internal precedent in this script for "enumerate the
set, verify membership" over a cheap existence test. This new pre-add test is **separate from**,
and must not alter, V7's own `git diff --cached HEAD` exact-exit-code discrimination (1 vs. 0 vs.
128) — the HARD CONSTRAINT against weakening that discrimination is about the existing V7 gate,
which this recommendation leaves untouched; the new case runs earlier and independently.

**Ordering matters for placement**: the existing case-1 test (`[ -e "$p" ] || git ls-files
--error-unmatch`) is checked *first* in the V2 `case` statement and would claim a
content-present directory before any new "fully-cached-untracked" test got a chance to run as a
trailing `elif`. The new test must be evaluated **before** case 1's existence check for a
positive pathspec, not appended after it.

**Note output distinctness** (per the HARD CONSTRAINTS): the existing W1/W2 NOTE text is
"accepted ... as fully-staged deletions ... the source half of a directory move" — a separate
NOTE string naming the new shape (e.g. "accepted ... as a `--cached` untracking with content
still present on disk") is needed so a future reader of stderr does not conflate the two.

### Existing Test Suite Conventions

`scripts/tests/test-git-commit-scoped.sh` groups cases by a single letter per concept cluster:
`T1-T18` (an earlier gate series), `U1-U6` (V7's gitignore-advisory false-negative tolerance),
`V1-V7` (contention/claim gates), `W1-W4` (the existing fully-staged-deletion carve-out: W1
directory-move pair, W2 its NOTE text, W3 pure deletion, W4 the genuine-failure safety case),
`X1-X8` (V8 post-commit integrity, including inversion/tautology-guard probes), `Z1-Z18`
(further gates). **`Y` is unused** and is available for a new cluster covering this task's
shape, matching the file's existing one-letter-per-concept convention — the planner may choose
differently; this is a naming-availability note, not a prescription.

W1 and W3 (the cases the VERIFY section says to pin) use plain `mv`/`rm -rf` — content is
genuinely gone from the working tree in both. Neither exercises the `--cached`-with-content-
present shape; pinning them unchanged alongside a new case is a correct, low-risk regression
guard exactly as the dispatch's VERIFY section specifies. Every assertion in this suite checks
the actual commit via `git log`/`git show --name-status`, never exit code alone — the suite's
own stated discipline (stated in its header and in the W1-W4 section comment) and a convention
any new case should follow, including a case asserting the files are genuinely *not* re-tracked
in the non-gitignored silent-revert scenario (an assertion the dispatch's VERIFY list does not
explicitly ask for, but which this research's new finding makes necessary to pin — otherwise a
future change could silently reintroduce the revert hazard while every currently-specified test
still passes).

### Standards and Prior Art

`context/standards/git-staging-scope.md`'s "Positive-Pathspec Ignore-Advisory Hazard" section
(the authoritative narrative backing the current carve-out) states the carve-out's premise
explicitly: "a pathspec that is absent from the working tree, resolvable against HEAD... The
vacated source half of a directory move has precisely this shape." This is the same premise the
script's own W1-comment states, and it is the premise this task's shape inverts (content
present, not absent). Any new carve-out added to the script needs a corresponding addition or
cross-reference here — this file has a "## Rename and Directory-Move Staging" section (line
~604) with a Rule / Failure-mode / Why-no-existing-gate-catches-it / Canonical-illustration
structure that is the natural template for a sibling "## Untracking Staging" section if the
ruling documents a recipe (whether or not the script itself is changed). This file is contested
territory with task 446 per the dispatch's own territory edges (land after it, merge rather than
overwrite).

No existing report, plan, or closed record (searched via `grep` across both `specs/state.json`
and `specs/archive/state.json`, and via the test suite's own case index above) covers the
`--cached`-with-content-present shape or names `git-commit-scoped.sh`/
`test-git-commit-scoped.sh` in file_scope — consistent with the dispatch's own DUPLICATE CHECK
PERFORMED section. This research adds no contradiction to that check.

## Recommendations

1. **Rule (2), sited pre-add.** Add a new case to the V2 classification loop (not the V7
   post-add loop) that accepts a positive pathspec when every HEAD-tracked file under it is
   staged as a pure deletion, regardless of on-disk presence. Route it to `filtered_pathspecs`
   only, withheld from `add_pathspecs`, exactly mirroring the existing case-2 mechanism's
   two-array split. This is the only placement that is sound for both the gitignored (refusal)
   and non-gitignored (silent revert) symptoms this research confirmed are the same underlying
   defect.
2. Use an enumerate-and-verify predicate (`git ls-tree -r --name-only HEAD -- "$p"` cross-checked
   against `git diff --cached --name-status HEAD -- "$p"`, requiring every tracked file to appear
   as a `D` line and none to appear as `M`/`A`/`R`), not a cheap existence test — this is what
   prevents a genuinely-partial directory from wrongly matching.
3. Give the new case its own NOTE text, textually distinct from the existing "source half of a
   directory move" NOTE, per the HARD CONSTRAINTS.
4. Extend `test-git-commit-scoped.sh` with a new letter cluster (`Y` is free) covering: the
   dispatch's required FAILS-before/passes-after regression case; a pin of the silent-revert
   hazard this research discovered (assert the files are NOT re-tracked after the fix, for a
   non-gitignored directory); and the two pins the dispatch's VERIFY section already names
   (W1/W3 unchanged; the on-disk-content-differs refusal; the out-of-repo 128 refusal). Use
   `scripts/tests/run-all.sh --only` the scoped suite name, not the full aggregator, per VERIFY.
5. Document the new shape in `context/standards/git-staging-scope.md`, as a sibling section to
   "Rename and Directory-Move Staging", once task 446's territory there has landed — merge, do
   not overwrite.
6. Do not adopt a bare option-(3) hand-written explicit-file-list recipe as a substitute for (1):
   it reproduces the identical gitignore-dependent hazard at every call site that would use it,
   since the hazard is in `git add`'s behavior toward already-staged-deleted, disk-present
   content, not in directory-vs-file pathspec granularity. If a recipe is documented at all
   (per the REQUIRED OUTCOME), it should simply be "pass the directory (or the files) to
   `git-commit-scoped.sh` as usual" — i.e., the fix above *is* the recipe, not a workaround
   layered on top of it.

## Decisions

- Confirmed (empirically, not just by reading the script) that the dispatch's ROOT CAUSE section
  is accurate for the gitignored case.
- Established as a new finding that the non-gitignored case is a silent-revert hazard, not a
  refusal, and that it shares the same root mechanism (`git add` run unconditionally on a
  pathspec whose correct post-state is "stay staged-deleted").
- Concluded that ruling option (1) as literally framed (widen the existing post-add V7 carve-out)
  cannot fix the non-gitignored case and is therefore an incomplete fix; the sound fix is
  option (2), pre-add.
- Concluded that option (3) does not independently solve the defect and should not be adopted as
  a standalone fix; any documented recipe should simply be "use the fixed script," not a
  workaround.

## Risks & Mitigations

- **Risk**: a pre-add predicate that enumerates `git ls-tree -r` per directory pathspec could be
  slow for a very large tree (the cited incident involved 500 files). **Mitigation**: this is the
  same order of cost the script's existing V8 gate already pays per commit (full enumeration via
  `git ls-files`/`git diff --name-only`/`git ls-files --others`), so it introduces no new
  complexity class — the planner should simply confirm this cost is acceptable, not avoid the
  enumeration.
- **Risk**: inserting the new case ahead of V2's existing case-1 test could change behavior for
  some other pathspec shape not anticipated here. **Mitigation**: the predicate should be gated
  tightly (every tracked file under the pathspec AND only deletions, nothing else staged) so it
  can only ever match the exact shape this task describes; the regression suite addition (VERIFY)
  is the concrete check for this.
- **Risk (process, not product)**: during this research, a scratch-repo reproduction accidentally
  ran against the real repository's working directory for one command (a `cd` to a path outside
  the harness's tracked working directories silently failed to persist across tool calls),
  overwriting `.gitignore` and creating an unwanted commit. This was caught immediately via
  `git log`/`git show`, and fixed with a corrective commit (`239f0217e`) restoring the file's
  prior content, scoped to `.gitignore` only via `git-commit-scoped.sh`. Logged to this task's
  issue log. No lasting effect; noted here only for transparency since it touched the shared
  repository outside this task's own file_scope.

## Context Extension Recommendations

- **Topic**: the `git add`-silently-undoes-a-`--cached`-untracking hazard.
- **Gap**: `context/standards/git-staging-scope.md`'s ignore-advisory section documents the
  gitignored-tracked-path advisory-false-negative hazard in detail, but has no section on the
  inverse direction — a positive pathspec whose correct behavior is to stay staged-deleted even
  though its content is present on disk, independent of gitignore status.
- **Recommendation**: once the fix lands, add a sibling section (modeled on "Rename and
  Directory-Move Staging") documenting the `--cached`-untracking shape, its two gitignore-
  dependent symptoms, and the carve-out that handles both. Land after task 446's edits to the
  same file.

## Appendix

- Scratch reproductions: `/tmp/claude-1000/-home-benjamin--config-nvim/7dad614e-3f09-4e99-893b-f23a655e66f7/scratchpad/{v7repro5,v7repro6}` (session-local, not part of the repository).
- Key script reads: `agent-system/extensions/core/scripts/git-commit-scoped.sh` (V2 loop ~598-705,
  V8 snapshot ~755-828, V7 add+verify loop ~830-911), `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` (W1-W4 ~1152-1264, U1-U6 ~841-962), `agent-system/extensions/core/context/standards/git-staging-scope.md` (~61-109, ~604-652).
- Searches performed: `grep` across `specs/state.json` and `specs/archive/state.json` for
  `cached`/`untrack`; `grep` of the two nearest-neighbour task plans (430, 446) for the same
  terms (no substantive hit); test-suite case-letter inventory via `grep` of `common_test_pass`.
