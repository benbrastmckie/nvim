# Implementation Summary: Task #302

- **Task**: 302 - Scoped commit directory pathspec and task lease
- **Status**: [COMPLETED]
- **Started**: 2026-10-12T02:49:35Z
- **Completed**: 2026-10-12T05:35:00Z
- **Effort**: ~3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_task-lease-wiring-ruling.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Half 2 of this task wired `git-commit-scoped.sh`'s contended-path task lease (`--task {N}`) at
every recipe site governed by one concrete task number, recorded why it is inapplicable at every
site that is not, ruled on and recorded the sanctioned task-scoped directory pathspec carve-out
in `context/standards/git-staging-scope.md`, and proved the wiring live with a scratch-repo
demonstration rather than asserting it from the text. All five plan phases closed; Phase 5 closed
`[COMPLETED WITH EXCLUSIONS]` on two gate findings that reproduce entirely outside this task's
declared scope.

## What Changed

- `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md` — Task Commit template gains
  `--task {N}`; Standard Commit template gains an inapplicability note; Execution Flow step 3
  (a 13th site found at plan time) now names `--task` conditionally on `task_number (if
  applicable)`.
- `agent-system/extensions/core/commands/task.md` — Step 7 commit gains `--task {N}`.
- `agent-system/extensions/core/skills/skill-meta/SKILL.md` — postflight commit gains `--task {N}`.
- `agent-system/extensions/epidemiology/commands/epi.md` — Step 5 commit gains `--task {N}`.
- `agent-system/extensions/present/commands/grant.md` — Step 8 commit gains `--task {N}`;
  CHECKPOINT 2 revision commit gains `--task {NEW_N}`.
- `agent-system/extensions/present/commands/slides.md` — Step 5 commit gains `--task {N}`.
- `agent-system/extensions/present/commands/timeline.md` — Step 8 commit gains `--task {N}`.
- `agent-system/extensions/core/commands/todo.md` — Step 6 (archival commit) and Step 6.5.3
  (metrics-sync commit) omission paragraphs extended to state why `--task` is inapplicable;
  none of the four Step 6 invocation lines, the Step 6.5.3 invocation line, or the
  `stage_paths` accumulator were touched.
- `agent-system/extensions/core/agents/meta-builder-agent.md` — Stage 6 omission sentence
  extended to cover `--task`, including the N=1 case.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — carve-out ruling added
  to the `lint-directory-pathspec-boundary.sh` References entry (four supporting arguments plus
  the exact-string-equality counter-argument, stated and answered); a new paragraph in the
  Concurrency Qualifier section cross-references `context/patterns/task-lock.md`, distinguishing
  the cross-task shared-file hazard from the same-task concurrent-write hazard.

## Decisions

- **Eight single-task sites wired, five sites ruled inapplicable with a stated reason.** The
  mechanical rule adopted from research: wherever `--honest-index-rows {N}` already keys to one
  concrete task number, `--task` on that identical number is the symmetric addition; wherever
  `--honest-index-rows` is already documented as inapplicable (no single task number governs the
  commit), `--task` inherits the identical inapplicability, and the existing omission prose was
  extended rather than duplicated.
- **The sanctioned task-scoped directory pathspec carve-out stays as-is.** Argued from four
  grounds — own-territory confinement, `git-commit-scoped.sh`'s own `:(exclude)` injection for
  the canonical ephemeral-runtime-file candidate set, the per-task dispatch lock in
  `context/patterns/task-lock.md`, and the roughly-three-dozen-site rename-pairing conversion
  cost — with the exact-string-equality counter-argument (the V5 contended-path check cannot
  match a directory token against a file-path manifest entry by construction) stated and
  answered: the manifest is populated only from declared `file_scope` source-tree paths, not
  another task's own artifact directory, so the bypassed check has nothing to match at these
  sites in practice.
- **The wiring was proven live, not merely present in the text.** A scratch repo mirroring
  `test-git-commit-scoped.sh`'s own `build_repo covered` fixture exercised the exact
  `commands/task.md` Step 7 argv against a path held by another synthetic task, confirming all
  four signals (exit 3, nothing staged, HEAD unmoved, holder named verbatim) plus a
  `--task`-omitted positive control proving the refusal was caused by the lease.

## Plan Deviations

- Phase 5's own stated verification criterion was `verify-deploy.sh` exits 0; the actual result
  was a reasoned-exclusion closure (2 of 36 checks failed) rather than a clean exit, per the
  plan's own fallback instruction. See Reasoned Exclusions below.

## Verification

- Build: N/A (markdown/prose task)
- Tests: `agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh`
  passed (1 passed, 0 failed) at Phase 4; the full, non-`--skip-slow` `run-all.sh` battery at
  Phase 5 reported 136 passed, 1 failed (the reasoned-exclusion case below), 137 total.
- Lints: `lint-directory-pathspec-boundary.sh --verbose` and `lint-scoped-commit-boundary.sh
  --verbose` both exit 0, both after every editing phase and again against the deployed tree.
  `check-task-references.sh --quiet` exits 0 throughout.
- Live refusal demonstration (Phase 4), captured verbatim:
  ```
  ERROR: git-commit-scoped.sh refuses to commit — path 'specs/state.json' is contended this cycle
  and currently claimed by task #501 (Verified Finding V5, mode-1b: explicit-path staging alone
  does not protect against concurrent same-file dispatch). Nothing was staged. Defer this path and
  re-sequence after task #501's own commit lands (or the claim's staleness timeout elapses) — never
  widen the pathspec or force it.
  ```
  rc=3, `git diff --cached` empty, `rev-list --count HEAD` unchanged at 1, holder `#501` named
  verbatim. The `--task`-omitted positive control on the identical fixture proceeded (rc=0, HEAD
  advanced 1->2).
- Files verified: Yes — `git diff` read-through of all nine edited files after every phase and
  again at Phase 5 confirmed no change beyond the intended `--task` additions / prose extensions,
  and no task-number reference or record-versioning language under `agent-system/**`.

### Reasoned Exclusions (Phase 5)

| Item | Reason | Evidence |
|------|--------|----------|
| `verify-deploy.sh` gate 3 (doc-lint): `check-evidence-probes.sh` not in `provides.scripts` | Caused by a concurrent sibling task's own in-flight `manifest.json` wiring, outside this task's declared `file_scope`. | `git log` shows the implicated `manifest.json` change already landed in a separate, already-committed sibling commit; the FAIL's own location (`skills/skill-todo/SKILL.md:550`) is also outside `file_scope`. Issue log entry `iss_1791774603165_laZO6J`. |
| `verify-deploy.sh` gate 8 (`run-all.sh`): `test-verify-deploy-context-budget.sh`'s baseline-fixture-is-clean assertion | Downstream propagation of the identical gate 3 failure — the test's fixture rsyncs the live tree and symlinks `.claude`, inheriting gate 3's FAIL. Zero gate20 findings confirms no actual context-budget regression. | Direct reproduction: `verify-deploy.sh --skip-slow --findings --quiet` against the live repo returns exactly the same two `FINDING` lines (gate3, plus gate16's unrelated pre-existing WARN) and no others. Issue log entry `iss_1791779161791_BiVHKg`. |

## Impacts

- Every recipe site that creates a task-scoped commit and is governed by exactly one task number
  now actually consults the contended-path lease, closing the "mechanism did not fail; it was
  never consulted" gap this task's description opened with.
- The task-scoped directory pathspec carve-out's rationale is now durably recorded in
  `git-staging-scope.md` itself, including the counter-argument, so a future auditor does not
  need to re-derive it or re-open the question from a plan file alone.

## Follow-ups

- A permanent regression case in `scripts/tests/test-git-commit-scoped.sh`, parameterized by a
  recipe's own invocation form, replacing this task's throwaway scratch probe (issue log entry
  `iss_1791779210433_eD8EbW`).
- `skill-meta/SKILL.md`'s `tasks_created > 1` identity ambiguity, inherited but not resolved by
  `--task {N}` (issue log entry `iss_1791779210455_vdRyzi`).
- No change to `git-commit-scoped.sh` itself surfaced as desirable while ruling; this entry
  documents that the check was made (issue log entry `iss_1791779210479_euvDxJ`).
- The two Phase 5 gate findings above belong to whichever task resolves the sibling's
  `manifest.json`/`check-evidence-probes.sh` wiring gap — not a new follow-up from this task,
  since that work is already in progress under a separate task.

## References

- Plan: `specs/302_scoped_commit_directory_pathspec_and_task_lease/plans/01_task-lease-wiring-ruling.md`
- Research: `specs/302_scoped_commit_directory_pathspec_and_task_lease/reports/01_task-lease-wiring-and-carveout-ruling.md`
- Progress files: `specs/302_scoped_commit_directory_pathspec_and_task_lease/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/302_scoped_commit_directory_pathspec_and_task_lease/handoffs/`
- Issue log: `specs/302_scoped_commit_directory_pathspec_and_task_lease/issues.jsonl`
