# Implementation Summary: Task #615

- **Task**: 615 - Retract extension grants on unload
- **Status**: [COMPLETED]
- **Started**: 2026-11-13T17:09:16Z
- **Completed**: 2026-11-13T19:40:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_retract-extension-grants-unload.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed `deep_merge`'s plain-array branch (`lua/neotex/plugins/ai/shared/extensions/merge.lua`) so
it records every fragment item in the tracking record regardless of pre-existence, instead of
deduping an item against the target *before* recording it. This closes the gap that made a
`permissions.allow`/`permissions.deny` (and non-`matcher` hook-event) tracking record go empty
after the first reload of an already-loaded extension, which meant unloading that extension
retracted none of its grants. Added a still-declared-by-another-loaded-extension guard to
`M.unmerge_settings` (via `opts.retained_fragments`/`opts.skip_array_removal`) and plumbed it
through `manager.unload` in `init.lua`, so an unload never strips a grant a sibling extension's
own fragment still declares. Covered all of this in six new `merge_spec.lua` cases, documented
the decision and its scope boundaries in a new pattern file, and repaired the four stale
records this repository already carried (`sapience` allow, `nix` allow, `lean` allow, `email`
deny) via a plain redeploy.

## What Changed

- `lua/neotex/plugins/ai/shared/extensions/merge.lua` — moved the tracking insert outside
  `deep_merge`'s dedup guard; extended `M.unmerge_settings` with `opts.retained_fragments` /
  `opts.skip_array_removal` and the `retained_at`/`descend` helpers that thread sibling
  fragments through the unmerge recursion.
- `lua/neotex/plugins/ai/shared/extensions/init.lua` — added `build_retained_fragments` beside
  `build_hook_valid_set`; built the retained set in `manager.unload` before
  `reverse_merge_targets`; extended `reverse_merge_targets` to forward `opts` to both
  `unmerge_settings` call sites; left the failed-load rollback call site passing no `opts`, with
  a comment recording that asymmetry as deliberate.
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` — repointed `read_host_fixture` at a
  new sibling fixture (recovered from commit `fc8cca3f0`) instead of an archived `specs/` task
  directory; corrected the pre-existing mcpServers "requirement (c)" test, which encoded the
  defect's old behavior for a nested array field; added a six-case `describe` block covering
  fresh merge, re-merge, unmerge-after-each, the coinciding-user-grant accepted residual,
  sibling-extension retention, and hooks non-regression.
- `lua/neotex/plugins/ai/shared/extensions/host_settings_fixture.json` — new file, the recovered
  fixture, sited beside the spec.
- `agent-system/extensions/nvim/context/project/neovim/patterns/merge-tracking-contract.md` —
  new pattern file: the defect, the fix, the tracking-shape decision and its rejected
  alternatives, the accepted residual, the array-path enumeration (including the mcpServers
  nested-field nuance and the wholesale-removal scope boundary), and the real (plain redeploy,
  never `--wipe`) repair route.
- `agent-system/extensions/nvim/index-entries.json` — index entry for the pattern file above.
- `.claude-extensions.json` — the four stale records repopulated as a redeploy side effect
  (`sapience` allow: 11, `nix` allow: 2, `lean` allow: 1, `email` deny: 7), plus sapience's four
  non-`matcher` hook events (`SessionStart`/`SessionEnd`/`UserPromptSubmit`/`Stop`).
- `agent-system/extensions/sapience/index-entries.json` — two stale `line_count` declarations
  reconciled as an incidental, correct side effect of the same redeploy (landed in a separate
  scoped follow-up commit, since it fell outside this task's declared `file_scope`).

## Decisions

- **Tracking shape**: track every fragment item unconditionally (shape (i)), extended with a
  still-declared-by-another-loaded-extension guard at unmerge time — not a provenance
  distinction (shape (ii): would misclassify every already-stale record's items as
  pre-existing and retract nothing) and not a reconcile-at-unload design (shape (iii): once the
  tracking record is complete, this shape's only advantage disappears, leaving only its cost).
- **Repair route**: a plain redeploy (`deploy-headless.sh`), not `--wipe` — `manager.wipe`
  restores `settings.local.json` as the merge base before `resync_all`, reproducing the same
  dedup-before-track check an unfixed engine would re-trigger.
- **Accepted residual**: a hand-added user grant coinciding with an extension's declared grant
  is removed on that extension's unload. A grant meant to survive independently of an
  extension's lifecycle belongs in `.claude/settings.json`, which no merge path touches.

## Plan Deviations

- **Phase 2**: Corrected `merge_spec.lua`'s pre-existing mcpServers "requirement (c)" test
  (pulled forward from Phase 4) — it asserted the old dedup-before-track behavior for a nested
  array field (`mcpServers.fixture.args`), which turns out to reach the same plain-array arm as
  `permissions.allow` on a second merge.
- **Phase 4**: Case 5 and Case 6 were re-seeded with a pre-existing array/hook entry (rather than
  a fresh/empty target) after discovering that `opts.retained_fragments` only guards the
  `"appended"`/`"hook_merged"` branches, not the wholesale-removal `"new_array"`/`"new_object"`/
  `"new_value"` types. Recorded as a scope boundary in the Phase 5 pattern file rather than
  extended, since none of the four repaired records is ever a fresh/never-before-populated
  array in practice.
- **Phase 6**: Discharged the plan's "run the complete gate set" task against the dispatch's
  Batch Gate Deferral scoped tier (`verify-deploy.sh --only-gate 3,4,5,13`, all passing) instead
  of the unscoped full battery, per the dispatch directive for this multi-task batch invocation.
  `deploy-headless.sh`'s own fast-gate pass separately surfaced 2 pre-existing, out-of-scope
  findings (a gate-10 timing flake; a gate-20 `SKILL.md` budget overage traced via `git log` to
  commit `9be017d79`, predating this task) — neither touches a file this task modified.

## Verification

- Build: N/A (Lua config, no build step)
- Tests: `merge_spec.lua` 30 successes, 0 failures, 0 errors (headless, post-redeploy); 5 named
  shell suites (`test-mcp-merge-target.sh`, `test-deploy-orphans.sh`,
  `test-deploy-verify-overlap.sh`, `test-deploy-propagation.sh`, `test-index-entries-schema.sh`)
  all pass; `verify-deploy.sh --only-gate 3,4,5,13` passes (doc-lint, task-reference lint,
  manifest parity/content-hash equality, whole-tree orphan detection).
- Files verified: Yes — `.claude-extensions.json`'s four records and sapience's four hook events
  confirmed populated with the exact declared counts; `.claude/settings.local.json`'s eleven
  sapience grants confirmed present and unduplicated after the redeploy.

## Impacts

- Loading an extension that declares `permissions.allow`/`permissions.deny` entries into a repo
  where those entries already exist now produces a non-empty tracking record, and unloading
  retracts exactly the declared set minus whatever a sibling extension still declares.
- Unloading the `email` extension now also removes its `permissions.deny` entries (a symmetric
  loosening, not a tightening, and the correct behavior going forward).
- A hand-added user grant coinciding with an extension's own declared grant will be removed on
  that extension's unload (the accepted residual — see the pattern file for the durable home for
  a grant meant to survive an unload: `.claude/settings.json`).

## Follow-ups

- The companion task in `/home/benjamin/.dotfiles` (`retire_machine_wide_sapience_surface`)
  states the seven read-tool sapience grants "retract cleanly on unload" while only the four
  write-tool grants survive. This task's research report measured the opposite: the tracking
  array was empty for all eleven, in both files, before this fix. That correction needs to be
  carried across by hand, since this task's edit scope is local to this repository only.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` exceeds its orchestrator
  context budget ceiling (25510B vs 25000B), and `specs/state.json` schema validation (gate 10)
  timed out during this task's redeploy run. Both predate this task and are unrelated to its
  files; recorded via `issue-record.sh` for separate follow-up.
- The untracked `agent-system/extensions/core/.claude-extensions.json` anomaly (flagged in the
  plan's Risks table) remains unexplained and out of scope; left untouched.

## References

- specs/615_retract_extension_grants_on_unload/reports/01_retract-extension-grants-unload.md
- specs/615_retract_extension_grants_on_unload/plans/01_retract-extension-grants-unload.md
- agent-system/extensions/nvim/context/project/neovim/patterns/merge-tracking-contract.md
- specs/615_retract_extension_grants_on_unload/issues.jsonl
