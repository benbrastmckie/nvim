# Implementation Plan: Task #658

- **Task**: 658 - Add a shared gitignored-specs predicate and a distinct, non-failure commit-path
  outcome for an all-ignored pathspec
- **Status**: [IMPLEMENTING]
- **Effort**: 9 hours
- **Dependencies**: None (task 618 shares file territory in `git-commit-scoped.sh`; declared
  not-blocking by the user's ruling, never co-admitted into one batch)
- **Research Inputs**: `specs/658_ignored_specs_predicate_and_commit_path/reports/01_ignored-specs-predicate-research.md`
- **Artifacts**: plans/01_ignored-specs-predicate-commit-path.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`git-commit-scoped.sh` has no ignore-awareness on its positive-pathspec side: a pathspec naming
an untracked, gitignored path is admitted by the V2 classification loop's case-1 existence test,
silently skipped by `git add`, then correctly observed missing from the index by the V7 post-add
verification loop, which refuses the **whole invocation** with exit `2` and a staging-failure
`ERROR`. This plan adds one shared predicate library (`scripts/lib/specs-ignore-lib.sh`, modelled
on `scripts/lib/engine-written-state-paths-lib.sh`'s documented style), a new `V13` classification
gate in `git-commit-scoped.sh` that consults it per pathspec before case 1 can claim the path, and
two new additive non-failure exit codes (`8` all-ignored-nothing-committed, `9`
committed-but-something-dropped-as-ignored). Done when the predicate exists in one place with its
own tests, the script's exit-code contract and header distinguish the new outcome beside the
existing V-codes, `context/standards/git-staging-scope.md` states the per-operation contract for
both postures, and a tracked-specs repository's commit behaviour is demonstrably unchanged.

All edits land in the **source store** (`agent-system/extensions/core/**`), never the deployed
`.claude/**` tree, with a redeploy via `deploy-headless.sh` in the final phase.

### Research Integration

The research report settles all four of the dispatch's open questions and this plan adopts its
findings, with the corrections recorded in Premise Re-Validation below:

- **(b) which path the defect takes** — the **V7 refusal path** (exit `2` at
  `scripts/git-commit-scoped.sh:1040`), not V2 case 3, not V8, not V9, not V10. Confirmed by live
  reproduction in three shapes, the third of which (a mixed pathspec with one ignored and one
  trackable sibling) **aborts the whole invocation**, withholding a legitimate commit. That
  all-or-nothing refusal, not a silent drop, is the actual shape of the defect.
- **(c) granularity** — both: a repository-level question (the GOAL sentence's own wording) and a
  per-pathspec question (the only one that can resolve a partially-ignored tree). Neither subsumes
  the other.
- **(d) tracked-and-ignore-matching** — needs no special handling. `git check-ignore -q` is
  index-aware and reports *not ignored* (rc 1) for an already-tracked path under both a
  parent-directory rule and a direct file-level rule, so the new gate structurally cannot
  misclassify a tracked path, and V7's existing tolerated-advisory carve-out is untouched.
- **(a) where the predicate belongs** — this plan departs from the report; see Decision D7.

Independently re-verified at plan time in a disposable scratch repository (no project file
touched): `git check-ignore -q` returns rc `0` for `specs`, `specs/`, `specs/TODO.md`, and
`specs/001_x/` under a `specs/` root ignore rule, and rc `1` for a non-ignored sibling; and
`git add -- specs/TODO.md outside.txt` against a wholly-ignored `specs/` stages `outside.txt`
(`M  outside.txt`) while skipping the ignored path and returning rc `1` — it does **not** abort
the whole add, confirming the report's Finding 1 observation over the contrary "refuse the WHOLE
add" phrasing in `git-commit-scoped.sh:387-389` (that comment describes the `:(exclude)`-entry
shape, a different case, and is not changed by this plan).

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class line the dispatch extracted was checked against the prior artifact and live
state. Results, including the confirmations:

| Carried figure | Verdict | Measurement |
|---|---|---|
| "95 files reference `git-commit-scoped.sh`" | **Not reproducible as stated; immaterial** | Repo-wide `grep -rl` matches **773** files (including the deployed `.claude/` mirror and `specs/**`); source-store-only matches **98**. Already superseded by the description's own MEASURED SCOPE CORRECTION, which rules it a reference count and never an edit surface. This plan touches 3 production consumers, not 95. |
| "`engine-written-state-paths-lib.sh` has exactly THREE production consumers" | **Confirmed** | `scripts/git-commit-scoped.sh`, `scripts/git-commit-phase.sh`, `scripts/orchestrate-cycle-postflight.sh`. The remaining footprint is `manifest.json`, five test suites, `scripts/tests/suite-classification.data`, and `context/standards/git-staging-scope.md`. |
| "the engine-written state-path set (`specs/TODO.md`, `specs/state.json`)" | **Stale by one member; immaterial** | The lib now returns three members, including `specs/events.jsonl`. The new predicate does not duplicate that list, so the design is unaffected. (Noted separately: `git-commit-scoped.sh:550`'s fail-open fallback still hardcodes only the two-literal pair — a pre-existing inconsistency, out of this task's scope.) |
| "No ignore-awareness exists anywhere in the commit path today: `git check-ignore` appears only in `check-task-references.sh`, `check-record-versioning.sh`, `verify-touched.sh` and in no commit helper or caller" | **FALSE as measured** | Those three named scripts contain **zero** occurrences of `check-ignore`. `git-commit-scoped.sh` — a commit helper — already calls `git check-ignore -q` at line 416, in its conditional ephemeral-`:(exclude)` injection loop, with a documented fall-through direction (only rc 0 skips injection). The gap is real but narrower than stated: it exists on the **positive-pathspec side only**. The in-repo `check-ignore` population is `scripts/check-runtime-file-tracking.sh`, `scripts/verify-deploy.sh`, `scripts/lib/runtime-file-patterns.sh`, `scripts/git-commit-scoped.sh`, two test suites, and two standards documents. |
| "The global root itself tracks 11,572 specs files" | **Drifted; immaterial** | `git ls-files -- specs \| wc -l` now reports **11,586** (+14). The reference case stands. |
| "sf1-engine untracked 389 files while leaving 604 on disk" | **Not verifiable from here** | An external consumer repository, not reachable from this working tree. Accepted as given; nothing in this plan depends on the exact counts. |
| "Task 618 edits `git-commit-scoped.sh` as well" | **Accepted as given, not re-measured** | The user's not-blocking ruling and the never-co-admit constraint are honoured; 618's own starting evidence is to be re-measured after this task lands, per the dispatch. |
| Report claim: "`git-staging-scope.md` currently has no language at all addressing a gitignored `specs/` tree" | **FALSE** | `context/standards/git-staging-scope.md:61-109` is `## Positive-Pathspec Ignore-Advisory Hazard`, which addresses gitignore interaction directly and contains an explicit prohibition: "**`git check-ignore -q` MUST NOT be used to detect this case.**" Phase 5 must *reconcile* with that passage, not contradict it — see Risk R1. |
| Report scope: "Both new codes must be excluded from both of `orchestrate-cycle-postflight.sh`'s case statements" | **Partially wrong** | The demotion gate's `2\|3\|4\|5)` arm already excludes `8`/`9` by construction; only the first `case "$commit_rc"` statement's `*)` catch-all would wrongly frame them as a loud, attributable `ERROR` (it does this to exit `7` today — a pre-existing gap, recorded as a non-goal). Only one case statement needs a new arm. |
| Report omission | **Three surfaces added by this plan** | (1) Existing test case **U5** (`scripts/tests/test-git-commit-scoped.sh:924-943`) asserts exit `2` + `ERROR:.*genuinely unstaged` for exactly the shape V13 reclassifies, and must be amended in the same phase as the gate. (2) A new lib+test pair requires rows in `manifest.json`'s `provides.scripts` and in `scripts/tests/suite-classification.data`, or `check-extension-docs.sh` Rule Q and `lint/lint-unit-integration-boundary.sh` fail. (3) Editing an indexed `context/**` file moves its `index-entries.json` `line_count` (currently `1091` for `git-staging-scope.md`, matching disk). |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; `specs/ROADMAP.md` was not consulted and is not
modified by this plan.

## Goals & Non-Goals

**Goals**:
- One shared predicate library answering, per repository, whether that repository's `specs` tree
  is gitignored — and, per path, whether a given pathspec is gitignored — in one place, consulted
  from one place, never reimplemented at a call site.
- `git-commit-scoped.sh` classifies an untracked, gitignored positive pathspec as its own drop
  reason (`V13`) **before** it can poison the single all-or-nothing `git add` call, with two new
  additive non-failure exit codes (`8`, `9`) and header documentation beside the existing V-codes.
- A partially-ignored tree's trackable sibling paths commit normally instead of being withheld.
- `context/standards/git-staging-scope.md` states the per-operation contract for both postures
  (tracked `specs` and wholly/partly ignored `specs`), reconciled with its existing
  `## Positive-Pathspec Ignore-Advisory Hazard` prohibition rather than contradicting it.
- The fixture pair the dispatch demands (tracked-specs and ignored-specs), each asserting the full
  exit-code contract, with one negative control per rule that bites exactly its own case.

**Non-Goals**:
- Changing **what** any commit site stages. The staging lists (`specs/{padded}_{slug}/`,
  `specs/TODO.md`, `specs/state.json`) are untouched; only the outcome reported for an ignored
  member of such a list changes.
- Any configuration key, environment variable, or global switch. The predicate decides per
  repository at runtime, always.
- Fixing the pre-existing exit-`7` framing gap in `orchestrate-cycle-postflight.sh`'s `*)`
  catch-all, or the pre-existing `6`/`7`-versus-local-`6` collision in `git-commit-phase.sh`'s
  exit-code vocabulary. Both are real, both predate this task, and both are recorded here rather
  than fixed (widening the change surface into shared territory 618 also edits).
- Touching `git-commit-phase.sh`'s post-commit completeness check. The research ruled this site
  out with live evidence: plain `git status --porcelain` (no `--ignored`) returns empty for an
  ignored, untracked path, so the check is already correct for this case.
- Any edit under `.claude/**`. That tree is a disposable deploy artifact; the final phase
  regenerates it.
- Re-measuring task 618's starting evidence (the dispatch assigns that to 618 itself, after this
  task lands).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| R1: `git-staging-scope.md:71` already states "`git check-ignore -q` MUST NOT be used to detect this case". A reader finding a new `V13` gate built on that exact primitive sees a flat contradiction. | H | H | Phase 5 states the scope of each claim explicitly: the existing prohibition is about detecting the **tracked-but-ignore-matching advisory** shape (where `check-ignore -q` disagrees with `git add`), and `V13` asks a **different question** (is this *untracked* path ignored) for which the same index-awareness is precisely what makes the primitive correct. Phase 5's acceptance includes that both passages cross-reference each other. |
| R2: Existing test case U5 asserts the old exit `2` for exactly the shape `V13` reclassifies; landing the gate without amending U5 closes a phase red. | H | H | Phase 2 is a declared `atomic-batch` covering `git-commit-scoped.sh` and U5 together. U5's real invariant (the ignored file is never tracked, no commit is created — "no `-f` behaviour crept in") is **preserved verbatim**; only its exit-code and message-class assertions move to `8` / `NOTE`. |
| R3: Folding `V13` drops into `dropped_pathspecs` would make the all-ignored shape report V6's exit `4` ("refuses to report success as plain nothing to commit") — the same failure-flavoured framing this task exists to remove. | H | M | Decision D1: `V13` feeds a dedicated `ignored_dropped` ledger **only**. Phase 3 includes a negative control asserting the all-ignored shape yields `8`, never `2` and never `4`. |
| R4: A `.gitignore` negation rule (`!specs/042_x/` under an ignored `specs/`) is a plausible consumer shape the research did not reproduce. | M | M | `git check-ignore` resolves negation natively, so `V13` handles it by construction. Phase 3 adds it as an explicit fixture rather than assuming it. |
| R5: A tracked file moved (`git mv`) to a new ignore-matching path in the same commit — a rename/copy-detection edge the research explicitly did not exercise. | M | L | Phase 3 adds a probe for this shape and records the measured outcome. If `V13` fires on the destination half, that is the correct outcome (`git-staging-scope.md:97-103` already states such a caller needs a destination-ignored guard) and the probe documents it; if it does not fire, today's behaviour is unchanged and nothing regresses. |
| R6: `git-commit-scoped.sh` is shared territory with task 618 and with concurrent sibling task 661 (which declares no `file_scope` and may touch any file). | H | M | Re-read every target file immediately before editing; stage and commit only this task's own hunks with explicit file-list staging, never a directory or glob add; never run `git-snapshot.sh` in its reverting default mode; stop and report any foreign commit or uncommitted modification after confirming via `git log` that it is not this task's own work. |
| R7: Exit codes `8`/`9` are new values a third-party caller may not expect. | L | M | Pre-existing posture, not a new hazard: every caller other than `orchestrate-cycle-postflight.sh` already wraps the invocation in `cmd \|\| echo "WARN: ... (non-blocking)"`, which collapses any nonzero exit to a non-blocking warning. Phase 4 gives the one caller that classifies codes an explicit `8\|9)` `NOTE` arm. |
| R8: A new script absent from `manifest.json`'s `provides.scripts` is never deployed, and produces **no authoring-time signal at all**. | H | M | Phase 1 declares `manifest.json` and runs `bash scripts/sync-manifest-scripts.sh --write` in the same phase, then `--check` as its own acceptance. |

## Decisions

- **D1 — `V13` drops feed `ignored_dropped` only, never `dropped_pathspecs`.** `V9` and `V10`
  feed both because V6's exit `4` exists for drops whose *cause* is ambiguous ("indistinguishable
  from the ordinary, benign no-op"). A `V13` drop's cause is definitively known and definitively
  benign, so admitting it to V6's ledger would re-impose exactly the failure-flavoured framing
  this task removes. The exit-8 gate (D2) covers the shape V6 would otherwise have claimed.
- **D2 — the exit-8 gate is placed immediately before the V3 post-filter gate**
  (`scripts/git-commit-scoped.sh:826-832`). In the all-ignored shape, `filtered_pathspecs` ends
  with zero positive entries, so V3 would otherwise refuse with exit `2` and its own
  equally-failure-flavoured wording before any commit is attempted. Exit `8` must therefore be
  decided first, and only when `ignored_dropped` is non-empty **and** no other drop reason
  contributed.
- **D3 — the exit-9 gate is placed after V10's exit `7`** (`scripts/git-commit-scoped.sh:1253`),
  giving the precedence chain `6` (V9) > `7` (V10) > `9` (V13), by the same
  precedence-by-placement convention V9 and V10 already use relative to each other. Exit `9`
  requires `commit_exit` to already be `0`.
- **D4 — `V13` is unconditional, not `--task`-gated** (unlike V10). The question "is this
  on-disk, untracked path ignored" is answerable and worth answering regardless of whether a
  caller supplies `--task`, and the research's reproductions exhibited the defect with no
  `--task` at all.
- **D5 — `V13` is evaluated after V9, V10, and V11 and before case 1's existence test.** After
  the first three so an ignored path that is *also* out-of-repository, out-of-`file_scope`, or
  part of a cached-untracking shape keeps being reported under its existing, already-tested
  message rather than being reclassified. Before case 1 for the same reason V9/V10/V11 are: keep
  a doomed path out of the single all-or-nothing `git add` call entirely, rather than letting it
  fail and then explaining the failure.
- **D6 — the library's predicates are rc-based booleans with no stdout, fail-open to
  "not ignored".** `rc 0` means *definitively ignored*; any other rc (not ignored, or
  indeterminate — a malformed pathspec, a missing repository, `git` itself failing) means *treat
  as not ignored*. This makes the fail-open direction structural rather than a convention a
  caller must remember, and it mirrors the fall-through direction `git-commit-scoped.sh:397-401`
  already documents for its own `check-ignore` call ("ONLY exit code 0 ... skips injection"). It
  departs from `engine_written_state_paths`'s print-and-return-0 shape because that function
  returns a *set*, where this one answers a *question*.
- **D7 — the library exports two functions, and `V13` consults it rather than inlining
  `git check-ignore`.** This departs from the research report, which recommended an inline
  per-pathspec check in V9/V11 house style. Rejected because the task's GOAL sentence states the
  deliverable is "one mechanism consulted from one place, never a per-call-site workaround", and
  the DONE WHEN criterion is "the predicate exists in one place with its own tests" — an inline
  duplicate of the same primitive in the script is a second place. `git-commit-scoped.sh`
  already sources a shared lib with a documented call-site fallback
  (`scripts/git-commit-scoped.sh:534-551`), so the pattern is established rather than new. The
  rejected alternative's merit (no sourcing dependency in the classification loop) is answered by
  D6's structural fail-open: a failed `source` leaves the predicate unavailable, and the call
  site's fallback is to behave exactly as today.
- **D8 — `index-entries.json`, `manifest.json`, and `suite-classification.data` are declared in
  the phases that move them, with reconciliation scheduled per the commit-blocking asymmetry.**
  None of the three checks is commit-blocking in this repository (no `pre-commit` hook is
  installed), so `index-entries.json`'s `line_count` reconciliation may legitimately land in the
  redeploy phase (where `deploy-headless.sh` repairs it as a side effect), while
  `manifest.json`'s and `suite-classification.data`'s rows are reconciled in-phase because they
  gate deployment and the suite lint respectively and are trivially cheap there.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4, 5 | 2 |
| 4 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Shared Predicate Library and Its Own Tests [COMPLETED]

**Goal**: The predicate exists in exactly one place, is registered for deployment and for the
suite lint, and has its own test asserting both polarities plus the partial-ignore case.

**Tasks**:
- [x] Write `agent-system/extensions/core/scripts/lib/specs-ignore-lib.sh`, structured like
  `scripts/lib/engine-written-state-paths-lib.sh`: a contract statement, the fail-open posture
  (D6), an explicit enumeration of its consumers, and a recorded list of rejected candidates.
  Sourced never executed; sets no shell options a caller inherits; never calls `exit`. *(completed)*
- [x] Export `specs_tree_is_gitignored <repo_root>` — `git -C "<repo_root>" check-ignore -q -- specs`,
  rc 0 = ignored, any other rc = not ignored / indeterminate. This answers the GOAL sentence's own
  repository-level question verbatim. *(completed)*
- [x] Export `path_is_gitignored <repo_root> <path>` — `git -C "<repo_root>" check-ignore -q -- "<path>"`,
  same rc contract. Document in the header that this is the function the `V13` gate consults per
  pathspec, and that its index-awareness (a tracked path reports *not ignored*) is the property
  that makes a separate tracked/untracked test unnecessary at the call site. *(completed)*
- [x] Document in the header, explicitly, why this library does **not** duplicate
  `engine-written-state-paths-lib.sh`'s path list and must never acquire one: this library answers
  a question about a repository's ignore configuration, not about which paths the engine writes. *(completed)*
- [x] Write `agent-system/extensions/core/scripts/tests/test-specs-ignore-lib.sh` using this
  corpus's existing scratch-repo harness pattern (`mktemp -d`, per-fixture `git init`), asserting:
  a tracked-`specs` repo -> `specs_tree_is_gitignored` rc 1; a wholly-ignored-`specs` repo -> rc 0;
  a repo ignoring only one task subdirectory -> rc 1 for the whole tree **and** rc 0 for
  `path_is_gitignored` on that subdirectory; a tracked-but-ignore-matching file ->
  `path_is_gitignored` rc 1 (the index-awareness property, asserted directly rather than assumed);
  and the fail-open direction — a nonexistent `repo_root` yields a non-zero rc, never rc 0.
  *(completed: 12 cases, all PASS)*
- [x] Add the row `test-specs-ignore-lib.sh<TAB>unit<TAB>-` to
  `agent-system/extensions/core/scripts/tests/suite-classification.data`, matching
  `test-engine-written-state-paths-lib.sh`'s own row shape. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write` to add both
  new paths to `manifest.json`'s `provides.scripts` array, then re-run with `--check` and confirm
  it reports clean. *(completed: both new paths staged via `git add` so `git ls-files` could see
  them, --write added 2 entries, --check reports CHECK PASSED)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh`, passed this
phase's whole declared `Files to modify` set, covers the edit — it resolves and runs the narrowed
suite pass itself — and the phase adds a new, not-yet-consulted library that changes no existing
behaviour, so no cross-cutting surface is reachable from it.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/specs-ignore-lib.sh` - CREATE: the shared predicate, two rc-based functions
- `agent-system/extensions/core/scripts/tests/test-specs-ignore-lib.sh` - CREATE: both polarities, the partial case, the index-awareness property, the fail-open direction
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - add the new suite's `unit` row (exists, confirmed at authoring time; if the file is absent or its format has changed, stop and report rather than inventing a row)
- `agent-system/extensions/core/manifest.json` - `provides.scripts` gains both new paths, written by `sync-manifest-scripts.sh --write` (exists, confirmed; if `sync-manifest-scripts.sh` is absent, add both entries by hand in the array's existing sorted position and say so)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-specs-ignore-lib.sh` passes every case.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` reports clean.
- `bash agent-system/extensions/core/scripts/lint/lint-unit-integration-boundary.sh` does not
  report the new suite as unclassified.
- The narrowed `verify-touched.sh` pass named in Tier Justification is green.

---

### Phase 2: `V13` Gate, `ignored_dropped` Ledger, Exits `8`/`9`, and the U5 Amendment [COMPLETED]

**Goal**: `git-commit-scoped.sh` classifies an untracked, gitignored positive pathspec as its own
drop reason before `git add` can see it, reports the all-ignored and partial-ignore shapes under
two new non-failure exit codes, documents both beside the existing V-codes, and leaves the one
existing test case that asserts the superseded behaviour correct again in the same commit.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/git-commit-scoped.sh` immediately before
  editing (shared territory: task 618, sibling task 661). *(completed: re-read confirmed no
  foreign edits present)*
- [x] Add an `ignored_dropped=()` ledger declaration beside `out_of_repo_dropped` and
  `containment_dropped` (around line 685-691), with a comment stating D1 explicitly: this ledger
  is **not** mirrored into `dropped_pathspecs`, and why. *(completed)*
- [x] Source `lib/specs-ignore-lib.sh` with the same guarded pattern the script already uses for
  `engine-written-state-paths-lib.sh` (`if source ... 2>/dev/null`), resolving once before the V2
  loop rather than per pathspec, and record whether the predicate is available in a flag the loop
  reads. *(completed: `specs_ignore_lib_available` flag)*
- [x] Insert the `V13` gate in the V2 classification loop immediately after the V11
  `is_cached_untracking_shape` block and immediately before `if [ -e "$p" ] || git ls-files ...`
  (D5). When the predicate is available and `path_is_gitignored "$PROJECT_ROOT" "$p"` returns rc
  0: emit a `NOTE:` (never an `ERROR:`) naming the pathspec and the reason, append to
  `ignored_dropped`, add to **neither** `add_pathspecs` **nor** `filtered_pathspecs`, and
  `continue`. When the predicate is unavailable, fall straight through to case 1 unchanged —
  today's behaviour exactly (D6/D7). *(completed, using `$root_resolved` rather than
  `$PROJECT_ROOT` -- the already-canonicalized variable V9/V10 themselves consult)*
- [x] Add the exit-`8` gate immediately before the V3 post-filter gate (D2): when
  `ignored_dropped` is non-empty, `dropped_pathspecs` is empty, and `filtered_pathspecs` carries
  no positive entry, print a `NOTE:` naming every ignored path and exit `8` — before any
  `git add` or `git commit` is attempted. *(completed)*
- [x] Add the exit-`9` gate after V10's exit `7` (D3): when `ignored_dropped` is non-empty and
  `commit_exit` is `0`, print a `NOTE:` naming every ignored path and exit `9`. *(completed)*
- [x] Extend the script's own header: the `# Exit codes:` list gains `8` and `9` entries in the
  same voice and at the same empirical level of detail as the existing ones (including the
  precedence statement relative to `6` and `7`), and the gate-label list gains a `V13` entry
  after `V12` naming the live-reproduced defect it closes, the placement rule, and the reason
  `git check-ignore -q`'s index-awareness makes a separate tracked/untracked test unnecessary.
  *(completed)*
- [x] Amend test case U5 in `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`
  (around lines 924-943): keep the fixture and the `after == before` / `tracked == ""` assertions
  **verbatim** — they are U5's real invariant ("no `-f` behaviour crept in") — and change only the
  expected rc from `2` to `8` and the expected stderr from `ERROR:.*genuinely unstaged` to the new
  `NOTE:` wording. Update U5's own comment to state what changed and why the invariant is
  unweakened. *(completed: 76/76 cases pass including amended U5)*
- [x] Confirm test case X5 (the ignore-matched file swept up **implicitly** inside a non-ignored
  directory pathspec) still passes **unchanged**: the directory pathspec itself is not ignored, so
  `V13` must not fire, and the inner file must stay silently skipped with exit `0`. *(completed:
  X5 passes unchanged)*
- [x] *(deviation: added, not in original task list)* `test-git-commit-scoped.sh`'s
  `REQUIRED_SCRIPTS` array and its five `chmod +x` exclusion guards needed
  `lib/specs-ignore-lib.sh` added so every scratch-repo fixture actually copies and sources the
  new library; without it the guarded `source` in `git-commit-scoped.sh` would silently fail
  inside every fixture and `V13` would never fire in-suite, leaving U5 at its pre-change rc
  regardless of the production edit. *(completed: added to the array plus all 5 guard sites)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: U5 is the **only** existing test case in the corpus whose assertions this
gate invalidates, and `git-commit-scoped.sh` plus `test-git-commit-scoped.sh` are the only two
files this phase edits. Confirm at implementation time by grepping the whole
`agent-system/extensions/core/scripts/tests/` tree for `genuinely unstaged` and for `ignore`-
related fixture builders before editing, and by running the full
`test-git-commit-scoped.sh` and `test-git-commit-phase.sh` suites after; if a second case also
goes red, amend it under the same atomic batch and record the deviation rather than deferring it.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh`, passed this
phase's declared `Files to modify` set, covers the edit and its direct dependents; the change
alters an exit-code contract whose readers span multiple files — exactly the `interface` row — and
those two reader files are updated under Phase 4 rather than here.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - `ignored_dropped` ledger, guarded lib source, the `V13` gate in the V2 loop, the exit-`8` gate before V3's, the exit-`9` gate after V10's, and the header's exit-code and gate-label lists
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - amend U5's rc and message assertions only, preserving its no-`-f` invariant verbatim (exists, confirmed at authoring time at lines 924-943; if U5 has already been renumbered or removed, locate the case asserting `ERROR:.*genuinely unstaged` for an untracked ignore-matched pathspec and amend that one instead, recording the discrepancy)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` passes in full,
  including the amended U5 and the unchanged X5, U1, U2, U3, U4, and U6.
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` passes unchanged.
- `bash -n agent-system/extensions/core/scripts/git-commit-scoped.sh` and
  `shellcheck` report no new findings.
- The narrowed `verify-touched.sh` pass named in Tier Justification is green.

---

### Phase 3: The Fixture Pair and One Negative Control Per Rule [COMPLETED]

**Goal**: Both postures are tested on both sides, each new control bites exactly the case it
targets and nowhere else, and no control can confuse the new outcome with today's exit `2` or
exit `4`.

**Tasks**:
- [x] Add a `build_repo_specs_ignored` fixture builder to
  `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`, in the house style of
  the existing `build_repo` / `build_repo_tracked_ignored` / `build_repo_with_scope` builders: a
  scratch repo whose `specs/` tree is tracked at first, then added to the root `.gitignore` and
  untracked via `git rm -r --cached`, leaving content on disk. *(completed)*
- [x] Add a `build_repo_specs_partially_ignored` builder: `specs/` tracked, with exactly one task
  subdirectory ignored by a specific rule while `specs/TODO.md` and `specs/state.json` stay
  tracked and freshly modified. *(completed; a missing `mkdir -p "$repo/specs"` initially broke
  this builder's own `git commit` -- fixed, see progress file)*
- [x] *(deviation: renamed Y1-Y6 -> AA1-AA7)* **Control Y1 (tracked-specs negative control, the
  backward-compatibility bar)**: no new assertion — confirm the existing baseline cases built on
  `build_repo covered` still pass byte-for-byte. State explicitly in the case comment that this
  control's whole purpose is that it required **no** change. *(completed as AA1 -- this suite
  already has pre-existing Y1-Y6 (V11 cached-untracking) and Z1-Z18 (V10 containment) case
  series, so every new control in this phase is named AA1-AA7 instead, to avoid colliding with
  and shadowing those existing case names)*
- [x] **Control Y2 (all-ignored -> exit `8`)**: against `build_repo_specs_ignored`, a realistic
  multi-path pathspec (`specs/TODO.md specs/state.json specs/{NNN}_x/`) asserts rc `8`, no new
  commit, no path tracked afterwards, a `NOTE:` naming every ignored path, and — the
  discriminating half — that the output carries **neither** `ERROR:.*genuinely unstaged` (today's
  exit `2`) **nor** `Verified Finding V3` **nor** `Verified Finding V6`, and that rc is neither
  `2` nor `4`. *(completed as AA2)*
- [x] **Control Y3 (partial-ignore -> exit `9`, with the sibling actually landing)**: against
  `build_repo_specs_partially_ignored`, a mixed pathspec asserts rc `9` **and** that the
  trackable sibling is present in `HEAD` via `git show --name-only --format="" HEAD` (this
  suite's house style — never exit code alone), **and** that the ignored entry is absent from that
  same output. This is the control for the defect's most harmful shape. *(completed as AA3)*
- [x] **Control Y4 (tracked-and-ignore-matching: `V13` must NOT fire)**: reuse
  `build_repo_tracked_ignored` and assert the invocation still exits `0`, the file still lands,
  the existing V7 tolerated-advisory `NOTE` still appears, and no `V13` `NOTE` appears. This is
  the negative control for Decision D7's index-awareness premise. *(completed as AA4)*
- [x] **Control Y5 (negation rule)**: a repo with `specs/` ignored and one task directory
  re-included via `!specs/{NNN}_x/`, asserting that the re-included directory commits normally
  (rc `0` or `9` depending on whether a sibling was also dropped) and is present in `HEAD` —
  Risk R4. *(completed as AA5, measured outcome: rc 9, batched with a brand-new,
  genuinely-still-ignored top-level sibling to isolate the negation question)*
- [x] **Probe Y6 (rename into an ignore-matched destination, Risk R5)**: `git mv` a tracked file
  to an ignored destination, commit both halves as a pathspec pair, and record the measured
  outcome in the case comment. Assert whichever behaviour is measured, stating in the comment
  that this dimension was previously unexercised and that either outcome is acceptable so long as
  no tracked content is silently lost. *(completed as AA6, measured outcome: rc 0, `V13` does not
  fire because `git mv` already stages the destination as tracked, index-awareness)*
- [x] **Control-of-the-controls probe**: in the house style of this suite's existing
  "negative-control probe (not a suite case)" blocks, deliberately neutralise the `V13` gate
  (a locally-patched copy) and confirm Y2 and Y3 both FAIL — a control that cannot distinguish
  the new outcome from today's exit `2` has not been written. *(completed as AA7: with the gate
  neutralised, AA2/AA3's identical scenarios no longer produce exit 8/9)*

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh`, passed this
phase's single declared file, covers the edit; the phase adds test cases and fixture builders only
and changes no production code, so nothing outside that file's own coverage is reachable.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - two new fixture builders and controls Y1-Y6 plus the control-of-the-controls probe

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` passes in full.
- Each of Y2 and Y3 fails when the `V13` gate is neutralised (the control-of-the-controls probe
  is the evidence; record its output).
- Y1 and Y4 pass with no change to the production script beyond Phase 2's.
- The narrowed `verify-touched.sh` pass named in Tier Justification is green.

---

### Phase 4: Consumer Exit-Code Handling [COMPLETED]

**Goal**: The one caller that classifies `git-commit-scoped.sh`'s exit codes treats `8` and `9` as
non-failure observability rather than as a loud orchestration defect, and the one caller that
passes them through documents that it does.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` immediately
  before editing. *(completed)*
- [x] Add an explicit `8|9)` arm to the WORK (i) `case "$commit_rc"` statement (around line 2118),
  placed after the `2|3|4|5|6)` arm and before the `*)` catch-all, emitting a `NOTE:`-level
  message (never `ERROR:`) stating that the target repository's `specs` tree is wholly or partly
  gitignored, that this is the repository's own configuration and not an orchestration defect, and
  — for `9` — that the commit itself landed. Leave `commit_attribution_note` empty on this arm so
  the emitted verdict JSON carries no failure attribution. *(completed)*
- [x] Do **not** record an `issue-record.sh` entry on the new arm: these are not issues.
  *(completed -- no such call added)*
- [x] Leave the demotion gate's `2|3|4|5)` arm (around line 2157) **unchanged** — it already
  excludes `8` and `9` by construction. Extend only its explanatory comment block (which today
  enumerates exit `1`, exit `6`, and the unrecognized-code catch-all as the deliberate
  exclusions) to name `8` and `9` as two further deliberate exclusions, with the reason: a task
  whose only "failure" is that its target repository ignores `specs/` must never be demoted to
  `partial`. *(completed; the arm's own `2|3|4|5)` / `*) : ;;` code is byte-identical, only the
  comment and the catch-all's inline note were extended)*
- [x] Update `agent-system/extensions/core/scripts/git-commit-phase.sh`'s `EXIT-CODE MAPPING`
  header block (around line 180-195) to state that inner codes `8` and `9` also pass through
  verbatim, and that they do not collide with this script's own locally-reserved `6` because they
  land outside the `0-6` range it reserves. Record, without fixing it, that inner codes `6` and
  `7` **do** collide with that local `6` — a pre-existing ambiguity outside this task's scope
  (non-goal) and a hazard a reader of this header should know about. *(completed)*
- [x] Make no change to `git-commit-phase.sh`'s post-commit completeness check: the research
  ruled that site out with live evidence. *(completed -- no change made)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh`, passed this
phase's declared `Files to modify` set, covers the edit; the postflight change adds one new case
arm whose predicate is disjoint from every existing arm, and the phase-commit change is
comment-only, so no behaviour outside those two files' own coverage changes.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - new `8|9)` `NOTE` arm in the WORK (i) `case "$commit_rc"`; demotion-gate rationale comment extended (the arm itself unchanged)
- `agent-system/extensions/core/scripts/git-commit-phase.sh` - `EXIT-CODE MAPPING` header note for the passthrough of `8`/`9`, plus the recorded `6`/`7` collision caveat

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` passes.
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` passes.
- `bash -n` on both edited scripts is clean, and `shellcheck` reports no new findings.
- Reading the demotion gate confirms `8` and `9` reach its `*) : ;;` no-demotion arm.
- The narrowed `verify-touched.sh` pass named in Tier Justification is green.

---

### Phase 5: `git-staging-scope.md` — Per-Operation Contract for Both Postures [COMPLETED]

**Goal**: The standards document states the contract for a tracked-`specs` repository and for a
wholly- or partly-ignored one, documents `8`/`9` and `V13` beside the existing codes and gate
labels, and reconciles the new gate's use of `git check-ignore -q` with the existing prohibition
instead of contradicting it.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/standards/git-staging-scope.md` immediately
  before editing. *(completed)*
- [x] Add rows for exit `8` and exit `9` to the `### Exit-Code Contract and Safety Gates` table
  (currently at line 809), in the same voice as the existing rows, each stating the precedence
  relationship to `6` and `7` and that both are observability rather than refusals. *(completed)*
- [x] Add a `- **V13** —` gate label after the existing `V10` entry, in the same voice: the
  live-reproduced defect (an untracked, gitignored positive pathspec reaching case 1 and refusing
  the whole invocation under V7's exit `2`), the placement rule, the dedicated `ignored_dropped`
  ledger and why it is **not** mirrored into `dropped_pathspecs` (D1), and a cross-reference to
  the new library. *(completed)*
- [x] Update the subsection's own introductory sentence, which today lists the documented gate
  labels as "(V2, V3, V5, V6, V8, V9)" while the table and label list already carry V10 — bring
  that enumeration current, including V13. *(completed)*
- [x] Amend `## Positive-Pathspec Ignore-Advisory Hazard` (line 61) to scope its existing
  prohibition explicitly (Risk R1): "`git check-ignore -q` MUST NOT be used to detect **this**
  case" — the tracked-but-ignore-matching advisory shape, where the primitive disagrees with
  `git add` — and add a forward pointer stating that the **untracked**-and-ignored question is a
  different question, that the same index-awareness is exactly what makes `check-ignore -q` the
  correct primitive for it, and that `V13` answers it through the shared library. Add the matching
  back-reference from the new `V13` label. *(completed; also measured and documented the real
  plain-mv call-site pattern's outcome in the Tracked-vs-moved-distinction paragraph -- see
  progress file)*
- [x] Add a new subsection, a sibling of `## Per-Operation Scope`, stating for each of
  `research` / `plan` / `implement`: a tracked-`specs` repository commits exactly as it does
  today, unchanged; a repository whose `specs` tree is wholly or partly gitignored sees the
  relevant paths dropped under `V13` with a non-failure outcome; and **what gets staged does not
  change** in either posture — the staging lists are identical, only the outcome reported for an
  ignored member of such a list differs. *(completed: "## Per-Operation Contract: Tracked vs.
  Gitignored specs")*
- [x] Add no task-number references and no record-versioning language anywhere in the file
  (`rules/no-task-references-in-deliverables.md`,
  `rules/no-record-versioning-in-deliverables.md`): state the current contract only, never that it
  "previously" said something else. *(completed: check-task-references.sh 0 occurrences;
  check-record-versioning.sh 0 BLOCKING, 9 ADVISORY -- identical to this file's own pre-edit
  baseline, 0 new)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
covers this source-store markdown edit (doc-lint and task-reference lint, run with the
source-store repository's own root as `TARGET` — simultaneously a deployed tree and a source
store, so neither gate silently SKIPs), together with the `prose` row's diff read-through.

**Scope Hypothesis**: this phase's prose edits move
`context/standards/git-staging-scope.md`'s line count off `index-entries.json`'s recorded
`line_count: 1091`, and `index-entries.json` is the only generated surface this phase's edits
disturb. Confirm at implementation time with
`bash agent-system/extensions/core/scripts/check-extension-docs.sh` (Rule R) after the edit; the
reconciliation is scheduled in Phase 6 because no commit-blocking check reads it in this
repository (D8).

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - exit-`8`/`9` table rows, the `V13` gate label, the corrected gate-label enumeration, the scoped-prohibition amendment plus cross-references, and the new both-postures per-operation subsection
- `agent-system/extensions/core/index-entries.json` - the `line_count` entry for `standards/git-staging-scope.md` moves off `1091`; declared here because this phase moves it, reconciled in Phase 6 (D8)

**Verification**:
- Diff read-through confirms every changed hunk is prose, and that the amended prohibition and the
  new `V13` label cross-reference each other. *(confirmed: 113 insertions/20 deletions, entirely
  prose)*
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports both gates running (never SKIP) and passing. *(measured: gate 4 (task-reference lint)
  PASSES; gate 3 (doc-lint) runs (never SKIP) but FAILS -- its only two finding classes are
  exactly the two the plan already anticipates and defers: (a) "deployed script content drift"
  for this task's own not-yet-redeployed source-store files (the general pre-redeploy state
  Phase 6's redeploy resolves), and (b) Rule R's `git-staging-scope.md` line_count mismatch
  (1091 declared vs. 1184 actual) -- precisely this phase's own declared Scope Hypothesis,
  whose reconciliation D8 explicitly schedules in Phase 6, not here. No other finding class
  appeared. Re-running this same gate-3/4 invocation after Phase 6's redeploy and reconciliation
  is expected to clear it.*
- `bash .claude/scripts/check-task-references.sh` and
  `bash .claude/scripts/check-record-versioning.sh` report no new findings for the edited file.
  *(confirmed: 0 task-reference occurrences; 0 BLOCKING / 9 ADVISORY record-versioning findings,
  identical to this file's own pre-edit baseline)*

---

### Phase 6: Redeploy, Reconcile Derived Surfaces, and Close [COMPLETED]

**Goal**: The source-store change is deployed, every derived surface this plan moved is
reconciled, and the complete gate set is discharged at the orchestration close.

**Tasks**:
- [x] Confirm every prior phase's work is committed and the working tree holds no partial edit of
  this task's own files. *(completed; only this task's own files plus pre-existing,
  unrelated-to-this-task dirty files (.claude-extensions.json, specs/central-errors.jsonl,
  specs/events.jsonl, .pid, a sibling task's .plan-revised.json) were present)*
- [x] Reconcile `index-entries.json`'s `line_count` for the edited standards file, either via
  `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` if that
  script is present, or as a side effect of the redeploy below; confirm afterwards that
  `bash .claude/scripts/check-extension-docs.sh` Rule R reports no drift. *(completed as a side
  effect of the redeploy below -- the script itself refuses to run from the source-store scripts/
  directory, so it must be invoked from the deployed tree, which the redeploy already produced
  with line_count 1184 correct; the deployed copy's own --write confirmed 0 changed, and
  check-extension-docs.sh now reports "core PASS" / "all extensions OK" with zero FAIL lines)*
- [x] Redeploy the whole tree: `timeout 540 bash .claude/scripts/deploy-headless.sh` (Bash tool
  `timeout` parameter raised to 600000, per `context/patterns/external-process-wait.md` Rule 1).
  This also clears the pre-existing per-extension staleness the dispatch reported for core, email,
  lean, nix, nvim, and sapience. *(completed: RESULT=landed_verify_red -- the deploy itself
  landed; post-deploy verify-deploy.sh found exactly 1 pre-existing, unrelated violation (Gate 27,
  scripts/tests/run-all.sh's own long-standing subject-resolution-declaration gap, confirmed via
  git log/git status to predate this dispatch and untouched by it); logged non-blocking)*
- [x] Confirm the deployed copies exist and match: `.claude/scripts/lib/specs-ignore-lib.sh`,
  `.claude/scripts/tests/test-specs-ignore-lib.sh`, and the updated
  `.claude/context/standards/git-staging-scope.md`. *(completed: all 7 of this task's edited/new
  files diff byte-identical between source store and deployed tree)*
- [x] Run the scoped touched-path check over every file this task touched:
  `bash .claude/scripts/verify-touched.sh` with no arguments (it derives the touched set itself
  from the working tree plus the committed diff against its own determined base). *(completed:
  51 passed, 1 failed (1 EXPECTED, 0 NEW) -- the one expected failure is
  test-verify-deploy-context-budget.sh, whose sole remaining finding is the same pre-existing
  Gate 27 run-all.sh violation named above; the gate3/gate5 drift findings present before this
  phase's redeploy are gone)*
- [x] Re-run `bash .claude/scripts/tests/test-git-commit-scoped.sh`,
  `bash .claude/scripts/tests/test-git-commit-phase.sh`,
  `bash .claude/scripts/tests/test-orchestrate-cycle-postflight.sh`, and
  `bash .claude/scripts/tests/test-specs-ignore-lib.sh` against the **deployed** tree, where
  gate 8 actually discovers suites. *(completed: 83/83, 84/84, 321/321, 12/12 -- all green)*
- [x] Defer the complete gate set to the orchestration close
  (`context/contracts/batch-gate-stage.md`'s once-per-invocation batch gate stage) rather than
  invoking the full battery independently in this dispatch. *(completed -- no independent full
  battery invoked in this dispatch)*
- [x] Record the final state of each DONE WHEN criterion in the implementation summary.
  *(completed -- see summary)*

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: the redeploy regenerates the entire deployed `.claude/**` tree, which is an
implicit scope claim over that whole tree and is declared below via the reserved
`__WHOLE_TREE__` sentinel rather than by naming a wide real path. Confirm at implementation time
that no `.claude/**` path is named directly in any phase's declared scope.

**Files to modify**:
- `__WHOLE_TREE__` - the redeploy regenerates the entire deployed tree (reserved sentinel, deliberately slashless and inert against every real path)
- `agent-system/extensions/core/index-entries.json` - the deferred `line_count` reconciliation for the edited standards file (D8)

**Verification**:
- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes successfully and reports no
  remaining per-extension staleness.
- `bash .claude/scripts/verify-touched.sh` (no arguments) is green over this task's touched set.
- All four named suites pass against the deployed tree.
- The complete gate set is explicitly deferred to the orchestration close; this phase's own
  in-dispatch obligation is the scoped touched-path check above, not an independent full-battery
  invocation.

## Testing & Validation

- [ ] `test-specs-ignore-lib.sh`: both polarities, the partial-ignore case, the index-awareness
  property for a tracked-but-ignore-matching path, and the fail-open direction.
- [ ] `test-git-commit-scoped.sh`: the amended U5; the unchanged X5, U1, U2, U3, U4, U6; and the
  new Y1-Y6 controls plus the control-of-the-controls probe.
- [ ] `test-git-commit-phase.sh` and `test-orchestrate-cycle-postflight.sh` pass unchanged.
- [ ] `sync-manifest-scripts.sh --check` and `lint-unit-integration-boundary.sh` are clean for the
  new suite.
- [ ] `verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>` passes for the standards-doc edit.
- [ ] A tracked-specs fixture repository's commit behaviour is unchanged — asserted by Y1 and by
  the existing baseline cases requiring no amendment.
- [ ] An all-ignored invocation is distinguishable from today's exit `2` and from exit `4`, both
  by rc and by message class — asserted by Y2.
- [ ] A partial-ignore invocation commits its trackable sibling, verified in `HEAD` rather than by
  rc alone — asserted by Y3.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/specs-ignore-lib.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-specs-ignore-lib.sh` (new)
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` (V13 gate, two new exit codes, header)
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` (U5 amendment, Y1-Y6)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (`8|9)` arm)
- `agent-system/extensions/core/scripts/git-commit-phase.sh` (header note)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` (contract for both postures)
- `agent-system/extensions/core/manifest.json`, `scripts/tests/suite-classification.data`,
  `index-entries.json` (registration and derived-surface reconciliation)
- A regenerated `.claude/**` deployed tree
- `specs/658_ignored_specs_predicate_and_commit_path/summaries/01_*-summary.md`

## Rollback/Contingency

Each phase commits independently, so a single phase can be reverted with
`git revert <sha>` without disturbing the others. The change is additive by construction: the
`V13` gate is skipped entirely whenever the library fails to source (D6/D7), and both new exit
codes are values no current caller distinguishes today, so reverting Phase 4 alone leaves Phase 2
behaviourally safe (the new codes collapse to non-blocking warnings at every other call site).

If a mid-phase rollback of uncommitted work becomes necessary, follow
`context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
shape, including its out-of-scope override flag — never a bare precautionary
`git-snapshot.sh {N}`. For an ordinary defensive checkpoint before the Phase 2 atomic batch, use
`bash .claude/scripts/git-snapshot.sh 658 --no-revert`, which is durable without reverting the
working tree.

The redeploy in Phase 6 is re-runnable and idempotent; a failed deploy is remedied by re-running
it, never by hand-patching any file under `.claude/**`.
