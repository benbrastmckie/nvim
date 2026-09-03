# Implementation Summary: Task #134

- **Task**: 134 - Close the tag-reachability gap so /tag never pushes a tag pointing at unpushed commits
- **Status**: [COMPLETED]
- **Started**: 2026-09-03T00:00:00Z
- **Completed**: 2026-09-03T00:20:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_tag-branch-reachability-gate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`/tag`'s Step 2 ("Validate Git State") computed only the symmetric `behind` count against
`origin/$current_branch` and never the `ahead` count, so tagging from a branch with unpushed
commits produced a pushed tag pointing at a commit absent from the remote -- a consuming repo's
`release.yml` preflight (`git merge-base --is-ancestor`) then rejected the tag only *after* it was
already public, requiring delete-and-re-push to recover. This implementation adds a REFUSE gate to
Step 2 that reuses the fetch and `remote_sha` Step 2 already computes, documents the new failure
mode in SKILL.md's Error Handling section, keeps `commands/tag.md` in sync, and verifies the fix
behaviorally against a real local git origin/clone fixture rather than by inspection alone.

## What Changed

- `agent-system/extensions/core/skills/skill-tag/SKILL.md` -- Step 2: added an `ahead` check
  (`git rev-list --count "origin/$current_branch..HEAD"`) inside the existing `remote_sha` guard,
  immediately after the `behind` block, with an inline comment recording the HEAD-only invariant
  that makes `ahead == 0` mathematically identical to (not a proxy for)
  `git merge-base --is-ancestor HEAD origin/$current_branch`. Updated the closing success line to
  `Git state: OK (clean working tree, fully pushed, up-to-date with remote)`. Also added an
  `### Ahead of Remote (Not Fully Pushed)` subsection to Error Handling, immediately after
  `### Behind Remote`, with example output diffed character-for-character against the new `echo`
  lines.
- `agent-system/extensions/core/commands/tag.md` -- Workflow item 1 now names all three Step 2
  conditions (clean working tree, branch fully pushed, up-to-date with remote); added a
  Requirements bullet for the new gate explaining why a consuming repo's release preflight
  requires the tagged commit to be reachable from `origin/<branch>`. Flag table, Warning,
  Examples, and Agent Restrictions sections left unchanged (no new flag was warranted).

## Decisions

- **REFUSE, not auto-push** (design question 1): pushing a branch is outward-facing and `/tag` is
  user-only precisely because publication timing is a human decision; the remedy is one command
  (`git push origin $current_branch`).
- **Placement: Step 2** (design question 2), inside the existing `remote_sha` guard, reusing the
  fetch and `remote_sha` variable already computed there.
- **Exact predicate, not a proxy** (design question 3): confirmed `/tag` always tags `HEAD` (Step
  6 has no commit-ish argument; Step 4 reports `git rev-parse HEAD`), so `ahead == 0` is
  mathematically identical to the CI's `git merge-base --is-ancestor HEAD origin/$current_branch`
  predicate, not an approximation of it. The HEAD-only invariant is recorded as an inline comment
  so a future maintainer adding non-HEAD tagging knows to re-derive the equivalence.
- **`--dry-run` truthfulness** (design question 4): satisfied by placement alone -- the gate adds
  no new command to preview, and Step 2 already runs unconditionally, strictly before Step 5's
  `--dry-run` early exit (verified behaviorally: `dry_run=true` does not change Step 2's outcome
  in any of the four fixture states).
- **No override flag** (design question 5): an ahead-of-remote branch has exactly one safe remedy
  and no legitimate bypass; a `--skip-*` flag would hand back the exact footgun this gate closes.
  Neither file's flag table was changed.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (markdown/shell skill file, no build step)
- Tests: Passed -- all 12 fenced `bash` blocks extracted from SKILL.md pass `bash -n`; a real
  bare-origin + clone fixture in the scratchpad directory (never committed) drove Step 2's logic
  through four states, each with a `dry_run=true` variant:
  - (a) fully pushed -> exit 0, prints the revised "fully pushed" success line.
  - (b) 5 unpushed commits -> exit 1, message names the correct count (5), branch (`main`),
    consequence, and remedy.
  - (c) 1 commit behind -> exit 1 with the pre-existing behind message (unchanged behavior).
  - (c-diverged) 1 ahead + 5 behind -> the behind message fires first, confirming the documented
    ordering (pulling is a prerequisite before "ahead" can be correctly assessed).
  - (d) each of (a)-(c) re-run with `dry_run=true` -> identical outcome, confirming Step 2 is
    unconditional and structurally precedes Step 5's early exit.
  - A real tag (`v0.0.1-test`) created and pushed in case (a)'s fixture satisfies
    `git merge-base --is-ancestor v0.0.1-test origin/main` (exit 0) -- the literal CI-gate
    assertion, not a stand-in.
  - `git status --short` in this repository confirmed no file under any `.claude/` directory was
    modified and no fixture artifact leaked into the repository.
- Files verified: Yes -- both edited files confirmed under `agent-system/extensions/core/`, not
  `.claude/`.

## Impacts

- `/tag` now hard-stops (REFUSE) before creating any tag when the current branch has commits not
  yet pushed to `origin/<branch>`, closing the third and last uncovered gate in the reference
  `release.yml` preflight (`git merge-base --is-ancestor`). Consuming repos following `/tag` as
  documented can no longer produce a pushed tag that fails that preflight after the fact.
- `commands/tag.md` no longer silently contradicts SKILL.md's actual Step 2 behavior.

## Follow-ups

- None. The recorded scope boundary (a branch with no upstream at all, or a failed fetch, both
  yield `remote_sha=""` and are indistinguishable without an extra network round-trip) is a
  pre-existing fail-open posture, deliberately left unchanged per the plan's Non-Goals.

## References

- `specs/134_tag_branch_reachability_gate/plans/01_tag-branch-reachability-gate.md`
- `specs/134_tag_branch_reachability_gate/reports/01_tag-branch-reachability-gate.md`
- `specs/131_tag_annotated_and_changelog_preflight/summaries/01_tag-annotated-changelog-preflight-summary.md` (prior art / follow-up filing)
