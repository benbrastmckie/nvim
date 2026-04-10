# Critic Findings: Task #392

**Teammate**: C (Critic)
**Artifact**: 02
**Task**: 392 - Refactor present extension commands (/grant, /budget, /funds, /timeline, /talk)
**Date**: 2026-04-09
**Reviewing**: reports/01_refactor-present-commands.md

---

## Key Findings

### 1. Agent Files Contain Stale Language Values (CRITICAL GAP)

The primary research report identifies that 3 commands create tasks with wrong language values (`grant`, `budget`, `timeline` instead of `present`). However, it **misses that the agent files themselves also embed these stale language values in their delegation context examples**.

Specific instances found:

- **grant-agent.md** (Stage 1 Parse Delegation Context, line ~122):
  ```json
  "language": "grant"
  ```
  The delegation context example shows `"language": "grant"` — this is the schema the skill passes to the agent. If the command and skill are updated but the agent still documents `"language": "grant"` in its parse examples, the schema documentation is misleading.

- **budget-agent.md** (Stage 1 Parse Delegation Context, line ~82):
  ```json
  "language": "budget"
  ```
  Same problem — the example input shows `"language": "budget"`.

- **timeline-agent.md** (Stage 1 Parse Delegation Context, line ~83):
  ```json
  "language": "timeline"
  ```

- **funds-agent.md** (Stage 1 Parse Delegation Context, line ~119):
  ```json
  "language": "present",
  "task_type": "funds"
  ```
  Correctly shows `"present"` with `task_type` — this is the model that grant, budget, and timeline agents should adopt.

- **grant-agent.md** also hard-codes `"grant"` in its dynamic context discovery query:
  ```bash
  jq -r '.entries[] |
    select(.load_when.languages[]? == "grant") |
    .path' .claude/context/index.json
  ```
  After refactoring to `language: "present"`, this query will find zero results unless the index entries are also updated.

**The refactor scope must include agent file delegation context examples and jq queries.**

### 2. Index-Entries.json Has a Split Language Problem (CRITICAL GAP)

The `index-entries.json` file uses **two different languages** in `load_when.languages`:

- All 16 grant-writing context entries: `"languages": ["grant"]`
- Budget entries: `"languages": ["present"]`
- Timeline entries: `"languages": ["present"]`
- Funds entries: `"languages": ["present"]`
- Talk entries: `"languages": ["present"]`

After refactoring commands to use `language: "present"` for all 5 subtypes, the 16 grant-writing context entries (README.md, funder-types.md, proposal-components.md, grant-terminology.md, proposal-structure.md, budget-patterns.md, evaluation-patterns.md, narrative-patterns.md, writing-standards.md, character-limits.md, executive-summary.md, budget-justification.md, evaluation-plan.md, submission-checklist.md, funder-research.md, grant-workflow.md, web-resources.md) will need their `load_when.languages` updated from `["grant"]` to `["present"]` (or `["present", "grant"]` for backwards compatibility).

**This is a significant scope addition — 16+ index entries need updating, not just EXTENSION.md.**

Additionally, the `load_when.agents` arrays reference `"grant-agent"` for these entries. This is agent-name-based routing (not language-based), so it will continue to work. However, if anyone queries by language after the refactor, the grant context files won't be found.

### 3. Grant-Agent Dynamic Context Query Will Break (HIGH)

Grant-agent.md contains this jq query for dynamic context discovery:

```bash
jq -r '.entries[] |
  select(.load_when.languages[]? == "grant") |
  .path' .claude/context/index.json
```

After refactoring:
- If index-entries.json is updated to `"languages": ["present"]`, this query returns nothing
- If index-entries.json is NOT updated (kept as `"grant"`), the query still works but is inconsistent

The research report does not mention updating the dynamic context discovery queries in agent files.

### 4. EXTENSION.md Language Routing Table Has Two Errors (MEDIUM)

The primary research correctly identifies EXTENSION.md needs updating. But reviewing the actual file, there are **two separate issues**:

1. The grant row shows `language: "grant"` (not `"present"`) — correctly identified
2. The routing table shows no `task_type` column at all — the table needs a new column added, not just a value change

Current table format:
```
| grant    | - | skill-grant | skill-grant |
| present  | budget | ...
```

Expected after refactor:
```
| present  | grant | skill-grant | skill-grant |
```

This requires a structural table change, not just a value substitution.

### 5. Co-Authored-By in Agent Files Also Need Updating (MEDIUM)

The grant-agent.md Phase Checkpoint Protocol includes a git commit template with the stale Co-Authored-By:

```bash
git add -A && git commit -m "task {N} phase {P}: {phase_name}

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

The primary research report identifies Co-Authored-By updates in commands but **does not include agent files** in the file change list. Grant-agent.md needs this updated to `Claude Opus 4.6 (1M context)`.

The budget-agent.md does NOT have a similar git commit template (it lacks the Phase Checkpoint Protocol section). The other agents (funds, timeline, talk) should be checked similarly.

### 6. README.md Does Not Cover the Full Extension Scope (MEDIUM)

The `context/project/present/README.md` is titled "Grant Writing Domain" and focuses exclusively on grant proposal development. It does not mention:
- Budget planning (budget-agent, skill-budget)
- Timeline management (timeline-agent, skill-timeline)
- Funding analysis (funds-agent, skill-funds)
- Academic talks (talk-agent, skill-talk)

The README.md navigation section at the bottom references grant-agent and skill-grant specifically (Task #205, #206) but the extension now has 5 agents. **After refactoring to unified `language: "present"`, this README becomes the landing page for all present tasks, but it only documents grants.**

This is a content gap not in the refactor scope.

### 7. opencode-agents.json Needs Parallel Updates (LOW-MEDIUM)

The `manifest.json` `merge_targets` includes:
```json
"opencode_json": {
  "source": "opencode-agents.json",
  "target": "opencode.json"
}
```

The `opencode-agents.json` file exists and defines agents by name (`grant`, `budget`, `timeline`, `funds`, `talk`). These agent keys in opencode.json are independent of the `language` field — they are agent selector names. The opencode routing is not language-based like the Claude Code routing, so the `language` field change in tasks would not affect opencode routing.

**However**: If any opencode command files pass `language: "grant"` or `language: "budget"` in task creation, those would also need updating. The opencode-agents.json file itself does not need changes.

### 8. Implement Routing Still References Bare "grant" Language (MEDIUM)

In `manifest.json` implement routing:

```json
"implement": {
  "grant": "skill-grant:assemble",
  ...
}
```

The `"grant"` key here (not `"present:grant"`) means that if a task has `language: "grant"`, it would still route to `skill-grant:assemble` for implementation. After the refactor changes tasks to `language: "present"`, this bare `"grant"` routing entry becomes dead code. It should either be removed or converted to `"present:grant": "skill-grant:assemble"`.

The primary research report does not mention this manifest routing cleanup.

### 9. No Tests for Present Extension Commands (HIGH)

The primary research report makes no mention of testing. There appear to be no test files for any of the 5 present extension commands. Since these are agent-orchestration commands (not pure Lua functions), testing is complex — but the lack of any testing strategy is a gap.

What should be verified post-refactor:
- Does `/grant "description"` create a task with `language: "present"` and `task_type: "grant"`?
- Does `/research N` for a `present:grant` task correctly route to `skill-grant`?
- Do skills correctly validate `language == "present"` after change?

There is no smoke test or manual validation checklist in the proposed scope.

### 10. Missing task_type Field in Timeline Agent Delegation Schema (MEDIUM)

The timeline-agent.md delegation context parse example (Stage 1) shows:
```json
"language": "timeline"
```

But there is no `task_type` field. After refactoring, the schema should be:
```json
"language": "present",
"task_type": "timeline"
```

The agent documentation needs to reflect what the command and skill actually pass. This is a documentation consistency issue but also affects agent behavior if the agent uses `task_type` for routing decisions.

---

## Gaps Identified

### Gaps Not Covered by Primary Research

1. **Agent file delegation context examples** - 3 agent files need `language` field updated in their parse examples (grant, budget, timeline agents)
2. **Grant-agent dynamic context jq queries** - Two queries use `languages[]? == "grant"` which will break or become inconsistent
3. **Index-entries.json grant section** - 16+ entries use `"languages": ["grant"]` that need updating to `["present"]`
4. **Manifest implement routing** - Bare `"grant"` key is dead code after refactor
5. **Grant-agent Co-Authored-By in git commit template** - Not in the command files but embedded in agent instructions
6. **README.md scope** - Does not cover the full extension after unification
7. **No validation/testing strategy** - No post-refactor smoke test defined

### File Count Undercount in Primary Research

The report lists 9 files requiring changes. The actual count is higher:
- 5 agent files need delegation context example updates (at minimum grant, budget, timeline)
- 1 index-entries.json needs 16+ language field updates
- 1 manifest.json needs implement routing cleanup

Revised estimate: **12-15 files**, **40-50 discrete changes**.

---

## Questions That Should Be Asked

1. **Should index-entries.json grant entries stay as `"languages": ["grant"]`?** Keeping `"grant"` maintains backwards compatibility if there are any existing tasks with `language: "grant"` that still need context loaded. This is a deliberate trade-off, not an oversight.

2. **What happens to existing tasks with `language: "grant"` after the refactor?** State.json currently shows no active present-related tasks, so the migration risk is low — but what about archived tasks? If someone runs `/implement` on an archived task with `language: "grant"`, will routing fail?

3. **Should the README.md be updated to cover all 5 capabilities?** This is out of scope for a "refactor" but is now the landing context page for all `present` language tasks.

4. **Should the manifest implement routing bare `"grant"` key be removed or kept?** Keeping it provides a safety net if any old tasks exist; removing it is cleaner.

5. **Does the grant-agent's dynamic context discovery need to query by `task_type` instead of `language`?** After unification, querying `languages[]? == "present"` would return budget, timeline, funds, and talk context too — too broad. The agent might need to filter by both language AND agent name.

---

## Confidence Level

**High confidence** on:
- Agent file delegation context examples needing updates (directly observed in 3 files)
- Index-entries.json grant section using stale language value (directly observed — 16 entries)
- Manifest implement routing bare "grant" key being dead code post-refactor
- Grant-agent Co-Authored-By in git commit template being stale

**Medium confidence** on:
- Whether the README.md update is in scope
- Whether opencode concerns are relevant (depends on whether opencode uses language field)

**Low concern** (not actually a problem):
- State.json: No active present tasks found — zero migration risk for existing data
- opencode-agents.json: Agent keys are agent selectors, not language-based routing

---

## Summary

The primary research is correct and well-structured, but **understates the scope by approximately 50%**. The most significant unaddressed gap is the `index-entries.json` grant context entries (16 files using `"languages": ["grant"]`) and the agent file delegation context examples embedding stale language values. These are not cosmetic — they affect context loading and agent parse documentation directly.

The implement routing cleanup in manifest.json is a small but important correctness fix that removes dead code.

The absence of any testing/validation strategy is notable given the cross-cutting nature of the language field change.
