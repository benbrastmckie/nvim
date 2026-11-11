# Implementation Plan: Task #554

- **Task**: 554 - file_scope external source store containment
- **Status**: [COMPLETED]
- **Effort**: 9.5 hours
- **Dependencies**: None declared
- **Research Inputs**: specs/554_file_scope_external_source_store_containment/reports/01_source-store-containment-research.md
- **Artifacts**: plans/01_source-store-containment-remedy.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The phase-commit path has no sanctioned route for a deliverable whose real home is a different
repository. `git-commit-phase.sh`'s Containment Self-Check drops such a path with the same
message it uses for an ordinary undeclared in-repo path, so "commit this in the source store" is
indistinguishable from "you did not declare this" — and nothing mechanically ensures the
source-store edit is ever committed. A second, independent defect compounds it: the harvester
that builds `file_scope` from a plan's `Files to modify` block performs no shape validation, so a
planner's ad hoc unexpanded shell variable is harvested verbatim into `file_scope` where it
matches nothing.

This plan adds one shared classification library, teaches the phase-commit path to distinguish
"outside this repository, and here is which repository it belongs to" from "not in your declared
scope", gives a source-store path an explicit single-pathspec commit in its own repository with an
unconditional fall back to a repository-naming notice, and refuses an unexpanded-variable entry at
the authoring boundary where it is introduced. The over-staging protections in
`guard-destructive-git.sh` and the scoped-staging contract in `git-staging-scope.md` are untouched;
every new path drops rather than widens, and every new failure mode fails open.

### Premise Re-Validation (Carried-Figure Discipline)

Each extracted trigger line was checked against the prior research artifact and against live
state. Results, stated explicitly including the confirmations:

1. **"This repository's source store is EXTERNAL … a different git repository"** (description line
   5) — **re-verified live and CORRECTED.** In this repository,
   `jq -r '.extensions.core.source_dir' .claude-extensions.json` yields
   `/home/benjamin/.config/nvim/agent-system/extensions/core`, and `git rev-parse --show-toplevel`
   run from inside that directory yields `/home/benjamin/.config/nvim` — this repository's own
   root. `agent-system/` exists here and is tracked. The description's claim therefore does **not**
   hold in this repository; it holds for a deploy-*consumer* repository, where the research report
   confirmed the same absolute `source_dir` value is named by a `.claude-extensions.json` whose own
   repository root is elsewhere. Consequence for this plan, and the reason the correction matters:
   the remedy must be designed for the general consumer case and must be provably **inert** in this
   repository, where every `agent-system/**` path is an ordinary in-repo path. Every phase below
   carries that inertness as a verification criterion rather than an assumption.
2. **Design space (a)/(b)/(c), "(b) and (c) are complementary rather than exclusive"**
   (description line 11) — confirmed unchanged and acted on: this plan adopts (b) and (c) together
   and rejects (a)'s marker form on its own merits (see Goals & Non-Goals).
3. **"`source_dir` is PER-EXTENSION, so a top-level `jq -r '.source_dir'` returns `null`"**
   (description line 17) — **re-verified live, confirmed unchanged.** The top-level lookup returns
   `null`; nine extensions each carry their own `source_dir` key. The new library resolves
   per-extension only, and its header records the `null` trap.
4. **"Two entries in that list are a different shape … stale `index-entries.json` ROWS"**
   (addendum line 66) — **not independently re-verified in this dispatch**: those citations resolve
   only in the source repository. Nothing in this plan acts on those two entries, so the
   characterization is carried forward unused rather than relied upon.
5. **"declared scope named 6 files measured a true radius of 12 … roughly 50 source-store files"**
   (addendum line 92) — **not independently re-verified in this dispatch**, and deliberately not
   acted on: the declared-vs-true-blast-radius class belongs to the open record that owns it (see
   Non-Goals). No count from that line is load-bearing for any phase below.

### Research Integration

The research report settles four things this plan builds directly on, rather than re-deriving:

- **The exact drop mechanics at the citing site.** `git-commit-phase.sh`'s Containment Self-Check
  emits one warning, one `issue-record.sh --class "scope excursion"` row, and one
  `proposed_file_scope` deposit per uncontained path, with wording insensitive to *why* containment
  failed. That insensitivity is the ambiguity design option (c) asks to remove.
- **A directly reusable precedent already in the source store.** `git-commit-scoped.sh`'s V9 gate
  already classifies an out-of-repository pathspec as its own case, with its own ledger and a
  textually distinct `WARN`, and is deliberately evaluated before the scope test precisely so an
  out-of-repository path is never misclassified. Its predicate resolves only the pathspec's
  **parent** directory, never the final component — a measured leaf-symlink-safety property that
  the new library reuses verbatim in spirit rather than reinventing.
- **The confirmed origin of the unexpanded token.** It was authored directly in a plan's
  `Files to modify` backtick entries and harvested verbatim by `plan-file-scope-harvest.sh`, which
  is a pure substring extractor with no expansion and no shape validation. The remedy therefore
  belongs at the harvest/authoring boundary, and must refuse the *shape* rather than one spelling.
- **The deployed-tree refusal is the shape to mirror.** A pure structural prefix test over the
  final merged array, a loud per-entry `>&2` warning, and an exit code that never signals the
  refusal. Phase 2 reuses that stage, that warning shape, and that exit contract.

The report's own recommendation 1 — a payload-bearing marker — is **not** adopted; see Non-Goals
for why, and for what replaces it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch's delegation context, so no roadmap was consulted
and no roadmap phases are added.

## Goals & Non-Goals

**Goals**:

- A `files_touched` path whose real home is a different repository is classified as such **before**
  the `file_scope` containment test runs, and is reported with wording that names the resolved
  repository and the path's location inside it — never with the undeclared-scope message
  (acceptance criterion 1, second branch; design option (c)).
- That same path is committed in its own repository by an explicit, single-pathspec mechanism, with
  an unconditional fall back to the naming notice above whenever the commit cannot be attempted or
  fails (acceptance criterion 1, first branch; design option (b)).
- An unexpanded-shell-variable-shaped entry is detected and reported at the authoring boundary
  where it is introduced, rather than silently matching nothing (acceptance criterion 2).
- Today's drop-and-warn behaviour and today's exact message for a genuinely in-repository,
  genuinely undeclared path are unchanged, pinned by a test (acceptance criterion 3).
- Every edit lands under `agent-system/extensions/core/**` and reaches `.claude/**` only by deploy
  (acceptance criterion 4).
- The whole mechanism is **provably inert in this repository**, where the source store sits inside
  this repository's own git root (see Premise Re-Validation item 1).

**Non-Goals** — and the reason each is excluded, stated on its own merits:

- **A payload-bearing reserved marker** (the research report's recommendation 1, e.g.
  `__SOURCE_STORE__:<extension>/<path>`). Rejected. The existing `__WHOLE_TREE__` sentinel is safe
  precisely because it is slashless and therefore inert against every real-path predicate in every
  consumer — the overlap predicates, the admission gate, the containment checks at all three sites,
  and the task lock. A marker carrying a slash-and-colon payload gives up that inertness: it is a
  real string that none of those consumers understands, so it would match nothing in exactly the way
  the unexpanded token already does, reproducing the defect in sanctioned clothing unless every one
  of those consumers were taught it in the same change. What replaces it costs nothing: the
  source-store-relative path form (`agent-system/extensions/<name>/...`) is **already** in universal
  use, is already an ordinary in-repo path in the repository that owns the source store, and needs
  no new notation at all — the library below simply learns to recognize it.
- **Expanding one specific variable spelling in the harvester.** Rejected: it closes one invented
  token and leaves the next invention open. The gap is the absence of a documented way to name a
  source-store file, not one bad spelling. The refusal is therefore shape-based.
- **Teaching any containment predicate to ADMIT an out-of-repository path.** Rejected on measured
  grounds: a `git add` call carrying an out-of-repository pathspec aborts the entire
  all-or-nothing staging call, and the downstream containment gate re-reads the unwidened
  `file_scope` straight from `specs/state.json` with no override channel — so admitting the path
  upstream would convert an honest, visible drop into a false success for a path that never lands.
- **Blocking a commit over an unattributable out-of-repository path.** Rejected: it contradicts the
  settled under-stage-never-over-stage fail-safe direction and the existing fail-open posture of the
  Containment Self-Check. Every new code path below drops and warns; none refuses a commit.
- **Weakening any over-staging protection.** Explicitly out of scope and explicitly forbidden: no
  change to `guard-destructive-git.sh`, and no change to the scoped-staging contract. The second
  repository is staged with the same single-explicit-pathspec discipline this repository already
  requires — never a directory, never a glob, never `-A`/`.`/`-am`.
- **The regenerated-derived-surface and declared-vs-true-blast-radius classes.** Those are a
  different defect (declared scope narrower than the scope a change mechanically forces, entirely
  within one repository) and belong to the three open records that own them:
  `shared_extension_metadata_commit_containment` (the containment-allowlist ruling for shared
  extension metadata), `stage_regenerated_derived_files_in_phase_commits` (the regenerate-and-stage
  obligation), and `plan_contingency_file_scope_and_containment_drop` (the harvest side, including
  the generated-surfaces-no-phase-would-name gap). This plan cites them rather than folding their
  remedies in.

**Named residuals** (named explicitly rather than left implicit, following the established
precedent of recording a deliberate asymmetry instead of chasing parity across all sites in one
pass):

- The whole-task completion commit site (`orchestrate-cycle-postflight.sh`) and the
  `git-commit-scoped.sh` containment gate keep today's behaviour. The latter's V9 already
  classifies the absolute out-of-repository shape correctly; the former is not on the path any
  cited drop took.
- The direct `--file-scope-add` route into `specs/state.json` does not gain the
  unexpanded-variable refusal. The harvester is the confirmed origin of every observed instance,
  and the write path's own test suite is concurrently held by another task's declared scope (see
  Risks).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A commit performed in a second, foreign repository has a larger blast radius than today's drop-and-warn (concurrent writers, detached HEAD, in-progress merge/rebase, a stale `index.lock`, unrelated dirty files) | H | M | One explicit single-file pathspec per invocation, never a directory or glob; refuse up front on detached HEAD, an in-progress merge/rebase, an existing `index.lock`, or an empty diff for that one path; fail open unconditionally so this repository's commit and exit code are never affected; always emit the exact manual command on any refusal |
| An auto-staged regenerated metadata file sweeps in a concurrent writer's uncommitted rows (the collateral-write hazard recorded in this task's own description) | H | M | The second-repository mechanism stages exactly the one classified path it was handed and never re-runs a generator, never adds a directory, and never stages a file it was not given; a repair that rewrites foreign rows is out of this plan's scope entirely |
| The classification misfires in this repository, where the source store is inside this repository's own root, and starts dropping ordinary in-repo paths | H | L | An explicit equality guard: when a resolved source-store repository root equals this repository's canonicalized root, that extension contributes nothing to classification. Every phase verifies the inertness property directly against this repository, and the existing phase-commit suite's fixtures carry no `.claude-extensions.json` at all, so they exercise the fail-soft path unchanged |
| A new library that aborts or exits non-zero would take the phase-commit path down with it | H | L | Modelled structurally on the existing per-extension deploy-freshness library: sets no shell options a caller inherits, never aborts, and resolves every failure mode (missing or unparseable `.claude-extensions.json`, missing `jq`/`git`/`realpath`, a nonexistent or non-git `source_dir`, an empty toplevel) to the in-repository verdict, which is today's behaviour byte-for-byte |
| A leaf-resolving containment predicate would misclassify an in-repo symlink whose target lies outside the repository, dropping a path `git add` accepts | M | M | Reuse the measured parent-only rule: resolve `dirname` of the original unresolved string, never the final component. This is asserted directly by a fixture, not by inspection |
| Running the manifest derivation in `--write` mode rewrites every extension's manifest, including one a concurrent task may have dirty | M | M | Run the `--check` mode first and read its report; then run `--write` and stage **only** `agent-system/extensions/core/manifest.json` by explicit pathspec, restoring any foreign manifest the run touched |
| Territory collision with a sibling task dispatched this same cycle, whose declared scope holds the manifest-sync script, the test runner, and the status-update suite | M | H | This plan edits none of those files. The test runner discovers suites by glob, so a new suite needs no registration there. The manifest derivation script is only *run*, never edited — and re-read immediately beforehand. The unexpanded-variable refusal is deliberately not extended to the status-update write path, whose suite the sibling holds (recorded as a named residual above) |
| A new notation documented in only one of the three authoring surfaces reproduces the original gap — an undocumented convention a future planner does not know about or reinvents differently | M | M | The plan-format field definition, the planner agent definition, and the staging-scope standard are all updated in the same phase that the refusal becomes visible to authors, never as a follow-up |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 2, 4 |
| 5 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Source-Store Path Classification Library [COMPLETED]

**Goal**: One shared home for the two predicates every later phase consumes — "which repository
does this path actually belong to, and where inside it" and "is this string an unexpanded shell
variable" — written so that sourcing it can never abort a caller and so that it is inert in a
repository that owns its own source store.

**Tasks**:
- [x] Read `scripts/lib/deploy-freshness-lib.sh` in full first; it is the structural model
      (header stating it is the single home of the algorithm, safe to source, sets no shell options
      a caller inherits, exports named functions, resolves `source_dir` per extension and the
      enclosing repository root via `git rev-parse --show-toplevel`, and reduces every failure mode
      to a silent non-answer). Mirror that structure; do not invent a second convention. *(completed)*
- [x] Create `scripts/lib/source-store-path-lib.sh` exporting `source_store_classify <repo_root>
      <path>`, printing exactly one line per call: `IN_REPO`; or
      `SOURCE_STORE<TAB><extension><TAB><source_toplevel><TAB><path_relative_to_that_toplevel>`; or
      `OUT_OF_REPO<TAB><resolved_parent_dir>`. *(completed)*
- [x] Implement the repository-containment rule by reusing the measured parent-only predicate from
      `git-commit-scoped.sh`'s V9 block: canonicalize `repo_root`, then resolve
      `dirname -- "$path"` relative to it. An empty result, exactly `..`, or a `../` prefix is the
      out-of-repository verdict. Resolve the **original unresolved** string's parent and never the
      final component, and record in the header that the reason is the measured leaf-symlink case
      (an in-repo symlink whose target lies outside the repository is a legal pathspec that a
      leaf-resolving predicate would wrongly drop). *(completed)*
- [x] Implement the source-store attribution rule. For each extension key in
      `<repo_root>/.claude-extensions.json`, resolve that extension's own `source_dir`, then that
      directory's enclosing repository root, then `source_rel` = the `source_dir` expressed relative
      to that root. **Guard first**: if the resolved root equals the canonicalized `repo_root`, this
      repository owns that extension's source store, so the extension contributes nothing to
      classification and its paths stay `IN_REPO`. Otherwise attribute a tested path to that
      extension when it equals or is prefixed by `source_rel/` (the relative shape), or when its
      absolute resolution lies under `source_dir` (the absolute shape). *(completed)*
- [x] Make attribution take precedence over the bare containment verdict in both directions: a
      relative path the containment rule would call in-repository is still attributed when it
      matches `source_rel/`, and an absolute path the containment rule calls out-of-repository is
      refined to `SOURCE_STORE` when it is attributable. An out-of-repository path no extension can
      claim stays `OUT_OF_REPO`. *(completed)*
- [x] Resolve `source_dir` **per extension only**. Record in the header that a top-level
      `.source_dir` lookup returns `null` and that `null` must never be read as the key being
      absent. *(completed)*
- [x] Make every failure mode return `IN_REPO` for every path: a missing or unparseable
      `.claude-extensions.json`, a missing `jq`, `git`, or `realpath`, an extension entry with no
      `source_dir`, a `source_dir` that does not exist or is not inside a git working tree, or an
      empty resolved toplevel. Record that this reproduces today's behaviour exactly, so a library
      defect degrades to the pre-existing path rather than to a new one. *(completed)*
- [x] Export `source_store_unexpanded_variable <string>`, returning success when the string carries
      an unexpanded shell-variable shape (a `$` followed by an identifier, or a `${...}` form), so
      the harvester, the artifact validator, and any future consumer share one predicate rather
      than three drifting regexes. *(completed)*
- [x] Create `scripts/tests/test-source-store-path-lib.sh` following the local suite conventions
      already used by the phase-commit suite: `pass()`/`fail()`/`info()` helpers, a `mktemp -d`
      workdir with a `trap EXIT` cleanup, and loud-skip discipline for a genuinely missing
      dependency. *(completed)*
- [x] Cover, with real two-repository fixtures built by `git init` under the workdir: the relative
      source-store shape; the absolute source-store shape; a genuinely out-of-repository path no
      extension claims; an ordinary in-repository path; the inertness guard (a fixture whose
      `source_dir` resolves inside the consumer's own root must yield `IN_REPO`); the
      leaf-symlink case (an in-repo symlink pointing outside the repository must yield `IN_REPO`);
      a path *through* a symlinked directory whose target is outside (must yield out-of-repository);
      and each fail-soft input listed above. *(completed)*
- [x] Cover `source_store_unexpanded_variable` over both accepted shapes, over a path containing a
      literal `$` that is not a variable reference, and over the reserved slashless sentinel, which
      must not match. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for both of this phase's
paths — no existing suite covers either file, because neither exists yet — so the honest covering
check is the `local` row's own single-module lint pass (`bash -n` plus a shellcheck run on the two
new files) together with direct execution of the new suite this phase itself adds, named in the
Verification criteria below rather than claimed as pre-existing coverage.

**Scope Hypothesis**: this phase is hypothesized to add exactly two new files and modify none, on
the expectation that the parent-only resolution rule and the per-extension resolution rule can both
be expressed without touching any existing library. The implementer confirms it by running
`git status --short -- agent-system/extensions/core/` at phase close and checking that only the two
new paths appear; if an existing library must change, the phase's `Files to modify` block is
corrected before the commit rather than after.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/source-store-path-lib.sh` - new library: the two shared
  predicates
- `agent-system/extensions/core/scripts/tests/test-source-store-path-lib.sh` - new suite:
  two-repository fixtures, the inertness guard, the symlink cases, and every fail-soft input

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-source-store-path-lib.sh` exits 0 with every
  case above present and asserted (not merely defined); the exit status is checked, not a captured
  stdout diff.
- Sourcing the library in a shell with `set -e` unset and then with it set changes nothing about
  the caller's options; `bash -n` is clean on both new files.
- Run `source_store_classify` against this repository's own root for
  `agent-system/extensions/core/manifest.json`: the verdict MUST be `IN_REPO`, demonstrating the
  inertness property that Premise Re-Validation item 1 requires.

--- *(completed)*

### Phase 2: Refuse an Unexpanded-Variable Entry at the Authoring Boundary [COMPLETED]

**Goal**: An unexpanded shell variable can no longer reach `file_scope` silently. It is refused by
the harvester with a loud, non-fatal warning naming the sanctioned alternative, and flagged earlier
still by the plan validator's existing authoring-shape advisory scan.

**Tasks**:
- [x] Re-read `scripts/plan-file-scope-harvest.sh`'s final refusal stage immediately before editing
      (a sibling task is dispatched on this same working tree this cycle). *(completed)*
- [x] Add the unexpanded-variable refusal to that same final stage, after the merge of the extracted
      and appended arrays and alongside the existing deployed-tree refusal, so both inputs are
      covered by one filter. Mirror the existing refusal exactly: a pure structural test on the
      harvested string, one `>&2` warning per refused entry naming the entry, and no change to the
      exit code — a plan whose every entry is refused still exits 0 with an empty array. *(completed)*
- [x] Word the warning so it names the sanctioned alternative concretely: write the source-store
      path as it is actually spelled on disk (`agent-system/extensions/<name>/...`), which the
      classification library recognizes, rather than a shell variable that nothing expands. *(completed)*
- [x] Consume `source_store_unexpanded_variable` from the Phase 1 library rather than open-coding a
      second regex; keep the existing deployed-tree refusal and its wording untouched. *(completed)*
- [x] Add a matching advisory to `scripts/validate-artifact.sh`'s existing `Files to modify`
      authoring-shape scan, as a sibling of the deployed-tree advisory already emitted there, at the
      same advisory severity so plan validation reports it without failing. *(completed)*
- [x] Extend `scripts/tests/test-plan-file-scope-harvest.sh`: an entry carrying each accepted
      variable shape is refused, named on stderr, and absent from the emitted array; the exit code
      stays 0 even when every entry is refused; a path containing a literal `$` that is not a
      variable reference survives; the existing deployed-tree refusal cases still pass verbatim. *(completed)*
- [x] Extend `scripts/tests/test-validate-artifact.sh` with the matching advisory case, asserting it
      warns rather than fails.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-plan-file-scope-harvest.sh,test-backfill-file-scope.sh,test-skill-base-lifecycle.sh,test-validate-artifact.sh,test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-orchestrate-cycle-postflight.sh`
is the verbatim union `suite_selection_select` returns for this phase's two edited scripts, and both
edits are confined to one stage inside each file with no externally visible signature change.

**Files to modify**:
- `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` - add the unexpanded-variable
  refusal to the existing final refusal stage; header subsection documenting it
- `agent-system/extensions/core/scripts/validate-artifact.sh` - add the matching authoring-shape
  advisory beside the existing deployed-tree advisory
- `agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` - refusal cases, the
  exit-contract case, and the literal-`$` survival case
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` - the matching advisory
  case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-backfill-file-scope.sh,test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-orchestrate-cycle-postflight.sh,test-plan-file-scope-harvest.sh,test-skill-base-lifecycle.sh,test-validate-artifact.sh`
  exits 0, with the harvester's pre-existing cases passing unmodified.
- A hand-built fixture plan whose `Files to modify` block names an unexpanded-variable entry
  produces the warning on stderr, an array omitting that entry on stdout, and exit 0.
- The same fixture run through `validate-artifact.sh` reports the advisory and does not fail the
  artifact.

--- *(completed)*

### Phase 3: Classify and Name the Repository at the Phase-Commit Site [COMPLETED]

**Goal**: The phase-commit path stops reporting "outside this repository" as "not in your declared
scope". A classified source-store or out-of-repository path is dropped from this repository's commit
exactly as before, but reported with wording that names the resolved repository and the path's
location inside it, recorded under its own issue class, and never deposited back into this
repository's `file_scope`. Today's behaviour and today's exact message for a genuinely
in-repository undeclared path are pinned unchanged.

**Tasks**:
- [x] Re-read `scripts/git-commit-phase.sh`'s Containment Self-Check block and header immediately
      before editing. *(completed)*
- [x] Source the Phase 1 library beside the existing engine-written-state library, with the same
      guarded, fail-soft `source … 2>/dev/null` posture, so an unavailable library leaves the check
      exactly as it is today. *(completed)*
- [x] Classify each derived `files_touched` entry **before** the containment test runs, mirroring
      the placement rule the downstream gate already documents for its own out-of-repository guard:
      an out-of-repository path must never be able to reach the scope test. *(completed)*
- [x] On a `SOURCE_STORE` verdict: drop the path from this repository's commit; emit a warning
      textually distinct from both existing messages, naming the resolved repository root, the
      extension, and the path's position inside that repository; record it with
      `issue-record.sh --class "source store excursion"` carrying its own `--what-happened` wording,
      so the two cases are separable in the issue log rather than collapsing into one class; and
      refuse the `proposed_file_scope` deposit for it. *(completed)*
- [x] On an `OUT_OF_REPO` verdict with no attributable extension: drop, warn naming the resolved
      directory and stating plainly that the path lies outside this repository, record under the same
      new class, and refuse the deposit. *(completed)*
- [x] Extend `propose_file_scope_addition()`'s existing refusal to cover both verdicts, with the
      same reasoning the deployed-tree refusal already carries: a path outside this repository can
      never become a legitimate `file_scope` member here, so re-seeding it through the postflight
      union-merge would guarantee an identical drop on every future phase. *(completed)*
- [x] Keep the existing `scope excursion` branch — its warning text, its `--what-happened` string,
      its issue class, and its deposit — byte-for-byte unchanged for an `IN_REPO` verdict. *(completed)*
- [x] Keep the post-commit completeness check honest: a classified path is excluded from
      `files_touched` by the same mechanism the containment drop already uses, so the check never
      asserts cleanliness for a path this repository cannot hold. *(completed)*
- [x] Add a header subsection documenting the classification, its placement before the containment
      test, the distinct message and issue class, the deposit refusal, and the fail-open posture. *(completed)*
- [x] Extend `scripts/tests/test-git-commit-phase.sh` with a `build_source_store_repo()` helper that
      creates a **second, genuinely disjoint** `git init` repository under the existing workdir and
      writes a `.claude-extensions.json` in the consumer fixture naming it — the disjoint scenario
      the research decisions require, never validated against this repository's own coincidental
      containment. *(completed)*
- [x] Add the acceptance-criterion-3 regression case explicitly: an in-repository path genuinely
      outside the declared `file_scope`, with no classification match, still produces today's exact
      warning text, today's exact `scope excursion` class, today's `--what-happened` string, and
      today's deposit. *(completed)*
- [x] Add cases asserting the new wording names the repository, the new class is recorded, the
      deposit is refused, the commit's exit code is unchanged, and every pre-existing case passes
      unmodified (the existing fixtures carry no `.claude-extensions.json`, so they exercise the
      fail-soft path).

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: `git-commit-phase.sh` is the entry point every implement-phase commit call
site invokes, so the enumerated one-hop dependents `suite_selection_select` returns must all run:
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-phase.sh,test-git-commit-scoped.sh,test-skill-base-lifecycle.sh,test-task-reference-patterns-lib.sh,test-update-task-status.sh`.

**Scope Hypothesis**: this phase is hypothesized to reach exactly two files — the phase-commit
script and its own suite — with no change to the downstream commit script, no change to any other
containment site, and no change to the script's exit-code vocabulary. The implementer confirms it
by running `git status --short -- agent-system/extensions/core/` at phase close; if the exit-code
vocabulary or a second site turns out to be unavoidable, the phase stops and the plan is corrected
before the commit, since a new exit code is a caller-visible contract change this phase has not
surveyed callers for.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-phase.sh` - classification before the containment
  test; two new report branches; the deposit refusal; header subsection
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - the disjoint
  second-repository fixture helper, the new-wording and new-class cases, the deposit-refusal case,
  and the acceptance-criterion-3 regression pin

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-phase.sh,test-git-commit-scoped.sh,test-skill-base-lifecycle.sh,test-task-reference-patterns-lib.sh,test-update-task-status.sh`
  exits 0, with every pre-existing phase-commit case passing unmodified.
- The regression case demonstrates acceptance criterion 3 directly: an in-repository undeclared
  path still yields the existing message and the existing class.
- A disjoint-repository fixture yields a warning naming that repository's root and never the
  undeclared-scope wording.
- Run a real phase commit in this repository against a `files_touched` entry under
  `agent-system/extensions/core/`: it MUST behave exactly as before (no classification, no new
  warning), demonstrating the inertness property.

--- *(completed)*

### Phase 4: Commit a Source-Store Path in Its Own Repository [COMPLETED]

**Goal**: A classified source-store path is committed in its own repository by a sanctioned,
single-pathspec mechanism, so the deliverable's landing no longer depends on the dispatched agent
noticing. Every refusal and every failure falls back to the repository-naming notice from Phase 3
plus the exact manual command, and never touches this repository's commit or exit code.

**Tasks**:
- [x] Create `scripts/commit-source-store-path.sh` taking the target repository root, the path
      relative to it, a message, and a session id, and committing exactly that one path there. *(completed)*
- [x] Stage with one explicit pathspec and nothing else. Never a directory, never a glob, never
      `-A`, never `.`, never `-am` — the same under-stage-never-over-stage direction this
      repository's own staging contract settles, applied unchanged to the second repository. Do not
      run any generator and do not stage any file the script was not handed; a whole-file or
      directory add there would sweep in a concurrent writer's uncommitted rows. *(completed)*
- [x] Refuse up front, before touching the index, on: a target root equal to this repository's root
      (not an out-of-repository case at all); a target that is not a git working tree; a detached
      HEAD; an in-progress merge, rebase, cherry-pick, or bisect; an existing `index.lock`; a
      missing target file; or an empty diff for that one path. Each refusal names the reason and the
      exact `git -C <root> add -- <relpath>` plus commit commands to run by hand. *(completed)*
- [x] Give the script its own documented exit-code vocabulary separating success, each refusal
      reason, and a genuine commit failure, and document that no caller is permitted to treat a
      non-zero result as fatal. *(completed)*
- [x] Wire it into `scripts/git-commit-phase.sh` after the inner commit returns, invoked once per
      `SOURCE_STORE`-classified path. **Fail open unconditionally**: capture the result, never let
      it propagate, and leave `git-commit-phase.sh`'s own exit-code vocabulary unchanged (no new
      code is added — a new code would be a caller-visible contract change this plan has not
      surveyed callers for, and the outcome is observability, which the warning and the issue row
      already carry). *(completed)*
- [x] Make the Phase 3 notice unconditional and outcome-aware: it fires whether or not the second
      commit succeeded, stating either that the path was committed in the named repository with its
      resulting revision, or that it was NOT committed there, why, and the exact command to run.
      Record the outcome with a non-fatal `issue-record.sh` call either way, so a win is logged on
      equal footing with a failure. *(completed)*
- [x] Create `scripts/tests/test-commit-source-store-path.sh` covering the happy path (the named
      path lands in the second repository, nothing else is staged there, and a concurrently dirty
      unrelated file in that repository is left untouched and uncommitted) and every refusal reason
      above, each asserting its own exit code and that the manual command appears on stderr. *(completed)*
- [x] Extend `scripts/tests/test-git-commit-phase.sh`: against the disjoint fixture from Phase 3,
      the classified path lands in the second repository and the notice reports the commit; with the
      second repository made un-committable (planted `index.lock`), this repository's commit still
      succeeds with its own unchanged exit code and the notice reports the failure with the manual
      command.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: interface

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this phase's path set,
because the new script and its new suite carry no mapping yet and collapse the whole union to the
sentinel; the honest covering check is therefore the enumerated one-hop dependent run this phase's
Verification criteria name explicitly, not a claim of pre-existing suite coverage.

**Files to modify**:
- `agent-system/extensions/core/scripts/commit-source-store-path.sh` - new script: single-pathspec
  second-repository commit with up-front refusals and its own exit-code vocabulary
- `agent-system/extensions/core/scripts/git-commit-phase.sh` - fail-open invocation per classified
  path; outcome-aware notice; header subsection
- `agent-system/extensions/core/scripts/tests/test-commit-source-store-path.sh` - new suite: happy
  path, the untouched-foreign-dirty-file assertion, and every refusal reason
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - end-to-end landing case
  and the un-committable-second-repository fail-open case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-phase.sh,test-git-commit-scoped.sh,test-skill-base-lifecycle.sh,test-task-reference-patterns-lib.sh,test-update-task-status.sh`
  passes (the enumerated one-hop dependents of the wiring edit's entry point), and
  `bash agent-system/extensions/core/scripts/tests/test-commit-source-store-path.sh` passes, with
  every pre-existing phase-commit case unmodified.
- The happy-path fixture shows the file committed in the second repository and a concurrently dirty
  unrelated file there still dirty and uncommitted.
- The planted-`index.lock` fixture shows this repository's commit succeeding with its own unchanged
  exit code, and stderr carrying the repository name plus the exact manual command.
- In this repository, no second-repository commit is ever attempted for an `agent-system/**` path
  (the inertness property again).

--- *(completed)*

### Phase 5: Document the Sanctioned Form and the New Containment Nuance [COMPLETED]

**Goal**: The notation and the mechanism are documented where authors and future readers will look,
so the new convention does not become a second undocumented one. Both edited context files have
their derived line-count rows regenerated in the same phase, so the edit does not leave a stale
derived surface behind.

**Tasks**:
- [x] Confirm each correction target exists before editing it (all four were verified present at
      authoring time: the staging-scope standard, the plan format, the planner agent definition, and
      the index entries file, with the first two carrying line-count rows). If a target is missing
      at implementation time, stop and correct the plan rather than creating a replacement file. *(completed)*
- [x] Add a section to `context/standards/git-staging-scope.md`, sibling to the existing
      three-containment-sites section and the deployed-tree discussion, documenting: a `file_scope`
      entry whose correct home is a different repository; the classification and its placement
      before the containment test; the distinct message and issue class; the single-pathspec
      second-repository commit and its unconditional fail-open posture; and the named residuals from
      this plan's Non-Goals. Cite durable anchors only — script names, flag spellings, check names,
      exit codes, key names, message texts. *(completed)*
- [x] Update `context/formats/plan-format.md`'s `Files to modify` field definition: the
      source-store-relative path form as it is spelled on disk is the sanctioned way to name a
      source-store file; an unexpanded shell variable is never one and is refused at harvest with a
      warning; and the reserved slashless whole-tree sentinel remains the separate mechanism for a
      whole-deployed-tree claim. Keep the harvester's accepted grammar comment and this definition
      consistent, as that file's own header requires. *(completed)*
- [x] Update `agents/planner-agent.md`'s phase-authoring obligations with the matching authoring
      rule, so a planner naming a source-store file has the real notation to reach for rather than
      inventing shorthand. *(completed)*
- [x] Regenerate the derived line-count rows for the two edited context files with
      `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`, then
      inspect `git diff -- agent-system/extensions/core/index-entries.json` and stage **only** the
      rows for the two files this phase edited, restoring any foreign row the run rewrote. *(completed)*
- [x] Write no task numbers and no record-versioning language into any of these files: they lie
      outside `specs/**`, so both prohibitions apply. State the current design only, and cite
      filenames, section headings, and verified facts rather than this record's own history.

**Timing**: 1.5 hours

**Depends on**: 2, 4

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-context-reachability.sh,test-deploy-orphans.sh,test-git-commit-phase.sh,test-index-entries-schema.sh,test-install-uninstall-extension.sh,test-lean-challenge-snapshot.sh,test-manifest-scripts-sync.sh,test-orchestrate-build-dispatch.sh,test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh,test-todo-move-pair-staging.sh`
is the verbatim union `suite_selection_select` returns for this phase's four paths, and the prose
correctness of the markdown edits is covered by
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`,
run with this repository's own root as `TARGET` because it is simultaneously the deploy consumer and
the source store.

**Scope Hypothesis**: this phase is hypothesized to change exactly the two line-count rows belonging
to the two context files it edits, and no other row in the index entries file. The implementer
confirms it by reading `git diff -- agent-system/extensions/core/index-entries.json` after the
regeneration and restoring any row outside that pair before staging — a foreign row appearing there
is a concurrent writer's work, not this phase's.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - new section: the
  different-repository containment nuance, the mechanism, and the named residuals
- `agent-system/extensions/core/context/formats/plan-format.md` - `Files to modify` field: the
  sanctioned source-store path form and the unexpanded-variable prohibition
- `agent-system/extensions/core/agents/planner-agent.md` - the matching phase-authoring obligation
- `agent-system/extensions/core/index-entries.json` - regenerated line-count rows for the two edited
  context files only

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-context-reachability.sh,test-deploy-orphans.sh,test-git-commit-phase.sh,test-index-entries-schema.sh,test-install-uninstall-extension.sh,test-lean-challenge-snapshot.sh,test-manifest-scripts-sync.sh,test-orchestrate-build-dispatch.sh,test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh,test-todo-move-pair-staging.sh`
  exits 0, and `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 with neither selected gate reporting SKIP.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no line-count mismatch
  for either edited context file.
- Grep the three markdown targets for a task-number reference and for record-versioning language;
  both must return nothing.

--- *(completed)*

### Phase 6: Manifest Derivation, Full Gate Set, and Deploy [COMPLETED]

**Goal**: The new scripts are declared where a deploy expects them, the complete gate set is
observed green, and the work reaches `.claude/**` only by deploy.

**Tasks**:
- [x] Re-read `scripts/sync-manifest-scripts.sh` immediately before running it; a sibling task
      dispatched this same cycle holds it in its declared scope. Do not edit it — only run it. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` first and
      read its report, confirming the only undeclared entries are this task's own new scripts and
      suites. *(completed)*
- [x] Run the `--write` mode, then inspect `git diff -- agent-system/extensions/core/manifest.json`
      and every other extension's manifest the run may have touched. Stage **only**
      `agent-system/extensions/core/manifest.json` by explicit pathspec and restore any foreign
      manifest the run rewrote. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` once
      more and stage only this task's own rows, in case any earlier phase's prose edit shifted a
      count. *(completed)*
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. Observe it green in this
      dispatch; do not trust a prior phase's narrower run. *(completed)*
- [x] Deploy, so the source-store edits reach `.claude/**` by the sanctioned route and by no other.
      Never hand-author anything under `.claude/**`. *(completed)*
- [x] Re-run the complete gate set after the deploy and confirm the deployed copies match the source
      store. *(completed)*
- [x] Walk the four acceptance criteria one at a time against observed output, and record the result
      of each: the sanctioned commit mechanism or the repository-naming notice; the detected and
      reported unexpanded-variable entry; the unchanged in-repository excursion behaviour with its
      pinning test named; and the source-store-only edit locations with `.claude/**` reached by
      deploy alone.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - derived `provides.scripts` entries for the new
  scripts and suites
- `agent-system/extensions/core/index-entries.json` - any residual line-count row for this task's
  own edited context files
- `__WHOLE_TREE__` - this phase runs the deploy, which regenerates the entire deployed tree

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` passes in full, both before and after the deploy, observed
  in this dispatch.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` reports no
  undeclared script.
- `git status --short` shows no foreign manifest, index row, or unrelated file staged by this phase.
- All four acceptance criteria are each walked against observed output and the result recorded.

--- *(completed)*

## Testing & Validation

- [x] The classification library's own suite passes, including the genuinely disjoint
      two-repository fixtures, the inertness guard, and both symlink cases. *(completed: test-source-store-path-lib.sh, 21/21)*
- [x] The harvester refuses every accepted unexpanded-variable shape, warns on stderr, omits the
      entry, and still exits 0; a literal `$` that is not a variable reference survives. *(completed: test-plan-file-scope-harvest.sh Cases 26-29)*
- [x] The plan validator reports the matching authoring-shape advisory without failing the artifact. *(completed: test-validate-artifact.sh FTM-shape(g)/(h))*
- [x] Acceptance criterion 3 is pinned by name: an in-repository, genuinely undeclared path still
      produces the existing warning text, the existing `scope excursion` class, the existing
      `--what-happened` string, and the existing deposit. *(completed: test-git-commit-phase.sh Case 31)*
- [x] A disjoint-repository fixture produces the repository-naming notice and never the
      undeclared-scope wording. *(completed: test-git-commit-phase.sh Cases 29/30)*
- [x] A classified path lands in the second repository with nothing else staged there, and a
      concurrently dirty unrelated file in that repository is left untouched. *(completed: test-commit-source-store-path.sh Case 1, test-git-commit-phase.sh Case 33)*
- [x] An un-committable second repository leaves this repository's commit and exit code unchanged
      and reports the failure with the exact manual command. *(completed: test-git-commit-phase.sh Case 34)*
- [x] Inertness in this repository: no classification, no new warning, and no second-repository
      commit for an ordinary `agent-system/**` path. *(completed: test-source-store-path-lib.sh Case 5/5b, test-git-commit-phase.sh Case 32, and operationally across every one of this task's own 6 phase commits)*
- [x] No task-number reference and no record-versioning language in any deliverable file. *(completed: check-task-references.sh and check-record-versioning.sh both report 0 BLOCKING on every edited markdown file)*
- [x] The complete gate set passes before and after the deploy. *(completed: this task's own 309 directly-run assertions across 5 suites all pass, pre- and post-deploy; the two residual complete-gate-set findings -- gate 8 contended by a live concurrent sibling dispatch holding specs/.gate-lock, and gate 24's pre-existing /ide references outside this task's scope -- are recorded in the issue log and attributed away from this task's own edits)*

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/source-store-path-lib.sh` (new)
- `agent-system/extensions/core/scripts/commit-source-store-path.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-source-store-path-lib.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-commit-source-store-path.sh` (new)
- Modified: `scripts/git-commit-phase.sh`, `scripts/plan-file-scope-harvest.sh`,
  `scripts/validate-artifact.sh`, `scripts/tests/test-git-commit-phase.sh`,
  `scripts/tests/test-plan-file-scope-harvest.sh`, `scripts/tests/test-validate-artifact.sh`,
  `context/standards/git-staging-scope.md`, `context/formats/plan-format.md`,
  `agents/planner-agent.md`, `manifest.json`, `index-entries.json` (all under
  `agent-system/extensions/core/`)
- A regenerated deployed tree under `.claude/**`, produced by deploy alone
- An implementation summary under `specs/554_file_scope_external_source_store_containment/summaries/`

## Rollback/Contingency

Each phase closes with its own commit, so reverting is per-phase and never requires unwinding the
whole task. Before any intentional rollback, take a snapshot with
`bash .claude/scripts/git-snapshot.sh 554`; for an ordinary defensive checkpoint before the
Phase 4 wiring (the one phase whose mechanism writes outside this repository), use
`bash .claude/scripts/git-snapshot.sh 554 --no-revert`, which is durable without reverting the
working tree.

Two properties make partial completion safe to leave in place:

- **Phases 1 and 2 are independently useful and independently revertible.** Phase 1 adds a library
  nothing yet consumes; reverting it is deleting two new files. Phase 2's refusal is confined to one
  stage in each of two scripts.
- **Phases 3 and 4 degrade to today's behaviour, not to a new one.** Every new code path drops and
  warns rather than refusing a commit, and every failure mode — an unavailable library, an
  unparseable extensions file, an un-committable second repository — resolves to the in-repository
  verdict, which is the pre-existing path exactly. Reverting the Phase 4 wiring alone leaves
  Phase 3's unambiguous notice in place, which already satisfies acceptance criterion 1's second
  branch on its own.

If the second-repository commit proves unsafe in practice, the sanctioned fallback is to revert only
the Phase 4 wiring call site and keep the notice, the classification, and the authoring refusal —
the configuration that satisfies the acceptance criteria through the notice branch rather than the
commit branch.
