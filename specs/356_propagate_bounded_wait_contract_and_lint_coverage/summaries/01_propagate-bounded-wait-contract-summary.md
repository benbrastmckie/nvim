# Implementation Summary: Task #356

- **Task**: 356 - Propagate the bounded-wait contract to the fourteen implementation agent definitions that lack it, and assert the coverage mechanically in the agent-contract lint
- **Status**: [COMPLETED]
- **Started**: 2026-10-07T09:00:00Z
- **Completed**: 2026-10-07T11:45:00Z
- **Effort**: ~2.75 hours
- **Dependencies**: None
- **Artifacts**: plans/01_propagate-bounded-wait-contract.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Propagated the bounded-wait MUST / MUST-NOT bullet pair (previously present only in
`general-implementation-agent.md` and the two Lean implementation agents) to all fourteen
implementation-agent definitions measured as missing it, via one canonical generated-copy
fragment appended to the existing `bounded-build-waiter.md` pattern document, and added
`lint-agent-contracts.sh` Check H to assert the coverage mechanically so the gap cannot reopen
silently. All six plan phases completed; the lint, its fixture test suite, and a live
deliberate-removal demonstration all confirm the propagation and its enforcement.

## What Changed

- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` — appended a
  "Canonical Agent-Contract Bullet (Generated-Copy Source)" section: the generated-copy
  explainer, an "Item 1 Ruling" subsection recording the rejected candidate homes ((a) a
  universal context pointer -- none exists; (c) per-agent duplication with no canonical source
  -- the exact anti-proliferation failure this change closes) and the adopted forward-looking
  template complement (b), the verbatim "Copy this exact text" bullet pair, a Classification
  Rule naming the three recorded exclusions, an "Item 3 Ruling" (hard variants do not inherit)
  and an "Item 4 Ruling" (research agents ruled out of this change's scope, not dismissed), and
  a brittleness note.
- `agent-system/extensions/core/context/templates/agent-template.md` — added a forward-looking
  bullet to the `### Implementation Agent` variant subsection directing a newly authored agent to
  carry the bounded-wait bullet pair from `bounded-build-waiter.md`.
- 14 implementation-agent definitions — each gained the literal MUST bullet (bounded-wait
  waiter idiom) and MUST NOT bullet (no `run_in_background`/`Monitor` on a local
  verification/gate/build/test process), appended to their existing `## Critical Requirements`
  MUST/MUST-NOT lists with no other change:
  `books/agents/books-implementation-agent.md`, `books/agents/books-implementation-hard-agent.md`,
  `cslib/agents/cslib-implementation-agent.md`,
  `cslib/agents/cslib-implementation-hard-agent.md`,
  `cslib/agents/pr-review-implementation-agent.md`, `email/agents/email-implementation-agent.md`,
  `latex/agents/latex-implementation-agent.md`, `nix/agents/nix-implementation-agent.md`,
  `nvim/agents/neovim-implementation-agent.md`, `python/agents/python-implementation-agent.md`,
  `rust/agents/rust-implementation-agent.md`, `typst/agents/typst-implementation-agent.md`,
  `web/agents/web-implementation-agent.md`, `z3/agents/z3-implementation-agent.md`.
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — added
  `BOUNDED_WAIT_FRAGMENT` constant, a curated `BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS` array (the
  14 files, with an inline comment recording the three exclusions, their per-file reasons, and
  the re-audit reproduce command verbatim), `check_h_bounded_wait_contract_bullet()` on Check
  C/G's exact shape, and its registration in `main()` after Check G.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` — added
  `BOUNDED_WAIT_FRAGMENT_SRC`, scratch-tree fragment copy, `BOUNDED_WAIT_MUST_LINE` /
  `BOUNDED_WAIT_MUSTNOT_LINE` constants, a conforming positive fixture (both bullets added to the
  existing `cslib-implementation-agent.md` fixture), two new fixtures
  (`nvim/agents/neovim-implementation-agent.md` missing both bullets,
  `z3/agents/z3-implementation-agent.md` carrying a near-miss paraphrase), and five new
  assertions (conforming PASS, missing-bullet FAIL, near-miss FAIL, exclusion-list no-FAIL,
  fragment-missing FAIL).

## Decisions

- **Item 1 (one shared home)**: the bullet pair's canonical source is a generated-copy section
  appended to the existing `bounded-build-waiter.md`, not a new document and not a bare
  `@`-pointer (which does not auto-resolve when Claude Code spawns a subagent). Rejected: (a) a
  universal always-load context pointer — none exists across all 17 agent files; (c) per-agent
  duplication with no canonical source — the exact failure mode this change closes. Adopted as a
  forward-looking complement: (b) `agent-template.md`, which covers only newly authored agents
  and fixes none of the fourteen existing gaps.
- **Item 2 (lint is load-bearing)**: `lint-agent-contracts.sh` Check H, mirroring Check C's and
  Check G's exact curated-array-plus-literal-text-comparison shape, fails loudly by name on a
  missing bullet, a near-miss paraphrase, or an absent fragment file, and passes on the
  post-propagation tree.
- **Item 3 (hard variants)**: hard-mode agent files do not inherit the bullet pair from their
  non-hard sibling — "Extends `{sibling}`" is prose, not a file-inclusion mechanism. Both
  `books-implementation-hard-agent.md` and `cslib-implementation-hard-agent.md` required their
  own independent literal copy and their own independent lint-array entry.
- **Item 4 (research agents)**: ruled out of this change's own acceptance scope, not dismissed.
  `general-research-agent.md` carries the external/remote-wait discipline but neither half of
  this local-background bullet pair, and the measured evidence/acceptance surface here are
  implementation-agent-scoped only. Recorded as a follow-up recommendation reusing the identical
  fragment-and-check mechanism.

## Plan Deviations

- **Phase 6** altered: added the explicit "Item 1 Ruling: One Shared Home, Rejected Candidates
  Recorded" subsection to `bounded-build-waiter.md` during Phase 6 rather than Phase 2. Phase 2
  had recorded the Classification Rule and the Item 3/Item 4 rulings but not an explicit
  rejected-candidates-(a)-and-(c) record; Phase 6's own verification bullet required it, so it
  was added at that point instead of being silently treated as already satisfied. Recorded via
  `issue-record.sh` (class: plan deviation, severity: minor).

## Verification

- Build: N/A (no build step for this task)
- Tests: Passed — `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh`
  exits 0, 32 passed / 0 failed (27 pre-existing + 5 new Check H assertions)
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` exits 0,
  209 PASS / 0 WARN / 0 FAIL, including 14 named Check H PASS lines
- Deliberate-removal demonstration on a real file
  (`z3/agents/z3-implementation-agent.md`): removal produced a named
  `FAIL ... missing the bounded-wait MUST/MUST-NOT bullet pair` with lint exit 1; restoration via
  targeted Edit reproduced the file byte-for-byte identical to its Phase 3 state (confirmed by
  `diff`), and the lint returned to exit 0
  — demonstrating both halves (the gap is caught; the fix passes) without relying on a one-off
  manual claim
- Coverage reproduce command: all 17 implementation-agent files report nonzero in both
  `run_in_background` and `bounded-build-waiter` columns (3 pre-existing + 14 newly propagated)
- 14-file exact-text check: 14 `OK`, 0 `MISSING`
- `shellcheck` on `lint-agent-contracts.sh`: clean (0 findings). `shellcheck` on
  `test-lint-agent-contracts.sh`: zero NEW findings introduced by this task (two pre-existing
  info-level findings — `SC2329` on an unused `cleanup` trap helper, `SC2016` on
  `OWNERSHIP_BULLET_LINE` — predate this task and are unrelated to its edits; this task's own two
  new backtick-containing constants carry explicit `# shellcheck disable=SC2016` directives)
- `bash .claude/scripts/check-task-references.sh agent-system`: 0 unexempted occurrences
- Files verified: Yes (all 14 agent files, the pattern fragment, the template, the lint script,
  and the test script all read back and confirmed)

## Impacts

- Every implementation-agent dispatch across core, books, cslib, email, latex, nix, neovim,
  python, rust, typst, web, and z3 now carries the same bounded-wait discipline that measurably
  prevented a stranded dispatch in `general-implementation-agent`'s natural-experiment evidence
  — eliminating the class of failure where a dispatched agent backgrounds a local
  verification/gate/build/test process and goes idle awaiting a notification that may never
  arrive.
- The coverage is now mechanically asserted: `lint-agent-contracts.sh` Check H fails the moment
  any of the 14 covered files, or a future file added to its curated array, loses the bullet
  pair — closing the "propagation without a lint merely resets the clock" risk the task
  description named explicitly.
- Deploying this change to a consumer repo's `.claude/` tree requires a deploy-tree
  regeneration from the source store; the propagated contract has no runtime effect on an agent
  until that regeneration runs (recorded as a recommendation below, not performed by this task).

## Follow-ups

- Apply the identical fragment-and-lint-check mechanism to research agents (item 4's recorded
  follow-up): several domain research agents hold Bash access explicitly for verification or
  build commands and are plausibly exposed to the same local-background-wait defect class, but
  this task's measured evidence and acceptance surface were implementation-agent-scoped only.
- `books/agents/books-implementation-agent.md` and `books/agents/books-implementation-hard-agent.md`
  are absent from both Check C's `IN_SCOPE_RELATIVE_PATHS` and Check G's
  `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` curated arrays, even though both files carry the
  no-task-references bullet (confirmed by direct grep) — a pre-existing curated-list drift
  predating this task, outside this change's scope, and left unrecorded in any other open task
  as far as this dispatch could determine.
- The deploy tree (`.claude/`) must be regenerated from the source store
  (`agent-system/extensions/**`) before any of this propagation takes effect on a live agent
  dispatch; this task deliberately made no deploy-tree change (per
  `rules/source-store-deploy-boundary.md`).

## References

- `specs/356_propagate_bounded_wait_contract_and_lint_coverage/plans/01_propagate-bounded-wait-contract.md`
- `specs/356_propagate_bounded_wait_contract_and_lint_coverage/reports/01_propagate-bounded-wait-contract.md`
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md`
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh`
