# Routing Guide - Lightweight Command Routing Context

**Created**: 2025-12-29 (Task 244 Phase 1)
**Purpose**: Lightweight routing context for orchestrator Stages 1-3 (command parsing and delegation preparation)

---

> **DEPRECATED** (2026-01-19): This file has been consolidated into:
> - `orchestration-core.md` - Command->Agent mapping, language extraction, routing validation
> - `orchestration-reference.md` - Troubleshooting routing issues
>
> This file is preserved for reference but should not be loaded for new development.

---

## Overview

This guide provides the minimal context needed for orchestrator routing decisions (Stages 1-3). It replaces loading heavy context files during routing, reducing context window usage from 60-70% to <15%.

**Usage**: Load this file during orchestrator Stages 1-3 instead of full context system.

---

## Command → Agent Mapping

### Workflow Commands

Commands that follow the 8-stage command-lifecycle.md pattern:

| Command | Agent | Description |
|---------|-------|-------------|
| `/research` | `subagents/researcher` | Conduct research, create reports, update [RESEARCHED] status |
| `/plan` | `subagents/planner` | Create implementation plans, update [PLANNED] status |
| `/implement` | `task-executor` | Execute phased implementation, update [IMPLEMENTED] status |
| `/revise` | `subagents/reviser` | Revise artifacts based on feedback, update status |
| `/task` | `orchestrator` | Unified task lifecycle: create, recover, divide, sync, abandon tasks |

**Routing Pattern**: Command file frontmatter specifies `agent:` field, orchestrator delegates directly.

### Direct Agent Commands

Commands that invoke agents directly without command-lifecycle.md:

| Command | Agent | Description |
|---------|-------|-------------|
| `/status` | `status-sync-manager` | Synchronize task status across TODO.md and state.json |
| `/commit` | `git-workflow-manager` | Create targeted git commits for task artifacts |

---

## Language-Based Routing

### Language Extraction

Extract language from task entry in TODO.md:

```bash
# Extract language field from task entry
language=$(grep -A 20 "^### ${task_number}\." specs/TODO.md | grep "Language" | sed 's/\*\*Language\*\*: //')

# Validate extraction succeeded
if [ -z "$language" ]; then
  language="general"
  echo "[WARN] Language not found for task ${task_number}, defaulting to 'general'"
else
  echo "[INFO] Task ${task_number} language: ${language}"
fi
```

### Language → Agent Routing

| Language | Research Agent | Implementation Agent | Notes |
|----------|---------------|---------------------|-------|
| `neovim` | `neovim-research-agent` | `neovim-implementation-agent` | Neovim plugin and configuration development |
| `markdown` | `researcher` | `implementer` | Documentation and markdown files |
| `meta` | `researcher` | `implementer` | System/meta configuration tasks |
| `general` | `researcher` | `implementer` | Default for unspecified language |

**Note**: Additional languages (latex, typst) are available via extensions in `.claude/extensions/`.

**Critical**: Always extract language explicitly. DO NOT assume language without extraction.

### Routing Validation

Before delegating to agent, verify routing is correct:

```bash
# Validate neovim routing
if [ "$language" == "neovim" ] && [[ ! "$agent" =~ ^neovim- ]]; then
  echo "[FAIL] Routing validation failed: language=neovim but agent=${agent}"
  exit 1
fi

# Validate non-neovim routing
if [ "$language" != "neovim" ] && [[ "$agent" =~ ^neovim- ]]; then
  echo "[FAIL] Routing validation failed: language=${language} but agent=${agent}"
  exit 1
fi

echo "[PASS] Routing validation succeeded"
```

### Implementation Status

**Stage 2 (DetermineRouting) Implementation:**
- ✅ Language extraction from state.json (Priority 1)
- ✅ Language extraction from TODO.md (Priority 2)
- ✅ Default to "general" fallback (Priority 3)
- ✅ Routing table lookup from command frontmatter
- ✅ Agent file existence validation
- ✅ Language/agent capability validation
- ✅ Logging for routing decisions

**Stage 4 (ValidateReturn) Artifact Validation:**
- ✅ Artifacts array non-empty check (prevents phantom research)
- ✅ Artifact file existence check
- ✅ Artifact file non-empty check (size > 0)
- ✅ Validation logging ([PASS]/[FAIL])

**Commands with Language-Based Routing:**
- ✅ /research (neovim → neovim-research-agent, default → researcher)
- ✅ /implement (neovim → neovim-implementation-agent, default → implementer)

---

## Delegation Preparation

### Session ID Generation

Generate unique session ID for tracking:

```bash
timestamp=$(date +%s)
random=$(openssl rand -hex 3)
session_id="sess_${timestamp}_${random}"
```

### Delegation Context Structure

```json
{
  "session_id": "sess_1735460684_a1b2c3",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "{command}", "{agent}"],
  "timeout": 3600,
  "task_context": {
    "task_number": 244,
    "description": "Phase 1: Context Index and /research Frontmatter Prototype",
    "language": "markdown"
  }
}
```

### Timeout Configuration

| Command | Default Timeout | Max Timeout | Notes |
|---------|----------------|-------------|-------|
| `/research` | 3600s (1 hour) | 7200s (2 hours) | Research can be time-intensive |
| `/plan` | 1800s (30 min) | 3600s (1 hour) | Planning is typically faster |
| `/implement` | 7200s (2 hours) | 14400s (4 hours) | Implementation can be complex |
| `/revise` | 1800s (30 min) | 3600s (1 hour) | Revisions are typically focused |

### Delegation Safety

**Max Delegation Depth**: 3 levels

```
Level 0: User
Level 1: Orchestrator → Command
Level 2: Command → Agent
Level 3: Agent → Utility (status-sync-manager, git-workflow-manager)
```

**Cycle Detection**: Track delegation_path to prevent cycles.

**Timeout Enforcement**: Monitor deadline, recover partial results on timeout.

---

## Command Argument Parsing

### Standard Argument Pattern

Most commands follow this pattern:

```
/{command} TASK_NUMBER [ADDITIONAL_ARGS]
```

Examples:
- `/research 244`
- `/research 244 "Focus on routing patterns"`
- `/plan 244 --phased`
- `/implement 244`

### Argument Extraction

```bash
# Extract task number (first argument)
task_number=$(echo "$ARGUMENTS" | awk '{print $1}')

# Extract remaining arguments (optional)
remaining_args=$(echo "$ARGUMENTS" | cut -d' ' -f2-)

# Validate task number is integer
if ! [[ "$task_number" =~ ^[0-9]+$ ]]; then
  echo "[FAIL] Task number must be an integer. Got: ${task_number}"
  exit 1
fi

# Verify task exists in TODO.md
if ! grep -q "^### ${task_number}\." specs/TODO.md; then
  echo "[FAIL] Task ${task_number} not found in TODO.md"
  exit 1
fi
```

### Flag Parsing

Some commands support flags:

| Command | Flag | Description |
|---------|------|-------------|
| `/research` | `--divide` | Subdivide research into multiple topics |
| `/plan` | `--phased` | Create phased implementation plan |
| `/implement` | `--resume` | Resume from incomplete phase |
| `/task` | `--recover` | Unarchive tasks from archive/ (supports ranges/lists) |
| `/task` | `--expand` | Expand existing task into subtasks (single task only) |
| `/task` | `--sync` | Synchronize TODO.md and state.json (git blame conflict resolution) |
| `/task` | `--abandon` | Abandon tasks to archive/ (supports ranges/lists) |

### /task Flag-Based Routing

The `/task` command uses flag-based routing to different operations:

**Flag Detection**:
```bash
# Detect which flag is present (only one allowed)
if [[ "$ARGUMENTS" =~ --recover ]]; then
  operation="recover"
  args="${ARGUMENTS#*--recover }"  # Extract task ranges
elif [[ "$ARGUMENTS" =~ --expand ]]; then
  operation="expand"
  args="${ARGUMENTS#*--expand }"  # Extract task number and optional prompt
elif [[ "$ARGUMENTS" =~ --sync ]]; then
  operation="sync"
  args="${ARGUMENTS#*--sync }"  # Extract optional task ranges
elif [[ "$ARGUMENTS" =~ --abandon ]]; then
  operation="abandon"
  args="${ARGUMENTS#*--abandon }"  # Extract task ranges
else
  operation="create"
  args="$ARGUMENTS"  # Task description and optional flags
fi
```

**Operation Routing**:
- `create`: Route to Stage 2 (PrepareTasks) → Stage 3 (CreateTasks)
- `recover`: Route to Stage 4 (RecoverTasks) → delegates to status-sync-manager
- `divide`: Route to Stage 5 (DivideExistingTask) → delegates to task-divider + task-creator
- `sync`: Route to Stage 6 (SyncTasks) → delegates to status-sync-manager
- `abandon`: Route to Stage 7 (AbandonTasks) → delegates to status-sync-manager

**Range Parsing** (for --recover, --sync, --abandon):
```bash
# Parse task ranges: "343", "343-345", "337, 343-345, 350"
parse_ranges() {
  local ranges="$1"
  local task_numbers=()
  
  # Split on commas
  IFS=',' read -ra parts <<< "$ranges"
  
  for part in "${parts[@]}"; do
    part=$(echo "$part" | tr -d ' ')  # Trim whitespace
    
    if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      # Range: expand to individual numbers
      start="${BASH_REMATCH[1]}"
      end="${BASH_REMATCH[2]}"
      for ((i=start; i<=end; i++)); do
        task_numbers+=("$i")
      done
    elif [[ "$part" =~ ^[0-9]+$ ]]; then
      # Single number
      task_numbers+=("$part")
    else
      echo "[FAIL] Invalid range format: $part"
      exit 1
    fi
  done
  
  # Deduplicate and sort
  printf '%s\n' "${task_numbers[@]}" | sort -nu
}
```

---

## Status Transitions

### Status Markers

Commands update task status using text-based markers:

| Status | Marker | Description |
|--------|--------|-------------|
| Not Started | `[NOT STARTED]` | Task created but not begun |
| Researching | `[RESEARCHING]` | Research in progress |
| Researched | `[RESEARCHED]` | Research completed |
| Planning | `[PLANNING]` | Planning in progress |
| Planned | `[PLANNED]` | Plan created |
| Implementing | `[IMPLEMENTING]` | Implementation in progress |
| Implemented | `[IMPLEMENTED]` | Implementation completed |
| Testing | `[TESTING]` | Testing in progress |
| Completed | `[COMPLETED]` | Task fully completed |
| Blocked | `[BLOCKED]` | Task blocked by dependency |
| Abandoned | `[ABANDONED]` | Task abandoned |

### Status Update Delegation

**CRITICAL**: Status updates MUST be delegated to status-sync-manager for atomic synchronization.

```json
{
  "agent": "status-sync-manager",
  "task_number": 244,
  "new_status": "researched",
  "timestamp": "2025-12-29T08:13:37Z",
  "artifacts": [
    "specs/244_phase_1_context_index_and_research_frontmatter_prototype/reports/01_context-index-research.md"
  ]
}
```

**DO NOT** update TODO.md or state.json directly. Always delegate to status-sync-manager.

---

## Error Handling

### Common Routing Errors

| Error | Cause | Resolution |
|-------|-------|------------|
| Task not found | Task number doesn't exist in TODO.md | Verify task number, check TODO.md |
| Invalid language | Language extraction failed | Default to "general", log warning |
| Routing mismatch | Language doesn't match agent | Abort with validation error |
| Missing agent | Command frontmatter missing `agent:` field | Add frontmatter to command file |
| Delegation cycle | Agent tries to delegate back to caller | Abort with cycle detection error |
| Timeout exceeded | Agent execution exceeds timeout | Recover partial results, log timeout |

### Error Response Format

```json
{
  "status": "failed",
  "summary": "Routing failed: Task 244 not found in TODO.md",
  "errors": [{
    "type": "validation",
    "message": "Task 244 not found in TODO.md",
    "code": "TASK_NOT_FOUND",
    "recoverable": false,
    "recommendation": "Verify task number exists in specs/TODO.md"
  }],
  "metadata": {
    "session_id": "sess_1735460684_a1b2c3",
    "agent_type": "orchestrator",
    "delegation_depth": 0
  }
}
```

---

## Context Loading Strategy

### Routing Stage (Stages 1-3)

**Load**: This file only (routing-guide.md)

**DO NOT Load**:
- subagent-return-format.md (11KB)
- subagent-delegation-guide.md (18KB)
- status-markers.md (27KB)
- command-lifecycle.md (15KB)

**Rationale**: Routing decisions don't require detailed workflow context. Load only what's needed for command parsing and agent selection.

### Execution Stage (Stage 4+)

**Load**: Context files needed for specific workflow

See `.claude/context/index.json` for execution context loading patterns.

---

## Quick Reference

### Routing Checklist

- [ ] Parse command and extract task number
- [ ] Validate task exists in TODO.md
- [ ] Extract language from task entry
- [ ] Determine target agent based on command + language
- [ ] Validate routing (language matches agent)
- [ ] Generate session ID
- [ ] Prepare delegation context
- [ ] Set timeout based on command type
- [ ] Check delegation depth < 3
- [ ] Delegate to agent

### Context Budget

- **Routing Stage**: <10% context window (this file only, ~200 lines)
- **Execution Stage**: 90% context window available (selective loading)

---

## Troubleshooting

### Phantom Research (Status Updated but No Artifacts)

**Symptom:** Task status shows [RESEARCHED] but no research report exists.

**Root Cause:** Agent returned status="completed" without creating artifacts.

**Detection:** Stage 4 artifact validation catches this:
```
[FAIL] Agent returned 'completed' status but created no artifacts
Error: Phantom research detected: status=completed but no artifacts
```

**Prevention:** Orchestrator Stage 4 now validates:
1. Artifacts array is non-empty (if status=completed)
2. All artifact files exist on disk
3. All artifact files are non-empty (size > 0)

**Recovery:**
1. Reset task status to [NOT STARTED]
2. Re-run command: `/research {task_number}`
3. Verify artifacts created after completion

### Language Routing Mismatch

**Symptom:** Neovim task routed to general researcher (or vice versa).

**Root Cause:** Language extraction failed or routing validation skipped.

**Detection:** Stage 2 routing validation catches this:
```
[FAIL] Routing validation failed: language=neovim but agent=researcher
Error: Routing mismatch: Neovim task must route to neovim-* agent
```

**Prevention:** Orchestrator Stage 2 now validates:
1. If language="neovim": Agent must start with "neovim-"
2. If language!="neovim": Agent must NOT start with "neovim-"

**Recovery:**
1. Verify **Language** field in TODO.md task entry
2. Verify routing configuration in command frontmatter
3. Re-run command after fixing language field

### Language Extraction Failed

**Symptom:** Warning message "Language not found for task {N}, defaulting to 'general'".

**Root Cause:** Task entry missing **Language** field in TODO.md.

**Detection:** Stage 2 language extraction logs warning:
```
[WARN] Language not found for task 258, defaulting to 'general'
```

**Fix:**
1. Add **Language** field to task entry in TODO.md:
   ```markdown
   ### 258. Resolve Truth.neovim sorries
   - **Status**: [NOT STARTED]
   - **Language**: neovim
   ```
2. Re-run command

### Agent File Not Found

**Symptom:** Error "Agent file not found: {agent}".

**Root Cause:** Routing configuration references non-existent agent.

**Detection:** Stage 2 agent file validation:
```
[FAIL] Agent file not found: neovim-research-agent
```

**Fix:**
1. Verify agent file exists: `.claude/agent/subagents/{agent}.md`
2. Fix routing configuration in command frontmatter
3. Create missing agent file if needed

### Routing Logs

**Example successful routing (Neovim task):**
```
[INFO] Task 258 language: neovim
[INFO] Routing to neovim-research-agent (language=neovim)
[PASS] Routing validation succeeded
```

**Example successful routing (Markdown task):**
```
[INFO] Task 256 language: markdown
[INFO] Routing to researcher (language=markdown)
[PASS] Routing validation succeeded
```

**Example failed routing (mismatch):**
```
[INFO] Task 258 language: neovim
[INFO] Routing to researcher (language=neovim)
[FAIL] Routing validation failed: language=neovim but agent=researcher
Error: Routing mismatch: Neovim task must route to neovim-* agent
```

---

**End of Routing Guide**
# Routing Logic Standard

## Overview

This standard defines how the orchestrator determines which agent to route commands to, including language-based routing for Neovim-specific tasks.

## Language Extraction

For commands with `routing.language_based: true`, extract language from task metadata.

### Priority Order

1. **Priority 1**: Project state.json (task-specific)
2. **Priority 2**: TODO.md task entry (**Language** field)
3. **Priority 3**: Default "general" (fallback)

### Implementation

#### Priority 1: Project state.json

```bash
# Find task directory
task_dir=$(find specs -maxdepth 1 -type d -name "${task_number}_*" | head -n 1)

# Extract language from state.json
if [ -n "$task_dir" ] && [ -f "${task_dir}/state.json" ]; then
  language=$(jq -r '.language // empty' "${task_dir}/state.json")
  
  if [ -n "$language" ]; then
    echo "[INFO] Language extracted from state.json: ${language}"
    # Use this language, skip to agent mapping
  fi
fi
```

#### Priority 2: TODO.md task entry

```bash
# Extract task entry (20 lines after task header)
task_entry=$(grep -A 20 "^### ${task_number}\." specs/TODO.md)

# Extract Language field
language=$(echo "$task_entry" | grep "Language" | sed 's/\*\*Language\*\*: //' | tr -d ' ')

if [ -n "$language" ]; then
  echo "[INFO] Language extracted from TODO.md: ${language}"
  # Use this language, skip to agent mapping
fi
```

#### Priority 3: Default fallback

```bash
# If language still not found, default to "general"
language=${language:-general}

echo "[WARN] Language not found for task ${task_number}, defaulting to 'general'"
```

## Agent Mapping

Map extracted language to appropriate agent using routing table from command frontmatter.

### Routing Tables

Commands define routing in frontmatter:

```yaml
routing:
  language_based: true
  neovim: neovim-research-agent      # Agent for Neovim tasks
  default: researcher             # Agent for all other tasks
```

### Mapping Logic

```bash
# Read routing table from command frontmatter
neovim_agent=$(yq '.routing.neovim' .claude/command/${command}.md)
default_agent=$(yq '.routing.default' .claude/command/${command}.md)

# Map language to agent
if [ "$language" == "neovim" ]; then
  target_agent="$neovim_agent"
  echo "[INFO] Routing to ${target_agent} (language=neovim)"
else
  target_agent="$default_agent"
  echo "[INFO] Routing to ${target_agent} (language=${language})"
fi
```

### Common Routing Tables

| Command | Language | Agent |
|---------|----------|-------|
| /research | neovim | neovim-research-agent |
| /research | general | researcher |
| /plan | neovim | neovim-planner |
| /plan | general | planner |
| /revise | neovim | neovim-planner |
| /revise | general | planner |
| /implement | neovim | neovim-implementation-agent |
| /implement | general | implementer |
| /review | any | reviewer (no language-based routing) |

## Routing Validation

Validate routing decision before delegation.

### Validation Steps

1. **Verify agent file exists**
   ```bash
   agent_file=".claude/agent/subagents/${target_agent}.md"
   
   if [ ! -f "$agent_file" ]; then
     echo "[FAIL] Agent file not found: ${target_agent}"
     exit 1
   fi
   
   echo "[PASS] Agent file exists: ${agent_file}"
   ```

2. **Verify language matches agent capabilities**
   ```bash
   # Neovim tasks must route to neovim-* agents
   if [ "$language" == "neovim" ] && [[ ! "$target_agent" =~ ^neovim- ]]; then
     echo "[FAIL] Routing validation failed: language=neovim but agent=${target_agent}"
     echo "Error: Neovim task must route to neovim-* agent"
     exit 1
   fi
   
   # Non-neovim tasks must NOT route to neovim-* agents
   if [ "$language" != "neovim" ] && [[ "$target_agent" =~ ^neovim- ]]; then
     echo "[FAIL] Routing validation failed: language=${language} but agent=${target_agent}"
     echo "Error: Non-neovim task cannot route to neovim-* agent"
     exit 1
   fi
   
   echo "[PASS] Routing validation succeeded"
   ```

3. **Update delegation path**
   ```bash
   delegation_path=["orchestrator", "${command}", "${target_agent}"]
   ```

## Direct Routing

For commands with `routing.language_based: false`, use direct routing.

### Implementation

```bash
# Read target_agent from command frontmatter
target_agent=$(yq '.routing.target_agent' .claude/command/${command}.md)

# Verify agent file exists
agent_file=".claude/agent/subagents/${target_agent}.md"

if [ ! -f "$agent_file" ]; then
  echo "[FAIL] Agent file not found: ${target_agent}"
  exit 1
fi

echo "[INFO] Routing to ${target_agent} (direct command)"
```

### Commands Using Direct Routing

| Command | Target Agent | Reason |
|---------|--------------|--------|
| /review | reviewer | Review is language-agnostic |
| /todo | (orchestrator) | No delegation |
| /task | (orchestrator) | No delegation |
| /errors | error-diagnostics-agent | Error analysis is language-agnostic |

## Error Handling

### Language Extraction Failed

**Symptom**: Cannot extract language from state.json or TODO.md

**Action**: Default to "general" and log warning

```bash
language=${language:-general}
echo "[WARN] Language not found for task ${task_number}, defaulting to 'general'"
```

**Impact**: Task routes to general agent instead of Neovim-specific agent

**Resolution**: Add **Language** field to task entry in TODO.md

### Agent File Not Found

**Symptom**: Routing validation fails because agent file doesn't exist

**Action**: Abort with error

```bash
echo "[FAIL] Agent file not found: ${target_agent}"
echo "Error: Cannot route to ${target_agent} - agent file missing"
echo "Expected path: .claude/agent/subagents/${target_agent}.md"
exit 1
```

**Resolution**: Create missing agent file or fix routing configuration

### Routing Mismatch

**Symptom**: Language doesn't match agent capabilities

**Action**: Abort with error

```bash
echo "[FAIL] Routing validation failed: language=${language} but agent=${target_agent}"
echo "Error: Neovim task must route to neovim-* agent"
exit 1
```

**Resolution**: Fix routing table in command frontmatter or correct task language

## Logging

All routing decisions are logged for debugging.

### Log Format

```
[INFO] Task {N} language: {language}
[INFO] Routing to {agent} (language={language})
[PASS] Routing validation succeeded
```

### Example Log

```
[INFO] Task 258 language: neovim
[INFO] Routing to neovim-research-agent (language=neovim)
[PASS] Agent file exists: .claude/agent/subagents/neovim-research-agent.md
[PASS] Routing validation succeeded
```

## See Also

- Orchestrator: `.claude/agent/orchestrator.md`
- Command Template: `.claude/context/core/templates/command-template.md`
- Delegation Standard: `.claude/context/core/standards/delegation.md`
- Command Argument Handling: `.claude/context/core/standards/command-argument-handling.md`
