# Implementation Summary: Task #468

- **Task**: 468 - Core docs architecture, guide, reference and template set audit for structural
  correctness and single-authority topic ownership
- **Status**: [COMPLETED]
- **Started**: 2026-11-04T05:30:00Z
- **Completed**: 2026-11-04T08:40:00Z
- **Effort**: ~3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_core-docs-correctness-audit.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Audited and corrected all 29 markdown files under `agent-system/extensions/core/docs/` for dead
`/research`/`/plan`/`/implement` command surfaces, broken relative links, a stale command
inventory, and three topic-duplication instances, then established a single authoritative home
per duplicated topic with pointers elsewhere. All 7 planned phases completed (6 clean, the final
phase with one reasoned, pre-existing, out-of-scope exclusion), redeployed to the live `.claude/`
tree via `deploy-headless.sh`.

## What Changed

- `agent-system/extensions/core/docs/docs-README.md` — added `fork-patterns.md` to the
  Documentation Map tree and Guides section; left its own correctly-resolving `../README.md`
  breadcrumbs untouched.
- `agent-system/extensions/core/docs/architecture/extension-system.md` — breadcrumb link fix; 2
  "extension picker" links added.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — close call A: replaced 3
  non-existent sample paths in a `files_modified` illustrative JSON example with 3 real command
  paths. No handoff-contract assertion changed.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — close call B:
  reworded the "on cycle limit" message's dead `/implement {N}` invocation surface to
  `/orchestrate {N} --implement`; no cycle-limit or budget semantics changed.
- `agent-system/extensions/core/docs/architecture/system-overview.md` — rebuilt the "Available
  commands" table from the live 15-command inventory (dropped the 3 dead rows, added a resolving
  link to the extension picker authority); reworded the removal-narration lifecycle sentence to a
  positive current-state statement.
- `agent-system/extensions/core/docs/guides/adding-domains.md` — fixed the "the the extension
  picker" typo; added 2 extension-picker links.
- `agent-system/extensions/core/docs/guides/component-selection.md` — restated 4 dead-command
  examples/diagram in terms of `/orchestrate`; reduced the architecture-explanation preamble to a
  one-paragraph summary plus a pointer to `system-overview.md`'s authority section (its unique
  "which component to create" decision tree, and its distinct File Location Reference section,
  both left intact).
- `agent-system/extensions/core/docs/guides/copy-claude-directory.md` — breadcrumb + commands-ref
  depth fixes; collapsed the dead-surface Task Management bullet and Quick Start block to
  `/orchestrate`.
- `agent-system/extensions/core/docs/guides/creating-commands.md` — corrected the Model Selection
  table row and Example Commands table (both named non-existent command files); reworded the
  retirement-narration sentence to a positive current-state statement.
- `agent-system/extensions/core/docs/guides/creating-extensions.md` — breadcrumb link fix; 3
  extension-picker links added; 4 dead-command template/walkthrough/contrast-case sites restated
  in phase-name or `/orchestrate`-dispatch terms, with the contrast case's record-versioning
  framing removed.
- `agent-system/extensions/core/docs/guides/creating-skills.md` — fixed the wrong
  `fork-patterns.md` target (was a non-existent `.claude/context/patterns/` path).
- `agent-system/extensions/core/docs/guides/development/context-index-migration.md` — fixed 2
  deploy-root-style relative-link prefixes.
- `agent-system/extensions/core/docs/guides/permission-configuration.md` — fixed 3 deploy-root
  style relative-link prefixes; fixed the dead-surface Test Commands example.
- `agent-system/extensions/core/docs/guides/user-guide.md` — breadcrumb link fix; reduced the
  near-duplicate `/orchestrate` Options table (17 rows) to a 4-row "most commonly used flags"
  subset plus a resolving pointer to `commands/orchestrate.md`'s Options section as the
  authority.
- `agent-system/extensions/core/docs/guides/user-installation.md` — breadcrumb link fix; fixed a
  second, newly discovered broken link (`../../../docs/installation/README.md`, resolving
  nowhere) to repo-root `docs/CLAUDE_CODE_INSTALL.md`.
- `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md` — 2
  extension-picker links added.
- `agent-system/extensions/core/docs/templates/README.md` — replaced a dead-surface sample
  command name (`# /research Command`) in an illustrative frontmatter example with a neutral
  placeholder.
- `agent-system/extensions/core/docs/examples/fix-it-flow-example.md` — dropped the leading
  slashes from a "Next Steps" phase-sequence mention.
- A regenerated `.claude/` deploy tree (produced by `deploy-headless.sh`, not hand-authored).

18 files touched total across 7 phase commits (one commit per phase, per the Commit-Per-Green-
Substep mandate).

## Decisions

- **Authority/pointer map** (one home per topic, concise pointers elsewhere):
  - `/orchestrate` full flag/option semantics: `commands/orchestrate.md`'s Options section
    (Claude Code loads it directly; cannot itself be a pointer) — `user-guide.md`'s table reduced
    to a 4-row subset plus a link.
  - One-line command quick reference: `merge-sources/claudemd.md`'s Command Reference table —
    re-confirmed already minimal and already pointing into `orchestrate-state-machine.md`; no
    change needed.
  - Comprehensive lifecycle walkthrough/troubleshooting: `guides/user-guide.md` (unchanged as
    authority).
  - Three-Layer Architecture explanation: `architecture/system-overview.md` —
    `component-selection.md`'s preamble reduced to a pointer.
  - Current core command inventory: `system-overview.md`'s rebuilt "Available commands" table.
  - What the extension picker is: `agent-system/extensions/README.md` — 9 bare prose mentions
    across 4 files gained a link, not a rewritten explanation.
  - Documentation map/file inventory: `docs-README.md` — gained the missing `fork-patterns.md`
    entry as its own content.
- **Scope-narrowing corrections applied during implementation** (each recorded as it arose):
  1. `component-selection.md`'s second "three-layer rendering" (plan's `~239-244`) turned out, on
     re-reading, to be a File Location Reference directory tree — unique content mapping
     components to on-disk paths, not a duplicate explanation. Left untouched; only the `~7-18`
     preamble was reduced.
  2. `user-guide.md`'s Options table did NOT omit `--allow-scope-collision` at implementation
     time, contrary to the plan's drift claim — the row was already present. Reduced the table
     to a pointer regardless, per the task's primary instruction.
- **Close call A** (`handoff-schema.md`): scope held strictly to the `files_modified` array; a
  separate `summary` field in the same illustrative example still mentions
  `research.md`/`plan.md`/`implement.md` by bare filename (no leading slash — not a
  dead-command-surface match) and was left untouched as outside this close call's named scope.
- **Close call B** (`orchestrate-state-machine.md`): the pre-edit grep for "to resume manually"
  across `scripts/`, `skills/`, `commands/` found zero matches, so the edit proceeded.

## Plan Deviations

**Boundary Register deferrals held throughout** (6 from the plan, confirmed byte-for-byte
unchanged by `git diff HEAD~7`, plus 2 newly discovered during implementation):

1. `architecture/batch-admit-schema.md:308-311` (record 274) — "second consumer" paragraph naming
   non-existent `commands/{research,plan,implement}.md` files. **Untouched.**
2. `architecture/handoff-schema.md:184-188` (records 378, 428, 450) — the `phase` field's
   definition lines. **Untouched.**
3. `architecture/orchestrate-state-machine.md:~949-956` and `~1394-1398` (records 387, 420, 450)
   — record-versioning prose inside the MT-commit-granularity and batch-gate-deferral-invariance
   assertions (including the deferral's own internal `` `/implement` `` mentions, part of the
   same protected assertion). **Untouched.**
4. The record-versioning vocabulary class in the three boundary-owned architecture files (~53
   occurrences). **Untouched as a class** — remediation narrowed to the 2 sites the research
   report named outside those files (`creating-commands.md`, `creating-extensions.md`), both
   fixed.
5. `reference/standards/agent-frontmatter-standard.md:204,217` (record 431) — out of scope
   entirely; file excluded from `file_scope`. **Untouched.**
6. `reference/standards/multi-task-creation-standard.md:54` (record 438) — already correct as
   written (a genuine phase-name reference). **No edit needed.**
7. **(New)** `architecture/handoff-schema.md:705` (records 378, 428, 450) — "normal `/research`,
   `/plan`, `/implement` invocation" names the non-orchestrator-mode handoff channel these
   records reason about. Not in the plan's original register; discovered during Phase 1's
   reconciliation and added to the deferral list rather than fixed.
8. **(New)** `reference/standards/agent-frontmatter-standard.md:352-354` — 3 broken relative
   links of the excluded file's own, pointing elsewhere. Cannot be fixed (file excluded from
   `file_scope` entirely); recorded as a second, file-scope-driven exclusion class for the
   relative-link resolver, distinct from the documented `CLAUDE.md`-target class.

**Phase 7 reasoned exclusion**: `deploy-headless.sh`'s redeploy landed successfully, but its
internal fast-gate check returned `RESULT=landed_verify_red` instead of the plan's target
`landed_verify_clean`, solely due to gate 18 (`lint-task-lookup-adoption.sh`) flagging 5
hand-rolled jq task-lookup shapes — all inside
`agent-system/extensions/core/scripts/test-state-write-concurrency.sh`, a file wholly outside
this task's `file_scope` and never touched by any of this task's 6 phase commits (confirmed by
an empty `git diff HEAD~6` on that file; its last touching commit, `88a2722f7` at
2026-11-03T18:19:28-08:00, predates this dispatch's 2026-11-03T21:42:34-08:00 start). The
dispatch's Batch Gate Deferral directive separately scopes this phase's own closing verification
to a narrowed tier (`verify-deploy.sh --only-gate 3,4` plus `lint-dead-command-recommendations.sh`
directly, both green), deferring the complete, unscoped gate set to the batch-level stage. Phase
7 closed `[COMPLETED WITH EXCLUSIONS]` with a full `#### Reasoned Exclusions` record (see the
plan). Recommend a follow-up task to migrate `test-state-write-concurrency.sh`'s hand-rolled jq
shapes onto the shared task-lookup helper.

No other deviation occurred; every remaining plan task was completed exactly as scoped.

## Verification

- Build: N/A (markdown-only source store)
- Tests: N/A (no code paths; see Follow-ups for the one pre-existing, unrelated test-suite gate
  failure)
- Files verified: Yes — relative-link resolver clean (two documented exclusion classes only);
  classified dead-command-surface grep shows zero `dead-surface` rows across the whole tree (39
  final matches, all phase-name-correct/path-literal-correct/file-reference/boundary-deferral);
  `lint-dead-command-recommendations.sh` green (0 violations); scoped gate
  (`verify-deploy.sh --only-gate 3,4`) green; `deploy-headless.sh` landed the redeploy.

## Impacts

- Users and future contributors reading `core/docs/` no longer encounter dead `/research`,
  `/plan`, or `/implement` command invocations, nor broken relative links, in the core
  documentation tree.
- Three previously-duplicated topics (full `/orchestrate` flag reference, Three-Layer
  Architecture explanation, "what is the extension picker") each now have exactly one
  authoritative home, reducing future drift risk.
- `fork-patterns.md` is now discoverable from the documentation hub, not only via one corrected
  inbound link.
- The eight non-terminal records' substantive territory (274, 378, 387, 420, 428, 431, 438, 450)
  remains fully intact — no assertion they own was altered.

## Follow-ups

- Recommend a dedicated follow-up task to migrate
  `agent-system/extensions/core/scripts/test-state-write-concurrency.sh`'s 5 hand-rolled
  `jq '.active_projects[] | select(.project_number == ...)'` task-lookup shapes onto the shared
  task-lookup helper, to let `lint-task-lookup-adoption.sh` (gate 18) pass and
  `deploy-headless.sh` reach `RESULT=landed_verify_clean` going forward. This is pre-existing and
  entirely outside this task's scope.
- Recommend a follow-up record for each of the two newly discovered Boundary Register deferrals
  (item 7: `handoff-schema.md:705`'s "normal invocation" phrasing; already covered by records
  378/428/450's existing scope, no new record needed — flagging for whichever of those three
  eventually touches this site) and for the record-versioning vocabulary class (item 4 above, ~53
  occurrences across the three boundary-owned architecture files) as a corpus-wide remediation
  candidate once those records settle.
- A standing relative-link lint for `agent-system/extensions/*/docs/` (and `context/`) remains a
  recommended follow-up, per the research report's Context Extension recommendation — this task
  used a throwaway scratchpad resolver, not a repo-standing tool.
- The `file_scope_collision` advisory against task 328 Phase 19 (Markdown Tranche C) is expected
  in a batched dispatch; no action needed from this task.

## References

- Plan: `specs/468_core_docs_correctness_and_single_authority_audit/plans/01_core-docs-correctness-audit.md`
- Research report: `specs/468_core_docs_correctness_and_single_authority_audit/reports/01_core-docs-correctness-audit.md`
- Phase handoffs: `specs/468_core_docs_correctness_and_single_authority_audit/handoffs/phase-{1..7}-handoff-*.md`
- Progress files: `specs/468_core_docs_correctness_and_single_authority_audit/progress/phase-{1..7}-progress.json`
