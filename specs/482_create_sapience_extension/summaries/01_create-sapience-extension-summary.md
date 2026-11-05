# Implementation Summary: Task #482

- **Task**: 482 - Create sapience extension
- **Status**: [COMPLETED]
- **Started**: 2026-11-05T15:41:00Z
- **Completed**: 2026-11-05T17:15:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_create-sapience-extension.md, reports/01_create-sapience-extension.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Created a new `sapience` extension in the source store at `agent-system/extensions/sapience/`,
modeled on `agent-system/extensions/approvals/`/`agent-system/extensions/literature/` for its
top-level manifest fields (no `task_type`, no `routing_agents`, `routing_exempt: true`) and on
`agent-system/extensions/memory/` for merge-target shape and directory layout. The extension
closes the MCP write-tool permission gap via `settings-fragment.json`, carries a postflight
`sapience_wrapup` instruction in `EXTENSION.md`, and documents the vault model, review-gate
boundary, transcript-filter ceiling, and the deliberate absence of a per-dispatch context
injection hook in five `context/project/sapience/` files. The extension was activated, the
deployed `.claude/` tree regenerated, and all scoped verification gates confirmed green.

## What Changed

- `agent-system/extensions/sapience/manifest.json` — new; extension declaration with no
  `task_type`/`routing_agents`/top-level `hooks`, `routing_exempt: true`, three merge targets
  (`claudemd`, `index`, `settings`)
- `agent-system/extensions/sapience/settings-fragment.json` — new; `permissions.allow` granting
  the four MCP write tools (`sapience_remember`, `sapience_wrapup`, `sapience_handoff`,
  `sapience_adddoc`), no `mcpServers` key
- `agent-system/extensions/sapience/EXTENSION.md` — new; merges into `.claude/CLAUDE.md` under
  `extension_sapience`; carries the postflight wrapup instruction and context pointers
- `agent-system/extensions/sapience/README.md` — new; purpose, file inventory, gap inventory
- `agent-system/extensions/sapience/index-entries.json` — new; five on-demand (`on_demand: true`,
  empty `load_when`) context index entries, one per domain file
- `agent-system/extensions/sapience/context/project/sapience/README.md` — new; navigation index
- `agent-system/extensions/sapience/context/project/sapience/domain/vault-model.md` — new; hosted
  vault model, MCP thin client, `mcp.py`'s exact CLI mode inventory (no `--search`/`--ask`)
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md` —
  new; staged-and-reviewed extraction path vs. direct-and-unreviewed MCP write tools, and the
  repository-scoped permission-grant tradeoff
- `agent-system/extensions/sapience/context/project/sapience/domain/transcript-filter-ceiling.md`
  — new; `source_skip()` mechanics and why orchestrated work cannot reach the vault except by
  explicit tool call
- `agent-system/extensions/sapience/context/project/sapience/domain/subagent-orientation.md` —
  new; the checkable refutation of the gap-3 context-injection-hook approach and the deliberate
  session-level-plus-on-demand alternative
- `.claude-extensions.json` — gained the `sapience` activation entry (written by the extension
  manager via `manager.load`, not hand-edited)
- Regenerated deployed tree (gitignored): `.claude/CLAUDE.md` section `extension_sapience`,
  `.claude/settings.local.json` (+4 permission grants, additive), `.claude/context/index.json`
  (+5 entries), `.claude/context/project/sapience/**`, `.claude/extensions/sapience/manifest.json`

## Decisions

- Modeled the manifest's top-level fields on `approvals`/`literature`, not `memory` (no
  `task_type`, no `routing_agents`), per the research's verified finding and the dispatch's
  non-goal (a).
- Dropped the dispatch-named `scripts/sapience-context.sh` gap-3 deliverable entirely: a
  manifest `hooks.context_injection` entry is structurally unreachable for a `task_type`-less
  extension (`skill_get_extension_dir()`'s first-match-on-`task_type` resolution in
  `skill-base.sh`), confirmed by direct code reading before writing anything.
- Listed the four write-tool grants explicitly rather than a `mcp__sapience__*` wildcard,
  matching the existing seven-entry dotfiles allow-list's own one-tool-per-line convention.
- Accepted gap 1's fix as repository-scoped, not machine-wide, as a deliberate, documented
  tradeoff rather than editing the out-of-scope `~/.dotfiles` repository.

## Plan Deviations

- **Phase 5 task "Run the complete gate set"** altered: the dispatch file for this invocation
  carried a Batch Gate Deferral directive (this task is one of several `implement`-phase
  dispatches in one multi-task `/orchestrate` batch), directing a scoped `verify-deploy.sh
  --only-gate` invocation instead of an independent full run. Ran `--only-gate 2,3,4,5,13,20`
  (hook registrations, doc-lint, task-reference lint, manifest-driven parity/content-hash,
  orphan detection, context-budget lock) — 12 checks, 0 failures. The complete, unfiltered gate
  set is deferred to the once-per-invocation batch-level stage, not forgiven.
- **Phase 5 task "If headless activation cannot run"** skipped: not applicable — nvim was
  available and the headless `manager.load('sapience', ...)` call succeeded on the first
  attempt, so the `[BLOCKED]`-fallback branch was never entered.
- **Phase 2's EXTENSION.md line-count target (35-45 lines)** superseded by a real measured
  constraint discovered during phase 5 verification: merging the initial 44-line EXTENSION.md
  into `.claude/CLAUDE.md` pushed the orchestrator eager-load total to 67,566 B, 766 B over gate
  20's 66,800 B regression baseline. Trimmed to 28 lines / 1,407 B by relocating duplicated
  review-gate-boundary detail to a short pointer, landing at 66,720 B — 80 B of margin, no
  baseline move needed, following this codebase's own established "always trim, never bump"
  precedent for this gate.
- **README.md's gap-3 explanation** altered mid-phase-5: an early draft named the dropped script
  literally as `scripts/sapience-context.sh`, which tripped `check-extension-docs.sh`'s
  script-reference check (any `.sh` filename mentioned in docs but absent from
  `provides.scripts` is flagged) and violated the plan's own Testing & Validation negative check.
  Rephrased to describe the dropped mechanism without the literal filename; confirmed clean by
  re-running both the doc-lint gate and the negative `grep` check.

## Verification

- Build: N/A (no executable surface beyond JSON/markdown)
- Tests: `verify-deploy.sh --only-gate 2,3,4,5,13,20` — 12 checks, 0 failures (scoped per Batch
  Gate Deferral); `check-extension-docs.sh` — `[sapience] OK`, summary row `sapience PASS`;
  `generate-context-line-counts.sh --check` — 5/5 sapience entries exact; `check-task-references.sh`
  — 0 occurrences
- Files verified: Yes — all five merge-target assertions confirmed independently in the deployed
  tree (CLAUDE.md section present, 4 permission grants present and additive, 5 index entries
  present, context directory and manifest deployed)

## Impacts

- Autonomous `/orchestrate` dispatches inside this repository can now call `sapience_remember`,
  `sapience_wrapup`, `sapience_handoff`, and `sapience_adddoc` without hitting an interactive
  permission prompt.
- Every agent dispatch (subagents included) now receives the postflight `sapience_wrapup`
  instruction via the merged `.claude/CLAUDE.md`, closing the practical gap that orchestrated
  work's transcripts are permanently filtered from the vault's own extraction pipeline.
- The permission fix is repository-scoped: a sapience session in any other project on this
  machine still hits the same permission prompt, since that project's own
  `.claude/settings.local.json` never receives this grant (documented, not silently accepted).

## Follow-ups

- Closing gap 1 machine-wide would require adding the same four `permissions.allow` entries to
  `~/.dotfiles/config/claude/settings.json` — a different repository, deliberately out of this
  task's scope.
- The dead `mcp__sapience__sapience` entry in the dotfiles allow-list (matches no real tool,
  since every real tool is `mcp__sapience__sapience_<verb>`) was observed during research but is
  out of scope to fix here (lives in `~/.dotfiles`).
- If a future extension needs a cross-cutting, task-type-independent pre-dispatch injection seam
  again (sapience is the second candidate after memory's `<memory-context>`), consider
  documenting a third, explicit "always-run injection" seam in `creating-extensions.md` rather
  than requiring each case to hand-edit `orchestrate-build-dispatch.sh`.

## References

- `specs/482_create_sapience_extension/plans/01_create-sapience-extension.md`
- `specs/482_create_sapience_extension/reports/01_create-sapience-extension.md`
- `agent-system/extensions/sapience/README.md`
