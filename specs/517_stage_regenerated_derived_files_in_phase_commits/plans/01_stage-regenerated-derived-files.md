# Implementation Plan: Task #517

- **Task**: 517 - Stage regenerated derived files in phase commits
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: #455 (`preflag_module_wiring_invariant_failures`) — semantic predecessor,
  completed; its landed finding is incorporated, not re-litigated. #513 — no edge (confirmed: no
  shared files). #430 — shares `agents/general-implementation-agent.md`; this plan's edit there is
  a single pointer line, so keep wording consistent if #430 lands first.
- **Research Inputs**: `specs/517_stage_regenerated_derived_files_in_phase_commits/reports/01_stage-regenerated-derived-files.md`
- **Artifacts**: plans/01_stage-regenerated-derived-files.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The execution half of the derived-surface friction: declaring a generated path does not
regenerate the file at it, and nothing in the phase-commit protocol tells an implementing agent
to re-run a surface's regeneration entry point and stage its output inside the phase that staled
it. This plan lands the research report's ruling — decision (c): a short, generic, declaration-only
obligation in the commit protocol (the rule), plus a non-blocking call to the already-built
derived-staleness probe at the phase-commit site (the mechanical backstop) — and one additional
component the report's own findings make unavoidable: the phase-commit Containment Self-Check
currently drops a regenerated derived-output path before the commit ever sees it, so without a
derived-output-prefix splice at that site the new rule is actively undone by the very script that
would carry it out. Every piece stays inert in a repository that declares no derived surfaces, and
no core file acquires knowledge of any consumer repository's generator scripts.

### Premise Re-Validation (Carried-Figure Discipline)

Each flagged line from the dispatch description, checked against live state at planning time:

1. **Source store is the edit target.** Re-derived, not trusted:
   `jq -r '.extensions | to_entries[]' .claude-extensions.json` resolves
   `.extensions.core.source_dir` to `/home/benjamin/.config/nvim/agent-system/extensions/core`
   (per-extension key, as the description states). **Confirmed unchanged.** All edit targets below
   are named at their source-store paths; `.claude/**` is never hand-authored.
2. **The originating repository declares no `derived_artifact_probes`.** Re-derived live:
   `jq -r '.derived_artifact_probes // "ABSENT", .coupled_generated_surfaces // "ABSENT"'
   ~/Projects/BimodalLogic/.claude-extensions.json` → both `ABSENT`. **Confirmed unchanged**, and
   confirmed as the report found it (both keys, not just one). This is why nothing in this plan
   has any effect on the cited incident without the companion consumer-repo record named in
   Phase 4.
3. **`checkpoint-commit.md`'s Step 1 computes staging from the plan file and self-reported
   `modified_files`.** Confirmed by direct read: the Step 1 block builds `stage_paths` from the
   task directory, `specs/TODO.md`, `specs/state.json`, `$plan_path`, and
   `jq -r '.modified_files[]?' "$metadata_file"`. Nothing in it runs a generator.
   **Confirmed unchanged.**
4. **Core must not acquire knowledge of `check-module-invariants.sh` / `typst-sync-check.sh`.**
   Re-derived: `grep -rln` across the whole core extension returns exactly two files,
   `scripts/plan-file-scope-harvest.sh` and `scripts/tests/test-plan-file-scope-harvest.sh`.
   **Confirmed unchanged** — and no edit in this plan adds a third.
5. **The four-recurrence claim.** Re-derived from the four cited entry ids against
   `~/Projects/BimodalLogic/specs/archive/867_formalize_gabbay_separation_ztime/issues.jsonl`
   (the log has been archived since creation time; the ids resolve there): all four present, all
   `severity: minor`, classes `gate-collision`/`gate-collision`/`tooling`/`gate-collision`,
   `dispatch_seq` 7/17/17/18. **Confirmed exactly as described.**

### Research Integration

The report's ruling is adopted whole: (a) as the rule, sited in `checkpoints/checkpoint-commit.md`
with a one-line pointer (not a verbatim copy, per `standards/anchor-pointer-convention.md`) from
`agents/general-implementation-agent.md`; (b) as a minimal, additive, non-blocking third call site
for the already-built `derived_probe_run_all`. The report's explicitly-declined non-goal —
promoting `coupled_generated_surfaces`' inline reader to `scripts/lib/` and wiring a second,
source-correlated backstop — stays declined here.

One finding of the report is extended by a check made during planning. The report identified that
`git-commit-phase.sh`'s Phase-Commit Containment Self-Check drops a regenerated path that is not
in the task's declared `file_scope`, and read that as coupling to the declaration half. Planning
re-derived the adjacent fact the report did not reach: `git-commit-scoped.sh`'s own V10 guard
(Containment Site 3) **already** widens its effective scope with
`derived_probe_output_prefixes`, and `git-commit-phase.sh` (Site 2) does not —
`grep -n derived scripts/git-commit-phase.sh` returns only prose uses of the English word, never a
`derived_probe_*` call. `standards/git-staging-scope.md`'s "Three Containment sites, not one"
section already settles why Site 3 cannot rescue this: Site 2 removes an uncontained path from its
own `files_touched` array *before* `git-commit-scoped.sh` is invoked, and V10 tests only the
pathspec entries it is handed, so it can neither see nor restore a path Site 2 already dropped.
That is the same asymmetry that section records for the own-task-directory member. Phase 2 closes
it for the derived-output member by mirroring the splice Site 3 already carries.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag is set; roadmap consultation
was skipped and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- State, once, generically, at the site where the staging decision is actually made, that a phase
  whose edits touch a *declared* derived-output surface must re-run that surface's own sanctioned
  regeneration entry point and stage the result in the same phase commit.
- Make that obligation mechanically executable: a declared derived-output path, regenerated
  mid-phase, must survive the phase-commit Containment Self-Check rather than being dropped.
- Add one additive, non-blocking staleness-detection call at the phase-commit site, reusing the
  built and tested `derived_probe_run_all` with no new schema and no new field.
- Keep every piece inert in a repository that declares no derived surfaces, and build-free.

**Non-Goals**:
- No edit to `scripts/plan-file-scope-harvest.sh` or its test (the declaration half, owned
  elsewhere), to `contracts/phase-closure.md`, or to any file declared by #513.
- No promotion of `coupled_generated_surfaces`' inline reader to `scripts/lib/`, and no
  source-correlated second backstop against `files_touched`.
- No turning `commit_blocking: true` into a real commit refusal anywhere.
- No new blocking gate: the backstop warns and records, never refuses a commit.
- No edit to any file in `~/Projects/BimodalLogic` or any other consumer repository.
- No naming of any consumer repository's generator scripts in any core file.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The new prose obligation is read but skipped by an implementing agent | M | L | Phase 3's backstop detects the resulting staleness mechanically, independent of whether the prose was followed; non-blocking, so it can never deadlock a dispatch. |
| The Site-2 splice is read as a general licence to widen `file_scope` | M | L | The splice admits only paths under a *declared* `derived_output_dirs` prefix, obtained from the same library Site 3 already uses; with no declaration it adds nothing. Phase 2's tests pin both the admit case and the inert case. |
| Unconditional `derived_probe_run_all` at every phase commit flags pre-existing staleness an earlier, unrelated phase left behind (misattribution) | L | M | Kept strictly non-blocking (warn + `issue-record.sh` only, never an exit-code effect). An earlier, slightly noisy detection is still strictly better than first learning of it at the end of the plan. |
| A future reader takes the obligation as licence to run a full build at a phase commit | M | L | The prose says "build-free regeneration entry point" explicitly and cites the declaration schema's own build-free requirement; it never names a build command. |
| Sourcing a new library in `git-commit-phase.sh` silently breaks its test fixture's sandbox copy list | M | M | `scripts/lint/lint-fixture-dependency-declaration.sh` exists for exactly this drift; Phase 3 adds the dependency to `REQUIRED_SCRIPTS` and to `build_repo`'s copy set in the same phase, and runs that lint as a verification criterion. |
| The pointer edit in `general-implementation-agent.md` removes or alters a literal fragment `lint-agent-contracts.sh` checks for | M | L | Read the enforcing script's live `*_FRAGMENT` variables before editing (the gate-required-restatement exclusion class in `standards/anchor-pointer-convention.md`); the edit is purely additive — one new line, nothing removed. |
| Nothing in this plan changes the cited incident's outcome without a companion declaration in the consumer repository | H | H (confirmed, not hypothetical) | Phase 4 records the companion-record recommendation explicitly in the summary and the issue log, and states that this record is not a complete fix in isolation. Creating that record is out of this repository's boundary. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is a strict sequence: Phases 2 and
3 both edit `scripts/git-commit-phase.sh` and `scripts/tests/test-git-commit-phase.sh`, so they
are deliberately not parallel, and Phase 4 regenerates the deployed tree from the finished source
store.

### Phase 1: State the Obligation in the Commit Protocol [COMPLETED]

**Goal**: The standing rule exists, once, generically, at the site where the staging decision is
made, with a pointer (never a copy) from the implementing agent's own phase-commit prose.

**Tasks**:
- [x] Re-read `context/checkpoints/checkpoint-commit.md`'s `### 1. Determine Targeted Scope` to
      confirm the Step-1 shape named in the Premise Re-Validation above is still what is on disk.
      *(completed: confirmed unchanged)*
- [x] Add a short paragraph (3-5 sentences, no more) to that section stating the obligation:
      before this phase's scope is computed, check whether any path this phase touched is, or
      stales, a surface this repository has **declared** — a `derived_artifact_probes` entry's
      `derived_output_dirs` prefix, or a `coupled_generated_surfaces` entry whose `trigger_glob`
      the touched path matches — and if so, re-run that surface's own sanctioned, **build-free**
      regeneration entry point now and let its output be among the paths this same commit stages.
      Name only the two `.claude-extensions.json` keys and point at
      `context/standards/repo-level-declarations.md` for their schema. Say explicitly that a
      declaration-free repository owes nothing here.
- [x] State, in the same paragraph, the one asymmetry a reader needs: the staging-admission
      widening in Phase 2 covers `derived_artifact_probes.derived_output_dirs` only, so a surface
      declared **solely** through `coupled_generated_surfaces` still needs its generated path
      inside the task's own declared `file_scope` to be stageable.
- [x] Read `scripts/lint/lint-agent-contracts.sh`'s live `*_FRAGMENT` variables before touching
      `agents/general-implementation-agent.md`, per the gate-required-restatement exclusion class
      in `context/standards/anchor-pointer-convention.md`. *(completed: confirmed the pointer
      edit site, step 5, is not among the four `*_FRAGMENT` enforcers)*
- [x] Add exactly one line to `agents/general-implementation-agent.md`'s Phase Checkpoint
      Protocol step 5, pointing at `checkpoints/checkpoint-commit.md` by path and by the exact new
      heading/section text that owns the obligation. A pointer, never a restatement — this is the
      collapsed-block shape `anchor-pointer-convention.md` requires. Nothing is removed.
- [x] Confirm no task-number reference and no record-versioning language ("previously", "no
      longer", "v2", a supersession note) entered either file. *(completed: grep confirmed zero
      hits)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh
agent-system/extensions/core/context/checkpoints/checkpoint-commit.md
agent-system/extensions/core/agents/general-implementation-agent.md
agent-system/extensions/core/index-entries.json` covers this phase's declared set — run at
authoring time, it selects `test-context-reachability.sh`, `test-deploy-orphans.sh`,
`test-index-entries-schema.sh`, `test-install-uninstall-extension.sh`,
`test-lint-agent-contracts-heartbeat.sh`, `test-lint-agent-contracts.sh`,
`test-manifest-scripts-sync.sh`, `test-orchestrate-build-dispatch.sh`,
`test-orchestrate-cycle-postflight.sh` and `test-roadmap-command-registration.sh`.

**Scope Hypothesis**: the obligation fits in one paragraph of 3-5 sentences in one section of
`checkpoint-commit.md` plus exactly one pointer line in `general-implementation-agent.md`, and no
third file needs the prose. Confirm at implementation time by re-reading both sites before
editing; if the pointer cannot be placed in one line without losing a claim a reader could
previously verify, record the claim-retention ledger entry
`context/standards/anchor-pointer-convention.md` requires rather than silently expanding to a
second paragraph.

**Files to modify**:
- `agent-system/extensions/core/context/checkpoints/checkpoint-commit.md` - the obligation
  paragraph, in `### 1. Determine Targeted Scope`
- `agent-system/extensions/core/agents/general-implementation-agent.md` - one pointer line in the
  Phase Checkpoint Protocol's step 5
- `agent-system/extensions/core/index-entries.json` - coupled generated surface: this file pins
  the line count of `checkpoints/checkpoint-commit.md` (119 at planning time), which this phase's
  edit moves. The detecting check (`check-extension-docs.sh` Rule R) is **not** commit-blocking in
  this repository, so the regeneration itself is deferred to Phase 4's deploy, which auto-repairs
  it; the declaration is owed here, in the phase that moves the quantity.

**Verification**:
- Diff read-through confirming every changed hunk lies inside markdown prose, with no
  executable/front-matter surface touched.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` passes (the pointer
  edit tripped no literal-fragment predicate).
- `bash agent-system/extensions/core/scripts/lint/lint-anchor-pointer-collapse.sh` passes.
- `grep` the two edited files for `check-module-invariants`/`typst-sync-check` — zero hits
  (neither generator name entered a core file).
- `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's declared paths
  is green.

---

### Phase 2: Make a Regenerated Declared Surface Stageable at Site 2 [COMPLETED]

**Goal**: A declared derived-output path, regenerated inside a phase, survives
`git-commit-phase.sh`'s Phase-Commit Containment Self-Check instead of being dropped before the
commit sees it — mirroring the widening Containment Site 3 already carries, and inert when the
repository declares nothing.

**Tasks**:
- [x] Re-confirm the gap before editing: `grep -n "derived_probe" scripts/git-commit-phase.sh`
      returns nothing, while `grep -n "derived_probe_output_prefixes" scripts/git-commit-scoped.sh`
      returns its V10 widening. If this has changed, stop and re-scope. *(completed: confirmed
      unchanged)*
- [x] In `scripts/git-commit-phase.sh`, inside the Containment Self-Check's existing non-empty
      `file_scope_arr` guard and immediately after the engine-written-state splice, add a third
      splice: guardedly `source` `lib/derived-artifact-probe-lib.sh`, call
      `derived_probe_output_prefixes "$PROJECT_ROOT"`, validate the returned JSON is an array of
      strings exactly as the engine-written-state splice validates its own, and append each
      prefix to `file_scope_arr`. Fail open on every failure mode (missing library, missing `jq`,
      malformed output) by adding nothing — never by widening and never by refusing.
- [x] Place the splice **after** the deployed-tree strip, so the strip's invariant (a `.claude/**`
      path is never a legitimate scope member) is unaffected, and inside the non-empty guard, so a
      task with no declared `file_scope` still skips the whole check rather than acquiring a scope
      it never declared.
- [x] Update `scripts/git-commit-phase.sh`'s own header section describing the Containment
      Self-Check to name the new member alongside the two it already documents.
- [x] In `context/standards/git-staging-scope.md`'s "Three Containment sites, not one" area,
      record the derived-output member as a per-site widening and state the subsumption asymmetry
      explicitly: Site 3's identical widening does **not** rescue Site 2, for the same reason
      already recorded there for the own-task-directory member (Site 2 drops the path from its own
      `files_touched`, and therefore from the pathspec, before `git-commit-scoped.sh` is ever
      invoked).
- [x] In `context/standards/repo-level-declarations.md`'s "Containment and the Derived-Output
      Exemption" section, extend the single-site statement to name all three Containment sites
      that now splice `derived_output_dirs`.
- [x] Add two cases to `scripts/tests/test-git-commit-phase.sh`, following its existing
      `build_repo`/`write_progress`/`run_phase_commit` fixture style: (i) a fixture repo declaring
      a `derived_artifact_probes` entry whose `derived_output_dirs` covers a regenerated path that
      is **not** in the declared `file_scope` — the path is KEPT, staged, lands in the commit, and
      produces no `scope excursion` row; (ii) the identical fixture with the declaration removed —
      the same path is still dropped, warned about, issue-recorded and deposited into
      `proposed_file_scope`, byte-for-byte as before this phase (the inert case).
- [x] Confirm no task-number reference and no record-versioning language entered any edited file.
      *(completed: grep confirmed zero new task-number references; the one pre-existing "no
      longer" phrase retained verbatim from the file's existing text is a functional description,
      not new draft-history narration)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this
phase's declared set selects `test-git-commit-phase.sh` and `test-git-commit-scoped.sh` — the two
suites that own both Containment sites — alongside `test-commit-source-store-path.sh`,
`test-context-reachability.sh`, `test-deploy-orphans.sh`, `test-index-entries-schema.sh`,
`test-install-uninstall-extension.sh`, `test-manifest-scripts-sync.sh`,
`test-milestone-ref-land.sh`, `test-roadmap-command-registration.sh`,
`test-skill-base-lifecycle.sh`, `test-task-reference-patterns-lib.sh`,
`test-todo-move-pair-staging.sh` and `test-update-task-status.sh`; nothing cheaper reaches the
Self-Check's admit/drop decision.

**Scope Hypothesis**: the splice is a short block (on the order of ten lines) structurally
mirroring the engine-written-state splice directly above it, and two new fixture cases suffice to
pin both the admit and the inert case. Confirm by reading the engine-written-state splice first
and composing against its actual shape; if the mirror does not compose that compactly — for
instance if `PROJECT_ROOT` is not the right root argument at that point in the script — record the
divergence in the phase's own progress notes rather than silently restructuring the Self-Check.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-phase.sh` - the third `file_scope_arr` splice
  plus its header documentation
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - the derived-output
  member and its Site-2/Site-3 subsumption asymmetry
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` - the
  Derived-Output Exemption section now names all three Containment sites
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - the admit case and the
  inert case
- `agent-system/extensions/core/index-entries.json` - coupled generated surface: pins the line
  counts of both `standards/git-staging-scope.md` (1190 at planning time) and
  `standards/repo-level-declarations.md` (311), which this phase's edits move. Non-commit-blocking
  here, so reconciled by Phase 4's deploy; the declaration is owed in this phase.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` is green, including
  both new cases and every pre-existing case (notably the idempotence fixture, which depends on a
  repeated drop continuing to produce a fresh `issues.jsonl` row).
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` is green (Site 3
  unchanged).
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` passes.
- `bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` passes.
- The inert case is explicitly observed, not inferred: with no `derived_artifact_probes` key, the
  fixture's drop/warn/issue-record/propose behavior is unchanged.

---

### Phase 3: Add the Non-Blocking Staleness Backstop at the Phase-Commit Site [NOT STARTED]

**Goal**: A declared derived surface that is stale at a phase commit is named at that commit
rather than only at the end of the plan — detection only, never a refusal, never a build, and
nothing at all in a repository that declares no probes.

**Tasks**:
- [ ] In `scripts/git-commit-phase.sh`, guardedly `source` `lib/derived-artifact-probe-lib.sh`
      (reusing whatever source already serves Phase 2's splice rather than sourcing it twice) and
      call `derived_probe_run_all "$PROJECT_ROOT" "git-commit-phase.sh:"` once, sited **after** the
      second-repository-commit block and **before** the post-commit completeness check, so it runs
      on every path that reaches a commit — including the one that exits 6.
- [ ] On a non-zero result: emit a `warn()` in the same named style the Containment Self-Check's
      drop warning already uses, naming what the library itself printed and stating the remedy
      (re-run the surface's own regeneration entry point and land it with a scoped follow-up
      commit), and record it non-fatally via `issue-record.sh` with `--kind issue --severity minor
      --phase implement` and a class string naming derived-surface staleness. Follow the existing
      precedent in this script, whose `scope excursion` and `source store excursion` classes are
      likewise outside the seed enum (`context/formats/issue-log.md`'s extensibility rule).
- [ ] Guarantee exit-code invariance explicitly: the probe's result is captured and never
      propagated. This script's documented vocabulary (0-6, with 8/9 passthrough) is unchanged,
      and an `issue-record.sh` or probe failure never alters it.
- [ ] Document the new call at the top of `scripts/git-commit-phase.sh` as its own header
      subsection, stating the non-blocking posture, the build-free property, and that an
      undeclared repository executes no probe.
- [ ] Update `scripts/lib/derived-artifact-probe-lib.sh`'s header consumer list to name the third
      consumer and to stop asserting that its consumers are exactly the two postflight engines.
      Keep the fail-open contract text untouched.
- [ ] Add `lib/derived-artifact-probe-lib.sh` to `scripts/tests/test-git-commit-phase.sh`'s
      `REQUIRED_SCRIPTS` array **and** to `build_repo`'s sandbox copy set — the new `source` makes
      it a mandatory dependency, which is exactly the drift
      `scripts/lint/lint-fixture-dependency-declaration.sh` detects.
- [ ] Add three cases to `scripts/tests/test-git-commit-phase.sh`: (i) a fixture declaring a probe
      whose `check_command` exits non-zero — the named warning is emitted, an issue row is
      written, and the script's exit code is **identical** to the same fixture without the
      declaration; (ii) a fixture declaring a passing probe — no warning, no issue row, exit code
      unchanged; (iii) a fixture declaring no probes — no probe executed at all and output
      unchanged from the pre-phase baseline (the inert case).
- [ ] Add one case to `scripts/tests/test-derived-artifact-probe-lib.sh` pinning that
      `derived_probe_run_all` invoked with the phase-commit notice prefix is fail-open and
      build-free on an absent/empty declaration: returns 0, executes no command, emits no stderr
      noise. This is the dispatch's VERIFY condition for decision (b), pinned at the library's own
      suite rather than only at the integration site.
- [ ] Confirm no task-number reference and no record-versioning language entered any edited file.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this
phase's declared set selects `test-git-commit-phase.sh`, `test-derived-artifact-probe-lib.sh`,
`test-gate-out-derived-staleness.sh`, `test-gate-out-repair-reporting.sh`,
`test-gate-out-self-attribution.sh`, `test-orchestrate-cycle-postflight.sh` and
`test-verify-touched.sh` (plus `test-commit-source-store-path.sh`,
`test-engine-written-state-paths-lib.sh`, `test-git-commit-scoped.sh`,
`test-milestone-ref-land.sh`, `test-skill-base-lifecycle.sh`,
`test-task-reference-patterns-lib.sh` and `test-update-task-status.sh`) — covering both the new
call site and every pre-existing consumer of the library whose header this phase edits.

**Scope Hypothesis**: three new fixture cases in `test-git-commit-phase.sh` and one in
`test-derived-artifact-probe-lib.sh` cover the backstop's whole contract (fires, stays quiet,
stays inert, never moves the exit code), and no existing case needs rewriting. Confirm by running
both suites before adding anything, so any pre-existing failure is attributed correctly; if an
existing case does need changing, say which and why in the phase's progress notes rather than
adjusting a fixture to fit.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-phase.sh` - the probe call, its warning and
  issue-record handling, and its header subsection
- `agent-system/extensions/core/scripts/lib/derived-artifact-probe-lib.sh` - header consumer list
  only; no behavioral change
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - the dependency
  declaration, the sandbox copy, and the three new cases
- `agent-system/extensions/core/scripts/tests/test-derived-artifact-probe-lib.sh` - the
  phase-commit-path fail-open/build-free case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` is green, all cases.
- `bash agent-system/extensions/core/scripts/tests/test-derived-artifact-probe-lib.sh` is green.
- `bash agent-system/extensions/core/scripts/lint/lint-fixture-dependency-declaration.sh` passes
  (the new mandatory dependency is declared, not drifted).
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` passes.
- Exit-code invariance is observed directly, not asserted: the failing-probe fixture's exit code
  equals the no-declaration fixture's.
- `grep` the edited scripts for any generator-script name from a consumer repository — zero hits.

---

### Phase 4: Deploy, Verify, and Record the Companion Recommendation [NOT STARTED]

**Goal**: The source-store changes are deployed and verified, the coupled `index-entries.json`
line counts are reconciled, and the one fact that keeps this record from being a complete fix on
its own — the originating repository declares neither key — is recorded where a reader will find
it.

**Tasks**:
- [ ] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deployed tree from the
      finished source store. This is whole-tree regeneration, declared below with the reserved
      sentinel.
- [ ] Confirm the deploy's own side-effect repair of `index-entries.json`'s `line_count` fields
      landed for `checkpoints/checkpoint-commit.md`, `standards/git-staging-scope.md` and
      `standards/repo-level-declarations.md`, and that `check-extension-docs.sh` Rule R is clean.
- [ ] Run the scoped touched-path check over every path this task touched:
      `bash agent-system/extensions/core/scripts/verify-touched.sh <the declared paths from
      Phases 1-3>`. Under `/orchestrate` this is this phase's own in-dispatch obligation; the
      complete gate set is owed once per orchestration invocation and is **deferred to the
      orchestration close**, not independently re-run here. Record that deferral in the phase's
      verification notes.
- [ ] Re-read the landed prose in the deployed tree to confirm the obligation reads as one generic
      rule about declared surfaces, naming no consumer repository's generator script, and that the
      pointer in `general-implementation-agent.md` resolves to the section that actually owns it.
- [ ] Record in the implementation summary, and via a non-fatal `issue-record.sh` entry, the
      companion-record recommendation: `~/Projects/BimodalLogic`'s own
      `.claude-extensions.json` declares neither `derived_artifact_probes` nor
      `coupled_generated_surfaces` (re-derived live, confirmed at planning time), so none of this
      record's work changes the outcome of the four cited recurrences until that repository
      declares its own coupled pairs. State that the correct next action is a record created
      **in that repository**, and that creating or editing it from here is out of bounds.
- [ ] Confirm the whole task's diff carries no task-number reference and no record-versioning
      language under `agent-system/**`.

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`, an
  implicit scope claim over the entire deployed tree that no real path can express
- `agent-system/extensions/core/index-entries.json` - the coupled `line_count` reconciliation
  declared by Phases 1 and 2, landing here as the deploy's own side-effect repair

**Verification**:
- `deploy-headless.sh` exits 0 and its inline `verify-deploy.sh` pass reports no failure.
- `bash agent-system/extensions/core/scripts/verify-touched.sh <this task's touched paths>` is
  green; the complete gate set is explicitly deferred to the orchestration close rather than
  invoked a second time here.
- The deployed `.claude/context/checkpoints/checkpoint-commit.md` and
  `.claude/agents/general-implementation-agent.md` carry the landed prose and pointer.
- The companion-record recommendation is present in the summary and in `issues.jsonl`.

---

## Testing & Validation

- [ ] A declared derived-output path, regenerated mid-phase, is staged by `git-commit-phase.sh`
      rather than dropped (Phase 2, admit case).
- [ ] With no declaration, the identical path is still dropped, warned about, issue-recorded and
      proposed back into `file_scope` — unchanged behavior (Phase 2, inert case).
- [ ] A declared, failing probe at a phase commit produces a named warning and an issue row, and
      does not change the script's exit code (Phase 3).
- [ ] A repository declaring no probes executes no probe and sees no new output (Phase 3, inert
      case).
- [ ] `derived_probe_run_all` called with the phase-commit notice prefix is fail-open and
      build-free on an absent/empty declaration (Phase 3, library suite).
- [ ] `lint-agent-contracts.sh`, `lint-anchor-pointer-collapse.sh`,
      `lint-fixture-dependency-declaration.sh`, `lint-shellcheck.sh` and
      `lint-scoped-commit-boundary.sh` all pass.
- [ ] No core file names any consumer repository's generator script.
- [ ] No file under `agent-system/**` gained a task-number reference or record-versioning
      language.

## Artifacts & Outputs

- The obligation paragraph in `context/checkpoints/checkpoint-commit.md`, plus a one-line pointer
  in `agents/general-implementation-agent.md`.
- A third `file_scope_arr` splice and a non-blocking probe call in `scripts/git-commit-phase.sh`,
  with both documented in its header.
- Consumer-list correction in `scripts/lib/derived-artifact-probe-lib.sh` (header only).
- Narrative updates in `context/standards/git-staging-scope.md` and
  `context/standards/repo-level-declarations.md`.
- Five new fixture cases in `scripts/tests/test-git-commit-phase.sh` and one in
  `scripts/tests/test-derived-artifact-probe-lib.sh`.
- A regenerated deployed tree and reconciled `index-entries.json` line counts.
- An implementation summary recording the companion consumer-repo recommendation.

## Rollback/Contingency

Every component is additive and independently revertible by phase commit. The prose obligation
(Phase 1) is revertible by reverting two markdown edits with no behavioral consequence. The Site-2
splice (Phase 2) and the probe call (Phase 3) each sit inside their own guarded block in one
script; reverting either commit restores the previous behavior exactly, and both are already
no-ops in a repository that declares nothing, so the blast radius of leaving one in place while
reverting the other is bounded. If Phase 2's splice turns out to interact badly with the
Containment Self-Check's fail-open posture, revert that phase alone and keep Phases 1 and 3 — the
rule and the backstop still stand, with the honest caveat that a regenerated path then needs an
explicit `file_scope` declaration to be stageable. Before any intentional rollback that would
discard uncommitted work, take a snapshot first
(`bash .claude/scripts/git-snapshot.sh 517`); for an ordinary defensive checkpoint during risky
work, use `--no-revert`.
