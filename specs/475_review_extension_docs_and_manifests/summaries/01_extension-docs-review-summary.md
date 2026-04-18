# Implementation Summary: Review Extension Docs and Manifests

- **Task**: 475 - Review extension docs and manifests
- **Status**: [COMPLETED]
- **Started**: 2026-04-17T00:00:00Z
- **Completed**: 2026-04-17T00:45:00Z
- **Effort**: ~45 minutes
- **Dependencies**: None
- **Artifacts**: plans/01_extension-docs-review.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Systematic review and correction of extension documentation across `.claude/extensions/`. Addressed loading safety risks (README.md in runtime directories), stale content in 4 extension READMEs, template compliance gaps in present/README.md, and cross-linking improvements across the extension hub.

## What Changed

- Removed `README.md` from `core/manifest.json` `provides.agents` and `provides.context` arrays to prevent runtime loading
- Deleted stale `.claude/agents/README.md`, `memory/commands/README.md`, and `memory/skills/README.md`
- Added README.md skip logic to `install-extension.sh` `install_commands()` and `install_agents()` glob loops
- Added `routing_exempt: true` to `slidev/manifest.json`
- Replaced all `--remember` references in `memory/README.md` with auto-retrieval model description
- Fixed 2 broken @-references in `nix/README.md` (module-patterns.md, nixos-rebuild-guide.md)
- Added `/consult` command to `founder/README.md` (command table, architecture tree, routing table)
- Fixed stale skill/agent names in founder architecture tree (skill-founder-spreadsheet, founder-spreadsheet-agent)
- Added `routing_exempt` field documentation to `extension-development.md`
- Fixed stale template reference in `extension-development.md`
- Expanded `present/README.md` from ~90 to ~218 lines with Architecture, Skill-Agent Mapping, Language Routing, Talk Modes, Workflow, Output Artifacts, and Dependencies sections
- Added Docs column with README links to `extensions/README.md` hub table
- Added Dependencies sections to `founder/README.md` and `present/README.md`

## Decisions

- Kept `README.md` entries in `provides.docs` (docs directory is not a runtime loading target)
- Updated founder README architecture tree to also add missing meeting/consult/financial-analysis agents and skills
- Used generic "All commands" instead of hardcoded count for founder lifecycle statement to avoid future staleness

## Impacts

- `check-extension-docs.sh` now passes cleanly (0 failures)
- No README.md files will be copied to `.claude/agents/` or `.claude/commands/` during extension installation
- All nix @-references now resolve to files that exist on disk
- Present extension documentation matches template compliance for complex extensions

## Follow-ups

- None identified. All planned work completed successfully.

## References

- `specs/475_review_extension_docs_and_manifests/reports/01_team-research.md`
- `specs/475_review_extension_docs_and_manifests/reports/02_followup-research.md`
- `specs/475_review_extension_docs_and_manifests/plans/01_extension-docs-review.md`
