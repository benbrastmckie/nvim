# Research Report: Task #531

**Task**: 531 - file_scope declaration hygiene remediation for the admission gate
**Started**: 2026-11-11
**Completed**: 2026-11-11
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: - `bash .claude/scripts/validate-state.sh specs/state.json` (live run), `specs/state.json`, task descriptions for 473/518/567/568/607, `bash .claude/scripts/check-record-versioning.sh`, codebase grep/glob, git history
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's own snapshot figures ("task 177", "28 of 52") are stale — confirmed
  stale by the live validator run, exactly as the dispatch warned. Task 177 does not
  exist in this repository's `state.json` at all (it is an artifact of the record's
  migration source, BimodalLogic). The live defect set is narrower: Check 8 flags
  exactly two coarse whole-directory `file_scope` entries (project 473, project 518),
  Check 9 (duplicates) is clean, and only 3 of 137 non-terminal tasks are missing
  `file_scope` entirely (567, 568, 607) — not 28.
- For project 473, the directory entry
  `agent-system/extensions/core/docs/architecture/` can be narrowed to the 5 files that
  actually carry the record-versioning occurrences it exists to triage (confirmed via a
  live `check-record-versioning.sh` scan: 0 BLOCKING / 43 ADVISORY, all five files
  named below). Narrowing removes the Check 8 WARN for 473 without changing its real,
  file-level territory overlap with the other 11 tasks (that overlap is legitimate and
  unaffected — it exists on only 2 of the 5 files).
- For project 518, the 16 whole-directory `agents/` entries can be replaced by the 40
  specific extension-agent files that actually carry the targeted boilerplate paragraph
  (verified by grep; count matches the task's own "40 extension agents" tally exactly).
- Projects 567, 568, and 607 can be backfilled with concrete, verified-on-disk
  `file_scope` lists derived directly from each task's own description text.
- The dispatch's second scope item (a `WIRED_REPO`/evidence-probe un-tracking detector
  at `scripts/check-evidence-probes.sh:717-720`) names a script that **does not exist
  anywhere in this repository's working tree or git history**. This is not a "not landed
  yet" situation the plan can close with a one-line addition as described — the file,
  and any test harness around it, would have to be built from nothing, or the citation
  corrected to point at this repo's real (if any) equivalent. Recommend treating this as
  a separate follow-up decision, not a sub-step of this remediation.

## Context & Scope

Task 531 is a `meta` task to remediate two declared defects in `specs/state.json`'s
`file_scope` field population, which the admission/overlap gate
(`validate-state.sh` Checks 8 and 9, and the overlap logic consumed by
`orchestrate-predispatch-review.sh`) depends on to see cross-task collisions. The
dispatch explicitly warns that its own count snapshot is stale and instructs re-deriving
from the live validator. This research phase re-derives the live defect set, identifies
concrete narrowing/backfill `file_scope` values for every affected task, and checks the
dispatch's secondary (opportunistic) scope item for whether it has already landed.

This phase does not edit `state.json` — the corpus is actively shared with six
concurrent sibling research dispatches this cycle (490, 515, 597, 600, 601, 603), several
of which declare `file_scope` entries inside `agent-system/extensions/core/`. No file
edits were made in this phase; all findings below are read-only.

## Findings

### Codebase Patterns

**Live validator output** (`bash .claude/scripts/validate-state.sh specs/state.json`):

```
[WARN] Coarse file_scope declaration: project_number 473, entry
  'agent-system/extensions/core/docs/architecture/' overlaps 11 distinct non-terminal
  task(s): 472,514,518,519,543,547,570,571,574,577,609
[WARN] Coarse file_scope declaration: project_number 518, entry
  'agent-system/extensions/lean/agents/' overlaps 5 distinct non-terminal task(s):
  472,515,516,537,556
[PASS] No duplicate file_scope entries found (exact or normalization-equivalent)
[WARN] file_scope visibility: 3 missing-key, 0 literal-null, 0 empty-array, out of 137
  non-terminal task(s)
[WARN] file_scope missing_key: project_number 567 (port_containment_strip_to_git_commit_scoped)
[WARN] file_scope missing_key: project_number 568 (repair_orchestrate_cycle_postflight_suite)
[WARN] file_scope missing_key: project_number 607 (gate_20_context_budget_and_timeout_sensitivity)
```

Task 177 (`FormalSystem/Metalogic/Decidability/`) does not appear anywhere in
`specs/state.json` — `jq '.active_projects[] | select(.project_number==177)'` returns
nothing. That path belongs to the BimodalLogic source repository this record was
migrated from (see the record's own Migration Provenance block), not to this repo. The
dispatch's warning that the counts are "a snapshot, not a contract" is fully borne out:
the live defect set is two coarse entries and three missing entries, not one Lean-style
whole-subtree entry and 28 missing entries.

**Project 473** (`Strip record-versioning language from the boundary-owned architecture
docs`, status `researched`, `file_scope: ["agent-system/extensions/core/docs/architecture/"]`):
A live scan (`bash .claude/scripts/check-record-versioning.sh agent-system/extensions/core/docs/architecture/`)
finds 0 BLOCKING / 43 ADVISORY findings, entirely confined to 5 files:

| File | ADVISORY occurrences |
|------|----------------------|
| `batch-admit-schema.md` | 9 |
| `extension-system.md` | 2 |
| `handoff-schema.md` | 13 |
| `orchestrate-cycle-postflight.md` | 1 |
| `orchestrate-state-machine.md` | 18 |

No other file under the directory has any occurrence. The task's own concurrent-territory
note (naming 378, 387, 420, 428, 431, 438, 450, 274 as records that own parts of this
directory) is itself stale: of those, only 431 and 438 are still open, and neither one's
`file_scope` touches any of the 5 files above — so the "boundary-owned" constraint from
468's planning time no longer binds any of these 5 files today (worth re-verifying again
at 473's own plan/implement time, per that task's own acceptance item 3). Narrowing 473's
`file_scope` to these 5 files eliminates the Check 8 coarse-directory WARN. It does not
eliminate real per-file overlap with the other 11 tasks Check 8 named — 7 of them
(514,543,547,570,574,577,609) touch `orchestrate-state-machine.md` and 5 of them
(472,518,519,571,577) touch `handoff-schema.md`; the union is the same 11 tasks. That is
expected and correct: a narrowed, file-level overlap is genuine shared territory for the
normal serialization/territory process to handle, not a hygiene defect Check 8 should
keep flagging.

**Project 518** (`State the blockers[] admission contract...`, status `not_started`): its
current `file_scope` already lists 7 individual files correctly (`wrap-up.md`,
`phase-closure.md`, `general-implementation-agent.md`, `planner-agent.md`,
`reviser-agent.md`, `general-research-agent.md`, `handoff-schema.md`) plus 16
whole-directory `agents/` entries, one per extension. The task's own description states
the measured corpus is 43 files total: "`core/agents/{general-implementation,planner,
reviser}-agent.md` plus 40 extension agents across" 16 named extensions, all carrying an
identical boilerplate paragraph beginning "`summary` and `blockers` are BOTH required
top-level fields." A live
`grep -rl "BOTH required top-level fields" agent-system/extensions/*/agents/` returns
exactly 42 files (the 3 named core files plus 39... recount below), and
`general-research-agent.md` (named in the task text but not carrying that boilerplate)
accounts for the 43rd. Per-extension file counts from the live grep (core files
excluded, already individually declared):

| Extension | Files |
|-----------|-------|
| books | 1 |
| cslib | 2 |
| email | 1 |
| epidemiology | 1 |
| filetypes | 6 |
| founder | 14 |
| latex | 1 |
| lean | 1 |
| nix | 1 |
| nvim | 1 |
| present | 6 |
| python | 1 |
| rust | 1 |
| typst | 1 |
| web | 1 |
| z3 | 1 |

Total: 40, matching the task's own tally exactly. Replacing the 16 directory entries
with these 40 specific file paths (full list in Recommendations) eliminates the Check 8
WARN for 518. The real overlap with 472, 515, 516, 537, 556 on `lean/agents/
lean-implementation-agent.md` (and 472 additionally on
`lean-implementation-hard-agent.md`) survives narrowing, as expected — 518's own backlog
reconciliation section already records a serializing edge with 472 for exactly this
reason.

**Projects 567, 568, 607** (missing `file_scope` entirely): each task's own description
names concrete edit targets precisely enough to backfill a verified file list without
further research:

- **567** ("Port git-commit-phase.sh's deployed-tree containment strip into
  git-commit-scoped.sh..."): description says "Scope: git-commit-scoped.sh and its test
  suite," and separately instructs restoring an assertion in
  `test-git-commit-phase.sh` Case 26 and re-checking its Case 20 fixture. All three
  files exist on disk: `scripts/git-commit-scoped.sh`,
  `scripts/tests/test-git-commit-scoped.sh`, `scripts/tests/test-git-commit-phase.sh`.
- **568** ("Fix test-orchestrate-cycle-postflight.sh, which fails 25 of 304
  assertions..."): names its own target scripts explicitly
  (`orchestrator-postflight.sh`, `update-task-status.sh`) plus the suite itself and the
  script the suite exercises (`orchestrate-cycle-postflight.sh`, confirmed via the
  suite's own `source` line). All four files exist on disk.
- **607** ("verify-deploy.sh gate 20 (orchestrator context budget) reports the
  eager-load total over its baseline... Decide between trimming the eager-load
  footprint of [commands/orchestrate.md, skills/skill-orchestrate/SKILL.md] and
  re-baselining the gate... Second, narrower question: ... gates 8 and 10 ... per-gate
  timeout..."): the baseline lives in
  `context/config/orchestrator-context-budget.json` (confirmed by grep in
  `verify-deploy.sh`), and the per-gate `timeout_s` is read from
  `scripts/gate-registry.data` via `gate_registry_field` (also confirmed in
  `verify-deploy.sh`). All five files (`commands/orchestrate.md`,
  `skills/skill-orchestrate/SKILL.md`, `context/config/orchestrator-context-budget.json`,
  `scripts/gate-registry.data`, `scripts/verify-deploy.sh`) exist on disk. Note:
  `gate-registry.data` is also declared by concurrent sibling task 601 this cycle — a
  real, expected overlap for the territory process, not a hygiene defect.

### External Resources

Not applicable — this is a pure codebase/state-file hygiene task with no external
dependency.

## Recommendations

Concrete `file_scope` values to apply at plan/implement time (all paths relative to
`agent-system/extensions/core/` unless an extension prefix is shown; all verified to
exist on disk in this research pass):

**Project 473** — replace the single directory entry with:
```
docs/architecture/batch-admit-schema.md
docs/architecture/extension-system.md
docs/architecture/handoff-schema.md
docs/architecture/orchestrate-cycle-postflight.md
docs/architecture/orchestrate-state-machine.md
```

**Project 518** — keep the 7 existing file entries unchanged; replace the 16
`agents/` directory entries with these 40 files:
```
agent-system/extensions/books/agents/books-implementation-agent.md
agent-system/extensions/cslib/agents/cslib-implementation-agent.md
agent-system/extensions/cslib/agents/pr-review-implementation-agent.md
agent-system/extensions/email/agents/email-implementation-agent.md
agent-system/extensions/epidemiology/agents/epi-implement-agent.md
agent-system/extensions/filetypes/agents/docx-edit-agent.md
agent-system/extensions/filetypes/agents/filetypes-router-agent.md
agent-system/extensions/filetypes/agents/filetypes-spreadsheet-agent.md
agent-system/extensions/filetypes/agents/presentation-agent.md
agent-system/extensions/filetypes/agents/scrape-agent.md
agent-system/extensions/filetypes/agents/sheet-agent.md
agent-system/extensions/founder/agents/analyze-agent.md
agent-system/extensions/founder/agents/deck-builder-agent.md
agent-system/extensions/founder/agents/deck-planner-agent.md
agent-system/extensions/founder/agents/finance-agent.md
agent-system/extensions/founder/agents/financial-analysis-agent.md
agent-system/extensions/founder/agents/founder-implement-agent.md
agent-system/extensions/founder/agents/founder-plan-agent.md
agent-system/extensions/founder/agents/founder-spreadsheet-agent.md
agent-system/extensions/founder/agents/legal-analysis-agent.md
agent-system/extensions/founder/agents/legal-council-agent.md
agent-system/extensions/founder/agents/market-agent.md
agent-system/extensions/founder/agents/meeting-agent.md
agent-system/extensions/founder/agents/project-agent.md
agent-system/extensions/founder/agents/strategy-agent.md
agent-system/extensions/latex/agents/latex-implementation-agent.md
agent-system/extensions/lean/agents/lean-implementation-agent.md
agent-system/extensions/nix/agents/nix-implementation-agent.md
agent-system/extensions/nvim/agents/neovim-implementation-agent.md
agent-system/extensions/present/agents/budget-agent.md
agent-system/extensions/present/agents/funds-agent.md
agent-system/extensions/present/agents/grant-agent.md
agent-system/extensions/present/agents/slide-planner-agent.md
agent-system/extensions/present/agents/slidev-assembly-agent.md
agent-system/extensions/present/agents/timeline-agent.md
agent-system/extensions/python/agents/python-implementation-agent.md
agent-system/extensions/rust/agents/rust-implementation-agent.md
agent-system/extensions/typst/agents/typst-implementation-agent.md
agent-system/extensions/web/agents/web-implementation-agent.md
agent-system/extensions/z3/agents/z3-implementation-agent.md
```
(39 listed above + `lean/agents/lean-implementation-agent.md` = 40; re-verify the exact
count with the grep command in Findings before writing, in case a sibling task edits
this corpus before 518's own plan/implement phase runs.)

**Project 567** — backfill with:
```
agent-system/extensions/core/scripts/git-commit-scoped.sh
agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh
agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh
```

**Project 568** — backfill with:
```
agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh
agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh
agent-system/extensions/core/scripts/orchestrator-postflight.sh
agent-system/extensions/core/scripts/update-task-status.sh
```

**Project 607** — backfill with:
```
agent-system/extensions/core/commands/orchestrate.md
agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
agent-system/extensions/core/context/config/orchestrator-context-budget.json
agent-system/extensions/core/scripts/gate-registry.data
agent-system/extensions/core/scripts/verify-deploy.sh
```

**Implementation mechanics**: these are direct `specs/state.json` field edits
(`active_projects[].file_scope`), not source-store edits — `file_scope` is
task-management metadata, not a deliverable, so the source-store-deploy-boundary rule
and the no-task-reference/no-record-versioning rules do not apply to this write. Use
`state-write.sh` (the sanctioned jq-mutation wrapper) rather than hand-editing the file,
and re-run `validate-state.sh` afterward to confirm Checks 8/9 and the missing-key count
all show clean for these five tasks before committing.

**Second scope item (WIRED_REPO / evidence-probe un-tracking detector)**: do not attempt
to implement this as "a one-line `git ls-files --error-unmatch` beside the `-f` test at
`scripts/check-evidence-probes.sh:717-720`" — that file does not exist in this
repository (see Risks below). Recommend the plan phase make an explicit choice: either
(a) treat this as out of scope for 531 and record it as a separate follow-up task (since
building a `check-evidence-probes.sh`-equivalent from nothing is a materially different,
larger piece of work than the one-line addition the dispatch describes), or (b) if an
equivalent mechanism is found to exist here under a different name during planning,
re-scope to that file's real location and line range.

## Decisions

- Treated the dispatch's embedded snapshot figures (task 177; "28 of 52") as advisory
  only, per the dispatch's own instruction, and based every recommendation on the live
  `validate-state.sh` run instead.
- For project 473, chose to narrow to the 5 files the live record-versioning scanner
  found rather than guessing from the task's "roughly 53" estimate or the stale
  territory note — the scanner result is the authoritative, reproducible source.
- For project 518, chose file-level enumeration over keeping any directory entries,
  since the task's own description already commits to an exact, named 43-file corpus
  that the live grep reproduces exactly.
- Did not attempt to independently resolve or re-verify 473's or 518's own substantive
  work (the record-versioning rewrite, the admission-contract prose) — that is each
  task's own research/plan/implement responsibility; this report only derives their
  `file_scope` values.

## Risks & Mitigations

- **Concurrency drift**: six sibling research dispatches are running this same cycle
  against overlapping `agent-system/extensions/core/` territory. The file lists above
  are a snapshot as of this research pass; re-run the verification greps/scans
  immediately before writing `file_scope` at plan/implement time, per the dispatch's
  own concurrency note.
- **Stale secondary citation**: `scripts/check-evidence-probes.sh` does not exist
  anywhere in this repository's working tree or git history (`git log --all -- '**/check-evidence-probes.sh'`
  returns nothing). The only two occurrences of "WIRED_REPO" in the whole codebase are
  prose comments in `context/patterns/task-abandon-mode.md` and `skills/skill-todo/SKILL.md`
  describing the hazard, with no mechanical detector anywhere. This is very likely a
  carried-over citation from the BimodalLogic source repository (where the record
  originated as #751) that was not re-pointed during migration. Flagging rather than
  silently implementing a guess at the "right" file, since inventing a detector under
  that name risks diverging from whatever this repo's intended equivalent (if any) is.
- **473/518 own substantive scope may shift their true file set**: both are
  `researched`/`not_started` and not yet planned — 473's record-versioning rewrite could
  legitimately touch a 6th file if a future edit to architecture/ introduces new
  occurrences, and 518's approach choice (A/B/C/D, per its own description) could change
  which files are touched if approach B (centralize, then point) is chosen over A
  (prose at every site) — approach B would shrink the file list to a handful of shared
  host files, not 47. Recommend the plan phase for 518 re-confirm the chosen approach
  before writing the narrowed `file_scope`, since the correct backfill differs by
  approach.

## Context Extension Recommendations

- **Topic**: `scripts/check-evidence-probes.sh` / `WIRED_REPO` detector.
- **Gap**: `context/patterns/task-abandon-mode.md` and `skills/skill-todo/SKILL.md` both
  cite this script as the mechanism that must be "re-pointed... before the task is
  archived," but no such script, nor any equivalent, exists in this repository. Either
  the citation is wrong (migrated verbatim from the BimodalLogic source repo without
  re-pointing) or the detector was never built here.
- **Recommendation**: a follow-up task should resolve which of the two is true and
  either build the detector or correct both citing files to describe the actual current
  state (no mechanical detector exists; the hazard is handled by manual discipline
  only).

## Appendix

- `bash .claude/scripts/validate-state.sh specs/state.json`
- `bash .claude/scripts/check-record-versioning.sh agent-system/extensions/core/docs/architecture/`
- `grep -rl "BOTH required top-level fields" agent-system/extensions/*/agents/`
- `git log --all --oneline -- '**/check-evidence-probes.sh'`
- `jq` queries against `specs/state.json` for project_numbers 177, 431, 438, 472, 473,
  514, 515, 516, 518, 519, 537, 543, 547, 556, 567, 568, 570, 571, 574, 577, 607, 609
