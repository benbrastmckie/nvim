# Implementation Plan: Task #628

- **Task**: 628 - Retract sapience write-tool grants from deployed repositories
- **Status**: [NOT STARTED]
- **Effort**: 6 hours
- **Dependencies**: task 527 (`[COMPLETED]`) — its Check E supplies a *pattern*, not retraction machinery; no blocking edge
- **Research Inputs**: specs/628_retract_sapience_write_tool_grants/reports/01_retract-sapience-write-grants.md
- **Artifacts**: plans/01_retract-sapience-write-grants.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The sapience extension's `settings-fragment.json` narrowed its permission grant to seven
read-shaped `mcp__sapience__*` tools, but five deployed repositories still carry eleven,
including all four MCP write tools. The cause is a sequencing gap, not a missing mechanism:
`manager.load`'s forced-reload branch — the only branch `deploy-headless.sh`'s default
`manager.resync_all` path ever exercises — merges the current fragment without first unmerging
the extension's own previously-recorded `merged_sections`. The retraction primitive
(`merge.unmerge_settings`), its sibling-retention guard (`build_retained_fragments`), and the
prior-record reader (`state.get_merged_sections`) all already exist and are already exercised by
`manager.unload`. This plan wires them into the forced-reload branch via the existing
`reverse_merge_targets` helper, adds rollback symmetry mirroring the existing
`settings_swept`/`restore_removed_hook_registrations` precedent, covers the new semantics with
regression tests, truths up the two surfaces that currently assert the retraction already works,
and remediates all five repositories by redeploying rather than by a hand-written migration.

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class line the dispatch flagged was re-measured live during this planning pass.

| Dispatch claim | Live result | Verdict |
|----------------|-------------|---------|
| `settings-fragment.json` grants exactly 7 read-shaped tools, no write tools | 7 grants, exact names match the dispatch's list | **Confirmed unchanged** |
| All five named repositories grant 11, including all four write tools | `.dotfiles` 11, `.config/nvim` 11, `BimodalLogic` 11, `sf1-engine` 11, `sapience-app` 11 — 5 of 5 | **Confirmed unchanged** |
| `verify-sapience-mcp.sh` check (e) fails here with "11/7 sapience grants" and labels it a known pre-existing residual | Check (e) body (`verify-sapience-mcp.sh:284-298`) compares `GRANT_COUNT -eq 7` and emits exactly that NOTE on failure; header lines 36-40 carry the same caveat | **Confirmed unchanged** |
| `rules/sapience-write-path.md` asserts a write-tool call "now raises an interactive permission prompt ... denied outright in a headless/autonomous run" | Source at `agent-system/extensions/sapience/rules/sapience-write-path.md`, "The Permission Grant Matches the Standing Contract" section, plus the residual caveat at lines 71-74 | **Confirmed unchanged; the assertion is false in all five repos** |
| The merge engine is additive-only and cannot retract | `deep_merge` (`merge.lua:376-456`) is additive-only, confirmed; but `M.unmerge_settings` (`merge.lua:517-653`) *is* a working retraction primitive, reached only from `manager.unload` | **Partially corrected** — retraction exists; its call-site coverage, not its existence, is the gap |

One **correction to the research report**, material to where the implementer looks: the report
states this repository's `.claude-extensions.json` tracks the 7 grants at
`extensions.sapience.merged_sections.settings.permissions.allow.items`. The actual path is
`extensions.sapience.merged_sections.settings.permissions.children.allow.items` (a `children`
level the report's prose omitted). The substantive claim is confirmed exactly as stated — that
array holds precisely the 7 current grants with `type: "appended"`, while
`.claude/settings.local.json` holds 11 — but a jq filter copied from the report's prose returns
empty. Use the `children` path.

Two further facts established during this pass that the report did not state:

- The `.claude/settings.json` grant count for `mcp__sapience__*` is **0**; all sapience grants
  live in `.claude/settings.local.json`, which is what `manifest.json`'s
  `merge_targets.settings.target` names. The retraction therefore operates on
  `settings.local.json`, and task 527's Check E (whose D6 ruling puts
  `root-files/settings.local.json` out of scope for every check) genuinely cannot see this file.
- Exactly **two** source-store surfaces carry the now-false residual caveat:
  `rules/sapience-write-path.md` and `scripts/verify-sapience-mcp.sh`. `EXTENSION.md`'s only
  "residual"/"narrowed" matches belong to the unrelated primary-session content-scoping residual
  and must not be touched.

### Research Integration

The plan adopts the research report's Recommendation 1 (generalized merge-engine retraction in
`manager.load`'s forced-reload branch) and Recommendation 2 (redeploy *is* the remediation; no
migration script). It adopts Recommendation 3 (rewrite the caveat) and extends it to the second
surface the report did not enumerate. It adopts Recommendation 4 (leave task 527's lint and
Gate 21 untouched) and does **not** build a permissions-SET detection check. It takes up the
report's Context Extension Recommendation as Phase 4 work, because the three-way mechanism map
(unload-only retraction, hooks-only load-time sweep, `resync_all`'s never-unloads invariant) is
exactly what made this bug invisible and is currently recoverable only by reading Lua.

The report's two ruled-out routes are accepted as ruled out and are not re-derived:
`deploy-headless.sh --wipe` round-trips `settings.local.json` byte-for-byte through
`settings_backup`, and a task-369-style permissions orphan sweep is strictly inferior to
`unmerge_settings` for a forced reload, where the extension's own prior record is already on disk.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap consultation was
performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- `manager.load`'s forced-reload branch retracts every merge-target entry the extension's own
  prior `merged_sections` recorded but its current fragment no longer declares — uniformly across
  every `settings`/`mcp` key, not permissions-only.
- A hand-added grant a user owns in `settings.local.json`, and a grant a *sibling* loaded
  extension's fragment still declares, both survive the retraction.
- A failed forced load restores what the pre-merge retraction removed, mirroring the existing
  `settings_swept` rollback precedent.
- All five named repositories grant exactly the seven read-shaped sapience tools and none of the
  four write tools; `verify-sapience-mcp.sh` check (e) passes in this repository.
- Both source-store surfaces that currently assert or excuse the residual state reality.
- A fresh load into a sixth repository still produces the seven-tool grant directly.

**Non-Goals**:

- A permissions-SET detection check inside `lint-hook-registration-paths.sh`, or any change to
  task 527's Check E or `verify-deploy.sh` Gate 21. Explicitly deferred (research
  Recommendation 4); a follow-up task may take it up.
- A hand-written one-time migration script over the five `settings.local.json` files. Redeploy is
  the remediation.
- Any use of `deploy-headless.sh --wipe`. Ruled out: `settings_backup` round-trips the stale file
  unchanged.
- Changing `deep_merge`'s additive-only record-everything semantics, which is load-bearing for
  unload and must stay as it is.
- Any git push, PR, or branch operation in the four out-of-tree target repositories.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The pre-merge unmerge perturbs `hooks` as well as `permissions`, since it now runs for every extension on every forced reload | H | M | Phase 1 captures a per-repo `jq -S '{hooks, permissions}'` fingerprint of every target's `settings.local.json` and `settings.json` before the change; Phase 5 re-captures and diffs. The only sanctioned delta is the four sapience write grants disappearing. Any `hooks` delta fails the phase. |
| A failed forced load leaves the retracted entries gone (no rollback symmetry) | H | M | Phase 2 records what the pre-merge unmerge removed into `merged_sections` and restores it on the rollback path, mirroring the existing `settings_swept`/`restore_removed_hook_registrations` pair at `init.lua:879-881` verbatim rather than inventing a second shape. |
| `build_retained_fragments` returns `skip_removal = true` (unreadable sibling manifest/fragment), silently suppressing retraction | M | M | That inverted fail-safe is correct and must be preserved, not bypassed. Phase 2 threads `opts.skip_array_removal` exactly as `manager.unload` does and emits a pcall-guarded INFO notification naming the suppression, so a silently skipped retraction is observable in deploy output rather than mistaken for a successful one. |
| A user-typed grant byte-identical to a fragment-declared string gets removed | L | L | Pre-existing and unchanged: `remove_tracked` visits only keys present in the passed tracked structure, so an untracked hand-added grant is never a candidate. The byte-identical-collision edge is already accepted by today's unload path; this task exercises the same rule from a new call site and introduces no new exposure. Phase 3 pins both halves as tests. |
| One of the four out-of-tree repositories is unreachable or dirty at Phase 5 | M | L | All five were reachable during this planning pass. Phase 5 treats each as an independent read-and-deploy target, runs no git operation in any of them, and records a per-repo result line; an unreachable repo is reported as an explicit exclusion rather than silently skipped. |
| `deploy-headless.sh` cannot be smoke-tested from the source store (`deploy-root-guard.sh` refuses) | M | M | Phase 3's integration case runs against a scratch deployed-tree-shaped fixture, and Phase 5's real verification runs only after a real `deploy-headless.sh` pass. No phase names a literal source-store invocation of a guard-protected script as its verification step. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Pin the pre-change baseline across all five repositories [NOT STARTED]

**Goal**: Capture a durable, re-diffable fingerprint of every target repository's merged settings
and every loaded extension's tracked record, so Phase 5 can prove the change removed exactly the
four sapience write grants and perturbed nothing else.

**Tasks**:

- [ ] For each of the five repositories (`/home/benjamin/.dotfiles`,
      `/home/benjamin/.config/nvim`, `/home/benjamin/Projects/BimodalLogic`,
      `/home/benjamin/Projects/Sapience/sf1-engine`,
      `/home/benjamin/Projects/Sapience/sapience-app`), record into the records file: the
      `mcp__sapience__*` grant count and the sorted grant list from
      `.claude/settings.local.json`; and `jq -S '{hooks, permissions}'` piped to `sha256sum` for
      both `.claude/settings.local.json` and `.claude/settings.json`.
- [ ] For each repository, record `jq -S '.extensions | to_entries | map({key, merged_sections})'`
      from its own `.claude-extensions.json`, so the prior tracked record Phase 2's retraction
      will read is pinned before any reload touches it.
- [ ] Record, for this repository, the sorted grant list from
      `agent-system/extensions/sapience/settings-fragment.json`, and the set difference
      (deployed minus fragment) that Phase 5 must find empty.
- [ ] Note in the records file the exact tracked-record jq path
      (`.extensions.sapience.merged_sections.settings.permissions.children.allow.items`),
      including the `children` level, so no later phase re-derives it.
- [ ] Run `bash .claude/scripts/issue-record.sh` for any repository that is unreachable or whose
      `.claude/settings.local.json` is absent, and record the exclusion in the records file.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: The phase writes one `specs/**` records file and runs only read-only
`jq`/`sha256sum` probes against other repositories, so the `prose` row's diff read-through plus
`bash .claude/scripts/validate-artifact.sh` on the records file is the full covering check
(`suite_selection_select` returns `__FULL_SWEEP__` for a `specs/**` path, sub-case (a)).

**Scope Hypothesis**: All five repositories currently carry exactly 11 `mcp__sapience__*` grants
and are reachable on this machine — measured live during this planning pass. The implementer
confirms each count at capture time rather than copying this figure; a repository that has since
been hand-edited to 7, or that is unreachable, is recorded as such in the records file and
carried forward to Phase 5's expectations rather than treated as a plan error.

**Files to modify**:

- `specs/628_retract_sapience_write_tool_grants/records/01_pre-change-baseline.md` - create; the
  per-repo grant lists, `{hooks, permissions}` fingerprints, tracked-record snapshots, and any
  reachability exclusions.

**Verification**:

- The records file exists, is non-empty, and carries one block per repository with both a grant
  list and both fingerprint hashes (or an explicit exclusion line).
- Diff read-through of the records file confirms every number in it was produced by a command run
  in this dispatch, not carried from this plan's text.

---

### Phase 2: Wire forced-reload retraction into `manager.load` [NOT STARTED]

**Goal**: Make a forced reload retract what the extension's own prior `merged_sections` recorded
and its current fragment no longer declares, reusing the existing primitives verbatim, with
rollback symmetry and a visible fail-safe suppression notice.

**Tasks**:

- [ ] In `manager.load`, inside the existing load `pcall` and after `updated_state`/`loaded_names`
      are read (currently `init.lua:786-790`), add a forced-reload retraction block gated on
      `state_mod.is_loaded(state, extension_name)` AND `opts.force` — so a first-time load, which
      has no prior record, is untouched.
- [ ] In that block, read the prior record via
      `state_mod.get_merged_sections(updated_state, extension_name)`. This must happen before
      `process_merge_targets` runs (currently `init.lua:846`) and therefore before
      `state_mod.mark_loaded`/`state_mod.write` overwrite it (currently `init.lua:895-896`);
      confirm that ordering holds in the file as found rather than assuming these line numbers.
- [ ] Build the sibling-retention data with the existing
      `build_retained_fragments(ext_manifest.merge_targets.settings.target, extension_name,
      loaded_names, config)`, and on `skip_removal == true` pass `opts.skip_array_removal = true`
      through rather than bypassing the guard.
- [ ] Call the existing `reverse_merge_targets(ext_manifest, prior_merged_sections, project_dir,
      config, { retained_fragments = ..., skip_array_removal = ... })`, not a new removal path.
      Confirm it covers both the `settings` and `mcp` targets and skips the `index` target, whose
      staleness is already handled by the pre-load `remove_orphaned_index_entries` cleanup
      immediately above.
- [ ] Record what the retraction removed so the rollback path can restore it, mirroring the
      existing `merged_sections.settings_swept` / `restore_removed_hook_registrations` pair
      (currently `init.lua:252` and `init.lua:879-881`). If `merge.lua` needs a restore entry
      point for the permissions/array shape that `restore_removed_hook_registrations` does not
      cover, add it beside that function using the same signature shape, and do not generalize
      the hook-specific one.
- [ ] Extend the rollback block (currently `init.lua:874-881`) to perform that restore, so a
      failed forced load does not leave the retracted entries gone.
- [ ] Emit a pcall-guarded `helpers.notify(..., "INFO")` line naming the extension whenever
      retraction is suppressed by the `skip_removal` fail-safe, matching the existing
      hook-sweep skip notices' wording and guard style, so a suppressed retraction is visible in
      deploy output.
- [ ] Update the doc comments on `reverse_merge_targets` and on `manager.load`'s `opts.force`
      paragraph (currently `init.lua:505-516`, which asserts everything downstream of the
      already-loaded abort "is already idempotent/overwrite-safe ... so no further special-casing
      is needed") so they describe the retraction step. Leave `deep_merge`'s own additive-only
      comment and `manager.resync_all`'s "never unloads" comment factually intact — both remain
      true; what changed is that `manager.load` now retracts before merging.

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: full

**Tier Justification**: `manager.load` is the single load path every extension's settings and
MCP merge passes through in every deployed repository, so a regression here silently strips a
sibling extension's grants or hook registrations tree-wide — a cross-cutting surface none of the
three suites `suite_selection_select` maps `init.lua` to (`test-deploy-orphans.sh`,
`test-deploy-verify-overlap.sh`, `test-mcp-merge-target.sh`) covers on its own.

**Files to modify**:

- `lua/neotex/plugins/ai/shared/extensions/init.lua` - the forced-reload retraction block in
  `manager.load`, the rollback restore, the suppression notice, and the two doc-comment updates.
  This file is genuine Neovim plugin source in this repository, **not** a `.claude/**` deploy
  artifact, so `rules/source-store-deploy-boundary.md` does not redirect it; the dispatch's
  "source store is the edit target" instruction names `agent-system/extensions/core/**` because
  it assumed the merge engine lived there, and the research report established it does not.
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - only if a restore entry point for the
  array/permissions shape is needed; no change to `deep_merge` or `unmerge_settings` themselves.

**Verification**:

- `nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua" -c qa`
  passes with no new failures (pre-existing failures, if any, recorded in Phase 1's records file
  as the baseline).
- `bash .claude/scripts/verify-deploy.sh` passes (the complete gate set for this repository).
- A forced reload of sapience into a scratch deployed-tree-shaped fixture (not the source store —
  `deploy-root-guard.sh` refuses a source-store invocation) retracts the four write grants and
  leaves the fixture's `{hooks}` fingerprint byte-identical.

---

### Phase 3: Regression coverage for the retraction semantics [NOT STARTED]

**Goal**: Pin the four behaviors that must hold, so a future reader cannot reintroduce the gap or
over-correct it into clobbering a grant someone owns.

**Tasks**:

- [ ] Add `merge_spec.lua` cases, beside the existing "permission array tracking" describe block,
      for: (a) a narrowed fragment — merge a wide fragment, then unmerge with that merge's own
      tracked data and re-merge a narrower fragment, asserting the dropped items are gone;
      (b) sibling retention — the same sequence with `opts.retained_fragments` carrying a second
      extension's fragment that still declares one dropped item, asserting that item survives;
      (c) hand-added survival — a grant present in the target but absent from every tracked
      structure survives the retraction untouched.
- [ ] Add an integration case to
      `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` covering the
      sequencing the unit tests cannot reach, since the retraction lives in `manager.load` rather
      than in `merge.lua`: a scratch deployed-tree-shaped fixture with a stale wide
      `settings.local.json` and a tracked record matching it, force-reloaded against a narrowed
      fragment, asserting the deployed file converges on the narrow set while its `hooks` key is
      byte-identical before and after.
- [ ] Add a rollback case asserting that a forced load made to fail after the retraction restores
      the retracted entries, exercising the Phase 2 rollback path rather than only its happy path.
- [ ] Keep every new case inside the existing describe/test-function conventions of each file;
      add no new test runner and no new fixture-generation script.

**Timing**: 1.75 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --only test-consumer-freshness.sh,test-deploy-freshness.sh,test-deploy-orphans.sh,test-deploy-propagation.sh,test-run-all-shared-fixture.sh`
plus the `PlenaryBustedFile merge_spec.lua` run together cover both touched paths exactly — these
are the suite names `suite_selection_select` returns for
`agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` and for
`merge_spec.lua` respectively.

**Files to modify**:

- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` - three new cases in the permission
  array tracking area.
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` - the forced-reload
  convergence case and the rollback case. This path already exists and is the file the deployed
  `.claude/scripts/tests/test-deploy-propagation.sh` is generated from; if it has been moved or
  renamed by the time this phase runs, the implementer locates the current source-store home of
  the deploy-propagation suite and extends that, rather than creating a parallel suite.

**Verification**:

- The `--only` invocation above passes with every new case green.
- `nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua" -c qa`
  passes with the three new cases green.
- Each new case is confirmed to actually fail against the pre-Phase-2 engine (temporarily, by
  stashing nothing and instead reasoning from the asserted values), or its assertion is tightened
  until it would — a case that passes both before and after the change pins nothing.

---

### Phase 4: Truth up the two caveat surfaces and record the mechanism map [NOT STARTED]

**Goal**: Make the two surfaces that currently assert or excuse the residual state reality, and
leave a durable record of the three-way retraction-mechanism map whose absence let this gap hide.

**Tasks**:

- [ ] In `agent-system/extensions/sapience/rules/sapience-write-path.md`, rewrite the residual
      caveat paragraph (currently the last paragraph of "The Permission Grant Matches the Standing
      Contract", beginning "A repository that loaded sapience before this grant was narrowed").
      Replace it with a statement that a forced reload or a `deploy-headless.sh` resync now
      retracts a narrowed grant from an already-loaded repository, that `deep_merge` itself
      remains additive-only by design, and that retraction is a separate step in
      `manager.load`'s forced-reload branch. Keep the preceding paragraph's permission-prompt
      assertion, which the rest of this plan makes true. Write no version or supersession
      language, per `rules/no-record-versioning-in-deliverables.md`, and cite durable anchors
      (function names, section headings) rather than task numbers, per
      `rules/no-task-references-in-deliverables.md`.
- [ ] In `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`, rewrite the two
      caveat sites: the header's check-(e) description (currently lines 36-40) and the
      failure-branch `NOTE:` block (currently lines 292-295). A count above 7 is now real drift,
      not a known residual, so the NOTE should direct the reader to run `deploy-headless.sh`
      against the repository rather than excuse the count. Do not change check (e)'s predicate,
      its expected count of 7, or its hook-key assertion.
- [ ] Add a subsection to
      `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md`
      naming, by durable function name only: `M.unmerge_settings` and `build_retained_fragments`
      (retraction, previously unload-only, now also reached from `manager.load`'s forced-reload
      branch); `state.get_merged_sections` (the prior-record reader); the hook-registration orphan
      sweep (load-time but scoped to `hooks` only); `manager.resync_all`'s "never unloads"
      invariant; and `settings_backup`'s byte-for-byte round-trip, which is why `--wipe` cannot
      substitute for retraction.
- [ ] Leave `EXTENSION.md` untouched. Its "residual"/"narrowed" matches belong to the unrelated
      primary-session content-scoping residual, confirmed during planning.
- [ ] Make no change to `lint-hook-registration-paths.sh`, `verify-deploy.sh` Gate 21, or any
      other lint — explicitly out of scope per Goals.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` over this phase's four
declared paths (no suite covers the union), so the honest covering check is the source-store
sub-case (b) gate subset `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
alongside the `local` row's diff read-through.

**Scope Hypothesis**: Exactly two source-store surfaces carry the residual caveat
(`rules/sapience-write-path.md` and `scripts/verify-sapience-mcp.sh`), established by
`grep -rln "additive-only\|pre-existing residual\|narrowed" agent-system/extensions/sapience/`
during this planning pass, whose third hit (`EXTENSION.md`) was inspected and found unrelated.
The implementer re-runs that grep before editing and extends the task list to any surface it
newly names, rather than treating the two-surface count as closed.

**Files to modify**:

- `agent-system/extensions/sapience/rules/sapience-write-path.md` - correct; the residual caveat
  paragraph. Confirmed present at authoring time. If the paragraph has already been rewritten by
  the time this phase runs, the implementer verifies the current text states the
  retraction-now-works design and records the no-op rather than re-editing.
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` - correct; the header
  check-(e) description and the failure-branch NOTE. Confirmed present at authoring time. If the
  NOTE is already gone, verify the predicate still asserts 7 and record the no-op.
- `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md` -
  amend; the new mechanism-map subsection. Confirmed present at authoring time (205 lines). If
  absent, create the subsection as a new sibling narrative file under the same directory and name
  it in the records file.
- `agent-system/extensions/core/index-entries.json` - declare and reconcile; the narrative file's
  indexed `line_count` entry (currently 205, matching the file exactly) moves when the subsection
  is added. `check-extension-docs.sh` Rule R is not commit-blocking in this repository and
  `deploy-headless.sh` auto-repairs the field, so reconciliation may land with Phase 5's
  redeploy; the declaration is owed here regardless.

**Verification**:

- `grep -n "additive-only\|pre-existing residual" agent-system/extensions/sapience/rules/sapience-write-path.md agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`
  returns no line that excuses a count above 7 as expected.
- The `--only-gate 3,4` invocation named in the Tier Justification exits 0.
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` exits 0 — the
  suite `suite_selection_select` returns for `verify-sapience-mcp.sh` taken on its own, run as an
  additional targeted check beyond the tier's own covering gate subset.
- Diff read-through confirms no task-number reference and no version/supersession language in any
  of the three markdown/script edits.

---

### Phase 5: Redeploy all five repositories and close the acceptance criteria [NOT STARTED]

**Goal**: Land the remediation in every named repository, prove the only delta is the four
sapience write grants disappearing, and confirm a fresh load still yields seven.

**Tasks**:

- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` against this repository
      first, then once per out-of-tree target with the repository root as `TARGET_REPO`. Capture
      each run's output. Do not pass `--wipe`.
- [ ] After each run, record the repository's `mcp__sapience__*` grant count and sorted grant
      list, and re-capture its `jq -S '{hooks, permissions}' | sha256sum` fingerprints for both
      `settings.local.json` and `settings.json`.
- [ ] Diff every fingerprint against Phase 1's baseline. The only sanctioned delta is the
      `settings.local.json` `permissions` hash changing in exactly the direction of the four
      write grants being removed. Any `hooks` delta, or any change to a non-sapience grant, halts
      the phase and is recorded via `issue-record.sh` before anything else proceeds.
- [ ] Run `bash .claude/scripts/verify-sapience-mcp.sh` in this repository and confirm check (e)
      passes with "all 7 permission grants and all 5 hooks".
- [ ] Confirm the fresh-load criterion: load the sapience extension into a scratch
      deployed-tree-shaped fixture that has never carried it, and assert the resulting
      `settings.local.json` holds exactly the seven read-shaped grants. This stands in for the
      dispatch's "a sixth repository" without creating one.
- [ ] Confirm `agent-system/extensions/core/index-entries.json`'s `line_count` for the narrative
      file now matches that file, repaired by the redeploy; if the redeploy did not repair it,
      correct the field directly.
- [ ] Record one result line per repository, including any repository excluded for
      unreachability, and record a win or issue entry via `issue-record.sh` reflecting how the
      redeploy pass actually went.

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: Five repositories are in scope and all five were reachable during this
planning pass. The implementer re-checks reachability per repository at deploy time against
Phase 1's recorded set; a repository Phase 1 already excluded is reported as an explicit
exclusion in the summary rather than silently dropped, and the acceptance claim is stated over
the repositories actually deployed to.

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, which regenerates the entire
  deployed `.claude/` tree in each target repository; the reserved sentinel declares that
  whole-tree claim, which no real declared path can express.
- `agent-system/extensions/core/index-entries.json` - reconcile the narrative file's `line_count`
  if the redeploy did not repair it.
- `specs/628_retract_sapience_write_tool_grants/records/01_pre-change-baseline.md` - append the
  post-change per-repo results and the fingerprint diff verdicts beside their baselines.

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` passes in this repository (the complete gate set, with
  no `--skip-slow` and no `--only-gate` narrowing).
- `bash .claude/scripts/verify-sapience-mcp.sh` passes check (e) in this repository.
- Every deployed repository reports exactly 7 `mcp__sapience__*` grants, with the four write
  tools absent from each — confirmed by the recorded sorted grant lists, not by the count alone.
- Every repository's `{hooks}` fingerprint for both settings files is byte-identical to its
  Phase 1 baseline.
- The fresh-load fixture yields exactly the seven read-shaped grants.

---

## Testing & Validation

- [ ] `merge_spec.lua`'s three new cases (narrowed-fragment retraction, sibling retention,
      hand-added survival) pass under `PlenaryBustedFile`.
- [ ] `test-deploy-propagation.sh`'s new forced-reload convergence case and rollback case pass.
- [ ] `bash .claude/scripts/tests/run-all.sh` passes with no new failures against Phase 1's
      recorded baseline.
- [ ] `bash .claude/scripts/verify-deploy.sh` passes in this repository.
- [ ] `bash .claude/scripts/verify-sapience-mcp.sh` check (e) passes.
- [ ] All five (or all reachable) repositories report exactly the seven read-shaped sapience
      grants and none of the four write tools.
- [ ] Every repository's `{hooks}` fingerprint is unchanged from the Phase 1 baseline.
- [ ] A fresh load into a never-loaded fixture yields exactly seven grants.
- [ ] No task-number reference and no version/supersession language in any non-`specs/**` edit.

## Artifacts & Outputs

- `specs/628_retract_sapience_write_tool_grants/records/01_pre-change-baseline.md` — per-repo
  before/after grant lists, settings fingerprints, tracked-record snapshots, exclusions, and the
  fingerprint diff verdicts.
- A forced-reload retraction step in `manager.load` with rollback symmetry and a visible
  fail-safe suppression notice.
- Three new `merge_spec.lua` cases and two new `test-deploy-propagation.sh` cases.
- A corrected `rules/sapience-write-path.md` caveat and a corrected
  `verify-sapience-mcp.sh` check-(e) narrative.
- A mechanism-map subsection in `source-store-deploy-boundary-narrative.md`.
- Five redeployed `.claude/` trees, each granting exactly the seven read-shaped sapience tools.

## Rollback/Contingency

The engine change is confined to `manager.load`'s forced-reload branch plus an optional restore
entry point in `merge.lua`; reverting those two files and rerunning `deploy-headless.sh` restores
the prior additive-only behavior exactly, at the cost of the eleven-grant residual returning. The
documentation and test edits are independently revertible and carry no runtime effect.

If Phase 5's fingerprint diff shows any `hooks` delta, the correct response is to halt before
deploying to further repositories, record the delta via `issue-record.sh`, and treat the
retraction's uniform-across-all-keys scope as the suspect — narrowing it to the `permissions` key
is the fallback design, strictly inferior but sufficient for this task's acceptance criteria, and
should be taken only on measured evidence that the uniform form perturbs hooks.

If a defensive checkpoint is wanted before Phase 2's engine edit, use
`bash .claude/scripts/git-snapshot.sh 628 --no-revert`, which is durable without reverting the
working tree. The default reverting form belongs only to a genuine rollback.
