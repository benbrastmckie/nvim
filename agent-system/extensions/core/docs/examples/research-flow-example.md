# Integration Example: Research Flow

This example traces a complete `/orchestrate --research` invocation through the current
architecture, showing how the command, `skill-orchestrate`, and the research agent work
together. It supersedes an earlier version of this example that traced the now-deleted
standalone `/research` command through the base lifecycle research skill — both were retired, and
`skill-orchestrate` now dispatches the research agent directly with no per-function skill hop.

<!-- task-ref-ok:begin illustrative worked example throughout this document uses a concrete task
     number (427) purely to make the walkthrough concrete; it is not a citation of real task
     provenance -->

---

## Scenario

A user runs `/orchestrate {N} --research` to research task {N} (documenting the command/skill/
subagent framework). This is a "meta" task type.

---

## Complete Flow Diagram

```
User Input: /orchestrate 427 --research
       |
       v
[Layer 1: Command] .claude/commands/orchestrate.md
       |
       | Parses $ARGUMENTS, resolves task_number = 427, forwards to skill-orchestrate
       v
[Layer 2: Skill] skill-orchestrate/SKILL.md (the four-move loop)
       |
       | Setup -- commands/orchestrate.md generates session_id, forwards task_numbers
       | Move 1 -- one orchestrate-cycle-plan.sh call: lookup task, extract task_type = "meta",
       |           resolve routing via command-route-agent.sh (RESEARCH_AGENT =
       |           "general-research-agent" for task_type "meta"), current_status =
       |           "not_started" -> research handler, loop-guard initialization, and
       |           dispatch-file composition via orchestrate-build-dispatch.sh's own live
       |           Stage 3.5 (Dispatch Prep) -- builds memory_context, lit_context, effort_note
       | Move 2 -- Invoke the Agent tool with subagent_type = "general-research-agent"
       v
[Layer 3: Agent] general-research-agent.md
       |
       | 1. Parse delegation context
       | 2. Load required context files
       | 3. Execute research (codebase + web)
       | 4. Create report artifact
       | 5. Write .return-meta.json
       v
[Return Flow]
       |
       | Agent -> skill-orchestrate Move 3 (the shared per-row postflight call: handoff/outcome
       |          read, loop-guard update, postflight)
       | -> Move 4 (--research stops the loop after this phase, so the branch is terminal here)
       | -> User
       v
Output: Research report created at specs/427_document.../reports/01_research-findings.md
```

---

## Step-by-Step Walkthrough

### Step 1: User Invokes Command

```bash
/orchestrate 427 --research
```

Claude Code reads `.claude/commands/orchestrate.md`, which invokes `skill-orchestrate` with the
task number and the `--research` phase-forcing flag.

### Step 2: skill-orchestrate Runs Move 1 (Plan the Cycle)

**Move 1** is one call to `orchestrate-cycle-plan.sh` that performs status refresh, eligibility,
classification, task-type routing, admission, loop-guard initialization, and dispatch-file
composition — the separate `Stage 1`/`Stage 1b`/`Stage 2`/`Stage 3` sections this walkthrough
used to carry here have all collapsed into this one call:

```bash
# Lookup task {N} in specs/state.json
# Exports: task_type = "meta", project_name, padded_num, description
```

**Task-type routing** (`command-route-agent.sh`, invoked from inside the same
`orchestrate-cycle-plan.sh` call):
```bash
source .claude/scripts/command-route-agent.sh "research" "meta" "general-research-agent" "$effort_flag"
# Resolves RESEARCH_AGENT for task_type "meta" via the manifest routing_agents ladder,
# falling back to the caller's own default ("general-research-agent") on a miss.
# Extension task types resolve to their own domain-specific research agent instead.
```

**Loop-guard initialization** — creates `.orchestrator-loop-guard`, the ephemeral per-cycle
runtime state tracking `cycle_count` and `detected_defects` across the four-move loop.

`current_status = "not_started"` routes to the research handler:

```bash
skill_preflight_update "$task_number" "research" "$session_id"
# Status -> researching
```

**Dispatch-file composition** — via `orchestrate-build-dispatch.sh`'s own live
`Stage 3.5 (Dispatch Prep)` label (a script-internal label, not a `SKILL.md` section — it is
still correct to cite by name) — builds `memory_context`, `lit_context`, `effort_note`, and
`hard_contracts_block` (each skipped when empty).

### Step 3: skill-orchestrate Issues Move 2 (Dispatch)

**Invoke the Agent tool**:

| Field | Value |
|-------|-------|
| `subagent_type` | `general-research-agent` (resolved by Move 1's routing call) |
| `model` | Move 1's dispatch-file `model` output, when non-empty |
| `prompt` | "Research task {N}: {description}" plus `memory_context`, `lit_context`, `effort_note` |
| `context` | `{ task_number: {N}, task_type: "meta", session_id, orchestrator_mode: true, lit_flag, task_dir, handoff_path, dispatch_seq }` |

### Step 4: Agent Executes Research

The agent (`general-research-agent.md`) receives the delegation context.

**Agent Stage 1: Parse Delegation Context**

Extract:
- task_number = 427
- task_name = "document_command_skill_subagent_framework"
- task_type = "meta"
- session_id = "sess_1736700000_abc123"

**Agent Stage 2: Determine Search Strategy**

Based on task_type = "meta":
- Primary: Context files + existing skills
- Secondary: WebSearch for Claude docs

**Agent Stage 3: Execute Searches**

```
Step 1: Codebase Exploration
- Glob(".claude/skills/**/SKILL.md") -> 10 skills found
- Glob(".claude/agents/*.md") -> agents found
- Glob(".claude/commands/*.md") -> commands found
- Read key files to understand patterns

Step 2: Context File Review
- Read .claude/context/templates/thin-wrapper-skill.md
- Read .claude/context/formats/subagent-return.md
- Read .claude/context/architecture/system-overview.md

Step 3: Synthesize Findings
- 8 key patterns identified
- 5 documentation gaps found
- 4 recommendations formed
```

**Agent Stage 4: Generate Output**

Create research report following `report-format.md`:

```markdown
# Research Report: Task #{N}

**Task**: {N} - Document command, skill, and subagent framework
**Date**: 2026-01-12
**Focus**: Framework documentation

## Summary
This research analyzed the existing command, skill, and subagent
architecture. Found 8 key patterns, 5 documentation gaps, and
formed 4 recommendations.

## Findings
### 1. Current Architecture: Command -> Skill -> Agent Delegation
...

### 2. Component Relationships
...

## Recommendations
1. Create Component Selection Guide
2. Create Skill Creation Guide
...
```

**Agent Stage 5: Create Artifact**

```bash
mkdir -p specs/427_document_command_skill_subagent_framework/reports/
write 01_research-findings.md
```

**Agent Stage 6: Write Metadata File**

The agent writes `.return-meta.json` (not inline JSON return):

```json
{
  "status": "researched",
  "summary": "Research completed with 8 key findings on the three-layer architecture.",
  "artifacts": [
    {
      "type": "research",
      "path": "specs/427_document_command_skill_subagent_framework/reports/01_research-findings.md",
      "summary": "Research report with 8 findings and 4 recommendations"
    }
  ],
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "general-research-agent"
  }
}
```

### Step 5: Return Flow (skill-orchestrate Move 3)

**Agent -> Move 3: outcome read, loop-guard update, postflight**

`skill-orchestrate` reads the agent's return after the Agent tool call completes, judging
transport-vs-subagent-authored outcomes per `context/patterns/infra-failure-discrimination.md`,
records `cycle_count` and any `detected_defects` for this cycle, then runs postflight — since
`--research` stops the loop after this phase (rather than falling through to plan/implement), the
Move 4 loop-condition check finds nothing non-terminal left to dispatch and the loop terminates
cleanly here:

```bash
skill_postflight_update 427 "research" "$session_id" "$SUBAGENT_STATUS"  # Status -> researched
skill_link_artifacts 427 "$ARTIFACT_PATH" "research" "$ARTIFACT_SUMMARY" '**Research**' '**Plan**'
rm -f "$loop_guard_file"  # cleanup on clean exit
skill_orchestrate_merge_return_meta "$meta_file" "$detected_defects" "implemented" \
  "$cycle_count" "$current_status"
```

**Command -> Git Commit**

Targeted staging per `.claude/context/standards/git-staging-scope.md` — never a repo-wide add:

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: complete research" \
  --session "sess_..." \
  --honest-index-rows {N} \
  -- "specs/427_document.../reports/" "specs/427_document.../.return-meta.json" \
     "specs/TODO.md" "specs/state.json"
```

**User Sees:**
```
Research completed for Task #{N}

Report: specs/427_document.../reports/01_research-findings.md

Status: [RESEARCHED]
Next: /orchestrate 427 --plan
```

---

## Key Decision Points

### Routing Decision

```
Input: /orchestrate 427 --research (task_type = "meta")

command-route-agent.sh resolves:
  source .claude/scripts/command-route-agent.sh "research" "meta" "general-research-agent" "$effort_flag"
  # Checks extension manifests' routing_agents block for task_type-specific routing
  # Falls back to the caller's own default: general-research-agent

Decision tree:
  Is task_type an extension type with custom routing_agents? NO
  -> Use default: general-research-agent
```

If task {N} had a task type provided by an extension (e.g., `task_type: "python"`), the flow would route to the extension's own research agent:
```
skill-orchestrate -> command-route-agent.sh -> python-research-agent
```
(Some extensions still route through their own domain research *skill* first — e.g.
`skill-python-research` — depending on how the extension is built; see the extension's own
manifest `routing`/`routing_agents` blocks.)

### Context Loading Decision

```
Agent: general-research-agent
Task type: "meta"

Context loading from index.json (4-tier progressive disclosure):
  Always load (tier 1):
    - repo/project-overview.md
    - patterns/anti-stop-patterns.md

  Task-type-specific (meta, tier 2-3):
    - meta/meta-guide.md
    - architecture/component-checklist.md
    - reference/skill-agent-mapping.md
    - (other entries matching task_type "meta" in index.json)

  Agent-specific:
    - formats/report-format.md (research agent context)
    - formats/return-metadata-file.md
```

---

## Artifact Locations

After `/orchestrate 427 --research` completes:

```
specs/
├── state.json                 # Updated: task {N} status = "researched"
├── TODO.md                    # Updated: task {N} [RESEARCHED] with link
└── 427_document_command_skill_subagent_framework/
    └── reports/
        └── 01_research-findings.md    # Created: research report
```

---

## Error Scenarios

### Scenario A: Task Not Found

If user runs `/orchestrate {N} --research` but task {N} does not exist:

```
skill-orchestrate Move 1 (status refresh / eligibility):
  Lookup task {N} in state.json -> NOT FOUND
  Aborts with: "Task {N} not found in state.json"

User sees:
  Error: Task {N} not found. Check task exists with /task --sync
```

### Scenario B: Network Error During Research

If WebSearch fails during research:

```
Agent Stage 3:
  WebSearch request fails -> network timeout

Agent continues with fallback:
  Use codebase-only patterns
  Note limitation in report

Return:
{
  "status": "partial",
  "summary": "Found 4 codebase patterns but WebSearch failed. Report contains local findings with suggested follow-up.",
  "errors": [{
    "type": "network",
    "message": "WebSearch request failed: connection timeout",
    "recoverable": true,
    "recommendation": "Retry research or proceed with codebase-only findings"
  }]
}
```

### Scenario C: Extension Task Type Routing

If user runs `/orchestrate {N} --research` where task {N} has `task_type: "python"` (with the python extension loaded):

```
skill-orchestrate Move 1 (task-type routing):
  Lookup task {N} -> task_type = "python"

Move 1 routing resolution:
  Routing: python -> python-research-agent (via command-route-agent.sh)

Flow:
  skill-orchestrate -> command-route-agent.sh -> python-research-agent

Agent uses:
  - WebSearch for library documentation
  - WebFetch for API references
  - Read for codebase exploration
  - Python-specific context files
```

---

## Session Tracking

The session_id flows through all layers:

```
commands/orchestrate.md generates: session_id = "sess_1736700000_abc123"
         |
         v
skill-orchestrate's Setup forwards session_id, then Move 2 passes it in delegation context to the agent
         |
         v
Agent includes session_id in .return-meta.json
         |
         v
skill-orchestrate's postflight and git commit reference session_id
         |
         v
Session tracked for debugging/auditing
```

<!-- task-ref-ok:end -->

---

## Summary

This example demonstrated:

1. **Command Layer**: User entry point (`/orchestrate`); parses arguments and forwards to `skill-orchestrate`
2. **Skill Layer**: `skill-orchestrate`'s state-machine dispatch — resolves routing, prepares delegation context, invokes the agent directly (no per-function skill hop for `general`/`meta`/`markdown` task types)
3. **Agent Layer**: Executes work, creates artifacts, writes `.return-meta.json` metadata file
4. **Return Flow**: `skill-orchestrate`'s Move 3 reads the handoff, updates the loop guard, and runs postflight — status update, artifact linking, git commit
5. **Status Updates**: Atomic state.json + TODO.md updates via shared scripts

The current architecture provides:
- Clean separation of concerns (command / orchestrator skill / agent)
- Shared infrastructure via `skill-base.sh` (~60% code reduction versus per-skill hand-rolling)
- Task-type-based routing via `command-route-agent.sh`
- File-based metadata exchange (`.return-meta.json`)
- Resume support via partial status, the loop guard, and the orchestrator handoff file

---

## Related Documentation

- [Component Selection](../guides/component-selection.md) - When to create each component
- [Creating Skills](../guides/creating-skills.md) - Skill creation guide
- [Creating Agents](../guides/creating-agents.md) - Agent creation guide
- `.claude/context/formats/subagent-return.md` - Return format schema

---

**Document Version**: 3.0 (Updated 2026-09-02 to retrace the flow through `/orchestrate` and
`skill-orchestrate`'s direct agent dispatch, after the standalone `/research` command and the
base lifecycle research skill were deleted)
**Created**: 2026-01-12
**Maintained By**: Project Development Team
