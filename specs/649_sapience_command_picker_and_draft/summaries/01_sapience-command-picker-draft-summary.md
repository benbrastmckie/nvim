# Implementation Summary: Task #649

- **Task**: 649 - Add the /sapience command: draft assembly and the approval-gated surface picker
- **Status**: [COMPLETED]
- **Started**: 2026-11-19T04:44:00Z
- **Completed**: 2026-11-19T13:57:54Z
- **Effort**: ~5.5 hours (matches plan estimate)
- **Dependencies**: 647 (sapience_project_binding_and_vault_read), 648 (sapience_publish_write_surfaces) — both completed
- **Artifacts**: plans/01_sapience-command-picker-draft.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added the `/sapience` command to the sapience extension's source store: a thin command file
(`commands/sapience.md`) that parses argument shapes and delegates to a fully direct-execution
skill (`skills/skill-sapience/SKILL.md`). The skill assembles a draft update from local
repository state and read-only vault state, resolves an optional named or picked collaborator,
and gates every outward write behind exactly one mandatory `AskUserQuestion` approval picker
showing each candidate surface's literal dry-run payload. No new script was added — the command
and skill are pure consumers of the four scripts the project-binding and publishers tasks
already built and deployed.

## What Changed

- `agent-system/extensions/sapience/context/project/sapience/domain/command-draft-and-picker.md` — New design record: the four candidate write surfaces mapped to `sapience-publish.sh` subcommands, pre-check defaults, the most-relevant-doc and decision-shaped rules, the literal-payload discipline, the body-fetch fallback, the single `ko` call, the option-construction marker site, and the dark `project_cid` migration path.
- `agent-system/extensions/sapience/context/project/sapience/README.md` — Added a nav row for the new design record.
- `agent-system/extensions/sapience/index-entries.json` — New entry for the design record; corrected the README.md entry's `line_count`.
- `agent-system/extensions/sapience/skills/skill-sapience/SKILL.md` — New direct-execution skill (no `Agent` tool anywhere): binding gate, vault-read-backed draft assembly, target resolution, collaborator resolution, preview, the single marker-bracketed option-construction block, the approval picker, confirmed execution, outcome reporting, and empty-selection handling.
- `agent-system/extensions/sapience/commands/sapience.md` — New command file: argument parsing for the three `/sapience` shapes, delegating to `skill-sapience`.
- `agent-system/extensions/sapience/manifest.json` — Wired `provides.commands` (`"sapience.md"`) and `provides.skills` (`"skill-sapience"`); `routing_exempt: true` and `provides.scripts` left unchanged.
- `agent-system/extensions/sapience/EXTENSION.md` — Replaced the "no slash command" paragraph in place with a `/sapience` command line (net 0 line delta; still exactly 60 lines).
- `agent-system/extensions/sapience/README.md` — Corrected the "no slash command" claims, added a literal `/sapience` mention, and added File Inventory rows for the three new files.
- `agent-system/extensions/README.md` — Updated the sapience row's description to mention the new command.

## Decisions

- **D1**: `skill-sapience` is fully direct-execution (no `Agent` tool anywhere), which dissolves the `AskUserQuestion` tool-withholding-from-dispatched-subagents hazard entirely rather than working around it.
- **D2**: The picker's option-construction code lives in exactly one marker-bracketed block, so a future shared-renderer extraction can find and absorb it without hunting scattered call sites.
- **D3/D4**: "Most relevant doc" and "decision-shaped" are both written as explicit, falsifiable rules in the design record, not left to in-skill judgment.
- **D5**: The decision-log row's body, when absent from the bounded read envelope, is fetched directly via the shared API lib rather than assumed present or fabricated.
- **D6**: Every candidate surface's preview is the literal dry-run output of the same `sapience-publish.sh` invocation the confirmed write later reuses with `--confirm` appended — never a second, hand-written preview string.
- **D7**: The KO surface issues exactly one batched `ko` call, inheriting the existing 3-8-note bound with no second cap.
- **D8**: A bare `--message` opens a separate, earlier collaborator-picker question, deliberately never merged with the approval picker.
- **D9**: No MCP write tool is named anywhere in either new instruction surface; every prescribed write routes through `sapience-publish.sh`.

## Plan Deviations

- **Phase 6** altered: used the explicit 9-touched-path form of `verify-touched.sh` for the Batch Gate Deferral's scoped discharge rather than its bare no-argument form, because the no-argument form resolved touched paths from the whole shared working tree (pulling in ~21 paths spanning concurrently-dispatched sibling tasks), not this task's own set. Phase 6's own Verification bullet explicitly names `<all touched paths>` as an argument list, so the explicit form matches the phase's own literal wording.

## Verification

- Build: N/A (no build step for this task type)
- Tests: Scoped `verify-touched.sh` over this task's 9 touched paths — mapped SELECT set 63/66 passed (2 expected pre-existing failures, 1 pre-existing unrelated flake independently corroborated by tasks 648/650); OWED fallback set clean 98/98.
- Files verified: Yes — `.claude/commands/sapience.md` and `.claude/skills/skill-sapience/SKILL.md` are byte-identical to the source store after deploy regeneration.
- `check-extension-docs.sh`: zero sapience findings across Rules A, E, R, T, U, and `check_readme_vs_manifest` (the one remaining Rule F finding is a pre-existing, out-of-FILE-SCOPE drift in a different task's script).
- `measure-eager-context.sh --check`: TOTAL 70,505 B against a 71,600 B baseline (1,095 B headroom; no trim needed).
- Complete gate set: deferred to this `/orchestrate` batch's closing stage per the Batch Gate Deferral directive, attributed back to this task by its `modified_files`.

## Impacts

- `/sapience` becomes the sapience extension's first command surface; the extension's manifest and documentation now accurately describe it as more than grants-and-docs-only.
- No change to the extension's permission grant: the write path uses `sapience-publish.sh` (a Bash script), so the existing 7-tool read-only MCP grant stays exactly as is.

## Follow-ups

- The pre-existing `scripts/sapience-vault-read.sh` deployed-vs-source trailing-newline drift (Rule F) remains open; it belongs to the project-binding task's scope, not this one.
- Task 581 (shared `AskUserQuestion` option renderer) can absorb this picker's option-construction block via its marker comments whenever it lands; no dependency edge was added, per the dispatch's explicit coordination note.
- The `project_cid`/`REPO_LINK_FOR` dark migration path remains off for this token; the design record states it as the eventual target without foreclosing it.

## References

- Plan: `specs/649_sapience_command_picker_and_draft/plans/01_sapience-command-picker-draft.md`
- Research report: `specs/649_sapience_command_picker_and_draft/reports/01_sapience-command-picker-draft.md`
- Design record: `agent-system/extensions/sapience/context/project/sapience/domain/command-draft-and-picker.md`
