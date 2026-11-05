# Implementation Summary: Task #393

- **Task**: 393 - Propagate modified_files repo-relative-paths constraint to silent agents
- **Status**: [COMPLETED]
- **Started**: 2026-10-17T05:00:00Z
- **Completed**: 2026-10-17T08:45:00Z
- **Effort**: ~4 hours
- **Dependencies**: None
- **Artifacts**: plans/01_propagate-modified-files-constraint.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Propagated the `modified_files` repo-relative-paths MUST-DO constraint and its track-on-write
procedure into all thirteen implementation agents that never mentioned the field (ten
dispatch-named plus three hard-mode agents the dispatch's glob could not reach), via a new
canonical fragment file and a new mechanically-enforced lint check (Check L) with full fixture
coverage. All six plan phases are `[COMPLETED]`.

## What Changed

- `agent-system/extensions/core/context/contracts/modified-files-bullet.md` — new canonical
  fragment carrying the exact MUST-DO bullet and track-on-write line, the thirteen-agent
  classification rule, the placement rule, and the remit-boundary note.
- `agent-system/extensions/core/index-entries.json` — one new entry for the fragment.
- Thirteen implementation agent definitions, each gaining: the track-on-write line under its own
  apply-the-change step, the MUST-DO bullet as the next sequential item of its `**MUST DO**:`
  list, and a `"modified_files"` key in its metadata JSON example —
  `books/agents/{books-implementation-agent.md,books-implementation-hard-agent.md}`,
  `cslib/agents/{cslib-implementation-agent.md,cslib-implementation-hard-agent.md,pr-review-implementation-agent.md}`,
  `latex/agents/latex-implementation-agent.md`,
  `lean/agents/{lean-implementation-agent.md,lean-implementation-hard-agent.md}`,
  `python/agents/python-implementation-agent.md`, `rust/agents/rust-implementation-agent.md`,
  `typst/agents/typst-implementation-agent.md`, `web/agents/web-implementation-agent.md`,
  `z3/agents/z3-implementation-agent.md`.
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — new
  `check_l_modified_files_bullet`, its thirteen-file in-scope array, wired into `main()`, plus
  header/`--help` documentation.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` — a required fixture
  repair (the `cslib-implementation-agent.md` scratch fixture, already asserted twice to produce
  no FAIL at all, gained both canonical lines plus a `"modified_files": []` key) and four new
  Check L assertion groups (missing-copy, near-miss paraphrase, no-FAIL/explicit-PASS,
  fragment-missing).

## Decisions

- Widened scope from the dispatch's literal 10 agents to all 13 (including the 3 hard-mode
  agents the `*implementation-agent.md` glob cannot match), since the defect, the fix, and the
  lint's own existing in-scope arrays for other checks already treat all three as implementation
  agents.
- Followed the no-progress-file (flat run-list) wording model for all thirteen agents, since none
  of them maintain a `files_touched` accumulator.
- Left the four already-compliant agents (general, email, nix, neovim) untouched — a recorded
  exclusion, not an oversight (uniformity-only change with no defect behind it).

## Plan Deviations

- **Phase 5**: the track-on-write canonical line was initially inserted word-wrapped across 3-4
  physical lines in all thirteen Phase 2-4 agent files for readability. Phase 2-4's own
  `grep -cF` verification used a truncated anchor substring that only spanned the first wrapped
  line, so it reported a false "1 match" pass. This was only caught when Check L's own runtime
  `grep -F` extraction of the complete line failed to match any of the 13 files. Fixed within
  Phase 5 by collapsing the line to a single physical line in all 13 files, re-verified against
  the real fragment text, and confirmed PASS by Check L itself. Recorded via `issue-record.sh`
  (class "verification blind spot", severity costly).
- **Phase 6**: the full `verify-deploy.sh` gate set reported 3 of 36 checks failed at the
  whole-repo level. All three are triaged and reported, not fixed: doc-lint (gate 3) and manifest
  verify.lua (gate 5) both named exactly `context/standards/git-staging-scope.md` and
  `scripts/tests/test-git-commit-scoped.sh` — sibling task 394's own declared `file_scope`,
  confirmed in-flight via `git log`/`git status`; gate 10 (`validate-state.sh --deep`) hit an
  unrelated 30s timeout against the shared `specs/state.json`. None name a path in task 393's
  own `file_scope`. Recorded via `issue-record.sh` (class "cross-task interference", severity
  minor).

## Verification

- Build: N/A (markdown prompt files and one bash script/test suite)
- Tests: Passed — `run-all.sh --only test-lint-agent-contracts.sh` (37/37 assertions, including
  all four new Check L groups); `lint-agent-contracts.sh --verbose` against the real tree exits 0
  with a Check L PASS line for all 13 in-scope files (344 passed, 13 pre-existing unrelated
  Check-I warnings dated 2026-10-08, 0 failed)
- Files verified: Yes — the originating `grep -L 'modified_files'` sweep (including the
  hard-mode glob) returns nothing; `generate-context-line-counts.sh --check` clean

## Impacts

- Every one of the thirteen implementation agents now self-documents the `modified_files`
  repo-relative-paths constraint that `git-commit-scoped.sh`'s V9 containment gate (task 304) was
  previously the only backstop against — the producer side of the gap is now closed, not just
  the consumer-side containment.
- Check L gives the lint suite a permanent, mechanical guarantee that the thirteen copies cannot
  silently drift back out of sync with the canonical fragment.

## Follow-ups

- A distinct, deliberately out-of-scope staging defect was observed and recorded (not fixed
  here): several of the smaller target agents' per-phase commit blocks build `stage_paths` from
  only the task directory, `specs/TODO.md`, and `specs/state.json`, never the source files the
  phase actually touched, unlike `general-implementation-agent.md`'s mechanized
  `git-commit-phase.sh` path. Recorded via `issue-record.sh` for its own future task.
- Sibling task 394's in-flight edits (`git-staging-scope.md`, `test-git-commit-scoped.sh`) will
  need its own redeploy/commit cycle to clear the doc-lint/manifest drift findings surfaced
  during this task's Phase 6 gate run; no action needed from task 393.

## References

- Plan: `specs/393_propagate_modified_files_constraint_to_silent_agents/plans/01_propagate-modified-files-constraint.md`
- Research report: `specs/393_propagate_modified_files_constraint_to_silent_agents/reports/01_propagate-modified-files-constraint.md`
- Canonical fragment model: `agent-system/extensions/core/context/contracts/no-task-references-bullet.md`
