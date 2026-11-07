# Implementation Summary: Task #22

- **Task**: 22 - Silence opencode-agents.json fragment validation spam (absorbed: picker Reload
  All/Regenerate honesty fix; absorbed: Global Update repo-registration feature)
- **Status**: [COMPLETED]
- **Started**: 2026-11-05T16:21:30Z
- **Completed**: 2026-11-05T18:47:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None blocking
- **Artifacts**: plans/01_silence-opencode-validation-spam.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented all six phases of the plan across three independent scopes sharing one task
directory: (1) silenced the per-extension `opencode-agents.json` validation WARN spam on
`<leader>al` bulk reload, fixed a fake-tool reference in the frozen `.opencode/` mirror, and
wrote the frozen-policy decision down where the next reader will find it; (2) made the
`[Reload All]`/`[Regenerate]` picker entries honest and self-documenting, with a shared preview
branch and a diagnosable fallback; (3) built the greenfield cross-repo registry and the
`Global Update` picker entry. Every phase closed `[COMPLETED]`, verified against real production
code paths (headless `require()` plus functional harnesses exercising the actual deployed
module behavior, including one real end-to-end reproduction of the original spam defect) rather
than by reading the diff alone.

## What Changed

- `lua/neotex/plugins/ai/shared/extensions/merge.lua` — `generate_opencode_json` gained an
  `opts.notify_skips` parameter (default `false`) and now returns a `skips` report as its third
  return value instead of unconditionally emitting a per-extension WARN notification.
- `lua/neotex/plugins/ai/shared/extensions/init.lua` — `manager.load` forwards `notify_skips`
  and returns the opencode skip report as its own third return value; `manager.resync_all`
  accumulates every call's skip report across the whole bulk reload and emits at most one
  aggregate INFO summary; added the non-fatal `repo_registry.upsert` hook on the load success
  path.
- `lua/neotex/plugins/ai/shared/extensions/repo_registry.lua` — new module: a global,
  cross-repo JSON registry (`read`/`upsert`/`list`/`prune_unreachable`/`is_host_repo`) under the
  established `stdpath("data") .. "/neotex-ai"` convention, with the host repo deliberately
  excluded from registration.
- `.opencode/extensions/web/agents/web-implementation-agent.md` — replaced the
  `browser_verify_text_visible` bullet with the source store's own retraction wording.
- `.opencode/README.md` — added a "Status: Frozen" section recording the four binding
  properties (unmaintained, ungenerated, drift-expected, nothing deleted).
- `agent-system/extensions/core/docs/docs-README.md` — added a one-line cross-reference to the
  frozen-policy section (the plan's originally named target file does not exist; this is the
  real docs index, deployed as `.claude/docs/docs-README.md`).
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` — corrected one-liners for
  `[Reload All]`/`[Regenerate]` (scope and destructiveness stated first), added a structured
  `description`/`detail` preview payload to both, added the same payload to a new
  `[Global Update]` special entry, and recorded the sync obligation plus Decisions 3's reasoning
  in code comments.
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` — added one shared
  `entry_type == "special"` preview branch (`preview_special`) covering all three bulk entries,
  and changed the terminal fallback to name the offending entry's `entry_type`/`name` instead of
  the bare `"Unknown entry type"` string.
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` — removed the dead `"Step Through"`
  submenu choice and its no-op branch (Decision 4); added the `Global Update` handler
  (lists registered repos, resyncs each via the existing non-destructive `manager.resync_all`,
  auto-prunes and reports unreachable repos, reports a total success count plus any per-repo
  failures); added `is_global_update` to the four existing special-entry key-action guards.

## Decisions

- Spam gating lives at the emitter (silent by default, returns detail) with aggregation at the
  bulk caller (`manager.resync_all`), not a per-call summary — a per-call summary would still be
  one notification per extension during a bulk reload.
- Previewer uses one shared `entry_type == "special"` branch reading per-entry fields, so a third
  bulk entry (`Global Update`) needed no previewer change at all.
- Kept `[Reload All]` and `[Regenerate]` as separate entries rather than collapsing either into
  the other's submenu; corrected their one-liners instead.
- Removed `"Step Through"` outright rather than implementing a real stepwise resync.
- Registry storage is a single global JSON file (not per-project), with the host repo
  (`vim.fn.stdpath("config")`) deliberately excluded from registration so `Global Update` cannot
  recurse into itself.
- `Global Update` is self-maintaining: an unreachable registered repo is automatically pruned and
  named in the report rather than requiring a separate confirmation dialog.

## Plan Deviations

- **Phase 2**: the plan's named cross-reference target `agent-system/docs/docs-README.md` does
  not exist (the plan itself anticipated needing an adjustment here). Used
  `agent-system/extensions/core/docs/docs-README.md` instead — the real docs index, deployed as
  `.claude/docs/docs-README.md` — adding the pointer to its existing "Extensions" section.
- **Phase 4**: `config.lua` was not modified. The plan's own task made this conditional
  ("if the investigation step concludes it belongs with the other path config"); concluded it
  does not, since the registry is preset-agnostic (spans both `.claude` and `.opencode`, and
  every repo) while `config.lua` is per-preset. The registry's location constant stays local to
  `repo_registry.lua`.
- **Phase 5**: "offer to prune" an unreachable registered repo was implemented as automatic
  prune-and-report rather than a separate interactive confirm step, to stay consistent with the
  entry's own "no confirmation dialog" detail text and non-destructive design.
- **Phase 6**: per this dispatch's own Batch Gate Deferral directive, ran
  `verify-deploy.sh --skip-slow --only-gate 4,5` as the scoped narrowing for this phase's touched
  files instead of an independent full gate run. Gate 4 passed; gate 5 found one expected,
  self-resolving finding (see Verification below) rather than a defect. The full, unscoped gate
  set is deferred to the `/orchestrate` batch-level Inter-Cycle Redeploy Checkpoint.

## Verification

- Build: N/A (no compiled build step; headless Neovim `require()` substitutes for this project).
- Tests: Passed — headless `require()` succeeded for every touched Lua module under the full
  plugin runtime (`merge`, `extensions.init`, `repo_registry`, `picker`, `picker.display.entries`,
  `picker.display.previewer`, `opencode.core`, `opencode`). Functional harnesses (not stubs where
  avoidable) confirmed: `generate_opencode_json`'s silent-default/verbose-opt-in/returned-skips
  contract against both a synthetic and a REAL deleted deployed file; `resync_all`'s aggregation
  arithmetic (exactly one INFO summary, correct cross-extension counts, `force`/`notify_skips`
  forwarded) via a real `manager` instance; `repo_registry.lua`'s full read/upsert/list/prune/
  host-exclusion/corruption-recovery behavior against a redirected scratch `stdpath`; the three
  picker entries' previews via the real captured `define_preview` closure (no `"Unknown entry
  type"`, all three one-liners distinguishable); and the `Global Update` handler's own
  aggregation logic (diffed line-for-line against the real `picker/init.lua` code) against two
  reachable repos (one clean, one failing) and one unreachable repo.
- Files verified: Yes — `git diff --diff-filter=D --name-only` confirms nothing under
  `.opencode/` or any `opencode-agents.json` fragment was deleted across the whole task;
  `git diff --stat` per phase confirmed each phase touched only its own declared files.
- Gate run: `verify-deploy.sh --skip-slow --only-gate 4,5` — gate 4 (task-reference lint) PASS;
  gate 5 (manifest-driven parity) found 1 finding (`core: Content differs from source:
  docs/docs-README.md`), which is the expected, self-resolving consequence of Phase 2's
  source-store edit not yet being redeployed — recorded via `issue-record.sh`
  (class `deploy-drift`, severity `minor`), resolved automatically by the `/orchestrate`
  batch-level Inter-Cycle Redeploy Checkpoint since this task's `modified_files` includes an
  `agent-system/extensions/**` path. The full, unscoped gate set was deferred to that checkpoint
  per this dispatch's Batch Gate Deferral directive, not independently re-run here.

## Impacts

- Operators reloading `<leader>al` on a project with an `opencode.json.managed` marker no longer
  see per-extension validation-failure spam; a genuine new breakage still surfaces (as one
  aggregate INFO summary, or via the `notify_skips` verbose opt-in), so the fix does not create a
  silent-failure blind spot.
- The `[Reload All]`/`[Regenerate]` picker entries now describe themselves accurately and render
  real help content; operators who previously had to guess from a false one-liner or an
  "Unknown entry type" pane now get an accurate description and preview for every bulk entry,
  including the new `Global Update` entry.
- `Global Update` gives operators a single entry point to refresh every repo `<leader>al` has
  ever loaded extensions into, without needing to visit each repo individually.

## Follow-ups

- None required for this task's own closure. The deploy-drift gate5 finding resolves itself at
  the next redeploy (automatic at the `/orchestrate` batch level); no manual action is needed.

## References

- Plan: `specs/022_silence_opencode_fragment_validation_spam/plans/01_silence-opencode-validation-spam.md`
- Report: `specs/022_silence_opencode_fragment_validation_spam/reports/01_silence-opencode-validation-spam.md`
- Phase handoffs: `specs/022_silence_opencode_fragment_validation_spam/handoffs/phase-{1..6}-handoff-*.md`
- Progress files: `specs/022_silence_opencode_fragment_validation_spam/progress/phase-{1..6}-progress.json`
