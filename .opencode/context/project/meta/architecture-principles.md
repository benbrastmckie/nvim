# Architecture Principles for Meta-Generated Systems

**Purpose**: Core principles for designing .opencode system architectures

**Version**: 1.0  
**Last Updated**: 2025-12-29

---

## Modular Design Principle

Build systems from small, focused files that do one thing well.

### File Size Guidelines

- **Commands**: 50-300 lines (target: 200 lines)
- **Agents**: 200-600 lines (target: 400 lines)
- **Context Files**: 50-200 lines (target: 150 lines)
- **Workflows**: 100-300 lines (target: 200 lines)

### Benefits

- Easier to understand and maintain
- Faster to load and parse
- Simpler to test and validate
- Clearer separation of concerns

### Anti-Pattern

Avoid monolithic files that try to do everything:
- [FAIL] Single 2000-line agent file
- [PASS] Orchestrator (300 lines) + 5 subagents (400 lines each)

---

## Hierarchical Organization Principle

Structure systems with clear hierarchy: orchestrator → subagents → workers.

### Organization Pattern

```
orchestrator (routing, delegation)
├── subagent-1 (specialized task)
│   ├── worker-1a (sub-task)
│   └── worker-1b (sub-task)
├── subagent-2 (specialized task)
└── subagent-3 (specialized task)
```

### Delegation Rules

1. **Orchestrator**: Routes requests, delegates to subagents, no execution
2. **Subagents**: Execute specialized tasks, may delegate to workers
3. **Workers**: Execute atomic operations, no delegation

### Depth Limits

- Maximum delegation depth: 3 levels
- Typical depth: 2 levels (orchestrator → subagent)
- Deep hierarchies (3 levels) only for complex domains

---

## Context Efficiency Principle

Optimize context loading to minimize token usage during routing.

### Context Allocation Strategy

- **Level 1 (Isolation)**: 0-5% context (routing only)
- **Level 2 (Filtered)**: 5-20% context (standard execution)
- **Level 3 (Full)**: 20-50% context (complex tasks)

### Loading Strategy

**Routing Stage** (minimize context):
- Load context index only
- Extract routing metadata
- Determine target agent
- Context usage: <10%

**Execution Stage** (load as needed):
- Load required context files
- Load optional context on-demand
- Cache frequently used context
- Context usage: varies by task

### Context Organization

```
.opencode/context/
├── index.md              # Entry point (always loaded)
├── core/                 # General standards (load on-demand)
│   ├── standards/
│   └── workflows/
└── project/              # Domain-specific (load on-demand)
    ├── domain-1/
    └── domain-2/
```

---

## Workflow-Driven Design Principle

Design workflows first, then create agents to execute them.

### Design Sequence

1. **Identify Workflows**: What processes need to happen?
2. **Break Into Stages**: What are the discrete steps?
3. **Assign Responsibilities**: Which agent handles each stage?
4. **Design Agents**: Create agents to fulfill responsibilities

### 8-Stage Workflow Pattern

All agents follow standardized 8-stage workflow:

1. **Input Validation**: Validate parameters and prerequisites
2. **Context Loading**: Load required context on-demand
3. **Core Execution**: Execute primary task logic
4. **Output Generation**: Generate results and artifacts
5. **Artifact Creation**: Write files to disk
6. **Return Formatting**: Format response per standard
7. **Postflight**: Validate artifacts, update status, create git commit
8. **Cleanup**: Perform cleanup operations

### Stage 7 Critical

Stage 7 (Postflight) is critical for system consistency:
- Validate all artifacts created successfully
- Update specs/TODO.md and specs/state.json atomically (via status-sync-manager)
- Create scoped git commit (via git-workflow-manager)
- Log any errors to errors.json

---

## Research-Backed XML Patterns

Use XML structure patterns validated by Stanford/Anthropic research.

### Optimal Component Sequence

```xml
<context>
  <system_context>...</system_context>
  <domain_context>...</domain_context>
  <task_context>...</task_context>
</context>

<role>Clear identity and expertise</role>

<task>Specific objective</task>

<workflow_execution>
  <stage id="1" name="...">...</stage>
  <stage id="2" name="...">...</stage>
  ...
</workflow_execution>

<constraints>
  <must>...</must>
  <must_not>...</must_not>
</constraints>

<validation_checks>
  <pre_execution>...</pre_execution>
  <post_execution>...</post_execution>
</validation_checks>
```

### Component Ratios

- **Role**: 5-10% of total prompt
- **Context**: 15-25% hierarchical information
- **Instructions**: 40-50% detailed procedures
- **Examples**: 20-30% when needed
- **Constraints**: 5-10% boundaries

---

## Frontmatter Delegation Principle

Commands are thin delegation layers; agents own workflow execution.

### Command Structure

```yaml
---
name: command-name
agent: orchestrator
description: "Brief description"
context_level: 2
routing:
  default: target-agent
timeout: 3600
context_loading:
  strategy: lazy
  index: ".opencode/context/index.md"
  required: [...]
  optional: [...]
---

# Command Documentation
[High-level workflow description]
[Delegates to agent for execution]
```

### Agent Structure

```yaml
---
name: agent-name
version: "1.0.0"
description: "Agent description"
mode: subagent
agent_type: processor
[... other frontmatter ...]
---

# Agent Implementation
[Complete 8-stage workflow]
[All execution logic]
```

### Separation of Concerns

- **Command**: User interface, documentation, routing metadata
- **Agent**: Workflow execution, validation, artifact creation

---

## Validation and Quality Principle

Build validation into every stage of the workflow.

### Pre-Execution Validation

- Verify all required parameters provided
- Validate parameter types and formats
- Check prerequisites (files exist, dependencies met)
- Validate delegation depth (must be < 3)
- Return error if validation fails

### Post-Execution Validation

- Verify all artifacts created successfully
- Verify artifacts are non-empty
- Verify artifacts contain required sections
- Verify artifacts within size limits
- Verify return format matches standard
- Verify status updates completed
- Verify git commit created

### Quality Thresholds

- Quality score: 8+/10 to pass
- File size: Within guidelines
- Context usage: <10% during routing
- Stage 7 execution: 100% (critical)

---

## Related Principles

- **Interview Patterns**: `.opencode/context/core/workflows/interview-patterns.md`
- **Domain Patterns**: `.opencode/context/core/standards/domain-patterns.md`
- **Agent Templates**: `.opencode/context/core/templates/agent-templates.md`

---

**Maintained By**: Logos/Theory Development Team
