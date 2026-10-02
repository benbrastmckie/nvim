# Implementation Summary: Task #309

- **Task**: 309 - Replace directory pathspecs with explicit file lists at the three task-commit sites
- **Status**: [COMPLETED]
- **Started**: 2026-10-02T00:00:00Z
- **Completed**: 2026-10-02T03:40:00Z
- **Effort**: ~4.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_explicit-file-list-pathspecs.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Every `bash .claude/scripts/git-commit-scoped.sh ... -- specs/` (and `-- .memory/`) call site in
the source store staged its entire shared directory, so a concurrent `/orchestrate` session's
in-progress artifact writes could be swept into whichever session committed next (the mode-1b
bleed). All such bare shared-directory pathspecs were replaced with explicit file lists (static
where the write set is fixed, or a `stage_paths` bash-array accumulator where it is inherently
dynamic), and a new standalone regression lint plus fixture test now guard against the pattern
regrowing.

## What Changed

- `agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh` — new. Three-layer
  lint (candidate window / structural classifier / file-level allowlist) detecting a bare
  shared-directory pathspec passed to `git-commit-scoped.sh`, with a deliberate carve-out for the
  sanctioned task-scoped directory form (`${...}` interpolation, `{N}`/`{NNN}` placeholder, or a
  literal `/[0-9]+_` already-substituted task-number directory segment).
- `agent-system/extensions/core/scripts/tests/test-lint-directory-pathspec-boundary.sh` — new.
  14-case both-polarity fixture test (3 negative, 6 positive/control, 5 verbose/quiet/allowlist).
- `agent-system/extensions/core/manifest.json` — registered both new scripts in `provides`.
- `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md` — Task Commit recipe: explicit
  list + `--honest-index-rows {N}`.
- `agent-system/extensions/core/agents/meta-builder-agent.md` — Stage 6 commit: explicit list +
  inline `--honest-index-rows` omission note.
- `agent-system/extensions/core/skills/skill-meta/SKILL.md` — postflight commit: explicit list.
- `agent-system/extensions/core/commands/task.md` — both commit sites (Step 7, review/spawn
  follow-up): explicit list.
- `agent-system/extensions/core/commands/todo.md` — Step 5 now builds a `stage_paths` bash-array
  accumulator through its own sub-steps (archive/state.json, moved directories, orphans,
  misplaced directories, conditional `specs/ROADMAP.md`, vault rotation's rename pair); Step 6's
  7 occurrences (1 multi-line + 6 message-variant examples) all reference
  `"${stage_paths[@]}"`.
- `agent-system/extensions/epidemiology/commands/epi.md`,
  `agent-system/extensions/present/commands/{grant,slides,timeline}.md` — task-creation (and
  grant's revision) commits: explicit list.
- `agent-system/extensions/core/context/standards/git-safety.md` — extra finding (beyond the
  task's named 9-file inventory): the "Example: /todo Command" CreateFinalCommit stage used a
  bare `specs/archive/` inconsistent with its own sibling safety-commit stage; fixed to the same
  explicit `specs/archive/state.json` plus a `{moved_directory_paths}` placeholder.
- `agent-system/extensions/memory/skills/skill-learn/SKILL.md` — extra finding: the Git Commit
  (Postflight) stage used a bare `.memory/`; fixed to the three always-regenerated indexes plus a
  new `touched_memory_paths` accumulator, with tracking notes added at each UPDATE/EXTEND/CREATE
  operation's write step.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — added a cross-reference
  bullet for the new lint, naming it not-yet-wired as a `verify-deploy.sh` gate with the
  critical-path-exclusion reason.

## Decisions

- **Scope widened from 17/9 to 19/11**: the lint's own first full-tree run found 2 additional real
  violations beyond the plan's named inventory (`context/standards/git-safety.md:365`,
  `memory/skills/skill-learn/SKILL.md:1060`) plus 1 false-positive raw hit
  (`docs/examples/research-flow-example.md:239`, a worked example with a concrete,
  already-substituted task number written with a literal `...` ellipsis). The false positive was
  fixed by broadening the lint's own classifier (recognizing `/[0-9]+_` as a task-scoped
  directory-segment form) rather than editing the example doc; the two real violations were fixed
  because they are squarely in scope of the task's closing requirement and neither touches an
  orchestrator-critical path.
- **`commands/todo.md`'s and `skill-learn/SKILL.md`'s write sets are inherently dynamic** (which
  directories move, whether the roadmap or a vault rotation fire; which memory files a given
  `/learn` run touches), so both recipes now build a bash-array accumulator through their own
  steps rather than a fixed enumerated list.
- **`specs/CHANGE_LOG.md`**, named in the plan's Scope Hypothesis for `commands/todo.md`'s write
  set, does not apply: that file belongs to the separate OpenCode-oriented `skill-todo/SKILL.md`,
  never written by the actual Claude Code `/todo` command. The real conditionally-written file is
  `specs/ROADMAP.md` (Step 5.5), added to the accumulator instead.
- **Vault rotation** (`commands/todo.md` Step 5.7, rare: >1000 tasks) moves the entire
  `specs/archive/` tree to `specs/vault/{NN}-vault/`. Staged as the exact rename pair
  (`specs/archive` + `"${vault_path}/"`), verified empirically that `git add` on both the
  now-removed old path and the new path records it as a rename — not a bare directory sweep,
  since it is exactly the two paths one `mv` touched.

## Plan Deviations

- **Task 1.1** altered: true violation count is 19 across 11 files, not the plan's hypothesized
  17 across 9 (2 extra real violations found; 1 raw hit was a lint false positive, fixed in the
  lint itself).
- **Task 3.2** altered: `commands/todo.md`'s archival write set implemented as a `stage_paths`
  accumulator, not a static list; `specs/CHANGE_LOG.md` does not apply, `specs/ROADMAP.md` does.
- **Task 3 (extra)** altered: 2 additional files fixed beyond the plan's named scope
  (`git-safety.md`, `skill-learn/SKILL.md`).
- **Task 4 (grant.md:476)** completed with a note: the Scope Hypothesis's "may also touch a
  grant-specific artifact path" caveat did not materialize on reading STAGE 2's actual steps.
- **Phase 5 (run-all.sh)** altered: the full whole-tree suite exceeded this dispatch's reasonable
  wait bound; both relevant suites were confirmed directly, matching the plan's own documented
  fallback.
- **Phase 5 (verify-deploy.sh gate 20)** altered: fails on an unrelated file, externally
  attributed to sibling task 315 (see Verification below), not a task 309 regression.

## Verification

- Build: N/A (markdown/shell source-store edits)
- Tests: `test-lint-directory-pathspec-boundary.sh` 14/14 passed;
  `test-lint-scoped-commit-boundary.sh` (sibling, regression check) 8/8 passed; a partial
  whole-tree `run-all.sh` run (through ~580 of its suites) showed exactly 2 failures, both
  tracing via `git log` to pre-existing commits unrelated to directory pathspecs
  (`test-gate-out-repair-reporting.sh`, `test-lint-json-channel-discipline.sh`) — zero failures
  attributable to this task.
- Lint: `lint-directory-pathspec-boundary.sh` (no path args, full default scan root) exits 0 —
  zero bare shared-directory pathspecs remain in the source store. Exempts the ~25
  task-scoped-directory sites correctly (spot-checked).
- Deploy: `deploy-headless.sh` landed; both new scripts present at
  `.claude/scripts/lint/lint-directory-pathspec-boundary.sh` and
  `.claude/scripts/tests/test-lint-directory-pathspec-boundary.sh`.
- `verify-deploy.sh`: 32/33 gates pass. Gate 20 (orchestrator context budget) FAILS —
  `skills/skill-orchestrate/SKILL.md` is 20930 B against its 20000 B ceiling. **Externally
  attributed, not a task 309 regression**: this task never touches that file; `git log` names
  the last commit touching it as `f9cac3ae6` ("task 315 phase 6: thread persisted_status through
  Move 3 and its mirrored doc copy"), and that file is in sibling task 315's own declared
  `file_scope`. Independently verified and acknowledged by the team lead during this dispatch.
  Zero gate regressions newly introduced by task 309; gate 17 (the sibling commit-boundary lint)
  passes clean.
- Files verified: Yes — all 19 real violation sites confirmed fixed via direct grep and lint
  re-scan; the 7 `commands/todo.md` pathspec variants confirmed byte-identical
  (`"${stage_paths[@]}"`).

## Impacts

- Closes the mode-1b cross-session commit-bleed hazard for every identified `git-commit-scoped.sh`
  call site that previously passed a bare shared-directory pathspec (`specs/` or `.memory/`),
  across core, epidemiology, present, and memory extensions.
- Establishes a mechanical regression guardrail (the new lint) so the pattern cannot silently
  regrow via copy-paste from a neighboring recipe, mirroring the sibling
  `lint-scoped-commit-boundary.sh`'s own role for the bare-`git commit -m` anti-pattern.
- `commands/todo.md`'s archival commit and `skill-learn/SKILL.md`'s memory commit now correctly
  stage every file/directory they actually touch (previously true by accident via the bare
  directory sweep; now true by explicit, auditable accumulation) — a secondary correctness
  improvement beyond the concurrency-safety motivation.

## Follow-ups

- **Wire `lint-directory-pathspec-boundary.sh` as a new `verify-deploy.sh` gate (gate 18)**.
  Deliberately excluded from this task: `verify-deploy.sh` is orchestrator-critical-path entry
  12, and this task's SCOPE NOTE forbids widening `file_scope` to include any critical path. The
  lint ships, is registered in `manifest.json`, and is auto-discovered by `run-all.sh` — it is
  simply not yet a deploy gate. Belongs to a task that explicitly admits touching a critical
  path.
- **Research follow-up**: the ~25 task-scoped-directory pathspec sites (`-- "${task_dir}/"`,
  `-- "specs/${padded_num}_${slug}/reports/"`, across lean/founder/web/present/epi skills) were
  deliberately left alone (sanctioned by `git-staging-scope.md`'s per-operation scope, narrower
  by construction since they name one task's own directory). Whether that sanctioning should be
  narrowed further is an open question for separate research, not resolved here.
- **Gate 20 (context budget) regression on `skills/skill-orchestrate/SKILL.md`**, externally
  attributed to sibling task 315's commit `f9cac3ae6` — not a task 309 follow-up, but flagged here
  for completeness since it was surfaced during this task's own Phase 5 verification. Reported to
  the team lead during this dispatch; resolution belongs to task 315 or a dedicated follow-up.

## References

- `specs/309_replace_directory_pathspecs_with_explicit_file_lists/plans/01_explicit-file-list-pathspecs.md`
- `specs/309_replace_directory_pathspecs_with_explicit_file_lists/reports/01_directory-pathspec-v5-gap.md`
- `specs/309_replace_directory_pathspecs_with_explicit_file_lists/progress/phase-{1..5}-progress.json`
- `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` (sibling lint, structural model)
