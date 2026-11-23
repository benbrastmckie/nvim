# Implementation Plan: Task #484

- **Task**: 484 - Collapse per-path scope-excursion issue rows into one record per drop event
- **Status**: [IMPLEMENTING]
- **Effort**: 3.75 hours
- **Dependencies**: Serialize behind #430, #446, #469 (file_scope overlap on git-commit-phase.sh,
  git-commit-scoped.sh and their suites — see the dispatch's Serialization Note and Risks below)
- **Research Inputs**: specs/484_collapse_perpath_scope_excursion_issue_rows_into_o/reports/01_collapse-scope-excursion-rows.md
- **Artifacts**: plans/01_collapse-scope-excursion-rows.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

One drop event at either Containment emitter currently writes one `issues.jsonl` row per dropped
path, so a phase that legitimately touches twenty migrated suites produces twenty near-identical
`scope excursion` rows. The fix is write-side and emitter-local: each per-path loop accumulates
its drops and fires exactly one non-fatal `issue-record.sh` call afterwards, carrying the full
dropped-path set through the already-documented-but-unused `--tags-json` seam
(`tags.dropped_paths` plus `tags.occurrence.count/first_seen/last_seen`). The JSON-construction
and call-firing step lives in one new small shared library sourced by both emitters, reusing the
`lib/engine-written-state-paths-lib.sh` / `lib/derived-artifact-probe-lib.sh` sharing precedent
these same two scripts already follow, so the new call shape exists at exactly one site. Neither
`issue-record.sh` nor `orchestrate-conclusion-aggregate.sh` changes at all: `tags` is validated
only as `type == "object"`, and the aggregate groups by JSONL line, so writing fewer, richer
lines fixes the aggregate-dominance symptom with no read-side edit and no corpus migration.

### Premise Re-Validation

The dispatch's Premise Re-Validation section flagged two description lines. Both were checked
against the research report and against live state during this planning dispatch:

- **"SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/\*\*"** — CONFIRMED, unchanged.
  `.claude-extensions.json`'s `.extensions.core.source_dir` resolves to
  `/home/benjamin/.config/nvim/agent-system/extensions/core`, and both emitters are present there.
- **"severity stays `minor`, posture stays drop-and-warn, never refuse"** — CONFIRMED, unchanged.
  Both call sites pass `--severity minor` today; `git-commit-phase.sh` calls `warn()` and keeps
  iterating, `git-commit-scoped.sh` echoes `WARN:` and `continue`s. Nothing in this plan alters
  either literal or either posture.

Two further description figures were re-derived rather than carried, as the description itself
instructed ("re-derive before editing; line numbers move"):

- The description's "around line 286" / "around line 655" citations are **stale**. The live
  `--class "scope excursion"` emission sites are `scripts/git-commit-phase.sh:779` and
  `scripts/git-commit-scoped.sh:888`, matching the research report's own figures. The structural
  claim the citations carried (one `issue-record.sh` call per dropped path, from inside a
  per-path loop, at exactly two sites) is confirmed intact at the new line numbers.
- The existing local corpus is **8** `scope excursion` rows across **6** task directories —
  re-measured this dispatch, identical to the research report's figure. The description's 123/122
  figures describe a different session's aggregate and are not re-verifiable from this repository;
  nothing in this plan depends on them.

### Research Integration

The plan adopts the research report's three decisions verbatim: full `tags.dropped_paths` array
(never a bounded sample, which would violate the no-suppression requirement, since the per-path
`warn()` lines reach only stderr and no queryable artifact); emitter-side collapse rather than an
`issue-record.sh` CLI change or a read-time-only grouping scheme; and `--severity minor` /
drop-and-warn preserved unchanged inside the new batched call. The report's correction of the
dispatch's Verification section is also adopted: `issue-grouping.sh` is the `/review` command's
own triage pipeline on a structurally different schema and is not a consumer of `issues.jsonl` —
the read-time consumer to verify against is `orchestrate-conclusion-aggregate.sh`'s `group_by`
pipeline.

Two research findings are deliberately NOT acted on here. `git-commit-phase.sh`'s
`source store excursion` block has the identical per-path fan-out shape under a different class
name; the task's required outcomes are worded entirely around the `scope excursion` class, so
that block is left untouched and recorded as a follow-up candidate. And the `manifest.json`
excursion observation in the dispatch's non-goals belongs to #469's evidence, not to this task.

### Decisions

- **Representation**: a full `tags.dropped_paths` array plus `tags.occurrence.{count, first_seen,
  last_seen}`, not a bounded sample. A sample would violate the no-suppression posture, because no
  other durable store of the dropped-path set exists — the per-path `warn()` output reaches stderr
  and the dispatch transcript only.
- **Collapse site**: the two emitters, through one shared library function. An `issue-record.sh`
  CLI change is unnecessary (`--tags-json` already carries everything, and `tags` is validated
  only as an object), and a read-time-only scheme cannot recover which rows belong to one drop
  event without a write-side marker — the architectural reason `issue-log.md` frames Occurrence
  Collapse as a write-side convention. The library answers the dispatch's own concern about
  duplicating a new call shape at two sites: the shape exists once.
- **Third-site asymmetry**: the `git-staging-scope.md` sentence asserting that every Containment
  site fires an issue row is corrected to match the code, rather than giving the postflight site
  its own `issue-record.sh` call. Adding a third emitter would expand this task into postflight
  territory that its required outcomes do not ask for and that overlaps the open calibration
  tasks; it remains available as a separately-scoped follow-up, and the corrected sentence leaves
  a future reader no contradiction to rediscover.
- **Severity and posture**: `--severity minor` and drop-and-warn are preserved byte-for-byte.
  This task changes how a drop is recorded, never whether one happens or what is dropped.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context and no roadmap flag was set,
so no roadmap consultation applies to this plan.

## Goals & Non-Goals

**Goals**:
- One `issue-record.sh` call per drop event at each of the two `scope excursion` emitters, with
  every dropped path recoverable from the single record's `tags.dropped_paths`.
- The new call-construction logic exists at exactly one site (a shared library), not duplicated
  across the two emitters.
- Regression coverage at both emitters asserting a multi-path drop writes exactly one row naming
  every dropped path, plus a repo-wide guard that no other site emits the class per path.
- The existing `issues.jsonl` corpus stays parseable and groupable with no backfill.
- The doc-vs-code asymmetry the research surfaced in `git-staging-scope.md` is explicitly
  dispositioned rather than left for a future reader to rediscover.

**Non-Goals**:
- Any change to the Containment predicate, to what gets dropped, or to the drop-and-warn posture.
- Any change to `issue-record.sh`'s CLI, schema, or validation.
- Any change to `orchestrate-conclusion-aggregate.sh`'s grouping pipeline.
- `file_scope` calibration or infrastructure-path allowlisting (#430, #446, #469).
- Class-vocabulary normalization (#477).
- The sibling `source store excursion` per-path fan-out in the same script.
- Adding an `issue-record.sh` call to the third (postflight) Containment site.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent edits from #430/#446/#469 on the same two scripts and suites | H | H | Serialize this task behind all three, per the dispatch's own Serialization Note; landing their calibration fixes first also shrinks the drop volume this change is measured against |
| Existing substring assertions in both suites break when a path moves from `what_happened` into `tags` | M | L | Both assert `grep -q "<path>" issues.jsonl` against the whole line; the path string still appears on the same line. Phase 2/3 run each suite unmodified before adding new cases, so a break surfaces as a specific failing case rather than a silent change |
| `jq` unavailable in a scratch test repo, losing the dropped-path set | M | L | Library falls back to a single call whose `what_happened` lists every path inline — fewer rows, never fewer paths |
| Moving the call out of the loop changes when it fires relative to a commit failure | L | L | Both post-loop emission points sit before any `git add`/`git commit` attempt, exactly as the in-loop calls did; Phase 2/3 verification asserts the record exists on a drop that is followed by a failed commit |
| A new library file left unregistered in `provides.scripts` is silently dropped from the deploy | M | M | Phase 1 registers it with `sync-manifest-scripts.sh --write` (derives the array from disk) and Phase 5 re-deploys and verifies the file is present in the deployed tree |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Shared batched-record library and its suite [COMPLETED]

**Goal**: One library function that builds the collapsed `--tags-json` payload and fires a single
non-fatal `issue-record.sh` call for a whole drop event, with direct unit coverage, registered in
the extension manifest. No emitter is converted in this phase.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lib/scope-excursion-record-lib.sh`, following *(completed)*
      the sibling libraries' sourced-never-executed conventions: sets no shell options, never
      calls `exit`, always returns 0, internal names prefixed and unset before return, one public
      function as the contract.
- [x] Give the public function a signature carrying what the two call sites differ on and nothing *(completed)*
      else: the directory holding `issue-record.sh` (resolved by the caller from its own
      `SCRIPT_DIR`, as the sibling libraries' callers already do), the task number, the
      caller-built `what_happened` sentence, the first-drop and last-drop ISO 8601 UTC timestamps,
      any extra pass-through arguments (`--phase implement` at one site, none at the other), and
      the dropped-path array.
- [x] Hardcode `--kind issue --class "scope excursion" --severity minor` inside the function so *(completed)*
      the class literal has exactly one non-test home in the scripts tree — this is what makes
      Phase 4's repo-wide guard a one-line assertion rather than a parser.
- [x] Build the tags payload with `jq` as *(completed)*
      `{"dropped_paths": [<every path, in drop order>], "occurrence": {"count": N, "first_seen": ..., "last_seen": ...}}`,
      where `count` mirrors the array length, and pass it through the existing `--tags-json` flag.
- [x] Preserve both existing tolerances: return 0 immediately when `issue-record.sh` is absent *(completed)*
      (the scratch repos in both suites have no such script), and swallow a non-zero result so a
      recording failure can never fail a commit.
- [x] Implement the `jq`-absent fallback: fire the same single call without `--tags-json`, with *(completed)*
      every dropped path listed inline in `what_happened`. Collapsing rows must never suppress
      paths.
- [x] Create `agent-system/extensions/core/scripts/tests/test-scope-excursion-record-lib.sh` *(completed)*
      following this directory's house convention (`common_test_pass`/`_fail`/`_info` from
      `lib/common.sh`, PASSED/FAILED counters, `mktemp -d` workdir with a `trap EXIT` cleanup,
      loud-skip discipline, verdict-line assertions) and `common_test_resolve_subject` for
      source-store/deployed subject resolution.
- [x] Cover in that suite: a 3-path call writes exactly one line; `tags.dropped_paths` holds all *(completed)*
      three in order; `tags.occurrence.count` equals 3; `class`/`severity`/`kind` are the expected
      literals; a 1-path call is well-formed too; an absent `issue-record.sh` is a silent no-op
      returning 0; the `jq`-absent fallback still names every path.
- [x] Register both new files by running *(completed)*
      `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check`, then
      `--write`, and confirm the resulting `manifest.json` diff contains only the two new
      `provides.scripts` entries.
- [x] Keep every new file free of task-number references and of record-versioning language (both *(completed)*
      rules apply under `agent-system/**`); describe the library on its own merits, never relative
      to the per-path shape it replaces.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: full

**Tier Justification**: this phase edits the extension's `provides.scripts` deploy registry —
global deploy configuration that every deploy-parity, orphan, and gate-registry assertion reads
across the whole tree rather than one module's own surface — and no narrower suite subset covers
that registry's parity claims.

**Scope Hypothesis**: `provides.scripts` is derived from disk rather than curated, so
`sync-manifest-scripts.sh --write` is safe to run over the whole manifest. Confirm by running
`--check` first and checking that the reported delta is exactly the two new files — if it reports
anything else, hand-add the two entries instead and record why.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/scope-excursion-record-lib.sh` - new; the one public
  batched-record function
- `agent-system/extensions/core/scripts/tests/test-scope-excursion-record-lib.sh` - new; unit
  coverage for the record shape and both tolerances
- `agent-system/extensions/core/manifest.json` - `provides.scripts` entries for the two new files

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-scope-excursion-record-lib.sh` exits 0
  with every case PASS.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` reports no
  remaining drift.
- Under `/orchestrate`, this phase's own in-dispatch obligation is the scoped touched-path check
  `bash agent-system/extensions/core/scripts/verify-touched.sh` over its three declared paths; the
  complete gate set is deferred to the orchestration close, not invoked independently here. Under
  a standalone run with no such close, `bash .claude/scripts/verify-deploy.sh` runs directly.

---

### Phase 2: Convert git-commit-phase.sh to one record per drop event [COMPLETED]

**Goal**: The Phase-Commit Containment Self-Check accumulates its drops and emits a single
collapsed record after its loop, with the per-path `warn()` and
`propose_file_scope_addition()` calls left exactly as they are.

**Tasks**:
- [x] Re-derive the emission site before editing (`grep -n -- '--class "scope excursion"'`); the *(completed)*
      live site is inside the `else` branch of `for f in "${files_touched[@]}"`.
- [x] Source the new library beside the existing guarded `source … 2>/dev/null || true` lines this *(completed)*
      script already uses for its sibling libraries, with the same fail-soft posture.
- [x] Introduce a drop-only accumulator array (the script today keeps only `kept_files_touched`, *(completed)*
      the complement) and append each dropped path to it in the same `else` branch.
- [x] Capture the first-drop timestamp on the first append and the last-drop timestamp after the *(completed)*
      loop, so `tags.occurrence.first_seen`/`last_seen` are measured rather than invented.
- [x] Remove the in-loop `issue-record.sh` call and fire one library call after the loop, guarded *(completed)*
      on a non-empty accumulator, before `files_touched=("${kept_files_touched[@]}")` is consumed
      downstream.
- [x] Build the `what_happened` sentence to name the count and point at `tags.dropped_paths` *(completed)*
      rather than inlining every path, keeping the free-prose field readable at any N.
- [x] Leave `warn()` per-path (including its `already_proposed` annotation) and *(completed)*
      `propose_file_scope_addition()` per-path untouched — this phase changes recording only.
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` unmodified *(completed)*
      first and confirm the existing drop cases still pass, then add a new case: a single commit
      attempt dropping three uncontained paths asserts exactly one `scope excursion` line in
      `issues.jsonl` and that line names all three paths.
- [x] Add a second new case asserting the record is still written when the drop is followed by a *(completed)*
      commit that itself fails, pinning the unchanged firing order.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this
phase's two declared paths covers the edit; the selector returns exactly
test-commit-source-store-path.sh, test-derived-artifact-probe-lib.sh, test-git-commit-phase.sh,
test-git-commit-scoped.sh, test-milestone-ref-land.sh, test-skill-base-lifecycle.sh,
test-task-reference-patterns-lib.sh and test-update-task-status.sh for that set.

**Scope Hypothesis**: this script emits `--class "scope excursion"` at exactly one site, and that
site is the only one this phase edits. Confirm with `grep -n` over the file before and after the
edit: before, one non-comment occurrence; after, zero (the literal moves into the library).

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-phase.sh` - accumulate drops, emit once after
  the loop via the shared library
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - multi-path-drop case and
  failed-commit ordering case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` exits 0, with the
  pre-existing drop cases passing unmodified alongside the two new ones.
- A manual three-path drop in a scratch repo leaves exactly one matching line in `issues.jsonl`
  (`grep -c`), whose `tags.dropped_paths` holds all three.
- `bash agent-system/extensions/core/scripts/verify-touched.sh <this phase's two paths>` is green.

---

### Phase 3: Convert git-commit-scoped.sh V10 to one record per drop event [COMPLETED]

**Goal**: V10's containment guard emits a single collapsed record over its already-existing
`containment_dropped` ledger instead of one call per pathspec.

**Tasks**:
- [x] Re-derive the emission site and the ledger's declaration/post-loop read before editing; the *(completed)*
      ledger already survives the pathspec loop and is read again for the exit-7 decision.
- [x] Source the new library beside this script's existing guarded `source … 2>/dev/null` lines, *(completed)*
      same fail-soft posture.
- [x] Remove the in-loop `issue-record.sh` call, keeping the per-pathspec `WARN:` echo, the *(completed)*
      `dropped_pathspecs` append, the `containment_dropped` append, and the `continue` untouched.
- [x] Capture the first-drop and last-drop timestamps around the loop as in Phase 2. *(completed)*
- [x] Fire one library call immediately after the pathspec loop closes and before the V13 and V3 *(completed)*
      exit-code decisions, guarded on a non-empty `containment_dropped`, so the record is written
      on every drop path including the ones that then refuse the commit.
- [x] Build this site's own `what_happened` sentence naming the count and pointing at *(completed)*
      `tags.dropped_paths`, keeping it textually distinct from the other emitter's.
- [x] Pass this site's task number (the contention task number the existing call already uses) and *(completed)*
      no `--phase` argument, matching the current call exactly.
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` unmodified *(completed)*
      first, then add a case where one invocation drops three uncontained pathspecs and asserts
      exactly one `scope excursion` line naming all three.
- [x] Add a case covering the drop-then-refuse shape (V3 or exit-7) asserting the single record is *(completed)*
      still present after the refusal.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this
phase's two declared paths covers the edit; the selector returns exactly
test-claude-refresh-matcher.sh, test-commit-source-store-path.sh, test-generate-task-order.sh,
test-git-commit-phase.sh, test-git-commit-scoped.sh, test-guard-destructive-git.sh,
test-guard-git-push.sh, test-handoff-dispatch-identity.sh,
test-lint-directory-pathspec-boundary.sh, test-lint-scoped-commit-boundary.sh,
test-orchestrate-conclusion-aggregate.sh, test-orchestrate-conclusion-roadmap.sh,
test-orchestrate-context-growth.sh, test-orchestrate-cycle-plan.sh,
test-orchestrate-cycle-postflight.sh, test-orchestrate-record-decision.sh,
test-orchestrate-recover-message-findings.sh, test-orchestrate-unwind-dispatch.sh and
test-redeploy-checkpoint-promotion.sh for that set.

**Scope Hypothesis**: `containment_dropped` already accumulates every V10 drop and survives the
loop, so no new accumulator is needed at this site. Confirm by re-greping the ledger's
declaration and its post-loop read before editing; if the ledger has become loop-local, add a
drop-only accumulator here exactly as Phase 2 does rather than widening this phase's edit.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - move the V10 record out of the
  pathspec loop into one post-loop library call
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - multi-pathspec-drop
  case and drop-then-refuse case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` exits 0, with the
  pre-existing V10 cases passing unmodified alongside the two new ones.
- A manual three-pathspec drop leaves exactly one matching line whose `tags.dropped_paths` holds
  all three, and the exit-code vocabulary (including exit 7) is unchanged.
- `bash agent-system/extensions/core/scripts/verify-touched.sh <this phase's two paths>` is green.

---

### Phase 4: Single-emitter guard, corpus re-verification, and doc disposition [NOT STARTED]

**Goal**: A standing guard that the class literal has exactly one non-test home; proof the
pre-existing corpus still groups; and an explicit, truthful disposition of the three-site parity
sentence the research surfaced.

**Tasks**:
- [ ] Add a repo-wide guard case to
      `agent-system/extensions/core/scripts/tests/test-scope-excursion-record-lib.sh`: scan the
      extension's `scripts/` tree excluding `tests/` for the `scope excursion` class literal in a
      `--class` position and assert the only occurrence is the library's own, so a future per-path
      emitter is caught at suite time. Exclude comment lines explicitly rather than by accident.
- [ ] Re-verify the pre-existing corpus is unstranded: run
      `bash .claude/scripts/orchestrate-conclusion-aggregate.sh` (or its own suite,
      `test-orchestrate-conclusion-aggregate.sh`) over a fixture mixing old single-path rows with
      a new collapsed row, and confirm both group under one class with correct citations. The
      change is additive — a new `tags` key — so no backfill of the existing rows is performed.
- [ ] Disposition the `git-staging-scope.md` asymmetry by correcting the doc, not by adding a
      third emitter: the postflight-sited Containment filter prints its per-path notice to stderr
      and does not write an issue row, and nothing in this task's required outcomes asks for
      three-site parity. Rewrite the "Three Containment sites, not one" passage's affected
      sentence to state the current design positively — the deposit is additive to, and never a
      substitute for, the warning this site fires and the issue row the two commit-wrapper sites
      fire — the disposition this plan's Decisions section records, with the alternative of giving
      the postflight site its own batched call left to a separately-scoped follow-up.
- [ ] Add a cross-reference from `issue-log.md`'s "Occurrence Collapse" section to the new library
      function as the convention's concrete implementation, so the next caller with the same
      precondition has a call site to copy rather than only prose.
- [ ] Phrase both doc edits with durable anchors only: no task numbers, and no "previously / no
      longer / used to" framing — state what the sites do, not what they stopped doing.
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` and,
      if either touched entry drifts beyond tolerance, `--write` to regenerate `index-entries.json`
      in the same phase.

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this
phase's four declared paths covers the edit; the selector returns exactly
test-context-reachability.sh, test-deploy-orphans.sh, test-git-commit-phase.sh,
test-index-entries-schema.sh, test-install-uninstall-extension.sh, test-manifest-scripts-sync.sh,
test-orchestrate-build-dispatch.sh, test-roadmap-command-registration.sh and
test-todo-move-pair-staging.sh for that set, with the doc-lint and task-reference gate pair
running alongside for the two markdown edits.

**Scope Hypothesis**: after Phases 2 and 3, exactly one non-comment `--class "scope excursion"`
occurrence remains in the extension's non-test `scripts/` tree, inside the new library. Confirm
by running the guard's own grep manually before committing it — if it finds a site this plan did
not name, stop and record it rather than silently folding the extra site into this phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-scope-excursion-record-lib.sh` - repo-wide
  single-emitter guard case
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - correct the three-site
  parity sentence to match the code
- `agent-system/extensions/core/context/formats/issue-log.md` - cross-reference the library as the
  Occurrence Collapse convention's implementation
- `agent-system/extensions/core/index-entries.json` - `line_count` for the two touched context
  entries, regenerated only if `--check` reports drift beyond tolerance

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-scope-excursion-record-lib.sh` exits 0,
  including the new guard case.
- The mixed old/new fixture groups under a single class through
  `orchestrate-conclusion-aggregate.sh`'s pipeline with citations for every row.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is green for the two markdown edits.
- `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` reports no
  outstanding drift for the two touched entries.

---

### Phase 5: Redeploy and close [NOT STARTED]

**Goal**: The source-store changes reach the deployed tree, and the orchestration's complete gate
obligation is discharged at its own close.

**Tasks**:
- [ ] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deployed tree from the
      source store.
- [ ] Confirm the deployed tree carries the new library and the new suite
      (`.claude/scripts/lib/scope-excursion-record-lib.sh`,
      `.claude/scripts/tests/test-scope-excursion-record-lib.sh`), which is the end-to-end proof
      that the `provides.scripts` registration from Phase 1 took.
- [ ] Run the three affected suites against the deployed tree
      (`test-scope-excursion-record-lib.sh`, `test-git-commit-phase.sh`,
      `test-git-commit-scoped.sh`) and confirm each exits 0.
- [ ] Run the scoped touched-path check over every path this task touched:
      `bash .claude/scripts/verify-touched.sh <the full touched set>`.
- [ ] Record explicitly in the phase's verification notes that the complete gate set is deferred
      to the orchestration close (the once-per-invocation batch gate stage) rather than invoked
      independently here. Under a standalone, non-orchestrated run with no such close, run
      `bash .claude/scripts/verify-deploy.sh` directly instead.

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: this task adds exactly two files to the deployed tree (the library and its
suite) and affects exactly three suites. Confirm by listing the two deployed paths after the
deploy and by re-running the touched-path selector over the task's full touched set — if it names
a suite this plan did not, run that one too rather than treating the plan's list as closed.

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed tree from the source
  store; no source file is edited in this phase

**Verification**:
- `deploy-headless.sh` exits 0 and the two new files are present in the deployed tree.
- The three affected suites each exit 0 when run from the deployed tree.
- `bash .claude/scripts/verify-touched.sh <full touched set>` is green, with the complete gate set
  explicitly deferred to the orchestration close.

## Testing & Validation

- [ ] A multi-path drop at `git-commit-phase.sh` writes exactly one `scope excursion` row naming
      every dropped path (dispatch Verification item 1).
- [ ] A multi-pathspec drop at `git-commit-scoped.sh` writes exactly one such row naming every
      dropped path (dispatch Verification item 1).
- [ ] A repo-wide scan finds no non-test site emitting the class per path (dispatch Verification
      item 2).
- [ ] Pre-existing single-path rows and new collapsed rows group together correctly through
      `orchestrate-conclusion-aggregate.sh`'s `group_by` pipeline with no backfill (dispatch
      Verification item 3, with the research report's correction of the named consumer).
- [ ] `--severity minor` and the drop-and-warn posture are byte-identical to today at both sites.
- [ ] Every pre-existing drop case in both suites passes unmodified.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/scope-excursion-record-lib.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-scope-excursion-record-lib.sh` (new)
- Modified: `git-commit-phase.sh`, `git-commit-scoped.sh`, `test-git-commit-phase.sh`,
  `test-git-commit-scoped.sh`, `manifest.json`, `git-staging-scope.md`, `issue-log.md`,
  `index-entries.json`
- A regenerated deployed `.claude/` tree

## Rollback/Contingency

Every phase is a separate commit against source-store files only; reverting a phase's commit and
re-running `deploy-headless.sh` restores the prior behavior with no data migration, because the
change is purely additive at write time (a new `tags` key) and touches no stored record. If the
collapse proves wrong at one emitter only, that emitter's commit can be reverted independently —
the library tolerates having one caller. The pre-existing `issues.jsonl` corpus is never rewritten
at any point, so no rollback step has to restore it.
