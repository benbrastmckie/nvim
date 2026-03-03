# Claude Code System Architecture

**Version**: 2.2
**Status**: Active
**Created**: 2025-12-26
**Updated**: 2026-01-28
**Purpose**: Comprehensive user documentation for the .claude skill and task management system

This document provides detailed explanations of the system architecture for users who want to understand how the agent system works. For minimal agent context loaded every session, see `.claude/CLAUDE.md`.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Principles](#architecture-principles)
3. [Component Hierarchy](#component-hierarchy)
4. [Delegation Flow](#delegation-flow)
5. [State Management](#state-management)
6. [Git Workflow](#git-workflow)
7. [Language Routing](#language-routing)
8. [Error Handling and Recovery](#error-handling-and-recovery)
9. [Meta System Builder](#meta-system-builder)
10. [Forked Subagent Pattern](#forked-subagent-pattern)
11. [Session Maintenance](#session-maintenance)
12. [MCP Server Configuration](#mcp-server-configuration)

---

## System Overview

The .claude system is a task management and automation framework designed for software development projects, with specialized support for Neovim configuration development. This document describes the architecture of the version 2.0 system, which represents a complete clean-break refactor from the previous version.

### Purpose and Goals

- Provide structured task management with research, planning, and implementation workflows
- Prevent delegation hangs and infinite loops through explicit return handling
- Enable atomic state synchronization across multiple tracking files
- Support language-specific routing (Neovim vs general development)
- Track and analyze errors for continuous improvement
- Automate git commits with clear, scoped changes

### Clean Break Rationale

Version 2.0 was built from scratch to address critical issues identified in Task 191:

1. **Delegation Hangs**: Commands would invoke subagents but never receive results, causing indefinite hangs
2. **Missing Return Handling**: No explicit stages for receiving and validating subagent returns
3. **Infinite Loops**: No cycle detection or delegation depth limits
4. **Timeout Failures**: No timeout enforcement, leading to indefinite waits
5. **Status Sync Failures**: Race conditions when updating TODO.md and state.json
6. **Missing Git Commits**: No automatic commit creation after task completion

The clean break approach ensures all components follow consistent patterns and standards from the start.

---

## Architecture Principles

### 1. Delegation Safety

All delegation follows strict safety patterns to prevent hangs and loops:

- **Session ID Tracking**: Every delegation has a unique session ID for tracking
- **Depth Limits**: Maximum delegation depth of 3 levels
- **Cycle Detection**: Check delegation path before routing to prevent loops
- **Timeout Enforcement**: All delegations have timeouts (default 3600s)
- **Return Validation**: All subagent returns validated against standard format

See `.claude/context/core/workflows/subagent-delegation-guide.md` for detailed patterns.

### 2. Standardized Returns

All subagents return a consistent JSON format:

```json
{
  "status": "completed|failed|partial|blocked",
  "summary": "Brief 2-5 sentence summary",
  "artifacts": [...],
  "metadata": {
    "session_id": "...",
    "duration_seconds": 123,
    "agent_type": "...",
    "delegation_depth": 1,
    "delegation_path": [...]
  },
  "errors": [...],
  "next_steps": "..."
}
```

This enables:
- Predictable parsing by calling commands
- Clear status indication
- Artifact tracking
- Error propagation
- Session tracking

See `.claude/context/core/standards/subagent-return-format.md` for full specification.

### 3. Atomic State Updates

Status changes are synchronized atomically across multiple files using the status-sync-manager:

- **Two-Phase Commit**: Prepare all updates in memory, then commit all or rollback
- **Files Synced**: TODO.md, state.json, project state.json, plan files
- **Rollback on Failure**: If any file update fails, all changes are rolled back
- **Consistency Guarantee**: Status is always consistent across all tracking files

### 4. Language-Based Routing

Tasks are routed to appropriate agents based on the Language field:

- `Language: neovim` → neovim-implementation-agent, neovim-research-agent
- `Language: markdown` → general agents (researcher, implementer)
- `Language: python` → general agents (future: python-specific agents)

This enables specialized tooling integration for Neovim configuration tasks.

### 5. Error Tracking and Recovery

All errors are logged to errors.json with:

- Error type and severity
- Context (command, task, agent, session)
- Fix status tracking
- Recurrence detection
- Fix effectiveness analysis

The /errors command analyzes patterns and creates fix plans automatically.

### 6. Smart Coordinator Pattern

The orchestrator acts as a smart coordinator with minimal context:

- **Preflight Validation**: Validates task exists, checks delegation safety
- **Language Extraction**: Extracts language from project state.json or TODO.md
- **Routing**: Determines target agent based on language and command configuration
- **Delegation**: Invokes agent with prepared context
- **Return Validation**: Validates agent return format
- **Postflight Cleanup**: Cleans up session registry

The orchestrator stays lightweight (<5% context window) by delegating all workflow logic to specialized agents.

### 7. Clean Context Organization

Context files are organized into `core/` (reusable) and `project/` (domain-specific):

**core/**:
- `standards/` - Return formats, templates, quality standards
- `workflows/` - Delegation patterns, status transitions, error handling
- `system/` - Routing rules, orchestrator guide, validation strategy
- `templates/` - Command and agent templates

**project/**:
- `neovim/` - Neovim configuration (plugins, keymaps, patterns)
- `repo/` - Repository-specific knowledge

This enables:
- **Three-Tier Loading**: Orchestrator (minimal), Commands (targeted), Agents (domain-specific)
- **Context Budget Enforcement**: Each tier has defined size limits
- **Clear Separation**: Core context is reusable, project context is Neovim configuration-specific

See `.claude/context/core/system/context-loading-strategy.md` for details.

---

## Component Hierarchy

The system has four levels of components:

### Level 0: Orchestration Layer

**Files**: `.claude/commands/*.md` (commands invoke skills via `Skill` tool)

**Responsibilities**:
- Central coordination and routing via commands
- Session ID generation and tracking
- Language-based routing to appropriate skills
- Checkpoint-based execution (preflight -> delegate -> postflight -> commit)

**Session Format**:
```
sess_{timestamp}_{random_6char}
Example: sess_1703606400_a1b2c3
```

Session IDs are generated at command preflight and passed through delegation for traceability.

### Level 1: Commands

**Directory**: `.claude/commands/`

**Commands**:
- `/task`: Create tasks in TODO.md
- `/research`: Conduct research and create reports
- `/plan`: Create implementation plans
- `/implement`: Execute implementation with resume support
- `/revise`: Revise existing plans
- `/review`: Analyze codebase and update registries
- `/todo`: Maintain TODO.md (clean completed tasks)
- `/errors`: Analyze errors and create fix plans
- `/meta`: Build custom .claude architectures through interactive interview

**Argument Parsing**:
All commands include an explicit `<argument_parsing>` section that specifies:
- **Invocation format**: How users should call the command
- **Parameters**: Position, type, required/optional status, extraction logic
- **Flags**: Boolean flags and their defaults
- **Parsing logic**: Step-by-step extraction process
- **Error handling**: User-friendly error messages for invalid inputs

Example from `/research` command:
```markdown
<argument_parsing>
  <invocation_format>
    /research TASK_NUMBER [PROMPT]
  </invocation_format>

  <parameters>
    <task_number>
      <position>1</position>
      <type>integer</type>
      <required>true</required>
      <extraction>Extract first argument after command name</extraction>
    </task_number>
  </parameters>
</argument_parsing>
```

The orchestrator reads this section and applies the parsing logic to extract arguments from user input.

**Common Pattern**:
All commands that invoke subagents follow this workflow:
1. ArgumentParsing: Extract and validate arguments using <argument_parsing> specification
2. Preflight: Validate inputs and update status
3. CheckLanguage: Determine routing based on task language
4. InvokeSubagent: Delegate to appropriate subagent with session tracking
5. ReceiveResults: Wait for and receive subagent return (with timeout)
6. ProcessResults: Extract artifacts and determine next steps
7. Postflight: Update status atomically and create git commit
8. ReturnSuccess: Return summary to user

### Level 2: Subagents

**Directory**: `.claude/agents/`

**Core Subagents**:
- `atomic-task-numberer`: Thread-safe task number allocation
- `status-sync-manager`: Atomic multi-file status updates
- `researcher`: General research for non-Neovim tasks
- `planner`: Implementation plan creation
- `implementer`: Direct implementation for simple tasks
- `task-executor`: Multi-phase plan execution with resume support

**Neovim-Specific Subagents**:
- `neovim-implementation-agent`: Neovim configuration implementation
- `neovim-research-agent`: Plugin and configuration research

**Support Subagents**:
- `error-diagnostics-agent`: Error pattern analysis and fix recommendations
- `git-workflow-manager`: Scoped git commits with auto-generated messages

**System Builder Subagents**:
- `domain-analyzer`: Analyzes domains to identify core concepts and recommend agent architectures
- `agent-generator`: Generates XML-optimized agent files (orchestrators and subagents)
- `context-organizer`: Creates modular context files (domain/processes/standards/templates)
- `workflow-designer`: Designs complete workflow definitions with context dependencies
- `command-creator`: Creates custom slash commands with clear syntax and routing

**Common Pattern**:
All subagents follow this structure:
1. Receive inputs with delegation context
2. Validate inputs
3. Execute task (may delegate to specialists)
4. Create artifacts
5. Return standardized format with session tracking

### Level 3: Specialists

**Directory**: `.claude/agents/specialists/` (future)

**Purpose**: Highly focused helpers for specific tasks (e.g., web-research-specialist)

**Constraint**: Maximum delegation depth of 3 means specialists cannot delegate further

---

## Delegation Flow

### Session ID Generation

Format: `sess_{timestamp}_{random_6char}`

Example: `sess_1703606400_a1b2c3`

Generated by caller before invoking subagent.

### Cycle Detection

Before delegating, check if target agent is already in delegation path:

```python
def check_cycle(delegation_path, target_agent):
    if target_agent in delegation_path:
        raise CycleError(f"Cycle detected: {delegation_path} → {target_agent}")
    return False
```

### Depth Enforcement

Maximum depth: 3 levels

```python
def check_depth(delegation_depth):
    if delegation_depth >= 3:
        raise DepthError(f"Max delegation depth (3) exceeded: {delegation_depth}")
    return True
```

### Timeout Enforcement

Default timeouts by operation:
- Research: 3600s (1 hour)
- Planning: 1800s (30 minutes)
- Implementation: 7200s (2 hours)
- Simple operations: 300s (5 minutes)

Timeout handling:
- Return partial results if available
- Mark task as IN PROGRESS (not failed)
- Provide actionable recovery message
- Log timeout to errors.json

### Return Validation

All returns validated against subagent-return-format.md:
1. Check JSON structure
2. Validate required fields present
3. Check status is valid enum
4. Verify session_id matches expected
5. Validate summary within length limits
6. Validate artifacts have valid paths

---

## State Management

### TODO.md

**Location**: `specs/TODO.md`

**Purpose**: User-facing task list with status markers

**Format**:
```markdown
### 191. Fix subagent delegation hang
- **Effort**: 14 hours
- **Status**: [COMPLETED]
- **Priority**: critical
- **Language**: markdown
- **Started**: 2025-12-20T10:00:00Z
- **Completed**: 2025-12-26T18:00:00Z
- **Plan**: [implementation-001.md](191_fix_subagent_delegation_hang/plans/implementation-001.md)
- **Research**: [research-001.md](191_fix_subagent_delegation_hang/reports/research-001.md)
```

**Status Markers**:
- `[NOT STARTED]`: Task created but not started
- `[IN PROGRESS]`: Task actively being worked on
- `[RESEARCHED]`: Research completed (intermediate state)
- `[PLANNED]`: Plan created (intermediate state)
- `[COMPLETED]`: Task fully completed
- `[ABANDONED]`: Task abandoned (won't complete)

### state.json

**Location**: `specs/state.json`

**Purpose**: Machine-readable project state

**Format**:
```json
{
  "tasks": {
    "191": {
      "status": "completed",
      "started": "2025-12-20T10:00:00Z",
      "completed": "2025-12-26T18:00:00Z",
      "effort_hours": 14,
      "language": "markdown"
    }
  }
}
```

### errors.json

**Location**: `specs/errors.json`

**Purpose**: Error tracking and fix effectiveness analysis

**Format**:
```json
{
  "_schema_version": "1.0.0",
  "_last_updated": "2025-12-26T00:00:00Z",
  "errors": [
    {
      "id": "error_20251220_abc123",
      "timestamp": "2025-12-20T10:00:00Z",
      "type": "delegation_hang",
      "severity": "critical",
      "context": {
        "command": "implement",
        "task_number": 191,
        "agent": "task-executor"
      },
      "message": "Command hung waiting for subagent return",
      "fix_status": "resolved",
      "fix_plan_ref": "191_fix_subagent_delegation_hang/plans/implementation-001.md",
      "fix_task_ref": 191,
      "recurrence_count": 1,
      "first_seen": "2025-12-20T10:00:00Z",
      "last_seen": "2025-12-20T10:00:00Z"
    }
  ]
}
```

### Plan Files

**Location**: `specs/{task_number}_{topic_slug}/plans/implementation-{version:03d}.md`

**Purpose**: Phased implementation plans with status tracking

**Phase Status Markers**:
- `[NOT STARTED]`: Phase not yet started
- `[IN PROGRESS]`: Phase actively being worked on
- `[COMPLETED]`: Phase fully completed

**Resume Logic**: /implement command checks plan file for first incomplete phase and resumes from there.

---

## Git Workflow

### Automatic Commits

Git commits are created automatically after:
- Task completion (full task)
- Phase completion (if using plan)
- Research completion
- Plan creation
- Error fix plan creation
- Review completion

### Scoped Commits

Only specified files are committed:
- Implementation files (code, documentation)
- Tracking files (TODO.md, state.json, plan file)
- Exclude unrelated changes

### Commit Message Format

**Per-phase commits**:
```
task {number} phase {N}: {phase_description}
```

Example: `task 191 phase 1: add return handling to commands`

**Full task commits**:
```
task {number}: {task_description}
```

Example: `task 191: fix subagent delegation hang`

**Other commits**:
```
{type}: {description}
```

Examples:
- `errors: create fix plan for 5 delegation_hang errors (task 192)`
- `review: update registries and create tasks`
- `todo: clean 10 completed tasks`

### Non-Blocking Failures

Git commit failures are logged to errors.json but do NOT fail the task. This ensures task progress is not lost due to git issues.

---

## Language Routing

### Routing Logic

Commands check the `Language` field in TODO.md to determine routing:

```python
def route_to_agent(task_language, operation):
    if task_language == "neovim":
        if operation == "research":
            return "neovim-research-agent"
        elif operation == "implement":
            return "neovim-implementation-agent"
    else:
        if operation == "research":
            return "researcher"
        elif operation == "implement":
            return "implementer"
```

### Neovim-Specific Integration

Neovim tasks use specialized agents:

**neovim-implementation-agent**:
- Modifies Lua configuration files
- Uses nvim --headless for validation
- Follows plugin specification patterns
- Logs errors to errors.json

**neovim-research-agent**:
- Searches plugin documentation
- Analyzes Neovim API usage
- Loads context from .claude/context/project/neovim/

### Future Language Support

The architecture supports adding language-specific agents for:
- Python (python-implementation-agent, python-research-agent)
- JavaScript/TypeScript
- Rust
- etc.

---

## Error Handling and Recovery

### Error Types

- `delegation_hang`: Command hung waiting for subagent
- `tool_failure`: External tool unavailable or failed
- `status_sync_failure`: Failed to update TODO.md/state.json atomically
- `build_error`: Build or validation failed
- `git_commit_failure`: Git commit failed
- `timeout`: Operation exceeded timeout
- `validation_failed`: Input validation failed
- `file_not_found`: Required file missing
- `cycle_detected`: Delegation would create cycle
- `max_depth_exceeded`: Delegation depth limit exceeded

### Error Logging

All errors logged to errors.json with:
- Unique ID
- Timestamp
- Type and severity
- Context (command, task, agent, session)
- Error message
- Fix status
- Recurrence tracking

### Error Analysis

The /errors command:
1. Groups errors by type and root cause
2. Checks historical fix effectiveness
3. Identifies recurring errors (fixes that failed)
4. Recommends specific fixes
5. Creates implementation plan for fixes
6. Creates TODO task linking fix plan
7. Updates errors.json with fix references

### Recovery Patterns

**Delegation Hang**:
- Root cause: Missing ReceiveResults stage
- Fix: Add explicit return handling stages
- Prevention: All commands follow standard delegation pattern

**Timeout**:
- Root cause: Operation too complex for timeout
- Fix: Adjust timeout or break into smaller phases
- Recovery: Resume from partial results

**Status Sync Failure**:
- Root cause: Concurrent file updates or I/O error
- Fix: Add retry logic with exponential backoff
- Recovery: Retry status update

**Git Commit Failure**:
- Root cause: Nothing to commit or merge conflict
- Fix: Check git status before committing
- Recovery: Manual commit if needed (non-blocking)

---

## Testing and Validation

### Component Testing

Test each component individually:
- Commands: Test with mock subagents
- Subagents: Test with mock inputs and validate returns
- Return format: Validate all returns against schema

### Integration Testing

Test full workflows:
- task → research → plan → implement
- Resume interrupted implementation
- Error analysis and fix plan creation
- Git commit creation and scoping

### Delegation Safety Testing

Test safety mechanisms:
- Cycle detection: Force delegation cycle
- Depth limit: Force depth > 3
- Timeout handling: Simulate long-running subagent
- Return validation: Send malformed return

### Language Routing Testing

Test language-specific routing:
- Neovim tasks → neovim agents
- Markdown tasks → general agents
- Mixed-language projects

### Error Recovery Testing

Test error handling:
- Tool unavailable: Remove required tools
- Status sync failures: Concurrent updates
- Git commit failures: Nothing to commit
- Partial completion: Timeout during phase

---

## Performance Considerations

### Lazy Directory Creation

Directories are created only when writing files, not during planning:
- Reduces filesystem operations
- Avoids empty directories
- Cleaner project structure

### Delegation Depth Limit

Maximum depth of 3 prevents:
- Excessive delegation overhead
- Deep call stacks
- Difficult debugging
- Performance degradation

### Timeout Tuning

Timeouts are tuned per operation type:
- Short timeouts for simple operations (5 minutes)
- Medium timeouts for research/planning (30-60 minutes)
- Long timeouts for implementation (2 hours)

Prevents indefinite waits while allowing complex operations to complete.

### Atomic Status Updates

Two-phase commit ensures:
- Consistency across files
- No partial updates
- Rollback on failure
- Minimal file I/O

---

## Future Enhancements

### Planned Features

1. **Parallel Phase Execution**: Execute independent phases in parallel
2. **Dependency Analysis**: Automatic dependency detection between tasks
3. **Progress Tracking**: Real-time progress updates during long operations
4. **Batch Task Execution**: Execute multiple tasks in sequence or parallel
5. **Advanced Error Analysis**: Machine learning for error pattern detection
6. **Tool Integration**: Additional tool integrations for development workflows
7. **Language Support**: Python, JavaScript, Rust-specific agents
8. **Performance Profiling**: Track and optimize slow operations

### Extensibility

The architecture supports extension through:
- New commands (add to .claude/command/)
- New subagents (add to .claude/agents/)
- New specialists (add to .claude/agents/specialists/)
- New language routing (update orchestrator routing logic)
- New error types (add to errors.json schema)

---

## Meta System Builder

### Overview

The `/meta` command provides an interactive system builder that creates complete .claude architectures tailored to specific domains. It guides users through an interview process to gather requirements and automatically generates production-ready agent systems.

### Architecture Generation Process

The meta system builder follows an 8-stage workflow:

**Stage 0: DetectExistingProject**
- Scans for existing .claude structure
- Identifies existing agents, commands, context files, and workflows
- Offers merge options (extend, separate, replace, or cancel)
- Ensures new systems integrate smoothly with existing work

**Stage 1: InitiateInterview**
- Greets user and explains the process
- Sets expectations for output
- Prepares for requirements gathering

**Stage 2: GatherDomainInfo**
- Collects domain name and industry
- Identifies primary purpose
- Determines user personas and expertise levels

**Stage 2.5: DetectDomainType**
- Classifies domain as development, business, hybrid, or other
- Identifies existing agents that match the domain type
- Adapts subsequent questions based on classification

**Stage 3: IdentifyUseCases**
- Gathers 3-5 specific use cases
- Assesses complexity for each (simple, moderate, complex)
- Maps dependencies and sequences between use cases

**Stage 4: AssessComplexity**
- Determines number of specialized agents needed
- Identifies knowledge types (domain, process, standards, templates)
- Defines state management requirements

**Stage 5: IdentifyIntegrations**
- Lists external tools and platforms to integrate
- Determines file operation requirements
- Designs custom slash commands

**Stage 6: ReviewAndConfirm**
- Presents comprehensive architecture summary
- Lists all components to be created
- Gets user confirmation before generation

**Stage 7: GenerateSystem**
- Routes to system-builder subagents to create complete structure
- Generates agents, context files, workflows, and commands
- Validates generated structure

**Stage 8: DeliverSystem**
- Presents completed system with documentation
- Provides quick start guide and testing checklist
- Offers tips for success

### System Builder Subagents

**domain-analyzer**
- Analyzes user domain descriptions to extract core concepts
- Recommends specialized agents based on use cases
- Designs context file structure (domain/processes/standards/templates)
- Creates knowledge graphs showing concept relationships
- Provides recommendations and identifies challenges

**agent-generator**
- Generates XML-optimized agent files following research-backed patterns
- Creates orchestrator with routing intelligence and context management
- Generates specialized subagents with clear inputs/outputs
- Scores agents against quality criteria (8+/10 required)
- Ensures consistent patterns across all agents

**context-organizer**
- Creates modular context files (50-200 lines each)
- Organizes into domain, processes, standards, and templates
- Documents dependencies between files
- Includes concrete examples in every file
- Generates context README for navigation

**workflow-designer**
- Designs complete workflow definitions with stages
- Maps context dependencies for each stage
- Defines success criteria and metrics
- Creates workflow selection logic
- Documents when to use each workflow

**command-creator**
- Creates custom slash commands with intuitive syntax
- Defines parameter handling and validation
- Generates 3-5 concrete examples per command
- Documents routing to appropriate agents
- Creates command usage guide

### Research-Backed Patterns

The system builder applies Stanford/Anthropic research patterns:

**Optimal Component Ordering** (12-17% performance improvement):
1. Context (hierarchical: system→domain→task→execution)
2. Role (clear identity and expertise)
3. Task (specific objective)
4. Instructions/Workflow (detailed procedures)
5. Examples (when needed)
6. Constraints (boundaries)
7. Validation (quality checks)

**Component Ratios**:
- Role: 5-10% of total prompt
- Context: 15-25% hierarchical information
- Instructions: 40-50% detailed procedures
- Examples: 20-30% when needed
- Constraints: 5-10% boundaries

**Routing Patterns**:
- Use @ symbol for all subagent references
- Always specify context level (Level 1/2/3)
- Define expected returns for every delegation
- Include validation gates with numeric thresholds

### Use Cases

**Extend Existing System**:
Add new capabilities to the existing system for a different domain while preserving existing work.

**Create Separate System**:
Build a completely separate .claude system for a different project or domain.

**Build New System**:
Create a fresh .claude architecture from scratch for a new project.

### Integration with Neovim Configuration

The meta system builder is fully integrated into the .claude system:
- Respects existing delegation safety patterns
- Follows standardized return format
- Uses atomic state synchronization
- Supports language-based routing
- Integrates with error tracking
- Creates automatic git commits

---

## Forked Subagent Pattern

### Overview

Version 2.1 introduces a "forked subagent" pattern for workflow skills. This pattern improves token efficiency by loading domain-specific context only in isolated subagent conversations rather than the parent context.

### Pattern Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Parent Context                           │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Skill (Thin Wrapper)                                │   │
│  │  - Frontmatter: context: fork, agent: {name}        │   │
│  │  - Body: Input validation + delegation only          │   │
│  │  - Context budget: ~100 lines                        │   │
│  └──────────────────────────────────────────────────────┘   │
│                            │                                 │
│                            ▼ Task tool invocation            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Forked Context (Isolated)                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Subagent (Full Execution)                           │   │
│  │  - Loads domain context via @-references             │   │
│  │  - Executes workflow logic                           │   │
│  │  - Uses specialized tools (MCP, Bash, etc.)          │   │
│  │  - Returns standardized JSON                         │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Skill Frontmatter Format

```yaml
---
name: skill-{name}
description: {description}
allowed-tools: Task           # Only Task needed for delegation
context: fork                 # Signal: don't load context eagerly
agent: {subagent-name}        # Target subagent to spawn
# Original context (now loaded by subagent):
#   - .claude/context/{path1}
#   - .claude/context/{path2}
# Original tools (now used by subagent):
#   - {Tool1}, {Tool2}, ...
---
```

### Skill-to-Agent Mapping

| Skill | Agent | Domain |
|-------|-------|--------|
| skill-neovim-research | neovim-research-agent | Neovim/plugin research |
| skill-researcher | general-research-agent | General web/codebase research |
| skill-planner | planner-agent | Implementation planning |
| skill-implementer | general-implementation-agent | General implementation |
| skill-neovim-implementation | neovim-implementation-agent | Neovim configuration implementation |
| skill-meta | meta-builder-agent | System building and task creation |

**Note**: Additional skills (latex, typst, document-converter) available via extensions in `.claude/extensions/`.

### Thin Wrapper Execution Flow

All forked skills follow this 5-step pattern:

1. **Input Validation**
   - Verify task exists in state.json
   - Check status allows operation
   - Extract optional parameters (focus_prompt, etc.)

2. **Context Preparation**
   - Generate session_id: `sess_{timestamp}_{random}`
   - Build delegation context with task details
   - Prepare timeout (3600s research, 7200s implementation)

3. **Invoke Subagent**
   - Call Task tool with target agent
   - Pass delegation context and task parameters
   - Subagent loads its own context and executes

4. **Return Validation**
   - Verify return matches `subagent-return.md` schema
   - Check status, summary, artifacts, metadata fields
   - Validate session_id matches expected

5. **Return Propagation**
   - Pass validated result to caller without modification
   - Errors are passed through verbatim

### Token Efficiency

Before (eager loading):
```
Parent context: ~2000 tokens (skill body + context files)
└── All context loaded even if not all needed
```

After (forked subagent):
```
Parent context: ~100 tokens (thin wrapper only)
Subagent context: ~2000 tokens (loaded only in fork)
└── Context isolated, doesn't bloat parent
```

### Benefits

1. **Token Efficiency**: Context loaded only in subagent
2. **Isolation**: Subagent context doesn't accumulate in parent
3. **Reusability**: Same subagent callable from multiple entry points
4. **Maintainability**: Clear separation (skill = routing, agent = execution)
5. **Testability**: Subagents testable independently

### Related Files

- `.claude/context/core/templates/thin-wrapper-skill.md` - Template reference
- `.claude/context/core/formats/subagent-return.md` - Return format standard
- `.claude/context/core/orchestration/orchestration-core.md` - Delegation patterns
- `.claude/CLAUDE.md` - Skill architecture section

---

## Session Maintenance

Claude Code resources can accumulate over time. The `/refresh` command helps manage these resources.

### Commands

| Command | Description |
|---------|-------------|
| `/refresh` | Interactive: cleanup processes, then select age threshold for directories |
| `/refresh --dry-run` | Preview both cleanups without making changes |
| `/refresh --force` | Execute both cleanups immediately (8-hour default) |

### Age Threshold Options

When running `/refresh` interactively, you'll be prompted to select an age threshold:
- **8 hours (default)** - Remove files older than 8 hours
- **2 days** - Remove files older than 2 days (conservative)
- **Clean slate** - Remove everything except safety margin (1 hour)

### Cleanable Directories

The following directories in `~/.claude/` are cleaned based on age:
- `projects/` - Session .jsonl files and subdirectories
- `debug/` - Debug output files
- `file-history/` - File version snapshots
- `todos/` - Todo list backups
- `session-env/` - Environment snapshots
- `telemetry/` - Usage telemetry data
- `shell-snapshots/` - Shell state
- `plugins/cache/` - Old plugin versions
- `cache/` - General cache

### Safety

**Process cleanup**:
- Only targets orphaned processes (no controlling terminal)
- Active sessions are never affected

**Directory cleanup**:
- Never deletes: `sessions-index.json`, `settings.json`, `.credentials.json`, `history.jsonl`
- Never deletes files modified within the last hour (safety margin)
- Age threshold selectable interactively or defaults to 8 hours with `--force`

### Shell Aliases (Optional)

Install convenience aliases:
```bash
.claude/scripts/install-aliases.sh
```

This adds: `claude-refresh`, `claude-refresh-force`

---

## MCP Server Configuration

### Known Issue

Custom subagents (spawned via Task tool) cannot access project-scoped MCP servers defined in `.mcp.json`. This is a Claude Code platform limitation tracked in GitHub issues #13898, #14496, and #13605.

### Workaround

For MCP servers that need to be accessible to subagents, configure them in user scope (`~/.claude.json`) instead of project scope.

After any MCP configuration changes, restart Claude Code for changes to take effect.

**Note**: The project `.mcp.json` file is kept for documentation purposes and works correctly for the main conversation - only subagents have the access limitation.

---

## Related Documentation

- Quick Start Guide: `.claude/QUICK-START.md`
- Testing Guide: `.claude/TESTING.md`
- Agent Context: `.claude/CLAUDE.md`
- Documentation Hub: `.claude/docs/README.md`
- Orchestration Core: `.claude/context/core/orchestration/orchestration-core.md`
- Return Format Standard: `.claude/context/core/formats/subagent-return.md`
- Task 191 Research: `specs/191_fix_subagent_delegation_hang/reports/research-001.md`
- Task 191 Plan: `specs/191_fix_subagent_delegation_hang/plans/implementation-001.md`
