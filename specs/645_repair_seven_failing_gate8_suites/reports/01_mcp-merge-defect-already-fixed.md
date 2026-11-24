# Research Report: Task #645

**Task**: 645 - Repair seven failing Gate 8 suites (remaining scope: the `.mcp.json` merge defect)
**Started**: 2026-11-23
**Completed**: 2026-11-23
**Effort**: ~1 hour (direct test runs + code trace + git archaeology; no full gate battery run)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/tests/test-mcp-merge-target.sh` (identical to the
  deployed `.claude/scripts/tests/test-mcp-merge-target.sh`), `lua/neotex/plugins/ai/shared/extensions/merge.lua`,
  `lua/neotex/plugins/ai/shared/extensions/init.lua`, `agent-system/extensions/nvim/context/project/neovim/patterns/merge-tracking-contract.md`
- Git history: `git log`/`git show` on `merge.lua` and the contract doc
- Direct execution: two runs of `test-mcp-merge-target.sh`, one attempted full `verify-deploy.sh`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect this task names as "remaining scope" -- `test-mcp-merge-target.sh` Assertions C and
  E, a hand-written `.mcp.json` server entry not surviving a forced-reload regenerate or a
  subsequent unload -- was **already fixed before this research dispatch began**, by commit
  `3c7f91a92` ("orchestrate conclusion: channel (a) direct fixes", landed 2026-11-19), which
  post-dates the task description's own last revision (2026-11-18, `sess_1795021326`). The
  description was never re-synced after that fix landed.
- Two direct runs of the suite in this dispatch (`bash .claude/scripts/tests/test-mcp-merge-target.sh`)
  both report **7 passed, 0 failed, exit 0**, deterministically.
- **Root cause (single, not two)**: Assertions C and E shared one root cause.
  `merge.lua`'s `M.unmerge_settings`'s `remove_tracked` helper treated three tracked-entry types
  -- `"new_array"`, `"new_object"`, and `"new_value"` -- identically: unconditional wholesale
  `t[key] = nil`. For an object-shaped merge target (`.mcp.json`'s `mcpServers` map, and the
  per-server entry nested inside it), the FIRST extension to populate that object key is tracked
  as `"new_object"`. Wholesale removal of a `"new_object"` deletes the *entire* object, including
  any sibling key a user hand-added into it afterward (e.g. `mcpServers.hand-written-server`) --
  not just the tracked extension's own sub-keys. Assertion C (retraction-then-remerge during a
  forced reload) and Assertion E (unload after that same regenerate) both exercise this exact
  code path on the exact same tracked record, so they are **one fault, not two**.
- **Which side was wrong**: the merge code (`merge.lua`'s `remove_tracked`), not the test's
  expectation. The task's own framing ("treat correctness of the merge as the default and the
  test expectations as correct unless evidence says otherwise") was the right call: the fix commit
  made `remove_tracked`'s `"new_object"` branch recurse into the object's tracked `children` (the
  same shape the `"merged"` branch already used) and only prune the object once nothing is left
  inside it -- exactly mirroring what `"appended"`/`"merged"` already did for arrays/objects whose
  own existence predates the merge. `"new_array"` and `"new_value"` keep unconditional removal
  (correct: a scalar or a freshly-created array has no nested tracked structure a hand-written
  sibling could hide inside).
- No further code change is needed. The remaining task work is **confirmatory**: run the full
  `verify-deploy.sh` gate set and `deploy-headless.sh` to formally close acceptance criteria 1, 4,
  and 5. This dispatch deliberately did **not** run the full gate battery itself -- see
  "Batch-Gate Deferral" below.

## Context & Scope

Task 645's description (as last revised) frames six of seven originally-measured Gate 8 findings
as already closed (provenance only, not re-diagnosed here) and names
`test-mcp-merge-target.sh`'s Assertions C and E as the one remaining genuine defect: a
hand-written `.mcp.json` server entry not surviving (C) a load -> plant -> forced-reload cycle,
and (E) a subsequent unload. The binding constraints forbid silencing the failure by loosening an
assertion, and forbid adding the suite to `known-failures.txt`. This research traced the defect
to its exact code location, determined whether it is still live, and -- since it was not --
determined when and how it was already closed, and by what commit.

## Findings

### Codebase Patterns

- **Merge-target architecture**: `merge_targets.mcp` in an extension's `manifest.json` reuses the
  exact same `merge.lua` machinery (`M.merge_settings` / `M.unmerge_settings` / `deep_merge` /
  `remove_tracked`) that drives `merge_targets.settings` (`.claude/settings.json`), parameterized
  only by target path and a `sort_keys = true` option for byte-stable redeploys
  (`init.lua:370-386`, `process_merge_targets`). The `.mcp.json` fixture extension used by the
  test declares only `merge_targets.mcp` (no `settings` target), which matters below.
- **Forced-reload retraction** (`init.lua:920-960`, inside `manager.load`): when
  `opts.force` is set on an already-loaded extension, the engine retracts the extension's own
  *prior* tracked `merged_sections` (read from `state.json` before it is overwritten) via
  `reverse_merge_targets`, THEN re-runs `process_merge_targets` to re-merge the *current*
  fragment. This retract-then-remerge round trip is what exposes the "new_object" defect: between
  retraction and remerge, a hand-written sibling key sitting in the SAME object the extension's
  own first load created is vulnerable to being deleted along with the object itself, unless
  `remove_tracked`'s `"new_object"` branch specifically preserves it. The retraction call at
  `init.lua:955` runs unconditionally whenever `prior_merged_sections` is non-empty -- it is not
  gated on whether the extension declares a `settings` merge target, so it fires correctly for an
  `mcp`-only fixture like the test's.
- **`remove_tracked`'s three wholesale-removal types, before the fix** (pre-`3c7f91a92`
  `merge.lua`): `"new_array"`, `"new_object"`, and `"new_value"` were one `if` branch,
  unconditionally `t[key] = nil`. This is correct for `"new_array"`/`"new_value"` (a freshly
  created array or scalar has no nested tracked children a sibling entry could occupy) but wrong
  for `"new_object"`, whose children ARE individually tracked (`deep_merge`'s "Object: recurse"
  arm always sets `children = {}` and recurses) -- exactly the shape the sibling `"merged"` branch
  already knew how to walk.
- **The exact fix** (commit `3c7f91a92`, `merge.lua` `remove_tracked`): split `"new_object"` into
  its own branch that recurses into `info.children` (mirroring `"merged"`) and only sets
  `t[key] = nil` after that recursion leaves the object `vim.tbl_isempty`. A defensive fallback
  branch (`"new_object"` with no `info.children`, which `deep_merge` never actually produces)
  preserves the old unconditional-removal behavior rather than silently no-op'ing.
- **Documentation parity**: the same commit updated
  `agent-system/extensions/nvim/context/project/neovim/patterns/merge-tracking-contract.md`'s
  scope-boundary and per-field-type tables, changing `mcpServers.<name>` first-time insertion from
  "Immune, unchanged" to "Also fixed, separately" and adding a dedicated explanation of why
  `"new_object"` no longer behaves like `"new_array"`/`"new_value"`. Code and doc are consistent
  as of this dispatch.
- **Source-store boundary mismatch**: the task description instructs "SOURCE STORE IS THE EDIT
  TARGET: `agent-system/extensions/core/**`", but the actual defect and its fix live entirely
  OUTSIDE `agent-system/**`'s `core` extension: `merge.lua`/`init.lua` are primary Neovim plugin
  code under `lua/neotex/plugins/ai/shared/extensions/`, governed by the root `CLAUDE.md`'s Lua
  standards and `neovim-lua.md`, edited directly (no deploy step -- confirmed not mirrored
  anywhere under `agent-system/`), and the contract-doc half of the fix landed under
  `agent-system/extensions/nvim/` (the `nvim` extension), not `core`. Only the test file itself
  (`test-mcp-merge-target.sh`, unchanged by the fix) lives under `agent-system/extensions/core/`.
  A planner should not expect this task's remaining work to involve any `core`-source-store edit.

### External Resources

Not applicable -- this is a self-contained in-repo Lua/shell defect; no external documentation
was consulted or needed.

### Direct Verification

Two consecutive direct runs of `bash .claude/scripts/tests/test-mcp-merge-target.sh` (identical
to the source-store copy under `agent-system/extensions/core/scripts/tests/`) both produced:

```
Results: 7 passed, 0 failed
```
exit code `0`, including:
- `[PASS] Assertion C (requirement d): hand-written entry survives regeneration alongside the extension's own entry`
- `[PASS] Assertion E: retraction still happened after a load -> regenerate -> unload sequence (tracking was not thinned in this run), and the hand-written entry survived`

`known-failures.txt` currently carries exactly 4 data rows (`test-run-all-parallel.sh`,
`test-gate-cache-equivalence.sh`, `test-verify-deploy-context-budget.sh`,
`test-double-loading-check.sh`) -- matching the task description's own count and unchanged by
this dispatch (no row added or removed).

### Batch-Gate Deferral (why the full gate set was not run here)

An unfiltered `verify-deploy.sh` invocation during this dispatch was refused with:

```
[verify-deploy] DEFERRED: a batch-gate-pending marker exists and this invocation is unfiltered --
the complete gate set is already owed to that session's own once-per-invocation batch-gate stage.
```

This is the `/orchestrate` batch's own mechanism (this dispatch runs concurrently with sibling
tasks 693 and 697 in the same cycle, per the Territory block) ensuring the full 42-gate battery
runs exactly once per batch, in the orchestrator's own gate stage, rather than once per concurrent
dispatch. `--override-batch-gate-deferral` is reserved for that stage's own discharger, not an
individual research dispatch, so this research deliberately did not force it. The suite-level
confirmation above (direct run, twice, deterministic) is the strongest evidence obtainable without
either overriding that deferral or duplicating the batch's own forthcoming gate run.

## Recommendations

- **No code change is required.** The implementation phase for this task should be verification-
  only: run the full `verify-deploy.sh` gate set (expected: exit 0, or a `warn_advisory`-tier
  all-expected Gate 8 given the unchanged 4-row `known-failures.txt`) and `deploy-headless.sh`
  (expected: `RESULT=landed_verify_clean`), to formally close acceptance criteria 1, 4, and 5 with
  verbatim pass/fail counts quoted, exactly as acceptance criterion 2 already requires for the
  suite's own direct run.
- The plan should **not** scope any edit under `agent-system/extensions/core/**` for this
  defect -- there is nothing left to fix there. If the plan needs an edit target at all (e.g. to
  correct the task's own stale framing for a future reader, which is a `specs/**` artifact
  concern, not a deliverable-file concern), it is in `specs/**` only.
- If the full gate run (run by the implementation phase, after the batch-gate deferral clears)
  surfaces a different, NEW Gate 8 failure not among the four known rows, treat that as a
  separate, newly-discovered defect -- out of scope for the diagnosis in this report, which is
  specific to the C/E hand-written-entry-survival defect this task named.

## Decisions

- Confirmed (not re-derived from scratch) that Assertions C and E are **one root cause**, per the
  task's own request to state this explicitly: both exercise `remove_tracked`'s `"new_object"`
  branch against the identical tracked record (`mcpServers` -> `mcpfixture-server`) created by
  the fixture's first load; C observes it directly (post-regenerate), E observes the same object
  surviving one step further (post-regenerate-then-unload). No second, independent fault was
  found in the unload path itself.
- Determined the merge CODE was the wrong side (not the test), consistent with the task's default
  framing, and verified this via the already-landed fix rather than re-deriving a new fix.

## Risks & Mitigations

- **Risk**: the batch's own full gate run (deferred above) could still surface a NEW Gate 8
  failure unrelated to this defect, since no full sweep was run in this dispatch. **Mitigation**:
  the implementation phase runs the full gate set as its own closing step (acceptance criterion
  1); this report's scope is limited to the named C/E defect, which is confirmed closed.
- **Risk**: a future reader of the task description (not re-synced since 2026-11-18) could waste
  effort re-diagnosing or re-editing `agent-system/extensions/core/**` for a defect that is
  already fixed elsewhere. **Mitigation**: recorded as an issue-log entry
  (`stale-task-description`, minor, phase research) and stated plainly in this report's Findings.

## Context Extension Recommendations

None -- no gap in `.claude/context/` documentation was identified. The relevant contract doc
(`merge-tracking-contract.md`) was already updated in lockstep with the code fix.

## Appendix

- Search queries / commands used: `find` for `*mcp-merge*`; `git log --oneline -- merge.lua` /
  `init.lua` / the test file; `git show 3c7f91a92 -- merge.lua` / `-- merge-tracking-contract.md`;
  two direct runs of `bash .claude/scripts/tests/test-mcp-merge-target.sh`; one attempted
  unfiltered `verify-deploy.sh --quiet` (refused, batch-gate-pending); `specs/.gate-cache/*.json`
  inspection (no `gate8.json` entry exists, consistent with Gate 8 never being cache-write-eligible
  under an all-expected/warn_advisory outcome).
- Key files read in full: `agent-system/extensions/core/scripts/tests/test-mcp-merge-target.sh`,
  `lua/neotex/plugins/ai/shared/extensions/merge.lua`, relevant sections of
  `lua/neotex/plugins/ai/shared/extensions/init.lua` (`process_merge_targets`,
  `reverse_merge_targets`, `manager.load`'s forced-reload retraction block).
- Commit referenced: `3c7f91a929fa8c1e4560cc9e2cb571abb105c014` ("orchestrate conclusion: channel
  (a) direct fixes", 2026-11-19).
