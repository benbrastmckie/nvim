# Implementation Summary: Collapse Routing Ladder to routing_agents

- **Task**: 127 - Collapse routing ladder to routing agents
- **Status**: [COMPLETED]
- **Started**: 2026-10-03T04:34:29Z
- **Completed**: 2026-10-03T08:30:00Z
- **Effort**: ~4 hours
- **Dependencies**: None outstanding
- **Artifacts**: plans/01_routing-ladder-collapse.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Collapsed the routing ladder to `routing_agents`-only across all 19 extension manifests,
retiring `command-route-skill.sh` and the skill-level `routing`/`routing_hard` manifest blocks.
All 7 plan phases completed: migrating `/epi` off the retired resolver, re-scoping the routing
validators to `routing_agents`/`routing_agents_hard` *before* touching any manifest, removing
`routing`/`routing_hard` from 17+2 manifests, deleting the dead resolver script and its
now-callerless library helper, and rewriting every piece of documentation (schema guide,
hard-mode guide, CLAUDE.md merge source, command-authoring templates, and several files
discovered beyond the plan's named scope) to describe the collapsed two-block model.

## What Changed

- `agent-system/extensions/epidemiology/commands/epi.md` — replaced the `command-route-skill.sh`
  source call with a direct `skill_name="skill-epi-research"` assignment
- `agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh` — Check A re-scoped to a
  research-anchored `routing_agents` completeness check; Check C re-scoped to
  `routing_agents_hard` internal completeness
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — `check_routing_block()`
  re-scoped to require `routing_agents` when skills/agents are declared; Rule B/C re-pointed to
  `routing_agents`/`routing_agents_hard` against `provides.agents` + deployed agent files
- 17 manifests — `routing` key removed (`cslib`, `email`, `epidemiology`, `filetypes`, `formal`,
  `founder`, `latex`, `lean`, `memory`, `nix`, `nvim`, `present`, `python`, `rust`, `typst`,
  `web`, `z3`); `routing_hard` additionally removed from `cslib`, `lean`
- `agent-system/extensions/core/scripts/command-route-skill.sh` — deleted
- `agent-system/extensions/core/manifest.json` — dropped `command-route-skill.sh` from
  `provides.scripts`
- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` — deleted
  `routing_manifest_for_task_type()`; corrected header prose (4 locations)
- `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` — removed Assert 1
  (built from the now-deleted `.routing`/`.routing_hard` blocks), kept Assert 2-4
- `agent-system/extensions/core/context/standards/shell-strict-mode.md` — removed the deleted
  script from the sourced-scripts enumeration
- `agent-system/extensions/core/scripts/verify-deploy.sh` — corrected gate 16's comment prose
- `agent-system/extensions/core/scripts/command-route-agent.sh` — reworded 3 comment-only
  mentions of the retired resolver
- `agent-system/extensions/{cslib,lean}/skills/skill-*-hard/SKILL.md` (4 files) — corrected
  stale routing-provenance lines to state the skill is no longer routing-reachable, pending the
  `hard_contracts` follow-on
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md` — rewritten to the
  collapsed two-block model; records the work-item-5 (negative, zero colon-suffixed values) and
  work-item-6 (confirmed, Check B + gate 7 already guard this) audit results
- `agent-system/extensions/core/merge-sources/claudemd.md` — "Routing Mechanism" section and
  Composability bullet corrected
- `agent-system/extensions/core/index-entries.json` — `manifest-routing-schema.md` and
  `hard-mode-routing.md` entries' summaries, keywords, and line counts corrected
- `agent-system/extensions/core/context/guides/hard-mode-routing.md` — stripped skill-side
  content (Step 4e safety gate, "Adding routing_hard Entries"); kept and tightened
  `routing_agents_hard` semantics; added the `hard_contracts` successor pointer
- `agent-system/extensions/core/docs/guides/creating-commands.md`,
  `docs/templates/command-template.md` — replaced the retired delegate pattern with
  `command-route-agent.sh` + direct Agent-tool dispatch
- 7 additional files corrected beyond the plan's named scope (discovered by repo-wide grep
  sweeps): `research-flow-example.md`, `adding-domains.md`, `extension-development.md`,
  `cslib/README.md`, `copy-claude-directory.md`, and two more header-comment fixes in
  `check-extension-docs.sh`/`manifest-routing-lib.sh`

## Decisions

- Fixed the 4 `cslib`/`lean` hard SKILL.md provenance lines in Phase 4 (pulled forward from
  Phase 6) rather than leave a known-RED `check-extension-docs.sh` gate between phases — deleting
  `command-route-skill.sh` immediately broke its undeclared-script-reference check for those two
  extensions
- Removed the orphaned deployed `.claude/scripts/command-route-skill.sh` directly (sanctioned
  manual remedy per `context/patterns/deploy-orphan-detection.md`) rather than running a full
  `deploy-headless.sh --wipe`
- Treated "zero occurrences" verification bullets literally once Phase 6 made clear the plan's
  bar tightens from "only historical mentions" (Phase 4/5) to true zero (Phase 6/7) — reworded
  the canonical guide docs' own historical prose to avoid the literal retired script/function
  names

## Plan Deviations

- **Phase 2**: fixed a bug discovered during verification — `provides.agents` entries carry a
  `.md` suffix that `provides.skills` entries don't; `check-extension-docs.sh`'s
  `target_resolvable()` now appends `.md` when comparing, fixing false-positive FAILs for
  `cslib`/`formal`/etc. agent targets
- **Phase 3**: `rust/manifest.json` needed a hand-rewrite (not the uniform `jq del()` used for
  the other 16 manifests) because jq's pretty-printer reformatted an unrelated hand-compacted
  inline array; restored byte-for-byte except the `routing` block removal
- **Phase 4**: pulled the 4 cslib/lean hard SKILL.md provenance-line corrections forward from
  Phase 6 (see Decisions); also reworded 3 comment-only `command-route-skill.sh` mentions in
  `command-route-agent.sh` and 1 in `test-routing-resolution.sh`'s own new comment, required by
  this phase's own "zero in any `.sh` file" verification bullet
- **Phase 6**: fixed 7 additional files carrying stale `command-route-skill`/`routing_hard`
  mentions not named in the plan's Files-to-modify lists (3 carried forward as a Phase 4 gap,
  4 newly discovered); reworded 4 literal `command-route-skill.sh` mentions and 1
  `routing_manifest_for_task_type()` mention inside the two canonical guide docs' own
  historical-explanation prose, since this phase's verification bar is strict zero, not "only
  historical mentions"

## Verification

- Build: N/A (meta task, no build step)
- Tests: Passed — `lint-routing-wiring.sh` (260/260), `test-routing-resolution.sh` (13/13),
  `validate-context-index.sh` (286 entries, 0 errors), `check-task-references.sh` (0
  occurrences), `verify-deploy.sh` gates 3/7/16 behaving exactly as designed (1 unrelated FAIL
  confirmed as task 217's in-flight sibling-territory drift)
- Files verified: Yes — all 17 manifests + index-entries.json valid JSON; `bash -n` clean on
  every edited shell script; three negative controls (Check A, `check_routing_block`, Check B)
  confirmed FAIL on an injected scratch-copy defect and pass once restored

## Impacts

- `/research`, `/plan`, `/implement` command authors must now use `command-route-agent.sh` +
  direct Agent-tool dispatch; the skill-level resolution path no longer exists
- `cslib`'s and `lean`'s hard-mode skills are no longer routing-reachable via any command; their
  `routing_agents_hard` agents remain reachable via `/orchestrate --hard` directly, pending a
  separate follow-on migration onto `hard_contracts`
- Every extension manifest author adding routing now declares `routing_agents` only (plus
  `routing_agents_hard` if hard-mode agents exist) — the schema doc's sample JSON and the
  command/template guides reflect this

## Follow-ups

- Separate, not-yet-dispatched follow-on: migrate `cslib`/`lean` off `routing_agents_hard` onto
  `hard_contracts`, and delete their now-routing-unreachable hard SKILL.md files
- `verify-deploy.sh` gate 16 will continue warning for `lean` (and `cslib`, when loaded) until
  that follow-on lands — this is expected, not a regression

## References

- Plan: specs/127_collapse_routing_ladder_to_routing_agents/plans/01_routing-ladder-collapse.md
- Research report: specs/127_collapse_routing_ladder_to_routing_agents/reports/01_routing-ladder-collapse.md
- Progress files: specs/127_collapse_routing_ladder_to_routing_agents/progress/phase-{1..7}-progress.json
