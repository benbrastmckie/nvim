# Implementation Plan: Task #486

- **Task**: 486 - Stop a required extension manifest.json registration being dropped from a phase commit as a scope excursion
- **Status**: [NOT STARTED]
- **Effort**: 3.5 hours
- **Dependencies**: None open (430, 446, 484, 494, 541 all confirmed completed/archived by the research round)
- **Research Inputs**: specs/486_manifest_registration_dropped_from_phase_commit/reports/01_manifest-registration-containment-rule.md
- **Artifacts**: plans/01_manifest-containment-splice.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Implement the research round's ruling — dispatch Option (1) — as a fourth local, non-declared
splice into `git-commit-phase.sh`'s Containment Self-Check `file_scope_arr`, following the exact
structural precedent of the three splices already present (own-task-directory,
engine-written-state allowlist, derived-output-prefix allowlist). When this phase's
`files_touched` contains at least one path under some extension's own `scripts/` tree (excluding
`scripts/deprecated/`), that same extension's own `manifest.json` is admitted into the
containment predicate's input for this one check. The splice is then pinned by new fixtures in
`test-git-commit-phase.sh` covering both the admit case and every behaviour the dispatch's HARD
CONSTRAINTS require to survive intact, and documented in `git-staging-scope.md`'s "Three
Containment sites, not one" section so the next similar-shaped request is answered by
documentation rather than by re-deriving the research.

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class line the dispatch extracted was checked against the live source store and the
prior research artifact before this plan was written:

- **"SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/\*\*"** — CONFIRMED unchanged.
  `.claude-extensions.json`'s `.extensions.core.source_dir` resolves to
  `/home/benjamin/.config/nvim/agent-system/extensions/core`, i.e. the source store for this
  task lives in this same repository. Every edit path below is a source-store path.
- **"iss_1793841635583_gpNhE6 (dispatch_seq 18, Phase 7 -- 47 of 48 migrated test files
  dropped)"** — NOT re-verified, deliberately. The dispatch itself instructs that the three cited
  issue rows are retained "as the evidence of RECURRENCE and of cost, NOT as a live description
  of the mechanism. Read them for the cost account, not for the diagnosis." The ratio is a
  historical cost figure from another task's issue log and is carried forward unchanged, not
  acted on as a live measurement.
- **"git-commit-phase.sh's is_contained() (around lines 272-305) normalizes a trailing-slash
  entry..."** — behaviour CONFIRMED present; the **line citation is STALE**. `is_contained()` is
  now defined at line 720, with the `while [ "${entry%/}" != "$entry" ]` normalization loop at
  lines 730-732 and its documenting comment immediately above; lines 272-305 are now header
  prose about repository classification. The dispatch's own "re-derive before editing, line
  numbers move" instruction anticipated exactly this. The behavioural claim ("THAT DEFECT IS
  CLOSED") stands — do not re-fix it.
- **"Do NOT make the check fatal. Fail-open on a missing/empty/malformed file_scope..."** —
  CONFIRMED live: the Containment Self-Check's own header comment at lines 580-582 states "Fails
  open (leaves files_touched untouched) on any missing/empty/unreadable/malformed file_scope, or
  any internal error below -- never block a commit over a guard defect," and all three existing
  splices sit INSIDE the `[ "${#file_scope_arr[@]}" -gt 0 ]` guard at line 655 precisely to
  preserve it. The new splice goes in the same place for the same reason.
- **"Any state.json write must go through the mutex-guarded state-write.sh path"** — CONFIRMED
  applicable and trivially satisfied: this plan performs **no** `state.json` write at all. The
  splice is local to `file_scope_arr` and is never written back to the declared `file_scope`.
- **"TERRITORY EDGES -- git-commit-phase.sh is SHARED FILE TERRITORY with three open records"** —
  RE-DERIVED AND SUPERSEDED. All three named records (430 `feed_undeclared_implement_paths...`,
  446 `close_the_plan_to_file_scope_reconciliation_gap`, 484
  `collapse_perpath_scope_excursion_issue_rows_into_one`) have landed; the research round
  verified each one's landed shape in the current script (the `proposed_file_scope` deposit
  block, the deployed-tree strip plus read-only `proposed_file_scope_lookup`, and the collapsed
  `scope_excursion_record_emit` call respectively). They are edges to preserve, not edges to
  wait on. Task 484's collapsed emit loop in particular is the very loop this plan's fixtures
  assert against, so Phase 2's negative fixtures must assert the COLLAPSED (one row per drop
  event) shape, never a per-path shape.

### Research Integration

The research report's ruling is adopted in full and this plan implements it without
re-litigation:

- **Option (1) selected.** The dispatch's own stated downside for Option (1) ("it widens declared
  territory without review, and `file_scope` is also the batch admission gate's conflict-detection
  input") does not apply to the implementation shape chosen: all three existing splices, and this
  fourth one, mutate only the in-script `file_scope_arr` copy, never `specs/state.json`'s declared
  `file_scope`, and are never consulted outside this one script's `is_contained()` closure.
- **Option (3) rejected on evidence.** The general declaration-staleness feedback mechanism has
  landed, but task 446's own summary states the follow-up commit "is never automatic on a later
  phase's ordinary commit" — it mechanizes recovery, it does not prevent the first drop or
  eliminate the extra-commit cost this record's SEVERITY line is about.
- **Option (2) rejected as the primary mechanism.** It targets the "agent never edited
  manifest.json at all" failure mode, which is already covered post-redeploy by
  `sync-manifest-scripts.sh --check` and `check-extension-docs.sh`'s Rule Q via
  `verify-deploy.sh` gate 3 — a different failure mode from this record's LIVE SYMPTOM (the edit
  WAS made and was then dropped by containment).
- **Trigger scope widened from the dispatch's illustrative example.** The dispatch illustrated
  with `scripts/lib/`; the obligation actually enforced by `sync-manifest-scripts.sh` and Rule Q
  is "full relative path under `scripts/` (not basename), `deprecated/*` excluded" (verified
  verbatim in `sync-manifest-scripts.sh`'s MATCHING header at line 37). The splice's trigger
  mirrors that rule exactly, so the widening's condition and the test that enforces the pairing
  agree on what counts.

### Prior Plan Reference

No prior plan. This is the task's first planning round.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch and no `roadmap_flag` was set, so no roadmap
consultation phases are included. Roadmap sequencing for this record is unchanged by this plan.

## Goals & Non-Goals

**Goals**:
- Prevent the FIRST drop of a structurally-derivable `manifest.json` registration from a phase
  commit, rather than only mechanizing its recovery.
- Keep the widening local: `file_scope_arr` only, never `specs/state.json`'s declared
  `file_scope`, so the batch-admission gate's conflict-detection input is untouched.
- Pin every HARD CONSTRAINT behaviour with a fixture so a future edit at this site cannot
  silently regress it.
- Leave a durable documentation pointer so the Option (2)/(3) rejection is not re-derived.

**Non-Goals**:
- Any change to `git-commit-scoped.sh`'s own, separate V10 containment guard (Site 3). Task 446
  built and rejected a union there; the dispatch's HARD CONSTRAINTS forbid touching it here.
- Any change to the trailing-slash normalization or the engine-written-paths allowlist — both
  already present and working; re-introducing either is explicitly forbidden.
- Any pre-commit nag about a MISSING manifest registration (Option (2)); that lint already exists
  and is already wired post-redeploy.
- Any `specs/state.json` write, declared-`file_scope` mutation, or new `lib/*.sh` file. The
  derivation is a pure string operation on in-hand `files_touched` entries.
- Making the Containment Self-Check fatal or narrowing its fail-open posture in any way.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The splice is read by a future maintainer as license to widen `file_scope_arr` by arbitrary structural inference | M | M | Inline header comment at the splice site stating it is local-only, never written back to `state.json`, and admits exactly one derived path per touched extension — matching the three existing splices' own documenting convention; plus the Phase 3 `git-staging-scope.md` paragraph |
| Over-inclusive trigger: a pure test-fixture edit under `scripts/tests/` also admits that extension's `manifest.json` although no registration is owed | L | H | Accepted deliberately. The splice admits one specific literal path, never a glob or directory, and the path must still genuinely appear in `files_touched` (i.e. the agent genuinely edited it) to be staged. Narrowing to add-vs-modify would need git plumbing this call site does not otherwise use |
| A malformed or exotic `files_touched` entry makes the derivation produce a nonsense path | L | L | Derivation is a pure `case`/parameter-expansion string operation with no filesystem or git lookup; a non-matching entry contributes nothing. Nothing in the splice can fail in a way that blocks a commit — fail-open is structural, not conditional |
| The new fixtures accidentally assert a per-path issue-record shape, regressing task 484's collapsed emit | M | M | Phase 2's negative fixtures assert exactly one `"class":"scope excursion"` line naming all dropped paths, mirroring existing Cases 43/44's assertion shape verbatim |
| `index-entries.json`'s `line_count` for the edited doc drifts from `wc -l` | L | H | Declared in Phase 3's own `Files to modify` and regenerated in that same phase; `deploy-headless.sh` runs `generate-context-line-counts.sh` automatically before every deploy, and `check-extension-docs.sh` Rule R reports the mismatch otherwise |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. This plan is a strict chain: the fixtures
assert the splice's behaviour, and the documentation paragraph describes the splice as landed.

---

### Phase 1: Add the extension-manifest splice to the Containment Self-Check [NOT STARTED]

**Goal**: `git-commit-phase.sh`'s Containment Self-Check admits the touched extension's own
`manifest.json` into its local `file_scope_arr` whenever that same extension's `scripts/` tree
(excluding `scripts/deprecated/`) is also present in this phase's `files_touched`.

**Tasks**:
- [ ] Re-derive the current line numbers before editing (they move; the dispatch's own citation
      was already stale). Confirm the three existing splices and the `is_contained()` definition
      are where this plan says: own-task-directory splice at ~line 667, engine-written-state
      splice at ~lines 679-691, derived-output-prefix splice at ~lines 705-715, `is_contained()`
      at ~line 720, all inside the `[ "${#file_scope_arr[@]}" -gt 0 ]` guard at ~line 655.
- [ ] Insert the fourth splice immediately AFTER the derived-output-prefix splice and BEFORE the
      `is_contained()` definition, inside that same non-empty guard — so the fail-open posture
      (a task with no declared `file_scope` skips the whole check and never acquires a scope
      member it never declared) is structurally unchanged.
- [ ] Derive the trigger purely by string operation over the post-classification `files_touched`
      array: an entry matching `*extensions/*/scripts/*` and NOT matching
      `*extensions/*/scripts/deprecated/*` yields a prefix ending at the segment immediately
      after `extensions/`; the admitted path is that prefix plus `/manifest.json`. Take the
      prefix verbatim from the entry rather than hardcoding `agent-system/`, so a source store
      rooted elsewhere is handled identically. Deduplicate so each extension contributes at most
      one entry.
- [ ] Perform no filesystem check, no `git` call, and no `jq` call in the splice — nothing that
      can introduce a new failure mode at this site. An entry that matches nothing contributes
      nothing; this is fail-open by construction, not by a guard.
- [ ] Write the inline header comment above the splice in the same voice as the three existing
      ones: why it exists (`sync-manifest-scripts.sh` / Rule Q enforce the pairing mechanically,
      so the registration is structurally derivable, not an unforeseeable discovery), that the
      matching rule mirrors `sync-manifest-scripts.sh`'s own MATCHING header verbatim, that it
      mutates `file_scope_arr` only and is never written back to `specs/state.json`, and that
      Options (2) and (3) were considered and rejected (one sentence each) so the next reader
      does not re-litigate them.
- [ ] Record any deviation, blocker, or unusually smooth result via `issue-record.sh` as it
      arises.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/git-commit-phase.sh` covers this single-script edit, selecting test-commit-source-store-path.sh, test-derived-artifact-probe-lib.sh, test-git-commit-phase.sh, test-git-commit-scoped.sh, test-milestone-ref-land.sh, test-scope-excursion-record-lib.sh, test-skill-base-lifecycle.sh, test-task-reference-patterns-lib.sh and test-update-task-status.sh.

**Scope Hypothesis**: this phase is hypothesized to be a single contiguous insertion of roughly
20-30 lines (comment plus derivation loop) into one file, with zero edits elsewhere. Confirm at
implementation time by re-reading the splice region before editing and by checking `git diff
--stat` after: a diff touching any file other than `git-commit-phase.sh`, or touching
`is_contained()`'s body, means the scope assumption was wrong and the phase should stop and
re-plan rather than widen silently.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-phase.sh` - add the fourth `file_scope_arr`
  splice plus its documenting header comment, inside the existing non-empty guard, after the
  derived-output-prefix splice and before `is_contained()`.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` is green (the
  pre-existing 44 cases must all still pass — this phase adds no fixture of its own).
- `bash -n agent-system/extensions/core/scripts/git-commit-phase.sh` clean, and `shellcheck`
  reports no new finding against the edited region.
- The narrowed pass named in Tier Justification above is green.
- Diff read-through confirms the splice sits inside the `[ "${#file_scope_arr[@]}" -gt 0 ]`
  guard and that neither the trailing-slash normalization nor the engine-written-paths allowlist
  was touched.

---

### Phase 2: Pin the rule and every surviving constraint with fixtures [NOT STARTED]

**Goal**: `test-git-commit-phase.sh` carries fixtures that fail if the splice is removed, and
that fail if any of the dispatch's HARD CONSTRAINT behaviours regresses.

**Tasks**:
- [ ] Re-read the test file's tail to find the next free case number and the
      `# task-ref-ok:end` marker; insert every new case BEFORE that marker (each new case uses
      the synthetic `--task 999` / `999_probe` literals the file-level `task-ref-ok` block
      already covers).
- [ ] **Admit fixture** — `files_touched` names a declared source file, a path under
      `agent-system/extensions/foo/scripts/lib/new-lib.sh` (declared via a `scripts/` scope
      entry), and `agent-system/extensions/foo/manifest.json` (NOT declared). Assert all three
      land in the commit, no drop warning names the manifest, and no `"class":"scope excursion"`
      row is written.
- [ ] **`deprecated/` exclusion fixture** — identical shape, but the touched script path is
      under `agent-system/extensions/foo/scripts/deprecated/old.sh`. Assert the undeclared
      `manifest.json` is STILL dropped, with its warning and its collapsed issue row.
- [ ] **Cross-extension negative fixture** — the phase touches extension `foo`'s `scripts/`
      tree (declared) and a DIFFERENT extension `bar`'s `manifest.json` (undeclared). Assert
      `bar`'s manifest is still dropped: the splice admits only the touched extension's own
      manifest.
- [ ] **Genuine-excursion survival fixture** (dispatch VERIFY item b) — a fixture that exercises
      the splice AND an ordinary out-of-territory path (e.g. `other/outside.txt`) in the same
      commit. Assert the out-of-territory path is dropped, its `warn()` fires, and exactly one
      `"class":"scope excursion"` row is written naming it — the COLLAPSED shape, mirroring
      existing Cases 43/44's assertion style, never a per-path shape.
- [ ] **Fail-open fixture** (dispatch VERIFY item c) — the splice-triggering `files_touched` set
      against an absent / empty / malformed `file_scope`. Assert the whole Containment
      Self-Check is skipped, everything stages, no warning fires, and the exit code is unchanged
      from the pre-splice behaviour.
- [ ] **Trailing-slash fixture** (dispatch VERIFY item d) — a declared scope entry written with
      a trailing slash (`agent-system/extensions/foo/scripts/`) still admits its children.
      Assert the child path lands and is not dropped.
- [ ] Record issues and wins via `issue-record.sh` as they arise.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` covers this test-file-only edit, selecting test-commit-source-store-path.sh, test-git-commit-phase.sh, test-milestone-ref-land.sh and test-task-reference-patterns-lib.sh.

**Scope Hypothesis**: six new fixture cases are hypothesized, expected to number 45-50 given the
file's current highest case (44) — a hypothesis about the file's current state, not a fact.
Confirm by re-reading the tail of `test-git-commit-phase.sh` before writing: if the highest
existing case number differs, renumber the new cases to continue from whatever is actually
there rather than forcing 45-50. If one fixture's scenario turns out to be already covered by an
existing case, fold the new assertion into that case instead of adding a duplicate and say so in
the phase's own notes.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - six new fixture cases
  inserted before the `# task-ref-ok:end` marker.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` exits 0 with every
  pre-existing case plus every new case passing.
- Temporarily reverting the Phase 1 splice (locally, not committed) makes the admit fixture FAIL
  — confirming the fixture actually pins the new behaviour rather than passing vacuously. Restore
  the splice before committing.
- The narrowed pass named in Tier Justification above is green.

---

### Phase 3: Document the splice, regenerate, redeploy, and close [NOT STARTED]

**Goal**: `git-staging-scope.md`'s "Three Containment sites, not one" section describes the
fourth splice and the recorded Option (2)/(3) rejection; the deployed tree is regenerated from
the source store and the whole change is verified.

**Tasks**:
- [ ] Add a short paragraph to `agent-system/extensions/core/context/standards/git-staging-scope.md`'s
      "Three Containment sites, not one" section documenting the fourth Site-2 splice: its
      trigger condition (a `files_touched` path under an extension's own `scripts/` tree,
      `deprecated/` excluded, mirroring `sync-manifest-scripts.sh`'s MATCHING rule), its effect
      (that extension's own `manifest.json` admitted into `file_scope_arr` for this check only),
      and the explicit statement that it is local-only and never written back to the declared
      `file_scope` the batch-admission gate reads. State the Option (2)/(3) rejection in one
      sentence each so the next similar request is answered here.
- [ ] Write no task-number reference and no record-versioning language into any file landing
      under `agent-system/**` (describe the current design only; cite durable anchors such as
      script names and section headings, never a task number or a "previously/no longer" framing).
- [ ] Redeploy the source store into the deployed tree with
      `bash agent-system/extensions/core/scripts/deploy-headless.sh`, which also runs
      `generate-context-line-counts.sh --write` and therefore updates
      `agent-system/extensions/core/index-entries.json`'s `line_count` for the edited doc in this
      same phase.
- [ ] Stage the regenerated `index-entries.json` alongside the doc edit in this phase's own
      commit — it is declared below precisely so the Containment Self-Check admits it.
- [ ] Record issues and wins via `issue-record.sh` as they arise.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - new paragraph in the
  "Three Containment sites, not one" section documenting the fourth splice.
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` for
  `standards/git-staging-scope.md` (coupled generated surface of the doc edit above; regenerated
  in this same phase by `deploy-headless.sh`'s own `generate-context-line-counts.sh --write`
  step, and reported by `check-extension-docs.sh` Rule R if left stale).
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`.

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/context/standards/git-staging-scope.md agent-system/extensions/core/index-entries.json agent-system/extensions/core/scripts/git-commit-phase.sh agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`
  is green over this task's full touched-path set.
- `bash .claude/scripts/check-task-references.sh` and the record-version lint report no new
  finding against the edited `agent-system/**` files.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` is clean (no new
  script file was added by this task, so `provides.scripts` must be unchanged).
- As the plan's final phase, this phase's own in-dispatch obligation is the scoped touched-path
  check above plus an explicit deferral of the complete gate set
  (`bash .claude/scripts/verify-deploy.sh`) to the orchestration close under `/orchestrate` —
  never an independent full-battery invocation as this phase's own criterion. A standalone,
  non-orchestrated run of this phase instead runs the complete gate set directly.

---

## Testing & Validation

- [ ] `test-git-commit-phase.sh` green, with the admit fixture demonstrably failing when the
      splice is reverted (non-vacuous pinning).
- [ ] A genuinely out-of-territory path is still dropped, still warned about, and still recorded
      as exactly one collapsed `"class":"scope excursion"` issue row.
- [ ] Fail-open behaviour on absent / empty / malformed `file_scope` is byte-for-byte unchanged.
- [ ] Trailing-slash normalization and the engine-written-paths allowlist both still work and are
      untouched by the diff.
- [ ] `specs/state.json` is not written by any phase of this task.
- [ ] `git-commit-scoped.sh` is not modified by any phase of this task.
- [ ] No task-number reference and no record-versioning language lands under `agent-system/**`.

## Artifacts & Outputs

- Modified `agent-system/extensions/core/scripts/git-commit-phase.sh` (fourth `file_scope_arr`
  splice plus documenting comment).
- Extended `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` (six new
  fixtures).
- Updated `agent-system/extensions/core/context/standards/git-staging-scope.md` (fourth-splice
  paragraph).
- Regenerated `agent-system/extensions/core/index-entries.json` `line_count`.
- Regenerated deployed `.claude/` tree (disposable deploy artifact, not a reviewable output).
- An implementation summary at completion.

## Rollback/Contingency

Each phase is a single-file edit (Phase 3 adds its regenerated coupled surface), so reverting is
a per-phase `git revert` of that phase's own commit. The splice is purely additive to a local
array: removing it restores exactly today's behaviour with no migration, no state to unwind, and
no deployed-tree residue beyond what the next redeploy regenerates. If the admit fixture cannot
be made non-vacuous (i.e. it passes with the splice reverted), stop and re-derive the trigger
condition rather than weakening the fixture — a vacuously-passing fixture is worse than none.
If implementation discovers that the trigger must consult the filesystem or git to be correct,
stop and re-plan: the research round's ruling explicitly rests on the derivation being a pure
string operation with no new failure mode.
