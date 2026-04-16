# Research Report: Task #426

**Task**: 426 - update_slides_command_manifest_critic_flag
**Started**: 2026-04-13T00:00:00Z
**Completed**: 2026-04-13T00:10:00Z
**Effort**: Small
**Dependencies**: None (skill-slide-critic SKILL.md, slide-critic-agent.md, and critique-rubric.md already exist)
**Sources/Inputs**: Codebase exploration of present extension files
**Artifacts**: specs/426_update_slides_command_manifest_critic_flag/reports/01_slides-critic-flag-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `/slides` command needs a new `--critic` flag with three input forms: `--critic /path/to/file`, `--critic N` (task number), `--critic prompt`
- The manifest.json needs a new routing entry under a `critique` key (or extending `research`) to route `present:slides` to `skill-slide-critic`
- The index-entries.json already has the critique-rubric.md entry but needs the `slide-critic-agent` added to relevant context entries' agent lists and `/slides --critic` to command lists
- EXTENSION.md needs a new row in Skill-Agent Mapping and a mention of `--critic` in the Commands table

## Context & Scope

The task is to integrate the already-created slide critique subsystem (skill-slide-critic, slide-critic-agent, critique-rubric.md) into the `/slides` command surface. All implementation artifacts exist; the wiring is missing.

## Findings

### 1. slides.md Command Changes

#### 1a. Frontmatter Updates

The `argument-hint` line (line 4) needs updating:

**Current**:
```
argument-hint: "description" | TASK_NUMBER | /path/to/file.md
```

**Needed**:
```
argument-hint: "description" | TASK_NUMBER | /path/to/file.md | TASK_NUMBER --critic [/path | prompt] | --critic /path/to/file
```

The `allowed-tools` line (line 3) needs `Task` added since skill-slide-critic uses the Task tool for subagent spawning:

**Current**:
```
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Bash(sed:*), Read, Edit, AskUserQuestion
```

**Needed**: Add `Task` to the allowed-tools list.

#### 1b. Syntax Section (lines 17-20)

Add new syntax entries:
```
- `/slides N --critic` - Critique existing task's slide materials
- `/slides N --critic /path/to/rubric.md` - Critique with custom rubric file
- `/slides N --critic "Focus on narrative flow"` - Critique with focus prompt
- `/slides --critic /path/to/slides.md` - Critique a standalone file (no task)
```

#### 1c. Input Types Table (lines 25-31)

Add a new row:

| Input | Behavior |
|-------|----------|
| `N --critic [path\|prompt]` | Route to skill-slide-critic for interactive critique loop |
| `--critic /path/to/file` | Read file, create temporary context, route to skill-slide-critic |

#### 1d. Input Detection (Step 2, lines 139-156)

The current detection logic checks three cases: task_number, file_path, description. A new check for `--critic` flag must be added **before** the existing checks (like the grant command's flag parsing pattern at lines 38-51 of grant.md).

**Proposed detection order** (matching the grant.md pattern):

1. Check for `--critic` flag in arguments
2. Check for task number (existing)
3. Check for file path (existing)
4. Default: description (existing)

**Flag parsing pseudocode**:
```bash
# Check for --critic flag (before other checks)
if echo "$ARGUMENTS" | grep -q '\-\-critic'; then
  # Extract task number before --critic (if present)
  task_number=$(echo "$ARGUMENTS" | grep -oE '^[0-9]+' || echo "")

  # Extract critic input after --critic
  critic_input=$(echo "$ARGUMENTS" | sed 's/.*--critic\s*//')

  if [ -n "$critic_input" ]; then
    # Detect if it's a file path or prompt text
    if echo "$critic_input" | grep -qE '^\.|^/|^~|\.md$|\.txt$'; then
      critic_type="file_path"
      critic_file="$critic_input"
    elif echo "$critic_input" | grep -qE '^[0-9]+$'; then
      critic_type="task_number"
      critic_task="$critic_input"
    else
      critic_type="prompt"
      critic_prompt="$critic_input"
    fi
  fi

  input_type="critic"
fi
```

#### 1e. New Stage for --critic Handling

A new stage is needed (between CHECKPOINT 1 and STAGE 1, or as a new STAGE 3). This stage:

1. **Validates** the task exists and is a `present:slides` task (if task number provided)
2. **Determines materials to review**: uses the task's existing reports/plans/slides, or the provided file path
3. **Builds delegation context** matching what skill-slide-critic expects (see SKILL.md Stage 3)
4. **Delegates** to skill-slide-critic via `Skill("skill-slide-critic", "task_number={N} session_id={session_id}")`
5. **Gate Out**: verifies critique completed, reports results

The skill-slide-critic SKILL.md (lines 34-37) already defines trigger conditions:
- Task has `task_type: "present:slides"`
- `workflow_type: "slides_critique"`

#### 1f. Core Command Integration Table (lines 335-343)

Add a new row:

| Command | Routes To | Purpose |
|---------|-----------|---------|
| `/slides N --critic` | skill-slide-critic | Interactive critique loop with accept/reject decisions |

### 2. manifest.json Routing Changes

**Current routing** (lines 17-42) has three sections: `research`, `plan`, `implement`.

**Needed**: Add a `critique` routing section. Looking at how existing routing works:

```json
"critique": {
  "present:slides": "skill-slide-critic"
}
```

This follows the same pattern as other routing entries. The `/slides` command's flag detection would look up `routing.critique["present:slides"]` to find the target skill.

Additionally, the `provides.skills` array (line 9) already includes `"skill-slide-critic"` and `provides.agents` already includes `"slide-critic-agent"`. No changes needed there.

### 3. index-entries.json Changes

**Current state**: The file already has a critique-rubric.md entry (lines 493-506) with:
```json
{
  "path": "project/present/talk/critique-rubric.md",
  "load_when": {
    "task_types": ["present"],
    "agents": ["slide-critic-agent"],
    "commands": ["/slides"]
  }
}
```

This is already good -- the rubric loads for `/slides` commands and for the slide-critic-agent.

**Needed changes**:

1. **Add `slide-critic-agent` to talk context entries**: The following entries (currently only referencing slides-research-agent, pptx-assembly-agent, slidev-assembly-agent, slide-planner-agent) should also include `slide-critic-agent` in their `load_when.agents` arrays:

   - `project/present/domain/presentation-types.md` (line 349) -- needed per agent's "Load for Talk Context" section
   - `project/present/patterns/talk-structure.md` (line 363) -- needed per agent's "Load for Talk Context" section
   - `project/present/talk/index.json` (line 403) -- useful for pattern discovery

2. **Verify critique-rubric.md entry commands**: Currently has `["/slides"]`. This is sufficient since `--critic` is a flag of `/slides`, not a separate command. No change needed here.

3. **Optional**: Add `"/slides --critic"` variant to commands arrays if the context system distinguishes flag variants. Based on the existing patterns (e.g., `/grant` doesn't have `/grant --draft` entries), this is NOT needed.

### 4. EXTENSION.md Documentation Changes

**Current state** (62 lines): Has Skill-Agent Mapping table, Commands table, Language Routing table, Talk Modes table, Talk Library section.

**Needed changes**:

#### 4a. Skill-Agent Mapping Table (lines 8-16)

Add new row:
```
| skill-slide-critic | slide-critic-agent | opus | Interactive slide critique with rubric evaluation |
```

Also add `slide-planner-agent` row if missing (it's referenced in manifest but not in EXTENSION.md).

#### 4b. Commands Table (lines 19-33)

Add new `/slides` variant:
```
| `/slides` | `/slides N --critic [path\|prompt]` | Critique slide materials with interactive feedback loop |
```

#### 4c. Language Routing Table (lines 36-43)

Consider adding a `critique` column or a note that `present:slides` tasks support critique workflow via `--critic` flag.

### 5. Delegation Path Alignment

The skill-slide-critic SKILL.md shows delegation_path as:
```
["orchestrator", "critique", "skill-slide-critic", "slide-critic-agent"]
```

But the slide-critic-agent.md shows:
```
["orchestrator", "slides", "skill-slides", "slide-critic-agent"]
```

These are inconsistent. Since the command entry point is `/slides`, the path should use `"slides"` as the second element. However, since the routing goes through `/slides --critic` -> `skill-slide-critic` (not `skill-slides`), the SKILL.md path is more accurate. The agent's example should be updated to match:
```
["orchestrator", "slides", "skill-slide-critic", "slide-critic-agent"]
```

This is a minor consistency fix that should be included in implementation.

## Decisions

- The `--critic` flag follows the same parsing pattern as `--draft`, `--budget`, `--revise` in the `/grant` command
- A new `critique` routing section in manifest.json is preferred over overloading the `research` section, because the critique workflow has a distinct interactive loop that differs from standard research
- No new `/critique` command is created; the flag on `/slides` is the entry point
- The `Task` tool must be added to slides.md allowed-tools since skill-slide-critic delegates via Task

## Risks & Mitigations

- **Risk**: Flag parsing order matters -- `--critic` must be checked before the generic task_number/file_path detection to avoid misrouting. **Mitigation**: Place `--critic` check first in the detection chain, matching the grant.md flag-first pattern.
- **Risk**: Delegation path inconsistency between SKILL.md and agent.md could confuse error tracking. **Mitigation**: Normalize to `["orchestrator", "slides", "skill-slide-critic", "slide-critic-agent"]` in both files.
- **Risk**: The `--critic /path/to/file` form (no task number) needs special handling since most skill-slide-critic logic assumes a task exists. **Mitigation**: Either require a task number for critique, or create a temporary task context in the command.

## Appendix

### Files to Modify

1. `.claude/extensions/present/commands/slides.md` -- Add --critic flag parsing, new input type, new stage, update frontmatter
2. `.claude/extensions/present/manifest.json` -- Add `critique` routing section
3. `.claude/extensions/present/index-entries.json` -- Add `slide-critic-agent` to talk context entries' agent arrays
4. `.claude/extensions/present/EXTENSION.md` -- Add skill-agent mapping row, command variant, routing note
5. `.claude/extensions/present/agents/slide-critic-agent.md` -- Fix delegation_path in example (minor)

### Search Queries Used

- Grep for `--critic` across present extension
- Read of slides.md, manifest.json, index-entries.json, SKILL.md, slide-critic-agent.md, EXTENSION.md
- Read of grant.md for flag parsing pattern reference
- Read of critique-rubric.md header for context path verification
