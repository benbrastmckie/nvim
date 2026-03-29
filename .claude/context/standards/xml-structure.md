# XML Pattern Guide for Agent Prompts

**Created**: 2025-12-29  
**Purpose**: Define optimal XML structure patterns for agent prompts based on research-backed best practices

---

## Overview

XML-structured prompts improve LLM performance through:
- **+25% consistency** in outputs (Stanford research)
- **+20% routing accuracy** for hierarchical agents
- **Better parsing** by LLMs (clear semantic boundaries)
- **Improved maintainability** (structured, predictable format)

This guide defines the standard XML patterns for agents in this system.

---

## Core Principles

### 1. Hierarchical Structure
Use nested XML tags to create clear information hierarchy:
```xml
<context>
  <system_context>...</system_context>
  <domain_context>...</domain_context>
  <task_context>...</task_context>
  <execution_context>...</execution_context>
</context>
```

### 2. Semantic Tags
Tag names should clearly indicate content purpose:
- `<context>` - Background information
- `<role>` - Agent's role/identity
- `<task>` - What the agent should do
- `<workflow_execution>` - Step-by-step process
- `<routing_intelligence>` - Routing logic
- `<quality_standards>` - Quality requirements
- `<validation>` - Validation criteria
- `<error_handling>` - Error handling logic

### 3. Optimal Component Ordering
Research shows this order maximizes performance:
1. **Context** - Set the stage
2. **Role** - Define identity
3. **Task** - State objective
4. **Workflow/Instructions** - Provide process
5. **Supporting sections** - Add details

---

## Standard Patterns

### Pattern 1: Command Files (Routing Layer)

**Purpose**: Route user requests to appropriate subagents  
**Complexity**: Low-Medium  
**Target Size**: <200 lines

```markdown
---
name: {command_name}
agent: {target_agent}
description: "{brief description}"
context_level: {1|2|3}
language: {varies|markdown|lean|etc}
routing:  # Optional
  lean: {lean_agent}
  default: {default_agent}
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "formats/subagent-return.md"
    - "{command_specific_context}"
  max_context_size: 50000
---

**Task Input**: $ARGUMENTS ({description})

<context>
  <system_context>
    {What this command does in the system - 1-2 sentences}
  </system_context>
  <domain_context>
    {Domain-specific context - 1-2 sentences}
  </domain_context>
  <task_context>
    {Specific task this command handles - 1-2 sentences}
  </task_context>
  <execution_context>
    {How this command executes - delegation, direct, etc - 1-2 sentences}
  </execution_context>
</context>

<role>{Brief role description - 1 sentence}</role>

<task>
  {Detailed task description - 2-4 sentences}
</task>

<workflow_execution>
  <stage id="1" name="Preflight">
    <action>{What happens in preflight}</action>
    <process>
      1. {Step 1}
      2. {Step 2}
      3. {Step 3}
    </process>
    <checkpoint>{Completion criteria}</checkpoint>
  </stage>
  
  <stage id="2" name="Delegate">
    <action>{Delegation action}</action>
    <process>
      1. {Prepare delegation context}
      2. {Invoke subagent}
      3. {Wait for return}
    </process>
    <checkpoint>{Delegation complete}</checkpoint>
  </stage>
  
  <stage id="3" name="ValidateReturn">
    <action>{Validation action}</action>
    <process>
      1. {Validate return format}
      2. {Check artifacts}
      3. {Verify success criteria}
    </process>
    <checkpoint>{Return validated}</checkpoint>
  </stage>
  
  <stage id="4" name="ReturnSuccess">
    <action>Return result to user</action>
    <return_format>
      {Expected return format}
    </return_format>
    <checkpoint>Result returned</checkpoint>
  </stage>
</workflow_execution>

<routing_intelligence>
  <context_allocation>
    {Context loading strategy}
  </context_allocation>
  
  <language_routing>  # If applicable
    {Language-based routing rules}
  </language_routing>
</routing_intelligence>

<quality_standards>
  {Quality requirements - bullet points}
</quality_standards>

<usage_examples>
  - `/{command} {example1}`
  - `/{command} {example2}`
</usage_examples>

<validation>
  <pre_flight>
    {Pre-flight validation checks}
  </pre_flight>
  <mid_flight>
    {Mid-flight validation checks}
  </mid_flight>
  <post_flight>
    {Post-flight validation checks}
  </post_flight>
</validation>

<error_handling>
  <error_type_1>
    {How to handle error type 1}
  </error_type_1>
  <error_type_2>
    {How to handle error type 2}
  </error_type_2>
</error_handling>
```

### Pattern 2: Subagent Files (Execution Layer)

**Purpose**: Execute complex workflows with full business logic  
**Complexity**: Medium-High  
**Target Size**: 200-400 lines

```markdown
---
name: "{subagent_name}"
version: "1.0.0"
description: "{detailed description}"
mode: subagent
agent_type: {planning|implementation|research|review}
temperature: 0.2
max_tokens: 4000
timeout: {seconds}
tools:
  read: true
  write: true
  bash: true
  grep: true
  glob: true
permissions:
  allow:
    - read: ["{patterns}"]
    - write: ["{patterns}"]
    - bash: ["{commands}"]
  deny:
    - bash: ["{dangerous_commands}"]
    - write: ["{protected_paths}"]
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "{required_context_1}"
    - "{required_context_2}"
  optional:
    - "{optional_context_1}"
  max_context_size: 50000
delegation:
  max_depth: 3
  can_delegate_to:
    - "{utility_agent_1}"
    - "{utility_agent_2}"
  timeout_default: {seconds}
  timeout_max: {seconds}
lifecycle:
  stage: 4
  command: "/{command}"
  return_format: "subagent-return-format.md"
---

# {Subagent Name}

<context>
  <specialist_domain>{What this agent specializes in}</specialist_domain>
  <task_scope>{Scope of tasks this agent handles}</task_scope>
  <integration>{How this agent integrates with system}</integration>
  <lifecycle_integration>
    {Lifecycle stage ownership and return format}
  </lifecycle_integration>
</context>

<role>
  {Detailed role description - 1-2 sentences}
</role>

<task>
  {Detailed task description - 3-5 sentences covering full workflow}
</task>

<inputs_required>
  <parameter name="{param_name}" type="{type}">
    {Parameter description}
  </parameter>
  <parameter name="{param_name}" type="{type}" optional="true">
    {Optional parameter description}
  </parameter>
</inputs_required>

<inputs_forbidden>
  <forbidden>{forbidden_input_1}</forbidden>
  <forbidden>{forbidden_input_2}</forbidden>
</inputs_forbidden>

<process_flow>
  <step_1>
    <action>{Action description}</action>
    <process>
      1. {Detailed step 1}
      2. {Detailed step 2}
      3. {Detailed step 3}
    </process>
    <implementation>
      {Code or detailed implementation notes}
    </implementation>
    <checkpoint>{Completion criteria}</checkpoint>
  </step_1>
  
  <step_2>
    {Similar structure}
  </step_2>
  
  {... more steps ...}
</process_flow>

<delegation_patterns>
  <delegate_to name="{utility_agent}">
    <when>{When to delegate}</when>
    <context>{What context to pass}</context>
    <expected_return>{What to expect back}</expected_return>
  </delegate_to>
</delegation_patterns>

<artifact_creation>
  <artifact type="{type}">
    <path>{artifact_path_pattern}</path>
    <content>{What the artifact contains}</content>
    <validation>{How to validate artifact}</validation>
  </artifact>
</artifact_creation>

<return_format>
  <structure>
    {
      "status": "completed|partial|failed|blocked",
      "summary": "{brief_summary} (<100 tokens)",
      "artifacts": [...],
      "metadata": {...},
      "session_id": "{session_id}"
    }
  </structure>
  <validation>
    {Return format validation rules}
  </validation>
</return_format>

<quality_standards>
  {Quality requirements specific to this agent}
</quality_standards>

<error_handling>
  <error_type name="{error_type}">
    <detection>{How to detect this error}</detection>
    <handling>{How to handle this error}</handling>
    <recovery>{Recovery instructions for user}</recovery>
  </error_type>
</error_handling>
```

### Pattern 3: Orchestrator Files

**Purpose**: Route commands to appropriate subagents with safety checks  
**Complexity**: Low  
**Target Size**: 200-300 lines

```markdown
---
name: orchestrator
version: {version}
type: router
description: "{brief description}"
mode: orchestrator
temperature: 0.1
max_tokens: 2000
timeout: 60
context_loading:
  strategy: minimal
  index: ".claude/context/index.json"
  required:
    - "core/standards/command-structure.md"
    - "system/routing-guide.md"
delegation:
  max_depth: 3
  timeout_default: 3600
  cycle_detection: true
---

<context>
  <system_context>
    {System-level context - what orchestrator does}
  </system_context>
  <domain_context>
    {Domain-specific context}
  </domain_context>
  <task_context>
    {Task-level context - routing and delegation}
  </task_context>
  <execution_context>
    {Execution context - minimal, pure routing}
  </execution_context>
</context>

<role>
  {Orchestrator role - 1 sentence}
</role>

<task>
  {Orchestrator task - routing with safety - 2-3 sentences}
</task>

<workflow_execution>
  <stage id="1" name="LoadCommand">
    {Load command file and extract routing metadata}
  </stage>
  
  <stage id="2" name="PrepareContext">
    {Generate delegation context with safety metadata}
  </stage>
  
  <stage id="3" name="CheckSafety">
    {Verify delegation safety constraints}
  </stage>
  
  <stage id="4" name="Delegate">
    {Invoke target subagent}
  </stage>
  
  <stage id="5" name="ValidateReturn">
    {Validate subagent return format}
  </stage>
  
  <stage id="6" name="ReturnToUser">
    {Relay result to user}
  </stage>
</workflow_execution>

<routing_intelligence>
  {Routing logic and patterns}
</routing_intelligence>

<delegation_safety>
  {Safety checks: cycle detection, depth limits, timeouts}
</delegation_safety>

<error_handling>
  {Error handling for routing failures}
</error_handling>
```

---

## XML Tag Reference

### Required Tags (All Files)

#### `<context>`
**Purpose**: Provide background information  
**Structure**: 4 sub-contexts (system, domain, task, execution)  
**Location**: After frontmatter, before role  
**Size**: 4-8 sentences total

#### `<role>`
**Purpose**: Define agent's identity and responsibility  
**Structure**: Single sentence or short paragraph  
**Location**: After context, before task  
**Size**: 1-2 sentences

#### `<task>`
**Purpose**: State what the agent should accomplish  
**Structure**: Detailed description of objective  
**Location**: After role, before workflow  
**Size**: 2-5 sentences

#### `<workflow_execution>` or `<process_flow>`
**Purpose**: Define step-by-step process  
**Structure**: Nested stages/steps with actions, processes, checkpoints  
**Location**: After task  
**Size**: Varies (main content section)

### Optional Tags (Context-Dependent)

#### `<routing_intelligence>`
**Purpose**: Define routing logic and patterns  
**Use**: Commands and orchestrators  
**Structure**: Nested sections for different routing aspects

#### `<delegation_patterns>`
**Purpose**: Define when and how to delegate  
**Use**: Subagents that delegate to utilities  
**Structure**: Nested delegate_to sections

#### `<artifact_creation>`
**Purpose**: Specify artifacts to create  
**Use**: Subagents that create files  
**Structure**: Nested artifact sections

#### `<return_format>`
**Purpose**: Define expected return structure  
**Use**: Subagents  
**Structure**: JSON schema and validation rules

#### `<quality_standards>`
**Purpose**: Define quality requirements  
**Use**: All files  
**Structure**: Bullet points or nested sections

#### `<validation>`
**Purpose**: Define validation criteria  
**Use**: Commands and subagents  
**Structure**: pre_flight, mid_flight, post_flight sections

#### `<error_handling>`
**Purpose**: Define error handling logic  
**Use**: All files  
**Structure**: Nested error_type sections

#### `<usage_examples>`
**Purpose**: Provide usage examples  
**Use**: Commands  
**Structure**: Bullet list of examples

---

## Best Practices

### 1. Keep Context Concise
- Each sub-context: 1-2 sentences
- Total context: 4-8 sentences
- Focus on essential information

### 2. Use Consistent Naming
- Stage names: PascalCase (e.g., `LoadCommand`, `PrepareContext`)
- Tag names: lowercase with underscores (e.g., `system_context`, `error_handling`)
- Attribute names: lowercase with underscores (e.g., `id`, `name`, `optional`)

### 3. Nest Appropriately
- Use nesting to show hierarchy
- Don't nest more than 3 levels deep
- Keep nested content focused

### 4. Add Checkpoints
- Every stage/step should have a checkpoint
- Checkpoints define completion criteria
- Use for validation and debugging

### 5. Be Specific
- Avoid vague descriptions
- Use concrete examples
- Define clear success criteria

### 6. Reference External Docs
- Don't duplicate information
- Reference context files for details
- Keep agent files focused

---

## Anti-Patterns (Avoid These)

### Overly Verbose Context (Avoid)
```xml
<context>
  <system_context>
    This command is part of a comprehensive agent system which provides
    extensive capabilities for task management, research, planning, and
    implementation automation across multiple domains...
  </system_context>
</context>
```

### ✅ Concise Context
```xml
<context>
  <system_context>
    Command for creating implementation plans with phased breakdown and status tracking.
  </system_context>
</context>
```

### ❌ Missing Checkpoints
```xml
<stage id="1" name="Preflight">
  <action>Parse arguments and validate task</action>
  <process>
    1. Parse task number
    2. Validate task exists
    3. Update status
  </process>
</stage>
```

### ✅ With Checkpoints
```xml
<stage id="1" name="Preflight">
  <action>Parse arguments and validate task</action>
  <process>
    1. Parse task number
    2. Validate task exists
    3. Update status
  </process>
  <checkpoint>Task validated and status updated</checkpoint>
</stage>
```

### ❌ Flat Structure
```xml
<workflow>
  Load command
  Prepare context
  Check safety
  Delegate
  Validate return
  Return to user
</workflow>
```

### ✅ Hierarchical Structure
```xml
<workflow_execution>
  <stage id="1" name="LoadCommand">
    <action>Load command file</action>
    <process>...</process>
    <checkpoint>...</checkpoint>
  </stage>
  <stage id="2" name="PrepareContext">
    <action>Prepare delegation context</action>
    <process>...</process>
    <checkpoint>...</checkpoint>
  </stage>
</workflow_execution>
```

---

## Migration Guide

### Converting Markdown to XML

**Before** (Markdown sections):
```markdown
## Purpose

Create implementation plans with phased breakdown.

## Workflow

1. Parse arguments
2. Validate task
3. Delegate to planner
4. Validate return
5. Return success
```

**After** (XML structure):
```markdown
<task>
  Create implementation plans with phased breakdown and status tracking.
</task>

<workflow_execution>
  <stage id="1" name="Preflight">
    <action>Parse arguments and validate task</action>
    <process>
      1. Parse task number from $ARGUMENTS
      2. Validate task exists in TODO.md
      3. Update status to [PLANNING]
    </process>
    <checkpoint>Task validated and status updated</checkpoint>
  </stage>
  
  <stage id="2" name="Delegate">
    <action>Delegate to planner subagent</action>
    <process>
      1. Prepare delegation context
      2. Invoke planner with task context
      3. Wait for return
    </process>
    <checkpoint>Planner invoked</checkpoint>
  </stage>
  
  <stage id="3" name="ValidateReturn">
    <action>Validate planner return</action>
    <process>
      1. Validate against subagent-return-format.md
      2. Check plan artifact created
    </process>
    <checkpoint>Return validated</checkpoint>
  </stage>
  
  <stage id="4" name="ReturnSuccess">
    <action>Return result to user</action>
    <return_format>
      Plan created for task {number}.
      {brief_summary}
      Plan: {plan_path}
    </return_format>
    <checkpoint>Result returned</checkpoint>
  </stage>
</workflow_execution>
```

---

## Validation Checklist

Use this checklist when creating or reviewing XML-structured agents:

- [ ] Frontmatter includes all required fields
- [ ] `<context>` has 4 sub-contexts (system, domain, task, execution)
- [ ] `<role>` is concise (1-2 sentences)
- [ ] `<task>` clearly states objective (2-5 sentences)
- [ ] `<workflow_execution>` or `<process_flow>` has clear stages/steps
- [ ] Each stage has `<action>`, `<process>`, and `<checkpoint>`
- [ ] Supporting sections are present (routing, quality, validation, errors)
- [ ] No duplication of information from context files
- [ ] File size is within target (<200 for commands, 200-400 for subagents)
- [ ] Examples are provided (for commands)
- [ ] Error handling is comprehensive
- [ ] References to external docs are clear

---

## References

- **Research**: Stanford/Anthropic studies on XML-structured prompts
- **Examples**: 
  - Commands: `.claude/command/review.md`, `todo.md`, `errors.md`
  - Subagents: `.claude/agent/subagents/planner.md`, `implementer.md`
  - Orchestrator: `.claude/agent/orchestrator.md` (after Phase 2)
- **Standards**: 
  - Command structure: `.claude/context/standards/command-structure.md`
  - Subagent structure: `.claude/context/standards/subagent-structure.md`
