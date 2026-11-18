# Research Report: Task #503

**Task**: 503 - MIGRATED FROM BimodalLogic 2026-11-05: `/revise` unavailable to a dispatched agent, undocumented at point of use
**Started**: 2026-11-17T00:00:00Z
**Completed**: 2026-11-17T00:00:00Z
**Effort**: small (documentation-only)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core source store), no web search needed
**Artifacts**: - specs/503_revise_unavailable_to_dispatched_agent/reports/01_revise-unavailable-dispatched-agent.md
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- Both mechanisms named in the dispatch's verification list are real and compound, not
  mutually exclusive: (i) the literal `/revise N` **command** is categorically unreachable from
  a dispatched subagent — the system's own command->skill->agent flow is documented as
  strictly unidirectional (`creating-commands.md`: "Commands invoke skills via the Skill tool;
  skills spawn agents via the Agent tool" — no reverse arrow exists anywhere in the source
  store); AND (ii) the underlying skill (`skill-reviser`) is nominally Skill-tool-reachable (it
  is NOT marked `user-only: true` the way `skill-tag` is) but calling it directly from a
  dispatched agent is unsanctioned-by-contract: it would bypass `commands/revise.md`'s own
  CHECKPOINT 1 (task-lock acquisition via `task-lock.sh acquire-retry`, cross-task `file_scope`
  overlap check) and CHECKPOINT 3 (`.return-meta.json` cleanup, defensive status correction) —
  both of which `commands/revise.md` owns and `skill-reviser/SKILL.md` assumes have already
  run.
- Candidate (iii) — "it would succeed and the observed unavailability was narrower than the
  entry's own wording" — is not the primary explanation. The measured incident's own wording
  ("could not invoke `/revise N`") is accurate as stated: no tool lets a dispatched subagent
  execute a literal slash command. The narrower nuance is that the *skill* underneath is not
  itself frontmatter-blocked the way `AskUserQuestion` is (per
  `agent-frontmatter-standard.md`'s "Tool Withholding from Dispatched Subagents" section) — but
  that nuance does not make direct invocation of `skill-reviser` a sanctioned route, for the
  GATE IN/OUT reasons above.
- The sanctioned mechanical path already exists, is correct, and is exactly what the measured
  incident used: `skill-reviser/SKILL.md`'s own Stage 7 "For Description Update" `state-write.sh`
  object-merge call (verbatim block captured below). The defect is purely that this path is
  undiscoverable without reading `skill-reviser`'s internals — it is not stated at either
  point-of-use surface (`commands/revise.md`, `skills/skill-reviser/SKILL.md`).
- Recommendation: state the unavailability and the exact fallback invocation on both of those
  two surfaces (the task's own named point-of-use locations). Do not add a general statement to
  `context/standards/postflight-tool-restrictions.md` — that file's scope and audience is the
  skill-postflight-phase boundary (what a postflight script may do after an agent returns), a
  different actor and a different restriction than "what a mid-execution dispatched agent may
  invoke." Rejected as the home for this statement; recorded as a Decision below.

## Context & Scope

Scope is documentation-only, as the dispatch states explicitly: do not change
`skill-reviser`'s own revision workflow, and do not add a new agent-invokable
description-update command — the mechanical fallback already exists and is correct. The task
is to make that fallback **discoverable** at the two surfaces a dispatched agent actually
reaches when it needs another task's description updated: `commands/revise.md` and
`skills/skill-reviser/SKILL.md`.

Both files resolve under this repository's `agent-system/extensions/core` source store (per
`.claude-extensions.json`'s `.extensions.core.source_dir`, confirmed live:
`/home/benjamin/.config/nvim/agent-system/extensions/core`), not under the deployed,
gitignored, disposable `.claude/` mirror — per `rules/source-store-deploy-boundary.md`, any
future implementation phase must edit the source-store copies, never the deployed ones.

## Findings

### Codebase Patterns

**1. Commands, skills, and agents are a documented strict pipeline with no reverse path.**
`docs/guides/creating-commands.md`: "Commands are the user-facing entry points; they route work
to skills, which delegate to agents" and "Commands invoke skills via the Skill tool; skills
spawn agents via the Agent tool." No document anywhere in the source store describes an agent
invoking a command. This is the structural basis for the literal `/revise N` command being
unreachable from a dispatched subagent — independent of any frontmatter `tools:`/
`disallowedTools:` configuration.

**2. `skill-tag` is the system's only existing `user-only` precedent, and `skill-reviser` does
not carry it.** `skills/skill-tag/SKILL.md` frontmatter:
```yaml
name: skill-tag
description: Create and push semantic version tags for CI/CD deployment. User-only command - agents cannot invoke.
allowed-tools: Bash, AskUserQuestion, Read
user-only: true
```
`commands/tag.md` likewise states `**User Only**: YES - Agents MUST NOT invoke this command`
under an explicit "Agent Restrictions" section. Neither `commands/revise.md` nor
`skills/skill-reviser/SKILL.md` carries any such field or sentence — confirmed by reading both
files in full. `CLAUDE.md`'s own "User-Only Skills" table lists only `skill-tag`. So
`skill-reviser` is, by the system's own existing convention, NOT a user-only skill — it is a
skill a dispatched agent could mechanically name via the Skill tool (it is listed in this
session's own available-skills listing, for example). The unavailability is therefore not of
the "marked user-only" kind at all; it is the narrower, undocumented "the command wrapping it
owns essential preflight/postflight steps the skill itself does not perform" kind.

**3. `commands/revise.md`'s GATE IN/OUT own exactly the steps a direct `skill-reviser`
invocation would skip.**
- CHECKPOINT 1 (`command-gate-in.sh`) acquires the task lock
  (`task-lock.sh acquire-retry "$task_number" "$operation" "$SESSION_ID" ...`) and runs the
  cross-task `file_scope` overlap check before DELEGATE — both documented in
  `commands/revise.md`'s own "Error Handling" section ("Locked by another session", "Cross-task
  `file_scope` overlap"). `skill-reviser/SKILL.md`'s own Stage 1 only validates that the task
  number exists in `state.json`; it performs no lock acquisition itself.
- CHECKPOINT 3's "Cleanup" step is explicit that `/revise` "has no CHECKPOINT 3 commit block of
  its own (`skill-reviser` commits inline), so this is the command's own last step and owns
  `.return-meta.json`'s deletion — `skill_cleanup` does not delete it at the skill's own Stage
  9." A direct `skill-reviser` invocation with no wrapping command would therefore leave a stale
  `.return-meta.json` behind in the target task's directory.
- This repo's own territory discipline (the "concurrent siblings" mechanism active in this very
  dispatch's Territory section) makes the lock-skipping risk concrete, not theoretical: a
  dispatched agent racing a sibling dispatch that also touches the same target task would have
  no lock protection if it called `skill-reviser` directly.

**4. The sanctioned mechanical fallback is `skill-reviser/SKILL.md`'s own Stage 7 "For
Description Update" block, exactly what the measured incident used:**
```bash
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == $num)) |= . + {
    description: $desc,
    last_updated: $ts
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg desc "$new_description" \
  --argjson num "$task_number" \
  --regen-todo
```
`state-write.sh` is the single mutex-guarded `specs/state.json` writer (documented in
`postflight-tool-restrictions.md`'s Allowed Operations table), so this call is safe even without
the command-level task lock: the mutex is internal to the script, not dependent on
`task-lock.sh`. This is the one piece of this skill's internals an agent currently has to
rediscover by reading `skill-reviser/SKILL.md` end to end — exactly the measured defect.

**5. `postflight-tool-restrictions.md` is the wrong home for this statement.** Its own header
states its audience and scope precisely: "Audience: Skill authors, /meta agent, system
maintainers" and "Skills that delegate to subagents via the Agent tool must maintain a clean
separation between agent work and postflight operations" — i.e. it governs what a SKILL's own
postflight-phase *script* may do after an agent subagent returns, not what a dispatched AGENT
may invoke mid-task. The topic this record is about (an agent needing to update a sibling
task's description while it is itself running) is a different actor at a different lifecycle
point than anything that file's Allowed/Prohibited tables address. Grafting this statement onto
that file would misfile it under an unrelated contract.

### External Resources

Not applicable — this is a closed-corpus documentation question entirely within this
repository's own source store; no external search was needed or performed.

## Recommendations

1. **`commands/revise.md`**: add a short note (e.g. near the top, after the `## /revise Command`
   heading, or as a new "## Agent Availability" section mirroring `commands/tag.md`'s "Agent
   Restrictions" section in spirit but with different content) stating: `/revise` is a
   user-facing slash command with no invocation path from a dispatched subagent (commands are
   reachable only from a literal user/session slash-command parse, never as a tool call); a
   dispatched agent that needs to update **another task's description** should use the
   `state-write.sh` invocation documented in `skill-reviser/SKILL.md`'s Stage 7 "For Description
   Update" block instead of attempting either `/revise` or a direct `skill-reviser` dispatch.
2. **`skills/skill-reviser/SKILL.md`**: add the mirror-image note near the top (e.g. under
   "Trigger Conditions," which already states the skill activates on "`/revise` command is
   invoked" — a natural place to add "this skill is not a sanctioned direct-invocation target
   for a dispatched agent; see Stage 7's Description Update block for the fallback a dispatched
   agent should call directly instead"). Point explicitly at the exact Stage 7 snippet reproduced
   in Finding 4 above, since that snippet already exists verbatim in this same file — the
   recommendation is to make it discoverable from the top of the file, not to write new content.
3. Do NOT add a new field (e.g. a `user-only`-style marker) to `skill-reviser`'s frontmatter —
   it is not user-only in the `skill-tag` sense: a human invoking `/revise` still goes through it
   normally, and nothing about this record's finding should change that. The gap is purely
   discoverability for the dispatched-agent caller, not a permissions change.
4. Do NOT add the statement to `context/standards/postflight-tool-restrictions.md` as a general
   home — see Decisions below for the full rejection rationale.

## Decisions

- **Rejected**: `context/standards/postflight-tool-restrictions.md` as the home for this
  statement. Rationale: that file's documented audience and scope (skill-postflight-phase
  tool boundary, for "Skill authors, /meta agent, system maintainers") governs a different actor
  (a skill's own postflight script, after a subagent has already returned) than this record's
  subject (a dispatched agent mid-execution, needing a route while it is itself still running).
  Filing the statement there would associate two unrelated restrictions under one heading
  readers would reasonably expect to be homogeneous.
- **Decided**: state the unavailability and the fallback at both of the task's named
  point-of-use surfaces (`commands/revise.md`, `skills/skill-reviser/SKILL.md`), each pointing
  at the other and at the exact `state-write.sh` Stage 7 snippet, rather than creating a third,
  new shared standards file. The two existing precedents for "what a dispatched agent cannot
  invoke" in this codebase (`AskUserQuestion`, documented in both
  `agent-frontmatter-standard.md`'s "Tool Withholding from Dispatched Subagents" section and
  `context/standards/push-consent-relay.md`) are each documented at their point of use /
  consequence rather than consolidated into one generic registry; this record's two-surface
  placement follows that existing pattern rather than inventing a new one. A future third
  instance of this same shape of gap would be the point to reconsider a shared registry — not
  yet, with only two documented instances.
- **Decided**: no change to `skill-reviser`'s own revision workflow and no new
  agent-invokable description-update command, per the dispatch's explicit scope boundary.

## Risks & Mitigations

- **Risk**: a future reader could still be tempted to invoke `skill-reviser` directly via the
  Skill tool, since it is not frontmatter-blocked and is listed as an available skill in a
  dispatched session (confirmed directly in this very research dispatch's own available-skills
  listing). **Mitigation**: the added note must say explicitly *why* this is unsafe (lock
  bypass, stale `.return-meta.json` left in the target task's directory), not just *that* it is
  discouraged — a bare "don't do this" invites exactly the rediscovery effort this record exists
  to eliminate.
- **Risk**: documenting the fallback only in prose risks a future edit to `state-write.sh`'s
  argument shape silently going stale in two now-duplicated locations (`skill-reviser/SKILL.md`
  Stage 7 and the new note in `commands/revise.md`). **Mitigation**: the implementation phase
  should make `commands/revise.md`'s note a pointer ("see `skill-reviser/SKILL.md` Stage 7") 
  rather than a second copy of the invocation shape, so there is exactly one place the exact
  shape lives.

## Context Extension Recommendations

- **Topic**: general cross-reference from `agent-frontmatter-standard.md`'s "Tool Withholding
  from Dispatched Subagents" section to the broader class of "things a dispatched agent cannot
  reach" (commands, in addition to `AskUserQuestion`).
- **Gap**: that section is scoped narrowly to measured tool-grant withholding
  (`AskUserQuestion`); it does not currently mention that slash commands are a structurally
  separate, always-unreachable category for a dispatched subagent, independent of any
  `tools:`/`disallowedTools:` configuration.
- **Recommendation**: not a blocking recommendation for this record (out of scope per the
  dispatch's two-surface deliverable), but worth a one-line future addition noting the
  distinction between "frontmatter-withheld tool" and "structurally-unreachable command," so a
  future reader of that section does not conflate the two mechanisms.

## Appendix

- Files read in full: `agent-system/extensions/core/commands/revise.md`,
  `agent-system/extensions/core/commands/tag.md`,
  `agent-system/extensions/core/skills/skill-reviser/SKILL.md`,
  `agent-system/extensions/core/skills/skill-tag/SKILL.md`,
  `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`,
  `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`,
  `agent-system/extensions/core/docs/guides/creating-commands.md`,
  `agent-system/extensions/core/context/reference/skill-agent-mapping.md`,
  `agent-system/extensions/core/context/workflows/command-lifecycle.md`.
- Searches used: `grep -rn -i "Tool Withholding\|withheld\|AskUserQuestion"`,
  `grep -rn -i "slash command"`, `grep -rn -i "agent.*cannot invoke\|cannot invoke.*skill\|user-only"`,
  `grep -rn -i "subagent.*cannot\|dispatched.*cannot\|no mechanism"` across
  `agent-system/extensions/core/{docs,context,rules}`.
- `jq -r '.extensions.core.source_dir' .claude-extensions.json` ->
  `/home/benjamin/.config/nvim/agent-system/extensions/core` (re-derived live, per the dispatch's
  instruction, rather than trusted from its note).
