# Research Report: Ignored-Specs Predicate and Commit-Path Outcome

**Task**: 658 - Add a shared predicate for a gitignored specs tree and a distinct, non-failure
commit-path outcome for an all-ignored pathspec
**Started**: 2026-11-19
**Completed**: 2026-11-19
**Effort**: medium
**Dependencies**: None (task 618 shares file territory, declared not blocking per the dispatch)
**Sources/Inputs**: Codebase reading (`git-commit-scoped.sh`, `engine-written-state-paths-lib.sh`,
`git-corpus-enum-lib.sh`, `git-commit-phase.sh`, `orchestrate-cycle-postflight.sh`,
`git-staging-scope.md`, `test-git-commit-scoped.sh`); live empirical reproduction in disposable
scratch git repositories (no project files touched by the probes themselves)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Reproduced the defect live**: a repository whose `specs/` tree is wholly or partly gitignored
  causes `git-commit-scoped.sh` to exit `2` with the EXACT SAME "Verified Finding V7... git add
  left one or more staged paths genuinely unstaged" `ERROR` a real staging failure produces — and,
  in a mixed pathspec, this refusal **aborts the whole invocation**, so even a legitimate,
  trackable sibling path (e.g. `specs/TODO.md`) is left uncommitted alongside the ignored one. The
  all-or-nothing refusal, not a silent drop, is the actual shape of the bug.
- **Root cause located precisely**: `git-commit-scoped.sh`'s V2 classification loop's case-1 test
  (`[ -e "$p" ] || git ls-files --error-unmatch -- "$p"`) matches an untracked-but-ignored path
  purely because it exists on disk, routing it into `add_pathspecs`. `git add` then silently skips
  it (confirmed: it does **not** abort the whole `git add` call the way the V9 out-of-repository
  shape does), but the V7 post-add index-verification loop correctly observes it never landed in
  the index and classifies it as `genuinely_failed_adds`, which exits `2` before `git commit` is
  even attempted.
- **The fix belongs in the SAME V2 loop, evaluated before case 1** — the identical placement rule
  V9/V10/V11 already use for exactly this reason (keep a doomed path out of the single
  all-or-nothing `git add` call entirely, rather than letting it fail and then explaining the
  failure). `git check-ignore -q` is the correct, already-in-use-elsewhere primitive, and it
  happens to have exactly the right index-aware behavior for the companion case: it reports
  "not ignored" for a path that is tracked and merely *matches* a `.gitignore` rule — confirmed
  live for both a parent-directory-pattern rule and a direct file-level rule — so the new gate
  needs no separate "is it tracked" test of its own; untracked-ness is a free side effect of using
  `git check-ignore -q` as the test.
- **Recommend BOTH shapes the dispatch's research question (a) offers, not an either/or**: one
  new shared library (modeled on `lib/engine-written-state-paths-lib.sh`'s own documented style)
  answering the repository-level question the task's own GOAL sentence poses verbatim ("whether a
  given repository's specs tree is gitignored"), plus a new per-pathspec safety gate inside
  `git-commit-scoped.sh` itself (in the house style of V9/V10/V11, using `git check-ignore -q`
  directly rather than through the library) for the partial-ignore case the repo-level question
  cannot answer alone. Both are needed; neither subsumes the other.
- **Two new, additive exit codes are needed, not one** — `8` for the all-pathspecs-ignored,
  nothing-committed shape (today's exit `2`) and `9` for the commit-succeeded-but-something-also-
  dropped-as-ignored shape (today's exit `2` as well, but via a different, even more destructive
  path: see Finding 3). Both are non-failure, mirroring the V9/V10 "observability, not a refusal"
  precedent (exit `6`/`7`) rather than V6's generic "ambiguous nothing-to-commit" framing (exit
  `4`), because — unlike V6's case — the predicate answers definitively why nothing landed.
- **Backward compatibility is confirmed intact by direct reproduction**: the existing V7 carve-out
  for a tracked path that merely *matches* a `.gitignore` rule is untouched by this design (see
  above), and a from-scratch tracked-specs repository never reaches the new gate at all, since
  every one of its positive pathspecs is already tracked.
- **One candidate third defect site was investigated and ruled out**: `git-commit-phase.sh`'s
  post-commit completeness check (`git status --porcelain -- "$f"` per `files_touched` entry) was
  suspected of also misclassifying a legitimately-dropped ignored path as "dirty". Live
  verification shows plain `git status --porcelain` (no `--ignored` flag) already returns **empty**
  output for an ignored, untracked path — so this check is already safe for this case, with no
  parallel fix required there.

## Context & Scope

This research answers the four questions the dispatch's "RESEARCH SETTLES, NOT THIS DESCRIPTION"
paragraph poses, for the goal of adding one shared predicate answering whether a repository's
`specs/` tree is gitignored, and making `git-commit-scoped.sh` report an all-ignored pathspec as
its own distinct, non-failure outcome. The investigation used only disposable scratch git
repositories built under `mktemp -d` (mirroring `test-git-commit-scoped.sh`'s own established
harness pattern: copy `git-commit-scoped.sh` plus its runtime dependencies into
`<scratch>/.claude/scripts/` so `PROJECT_ROOT` resolves correctly and `deploy-root-guard.sh`'s
`*/.claude` case matches) — no file inside this repository's own tree was modified by any probe.

## Findings

### Finding 1 — Where an ignored, untracked positive pathspec lands today (settles question b)

Live reproduction, three shapes:

1. **A single ignored-and-untracked pathspec** (`specs/TODO.md`, with `specs/` wholly
   gitignored): `git-commit-scoped.sh` prints git's own "The following paths are ignored by one
   of your .gitignore files" hint, then exits `2` with `ERROR: ... Verified Finding V7 ...
   Failing path(s): specs/TODO.md (not present in the index at all)`.
2. **The realistic multi-path commit shape** (`specs/TODO.md specs/state.json specs/001_x/`, all
   under a wholly-ignored `specs/`): identical outcome — exit `2`, all three paths named as
   "genuinely unstaged" — **even though none of them is actually a staging defect**; the entire
   commit refuses, including the task directory.
3. **A partially-ignored tree** (only `specs/002_y/` is gitignored via a specific rule;
   `specs/TODO.md` and `specs/state.json` remain tracked and freshly modified): the mixed pathspec
   `specs/TODO.md specs/002_y/` **still exits 2 for the WHOLE invocation**, dropping the
   legitimate, trackable `specs/TODO.md` change along with the ignored one. This is the most
   consequential empirical finding: today's defect is not merely "a cosmetically wrong exit code
   for a no-op" — it can **actively prevent a trackable, in-scope change from being committed**,
   whenever it happens to share a pathspec list with an ignored sibling.

Mechanically, this happens because `git-commit-scoped.sh`'s V2 classification loop (lines
699-823 at time of research) tests `[ -e "$p" ]` for case 1 before anything checks whether `$p` is
ignored — the file exists on disk, so it is unconditionally routed into `add_pathspecs`. `git add`
itself does **not** abort the whole call the way the V9 out-of-repository shape does (confirmed:
in a mixed call with one ignored path and one ordinary non-ignored path, `git add` actually staged
the ordinary path — `git status --short` showed `A  outside.txt` — while silently skipping the
ignored one and returning overall exit `1`). But the post-add verification loop at lines 1002-1026
(`git ls-files --error-unmatch` fails because it was never staged; `staged_deletion_rc` does not
apply because the file is present on disk, not a staged deletion) correctly concludes the path
never landed in the index, appends it to `genuinely_failed_adds`, and the script refuses with exit
`2` at line 1040 — **before `git commit` is ever invoked, and before the V6 "nothing to commit"
gate at line 1210 is ever reached.** The ignored-and-untracked shape therefore takes the **V7
refusal path**, not V2 case 3 ("genuinely unmatched"), not V8 (post-commit only), not V9
(in-repository, so the containment guard never fires), and not V10 (file_scope containment is an
orthogonal question; the path can be perfectly in-scope and still be ignored).

### Finding 2 — The tracked-and-ignore-matching case needs no special handling (settles question d)

`git check-ignore -q` is **index-aware** in exactly the direction this task needs. Reproduced
live for both documented mechanisms:

- A path tracked **before** a parent-directory `.gitignore` rule is added (the existing
  `build_repo_tracked_ignored` fixture shape in `test-git-commit-scoped.sh`, and the live
  `specs/archive/state.json` incident V7 was built for): `git check-ignore -q` on the tracked file
  returns **not ignored** (`rc=1`).
- A path tracked **before** a direct, file-level (non-parent-directory) `.gitignore` rule naming
  it exactly: also **not ignored** (`rc=1`), and in this shape `git add` does not even print the
  advisory hint — it stages cleanly with exit `0`.

Both confirm the V7 header's own documented claim ("`git check-ignore -q`... is index-aware and
reports 'not ignored' for exactly these tracked paths") empirically, for both rule shapes. **This
means a new gate built on `git check-ignore -q` automatically and correctly excludes every
tracked path from being misclassified as "ignored" — no separate tracked/untracked test is
needed in the new gate's own predicate.** The right answer for a tracked-and-ignore-matching path
is exactly what V7 already does today: stage and commit it, unaffected by this change.

### Finding 3 — The predicate is needed at two granularities, not one (settles question c)

The GOAL sentence frames the predicate at repository granularity ("whether a **given repository's**
specs tree is gitignored"), and a single `git check-ignore -q -- specs` call at a repository's own
root answers exactly that question in one shot — confirmed live: `rc=0` (ignored) against a repo
with `specs/` in its root `.gitignore`; `rc=1` (not ignored) against both a repo that tracks
`specs/` normally and a repo that ignores only one task subdirectory inside an otherwise-tracked
`specs/` (`specs/002_y/` specifically, confirmed `rc=1` for bare `specs` in that same repo while
`rc=0` for `specs/002_y/` directly). **This repository-level answer is real, cheap, and correct —
but it is not sufficient on its own**, because the live partial-ignore reproduction above (Finding
1, shape 3) shows a repository can simultaneously have a perfectly trackable `specs/TODO.md` and
an ignored `specs/002_y/` in the SAME commit pathspec. A caller that only asked the repository-
level question would have no way to know which of its own pathspec entries to drop versus keep.

**Recommendation: both granularities, each serving a distinct, non-overlapping job precisely the
way the GOAL's own phrase "one mechanism consulted from one place" intends it:**

1. **A new shared library**, modelled structurally on `lib/engine-written-state-paths-lib.sh`'s
   own documented style (a contract statement, a fail-open posture, an explicit consumer
   enumeration, rejected-candidate notes) — propose
   `agent-system/extensions/core/scripts/lib/specs-ignore-lib.sh`, exporting one function,
   `specs_tree_is_gitignored <repo_root>` (prints `true`/`false`, or an rc-0/rc-1 boolean contract
   — the plan phase should pick the shape that matches this library's actual callers, following
   `engine-written-state-paths-lib.sh`'s own precedent of a plain stdout print plus unconditional
   `return 0`), implemented as `git -C "<repo_root>" check-ignore -q -- specs`. This answers the
   literal GOAL-sentence question and is what `context/standards/git-staging-scope.md`'s new
   per-operation-contract prose (see Recommendations below) should cite, and what a future
   caller wanting a cheap up-front "should I even try" check (or a test fixture asserting the
   predicate itself, independent of the commit script) should consult.
2. **A new per-pathspec safety gate inside `git-commit-scoped.sh`'s own V2 loop**, using
   `git check-ignore -q -- "$p"` directly on each candidate pathspec — in the same house style
   V9's `realpath` test and V11's `is_cached_untracking_shape` predicate already use (a self-
   contained check inline in the script that owns per-pathspec classification, not routed through
   a shared library for a decision this script must make path-by-path regardless of the
   repository-level answer). This is the gate that correctly handles Finding 1's partial-ignore
   shape, because it is evaluated once per positive pathspec actually named in the call, not once
   per repository.

Neither one is redundant: the shared library is the one-shot, repository-wide question the GOAL
names and the standards doc should document; the inline per-pathspec gate is the mechanism that
actually fixes the commit-path defect for a real, mixed pathspec list. This mirrors the existing
precedent inside this same script almost exactly: V10 (per-pathspec Containment) consults a
shared library (`engine-written-state-paths-lib.sh`) for one specific sub-question (what the
engine-written path set is) while performing its own per-pathspec classification inline — the new
design simply adds a second, analogous shared-library sub-question (is the whole tree ignored)
consulted the same way.

### Finding 4 — Exit-code design, with a third site (ruled out) and a confirmed second-site need

**New gate, named `V13`** (the next unused V-letter after V12 in the script's own header
vocabulary), placed in the V2 loop **after V9, V10, and V11** (so an ignored path that is *also*
out-of-repository, out-of-file_scope, or part of a cached-untracking shape keeps being reported
under that existing, already-tested message rather than being reclassified) and **before case 1's
own existence test** (the same placement rule V9/V10/V11 all use, for the same reason: keep a
doomed path out of the single all-or-nothing `git add` call rather than letting it fail and then
explaining the failure). Unlike V10, this gate should be **unconditional**, not gated on `--task`
— the question "is this on-disk, untracked path ignored" is answerable and worth answering
regardless of whether a caller happens to supply `--task`, and Finding 1's reproductions did not
require `--task` at all to exhibit the defect.

A matching new ledger, `ignored_dropped` (parallel to `out_of_repo_dropped`/`containment_dropped`),
records every V13-classified path. **Two new, additive exit codes**, both non-failure
("observability", in this script's own existing V9/V10 vocabulary — never an `ERROR`, always a
`NOTE`):

- **New exit `8`** — every positive pathspec that would otherwise have survived was instead
  dropped by V13 alone (no other drop reason contributed), and the commit attempt produced no
  commit. This must be decided **before** the existing V3 post-filter gate (line ~830, which
  today would otherwise claim this exact shape and exit `2` with its own "zero positive pathspec
  entries remain... Verified Finding V3" wording — itself just as failure-flavored and just as
  wrong for this case as V7's message is). Replaces today's V7-path exit `2` for Finding 1's
  shapes 1 and 2.
- **New exit `9`** — mirrors the V9/V10 "commit succeeded (`commit_exit` `0`) but something was
  also dropped" shape: one or more positive pathspecs were dropped by V13 while at least one
  other pathspec survived and committed. Decided after V9's exit `6` and V10's exit `7` (same
  precedence-by-placement convention those two already use relative to each other), so an
  invocation tripping more than one of V9/V10/V13 keeps reporting the earliest-placed one.
  Replaces today's V7-path exit `2` for Finding 1's shape 3 — the most harmful shape, because
  today it also silently withholds the legitimate sibling commit; under the new design that
  sibling commits normally and only the ignored entry is reported, non-fatally, via exit `9`.

**Caller updates required at exactly the two other named production consumers** (per the
dispatch's own "MEASURED SCOPE CORRECTION" — this predicate's consumer set is the same three
sites `engine-written-state-paths-lib.sh` already names, not the 95-file reference count):

- `orchestrate-cycle-postflight.sh`'s WORK (i) per-cycle commit `case "$commit_rc"` statement
  (around line 2118) currently buckets `2|3|4|5|6)` into one loud, attributable `ERROR` branch,
  and a separate demotion gate (around line 2157) buckets `2|3|4|5)` into a `completed -> partial`
  downgrade. **Both new codes must be excluded from both of these**, the same way exit `6`
  already is excluded from the demotion gate and the "unrecognized code" `*)` catch-all is
  excluded from the loud-`ERROR` framing today being too harsh for `7` — a task whose only
  "failure" is that its target repository ignores `specs/` must never be demoted to `partial` or
  reported as an `orchestration defect` for that fact alone. Recommend an explicit `8|9)` arm with
  its own `NOTE`-level (not `ERROR`-level) wording, analogous to how exit `1`'s branch already
  gets `WARNING`-but-non-blocking treatment, rather than letting these fall through the generic
  `*)` catch-all (which this document itself flags, for exit `7`, as "a real, if slightly reduced,
  observability gap").
- `git-commit-phase.sh` forwards `--task` to `git-commit-scoped.sh` and passes its exit code
  through verbatim in the `0-5` range, with its own locally-reserved `6` for a distinct
  completeness-check failure (see below). Its header's "EXIT-CODE MAPPING" comment documents the
  `0-5` passthrough and the local `6` explicitly; it will need a parallel note that `8` and `9`
  also pass through verbatim (not colliding with its own local `6`, which remains in the `0-6`
  range this header already reserves for itself — the new codes land outside that range by
  construction, so no renumbering is required there).

**Third site investigated and ruled OUT**: `git-commit-phase.sh`'s post-commit completeness check
(`git status --porcelain -- "$f"` per `files_touched` entry, flagging any entry with non-empty
output as "dirty") was suspected of re-introducing the same false-failure shape downstream of a
correctly-fixed `git-commit-scoped.sh` — an ignored, never-committed path staying "dirty" forever
and tripping this check's own `exit 6`. **Live verification shows this concern does not
materialize**: `git status --porcelain` with no `--ignored` flag returns **empty** output for an
ignored, untracked path (confirmed directly against the scratch fixture), because plain
`git status` excludes ignored paths from its default output entirely, independent of any path
argument. The completeness check is therefore already correct for this case with **no parallel
fix needed** at that site — a negative finding worth recording so a future pass does not
re-investigate it.

## Recommendations

1. **New shared library** `agent-system/extensions/core/scripts/lib/specs-ignore-lib.sh`,
   structured like `lib/engine-written-state-paths-lib.sh` (contract statement, fail-open posture,
   consumer enumeration), exporting `specs_tree_is_gitignored <repo_root>` implemented as
   `git -C "<repo_root>" check-ignore -q -- specs`. Give it its own small test file
   (`tests/test-specs-ignore-lib.sh`) asserting both polarities (tracked-specs repo: not ignored;
   wholly-ignored-specs repo: ignored; partially-ignored repo: whole-tree answer is "not ignored"
   even though a subdirectory is) — the DONE WHEN criterion "the predicate exists in one place
   with its own tests" is most naturally read as this file plus this test, not as a bundled
   addition to `test-git-commit-scoped.sh`'s own suite (which should instead gain the V13-specific
   cases below, exercising the per-pathspec gate rather than the repo-level predicate).
2. **New `V13` gate inside `git-commit-scoped.sh`**, per Finding 4's placement, ledger, and
   exit-code design (`8`, `9`). Update the script's own header comment block (the `# Exit codes:`
   list and the `#   V8 ... / V9 ... / V10 ... / V11 ... / V12 ...` gate-label list) to add `V13`
   and the two new codes, in the same voice and at the same level of empirical detail the existing
   V-entries use — this is the literal DONE WHEN requirement ("its header documents the new
   outcome beside the existing V-codes").
3. **Update the two other production consumers' own exit-code handling** exactly as Finding 4
   specifies: `orchestrate-cycle-postflight.sh`'s WORK (i) `case "$commit_rc"` (both the
   attribution/logging arm and the demotion-gate arm) and `git-commit-phase.sh`'s header-comment
   "EXIT-CODE MAPPING" note. Neither needs a logic change beyond the case-arm membership and the
   comment; `git-commit-phase.sh`'s own completeness check needs no code change at all (Finding
   4's ruled-out third site).
4. **`context/standards/git-staging-scope.md` updates**, satisfying the DONE WHEN clause "states
   the per-operation contract for both postures": extend the existing "Exit-Code Contract and
   Safety Gates" table and gate-label prose (the file's own `## Commit-Level Path Scoping and
   Cross-Process Serialization` section) with rows for `8`/`9` and a `V13` gate-label entry in the
   same voice as the existing V9/V10 entries, cross-referencing the new library. Separately, add a
   short subsection (a natural sibling of "Per-Operation Scope") stating explicitly, for each of
   `research`/`plan`/`implement`: a tracked-specs repository commits exactly as it does today
   (unchanged byte-for-byte, confirmed by Finding 2), and a repository whose `specs/` tree is
   wholly or partly gitignored sees the relevant staged paths dropped under V13 with a non-failure
   outcome rather than any commit-site change to WHAT gets staged — the staging lists themselves
   (`specs/{padded}_{slug}/`, `specs/TODO.md`, `specs/state.json`, etc.) are unchanged; only the
   OUTCOME reported for an ignored member of that list changes.
5. **Verification bar, per the dispatch's own instruction**: build the fixture pair the dispatch
   demands — a tracked-specs fixture repo and an ignored-specs fixture repo — asserting the full
   exit-code contract on both sides, with "one negative control per rule, each biting exactly the
   case it targets and nowhere else." Concretely this means, at minimum: (a) a tracked-specs
   control proving `git-commit-scoped.sh`'s behavior is byte-for-byte unchanged (reuse the
   existing suite's own baseline cases as the negative control — no new assertion needed, just
   confirmation they still pass); (b) an all-ignored control hitting exit `8` and distinguishing it
   from exit `2` and exit `4`; (c) a partial-ignore control hitting exit `9` and confirming the
   surviving sibling path actually lands in `HEAD` (via `git show --name-only`, this suite's own
   house style, never exit code alone); (d) a tracked-and-ignore-matching control (reusing
   `build_repo_tracked_ignored`) proving V13 does NOT fire for that shape and U1/U2's existing exit
   `0` assertions are unaffected.

## Decisions

- The predicate is implemented at **both** repository and per-pathspec granularity (Finding 3),
  not a single either/or choice — this is a decision this research makes explicitly, since the
  dispatch's question (c) was open and the two granularities serve genuinely different, additive
  consumers rather than being alternatives.
- The new V13 gate is **unconditional** (not gated on `--task`), unlike V10 — a deliberate
  departure from treating "--task-gated" as the default shape for every new V-gate, justified by
  Finding 1's reproductions requiring no `--task` to exhibit the defect.
- Two new exit codes (`8`, `9`), not one — justified by the V9/V10 precedent of splitting
  "all-dropped" from "some-dropped-but-committed" into materially different caller-visible
  outcomes, and by Finding 1 shape 3 showing the two shapes have materially different stakes (a
  legitimate sibling commit is at risk in the partial case but not the all-ignored case).
- `git-commit-phase.sh`'s post-commit completeness check needs no change (Finding 4's ruled-out
  third site) — recorded explicitly as a decision-not-to-change, with its own live evidence, so a
  future pass does not re-open this question without new evidence.

## Risks & Mitigations

- **Risk**: placing V13 after V9/V10/V11 but before case 1 could still interact badly with V7's
  own tolerated-advisory NOTE path if a future `.gitignore` rule shape produces a FALSE "ignored"
  verdict for a path `git add` would actually have staged. **Mitigation**: Finding 2's live
  verification already confirms `git check-ignore -q` never reports "ignored" for a tracked path
  under either rule shape tested; the plan phase should additionally probe a rename/copy-detection
  edge (a tracked file moved to a new, ignored-matching path in the same commit) before finalizing,
  since this research did not exercise that specific combination.
- **Risk**: a consumer repository with `specs/` gitignored but SOME task subdirectories explicitly
  un-ignored (a `.gitignore` negation rule, `!specs/042_x/`) is a plausible real-world shape this
  research did not reproduce live. **Mitigation**: `git check-ignore -q` already correctly
  resolves negation rules (this is standard, well-tested git behavior, not something this script
  reimplements), so the per-pathspec V13 gate should handle it correctly by construction; flag for
  the plan phase as a fixture worth adding to the verification bar rather than a design change.
- **Risk**: exit codes `8`/`9` are new values a THIRD-PARTY caller (outside this repository's own
  three named production consumers) might not expect. **Mitigation**: every caller other than
  `orchestrate-cycle-postflight.sh` already wraps the invocation in `cmd || echo "WARN: ...
  (non-blocking)"` per this document's own "Recorded caller-escalation residual" note — any
  nonzero exit, including the two new ones, already collapses to a non-blocking warning for those
  callers today, so this is a documented, pre-existing posture, not a new hazard introduced by this
  change.

## Context Extension Recommendations

- **Topic**: gitignore-awareness in the commit pipeline.
- **Gap**: `context/standards/git-staging-scope.md` currently has no language at all addressing a
  gitignored `specs/` tree (confirmed by reading the file's full table of contents); every
  existing passage assumes a tracked `specs/` tree.
- **Recommendation**: the per-operation-contract subsection proposed in Recommendations item 4
  above is the natural home; no separate new standards file is needed, since this is a refinement
  of an existing, actively-maintained contract document rather than a new domain.

## Appendix

### Search queries / investigation steps used
- Repository `find`/`grep` for `git-commit-scoped.sh`, `engine-written-state-paths-lib.sh`,
  `git-corpus-enum-lib.sh`, `check-task-references.sh`, `check-record-versioning.sh`,
  `verify-touched.sh`, and `git-staging-scope.md` under `agent-system/extensions/core/`.
- Full read of `git-commit-scoped.sh` (1258 lines) and `engine-written-state-paths-lib.sh`.
- Full read of `git-corpus-enum-lib.sh` (the "existing ignore-aware" style named in the dispatch).
- Targeted read of `git-staging-scope.md`'s Overview, Canonical Runtime-File Exclusion Set,
  Multi-Task Application, Fail-Safe Direction, Staging-Layer Containment Filter, Commit-Level
  Path Scoping and Cross-Process Serialization (including the full Exit-Code Contract and Safety
  Gates table), and Per-Operation Scope sections.
- Read of `test-git-commit-scoped.sh`'s fixture-builder functions (`build_repo`,
  `build_repo_tracked_ignored`, `run_commit`) and its U1-U4 case block (the existing V7
  tracked-and-ignore-matching coverage).
- Read of `git-commit-phase.sh`'s header (EXIT-CODE MAPPING, REPOSITORY CLASSIFICATION) and its
  invocation + post-commit completeness-check tail (lines ~690-768).
- Targeted `grep` of `orchestrate-cycle-postflight.sh`'s WORK (i) `case "$commit_rc"` handling and
  its commit-landing demotion gate (lines ~2108-2196).
- Four live empirical reproductions in disposable `mktemp -d` scratch git repositories (repoA:
  tracked-specs baseline; repoB: wholly-ignored specs/, including the single-pathspec, realistic
  multi-pathspec, and mixed-with-a-valid-sibling shapes; repoC: partially-ignored specs/, one task
  directory only; repoU: the pre-existing tracked-and-then-ignored shape, re-verified directly).
- Verified `git check-ignore -q` behavior directly: whole-tree (`specs`), per-directory
  (`specs/001_x/`), per-file, tracked-before-parent-dir-rule, and tracked-before-direct-file-rule.
- Verified `git status --porcelain`'s default (no `--ignored`) behavior against an ignored,
  untracked path, to rule out the suspected third defect site.

### References
- `agent-system/extensions/core/scripts/git-commit-scoped.sh`
- `agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh`
- `agent-system/extensions/core/scripts/lib/git-corpus-enum-lib.sh`
- `agent-system/extensions/core/scripts/git-commit-phase.sh`
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`
- `agent-system/extensions/core/context/standards/git-staging-scope.md`
