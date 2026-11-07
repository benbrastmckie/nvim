# Implementation Summary: Task #466

- **Task**: 466 - validate-wiring.sh reports Missing context file for context paths present on disk and in index.json
- **Status**: [COMPLETED]
- **Started**: 2026-11-07T00:49:00Z
- **Completed**: 2026-11-07T01:18:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_wiring-missing-context-attribution.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The task description hypothesized a path-resolution defect in `validate-wiring.sh`. Reproduction
showed this diagnosis was wrong: every one of the 41 `Missing context file` failures belonged to
the `.opencode` arm of a `--all` run, where the files genuinely did not exist — the validator's
verdict about the filesystem was correct. What was actually wrong was that the failure line gave
no indication of which deployed tree (`.claude` vs `.opencode`) it was resolved against, so a
reader spot-checking `.claude/context/...` found the file and concluded the validator was broken.
Two real defects were fixed: an unattributed failure message in `validate_context_files`, and a
genuine, long-standing data inconsistency in the committed `.opencode/context/index.json`
(41 entries for the memory/nix/neovim extensions, which `.opencode` does not load).

## What Changed

- `agent-system/extensions/core/scripts/validate-wiring.sh` — `validate_context_files` now
  derives a `$system_label` from `$system_dir` (`.claude`/`.opencode`), labels every failure line
  with the tree and the full resolved path (`Missing context file [$system_label]: $path
  (expected at $full_path)`), labels the success line, and emits a per-tree `log_info` line
  (`[$system_label] $missing of $total context index entries missing on disk`).
- `agent-system/extensions/core/scripts/tests/test-validate-wiring.sh` — added case (f)
  (`.claude`-only fixture, one present + one absent context-index entry: asserts exactly one
  tree-attributed failure naming only the absent entry) and case (g) (same setup against the
  `opencode-only` fixture, asserting the failure instead names `.opencode`), plus assertions on
  the new per-tree count line; extended the header comment.
- `.opencode/context/index.json` — pruned 41 dangling entries under `project/memory/`,
  `project/neovim/`, and `project/nix/` (0 of 41 resolved on disk; `.opencode` carries no
  extensions manifest for those extensions), reducing the file from 150 to 109 entries, all of
  which resolve.
- Deployed `.claude/` tree regenerated via `deploy-headless.sh` (gitignored deploy artifact, not
  independently tracked).

## Decisions

- Pruned the dangling `.opencode` index entries rather than mirroring the 41 context files into
  that frozen tree, per the plan's explicit rejection of mirroring/WARN-downgrade alternatives:
  mirroring would expand a frozen tree's footprint just to satisfy stale index entries for
  extensions `.opencode` has no manifest for.
- Derived the tree label via `basename "$system_dir"` with no new function parameter and no
  call-site change, after confirming exactly one call site of `validate_context_files`.
- Used `jq --indent 2` to prune the `.opencode` index, first round-tripping the untouched file
  through the same filter to verify byte-identical output, confirming the edit preserves the
  file's existing formatting conventions exactly.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A
- Tests: Passed — `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
  test-validate-wiring.sh` passes (10/10 assertions, including a negative control that proved
  cases (f)/(g) actually test attribution: reverting the label change caused those exact two
  assertions to fail).
- Files verified: Yes — `.claude/context/index.json` (311 entries) and `.opencode/context/index.json`
  (109 entries) both resolve every entry to a file on disk.
- `bash .claude/scripts/validate-wiring.sh --all` exits 0, `VALIDATION PASSED`, zero `Missing
  context file` lines; `--claude` and `--opencode` each independently report zero.
- Move-aside/restore probe: temporarily removing `.claude/context/architecture/component-checklist.md`
  produced `Missing context file [.claude]: architecture/component-checklist.md (expected at
  <full path>)`; restoring the file returned the run to green with no residual git diff.
- Deployed `.claude/scripts/validate-wiring.sh` and `.claude/scripts/tests/test-validate-wiring.sh`
  confirmed byte-identical to their source-store counterparts after `deploy-headless.sh`.

## Impacts

- The validator's output is now self-auditable: a reader can check a failure against disk
  without first inferring which deployed tree it came from, and a passing run states which tree
  passed.
- The `.opencode` context index no longer claims files that tree does not contain, so
  `validate-wiring.sh --all` is green for the right reason rather than being silenced.
- The regression suite now proves the attribution contract in both directions, guarding against
  a future readability regression in this message.

## Follow-ups

- None directly from this task. Two pre-existing, out-of-scope findings were observed during the
  post-deploy gate run and explicitly left untouched per this dispatch's briefing: a gate10
  (`validate-state.sh --deep`) 30-second wrapper-timeout flake (confirmed passing standalone in
  33.9s) and 2 `/ide` dead-command-recommendation findings in the memory extension's
  `memory-setup.md`/`memory-troubleshooting.md`.

## References

- Plan: specs/466_validate_wiring_missing_context_false_positive/plans/01_wiring-missing-context-attribution.md
- Dispatch: specs/466_validate_wiring_missing_context_false_positive/.dispatch/19.md
