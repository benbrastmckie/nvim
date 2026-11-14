# Implementation Summary: Task #623

- **Task**: 623 - Make the `web` extension depend on the `typescript` extension and split the shared TypeScript context down a layer
- **Status**: [COMPLETED]
- **Started**: 2026-11-13T19:50:00Z
- **Completed**: 2026-11-14T02:05:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None (prerequisite tasks 621 and 622 both completed)
- **Artifacts**: plans/01_web-typescript-dependency-split.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Wired the `web` extension to depend on the `typescript` extension (`manifest.json`
`dependencies`), trimmed `typescript-web.md`'s two generic TypeScript subsections (Common Zod
Patterns, Import Aliases) down to named cross-reference pointers into `typescript`'s own
context tree, and added the matching static `## Context References` pointer to each web agent
so the dependency actually changes agent behavior rather than being a manifest-only no-op. All
three plan phases completed; end-to-end scratch-target deploy, auto-load, and unload-hard-block
behavior verified in two disposable scratch repositories, both fully deleted afterward.

## What Changed

- `agent-system/extensions/web/context/project/web/domain/typescript-web.md` — trimmed the
  `### Common Zod Patterns` and `## Import Aliases` subsections (303 -> 272 lines) to named
  pointers into `typescript/patterns/zod-validation-patterns.md` and
  `typescript/patterns/path-alias-patterns.md`, retaining the Astro-specific alias-resolution
  clause and every other section unchanged.
- `agent-system/extensions/web/index-entries.json` — regenerated `line_count` for the trimmed
  file (303 -> 272) via `generate-context-line-counts.sh --write`.
- `agent-system/extensions/web/agents/web-research-agent.md` — added one `@`-reference line to
  `**Load for Web Research**` pointing at `project/typescript/README.md`.
- `agent-system/extensions/web/agents/web-implementation-agent.md` — added the same one-line
  pointer to `**Load for Web Work**`, adjacent to the existing `typescript-web.md` entry.
- `agent-system/extensions/web/manifest.json` — `dependencies` changed from `["core"]` to
  `["core", "typescript"]`.
- `agent-system/extensions/web/README.md` — one-line Installation note that loading `web`
  auto-loads `typescript`.
- `agent-system/extensions/web/EXTENSION.md` — one-line `### Context` note on the dependency
  (file now 28 lines, under the 60-line merge-source ceiling).
- `agent-system/extensions/typescript/index-entries.json` — inspected, confirmed unchanged
  (`git diff --stat` empty; its 9 entries, `load_when` blocks, and `line_count` values all
  stand as-is).

## Decisions

- Kept both Astro-specific sections (`## Content Collection Schemas with Zod`, `## Type
  Checking`) untouched, trimming only the two genuinely generic subsections, per the plan's
  narrow, bounded scope.
- Reworded the Zod-pointer prose to avoid repeating the literal `z.coerce.date()` token, since
  the retained Content Collection Schemas block already legitimately contains it twice — keeping
  the file's only non-retained occurrences of that token at zero.
- Ran the sanctioned bounded-wait redeploy (`timeout 540 bash .claude/scripts/deploy-headless.sh`)
  when Phase 3's scoped gate run hit the pre-existing `lean` deploy staleness this dispatch's own
  freshness context had already flagged — resolved gate 5 without touching any file outside that
  staleness's own remedy path.
- Deferred the complete `verify-deploy.sh` gate set to the once-per-batch stage per this
  dispatch's Batch Gate Deferral directive, discharging Phase 3 instead against the scoped
  narrowing invocation `verify-deploy.sh --skip-slow --only-gate 3,4,5,6,7`.

## Plan Deviations

- **Phase 1 verification grep** (`z.discriminatedUnion\|z.coerce.date` expected to return 0):
  altered to verify intent rather than the literal count. The retained, Astro-specific Content
  Collection Schemas block legitimately contains two `z.coerce.date()` calls the plan explicitly
  preserves, so a literal 0 was never achievable without deleting content outside this phase's
  scope. Confirmed instead that the generic primitive block (including `z.discriminatedUnion`,
  which has zero occurrences file-wide) is fully gone from the trimmed subsection.
- **Phase 3's complete gate set** (`bash .claude/scripts/verify-deploy.sh`, no narrowing):
  altered to the scoped tier `--only-gate 3,4,5,6,7` per this dispatch's Batch Gate Deferral
  directive — the full battery runs once at the end of the whole `/orchestrate` batch
  invocation rather than independently in this dispatch.

## Verification

- Build: N/A (markdown/JSON/manifest changes only)
- Tests: Passed — `test-context-reachability.sh`, `test-deploy-orphans.sh`,
  `test-index-entries-schema.sh`, `test-install-uninstall-extension.sh`,
  `test-manifest-scripts-sync.sh`, `test-roadmap-command-registration.sh` (Phase 1);
  `test-lint-agent-contracts.sh`, `test-lint-agent-contracts-heartbeat.sh` (Phase 2); five named
  lints plus the scoped gate set 3,4,5,6,7 (Phase 3, gate 4 excepted — see Follow-ups)
- Files verified: Yes — `generate-context-line-counts.sh --check` reports 604/604 exact
  post-change; scratch-target loads confirmed every expected file, merge-target, and index entry

## Impacts

- Any task routed through `web-research-agent` or `web-implementation-agent` now has a static,
  discoverable pointer into the generic TypeScript context tree, closing the gap the research
  phase identified (the manifest dependency alone would not have made this true, since neither
  agent consults `index.json` `load_when` at runtime).
- Future generic-TypeScript content changes belong in the `typescript` extension's own tree, not
  duplicated into `web`'s `typescript-web.md`.
- `typescript` is now a structural dependency of `web`: unloading `typescript` while `web` is
  loaded is refused (confirmed live), and the correct teardown order is `web` first.

## Follow-ups

- Three pre-existing, unrelated findings were observed but not remediated (all outside this
  task's declared `file_scope`):
  1. `check-task-references.sh` (gate 4) reports one finding in
     `agent-system/extensions/core/context/config/orchestrator-context-budget.json`, a
     committed, unmodified file carrying a historical task-reference string in its own
     budget-ceiling derivation log.
  2. The orchestrator eager-load context budget measured 70,444 B against its 70,400 B
     baseline (44 B over) — pre-existing drift unrelated to `web`/`typescript`, neither of
     which is eager-loaded in this repository's current deploy.
  3. `lint-test-root-resolution.sh` flags a fixed-depth `REPO_ROOT` walk in
     `agent-system/extensions/typescript/scripts/tests/test-typescript-verify.sh:40` (last
     touched by a prior task's own commit chain).
- `web-astro.md`'s "TypeScript Standards" table still duplicates content against
  `typescript-style-guide.md` — named by research as an explicit non-goal/follow-up, not
  addressed here.

## References

- Plan: `specs/623_web_extension_depends_on_typescript/plans/01_web-typescript-dependency-split.md`
- Research: `specs/623_web_extension_depends_on_typescript/reports/01_web-typescript-dependency-split.md`
- Progress files: `specs/623_web_extension_depends_on_typescript/progress/phase-{1,2,3}-progress.json`
- Handoffs: `specs/623_web_extension_depends_on_typescript/handoffs/`
