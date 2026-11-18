# Implementation Summary: Task #503

- **Task**: 503 - `/revise` unavailable to a dispatched agent, undocumented at point of use
- **Status**: [COMPLETED]
- **Started**: 2026-11-17T23:35:00Z
- **Completed**: 2026-11-18T08:58:00Z
- **Effort**: ~1.3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_revise-unavailability-point-of-use.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`/revise` is a user-facing slash command with no invocation path from a dispatched subagent, and
that unavailability was stated nowhere a dispatched agent would meet it. This task added a
point-of-use unavailability note, plus a named fallback route, to the two surfaces a dispatched
agent actually meets: `commands/revise.md` and `skills/skill-reviser/SKILL.md`, each pointing at
the other. Both notes were authored under the source store
(`agent-system/extensions/core/`), landed in the deployed `.claude/` tree, and verified against
the scoped gate set this dispatch's Batch Gate Deferral directive named.

## What Changed

- `agent-system/extensions/core/commands/revise.md` — added a new `## Agent Availability`
  section (placed between the header block and `## Arguments`) stating: (i) `/revise` is
  structurally unreachable from a dispatched subagent (the documented command->skill->agent flow
  is strictly unidirectional, independent of any frontmatter `tools:`/`disallowedTools:`
  configuration), and (ii) a direct `skill-reviser` Skill-tool dispatch is not the substitute,
  because it bypasses this command's own CHECKPOINT 1 (task-lock acquisition, cross-task
  `file_scope` overlap check) and CHECKPOINT 3 (`.return-meta.json` deletion for the Description
  Update path), leaving a stale sidecar and no lock protection. Points a dispatched reader at
  `skills/skill-reviser/SKILL.md` Stage 7's "For Description Update" block as the sanctioned
  route.
- `agent-system/extensions/core/skills/skill-reviser/SKILL.md` — extended `## Trigger
  Conditions` with the mirror note (this skill is not a sanctioned direct-invocation target for
  a dispatched agent, same two reasons), pointing at this same file's own Stage 7 block and back
  across to `commands/revise.md`'s new section.
- The deployed `.claude/` tree (gitignored, not a committed artifact) now carries both notes;
  `check-deploy-freshness.sh` reports no staleness for the `core` extension.

## Decisions

- **Rejected**: `context/standards/postflight-tool-restrictions.md` as the home for a general
  "what a dispatched agent cannot invoke" statement — its documented purpose and audience
  (allowed-vs-prohibited operations during a skill's own postflight phase, for skill authors and
  the `/meta` agent) govern a different actor at a different lifecycle point than a dispatched
  agent needing a route while still running. The file was left untouched.
- **Rejected**: a third, new consolidated registry file for this class of restriction. The two
  existing precedents (`agent-frontmatter-standard.md`'s "Tool Withholding from Dispatched
  Subagents" section, and `push-consent-relay.md`) are each documented at their point of use;
  two-surface placement follows that pattern rather than inventing a registry.
- **Decided**: the exact `state-write.sh` invocation shape lives in exactly one place — Stage
  7's "For Description Update" block in `skills/skill-reviser/SKILL.md` — and `commands/
  revise.md` points at it by file, stage, and heading rather than duplicating it.
- **Decided**: no `user-only: true` marker added to `skill-reviser` or `commands/revise.md`. A
  human invoking `/revise` still routes through it exactly as before; the gap was
  discoverability, not permissions.

## Plan Deviations

- **Phase 3 verification**: the plan's literally-named unflagged `verify-deploy.sh` run was
  replaced with the scoped `--only-gate 3,4,5 --skip-unchanged` narrowing, per this dispatch's
  own Batch Gate Deferral directive (Phase 3 declares `Verification Tier: full` and is the
  plan's final such phase in a multi-task `/orchestrate` batch). The complete unflagged sweep is
  deferred to the batch's own conclusion stage rather than independently re-run here.
- **Phase 2 verification**: the plan's named `run-all.sh --only ...` invocation (without
  `--fail-on-new`) exits 1 solely because of one pre-existing EXPECTED failure
  (`test-verify-deploy-context-budget.sh`, a documented `real-defect` row in
  `tests/known-failures.txt`, caused by pre-existing `core`-extension deploy staleness unrelated
  to this task's two files). Re-ran the identical suite list with `--fail-on-new` to obtain the
  authoritative 0-NEW-failures signal (exit 0, 27 passed, 1 expected, 0 NEW) rather than treating
  the pre-existing failure as a regression.

## Verification

- Build: N/A
- Tests: Passed (scoped) — Gate 8 suite subset (28 suites) green with `--fail-on-new` (0 NEW
  failures); gates 3/4/5 (`--only-gate 3,4,5 --skip-unchanged`) green both before and after the
  Phase 3 redeploy; `deploy-headless.sh`'s own internal `verify-deploy.sh` invocation (41
  checks) passed with 0 failures.
- Files verified: Yes — both edited files confirmed present and correct in the deployed
  `.claude/` tree; the sole `subagent_type: "reviser-agent"` literal in `SKILL.md` is unchanged
  and unduplicated; no frontmatter (`user-only`/`tools:`/`disallowedTools:`) hunk in either file;
  `postflight-tool-restrictions.md` unmodified; no `task N`-shaped citation introduced.

## Impacts

- A dispatched agent encountering either surface now learns, before attempting `/revise` or a
  direct `skill-reviser` dispatch, that both are unavailable/unsanctioned and exactly where the
  sanctioned description-update route lives — closing the rediscovery gap the measured incident
  exposed, without changing `skill-reviser`'s revision workflow or adding a new command.

## Follow-ups

- None named by this record's scope boundary. The research report's future-nicety suggestion
  (cross-referencing `agent-frontmatter-standard.md`'s "Tool Withholding" section with the
  structural, frontmatter-independent command-unreachability distinction this task documents)
  was explicitly declared a non-goal and is not carried forward here.

## References

- Plan: `specs/503_revise_unavailable_to_dispatched_agent/plans/01_revise-unavailability-point-of-use.md`
- Research: `specs/503_revise_unavailable_to_dispatched_agent/reports/01_revise-unavailable-dispatched-agent.md`
- Progress: `specs/503_revise_unavailable_to_dispatched_agent/progress/phase-{1,2,3}-progress.json`
- Handoffs: `specs/503_revise_unavailable_to_dispatched_agent/handoffs/`
