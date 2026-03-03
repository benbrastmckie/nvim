# Agent Templates for System Generation

**Purpose**: Standard templates for different agent types

**Version**: 1.0  
**Last Updated**: 2025-12-29

---

## Orchestrator Template

**Purpose**: Route requests and delegate to subagents

### Frontmatter

```yaml
---
name: "domain-orchestrator"
version: "1.0.0"
description: "Routes requests and delegates to domain-specific subagents"
mode: orchestrator
agent_type: router
temperature: 0.1
max_tokens: 2000
timeout: 3600
tools:
  read: true
permissions:
  allow:
    - read: [".opencode/**/*"]
  deny: []
context_loading:
  strategy: lazy
  index: ".opencode/context/index.md"
  required:
    - "core/standards/delegation.md"
    - "core/standards/delegation.md"
  optional:
    - "domain/routing-rules.md"
  max_context_size: 30000
delegation:
  max_depth: 3
  can_delegate_to: ["subagent-1", "subagent-2", "subagent-3"]
  timeout_default: 1800
  timeout_max: 3600
lifecycle:
  stage: 8
  return_format: "subagent-return-format.md"
---
```

### Structure

```xml
<context>
  <specialist_domain>Request routing and delegation</specialist_domain>
  <task_scope>Analyze requests and route to appropriate subagents</task_scope>
</context>

<role>Orchestrator specializing in request analysis and delegation</role>

<task>Route requests to appropriate subagents based on request type and context</task>

<workflow_execution>
  <stage id="1" name="InputValidation">...</stage>
  <stage id="2" name="ContextLoading">...</stage>
  <stage id="3" name="RequestAnalysis">...</stage>
  <stage id="4" name="SubagentSelection">...</stage>
  <stage id="5" name="Delegation">...</stage>
  <stage id="6" name="ResultProcessing">...</stage>
  <stage id="7" name="Postflight">...</stage>
  <stage id="8" name="Cleanup">...</stage>
</workflow_execution>
```

---

## Research Template

**Purpose**: Investigate topics and create research reports

### Frontmatter

```yaml
---
name: "domain-researcher"
version: "1.0.0"
description: "Conducts research and creates comprehensive reports"
mode: subagent
agent_type: research
temperature: 0.3
max_tokens: 4000
timeout: 3600
tools:
  read: true
  webfetch: true
permissions:
  allow:
    - read: ["**/*"]
    - write: ["specs/**/*"]
  deny: []
context_loading:
  strategy: lazy
  index: ".opencode/context/index.md"
  required:
    - "core/standards/delegation.md"
    - "core/workflows/research-workflow.md"
  max_context_size: 50000
delegation:
  max_depth: 3
  can_delegate_to: []
  timeout_default: 3600
  timeout_max: 3600
lifecycle:
  stage: 8
  return_format: "subagent-return-format.md"
---
```

### Structure

```xml
<context>
  <specialist_domain>Research and investigation</specialist_domain>
  <task_scope>Investigate topics and create comprehensive reports</task_scope>
</context>

<role>Research Specialist expert in investigation and documentation</role>

<task>Conduct research and create detailed reports with findings and recommendations</task>

<workflow_execution>
  <stage id="1" name="InputValidation">...</stage>
  <stage id="2" name="ContextLoading">...</stage>
  <stage id="3" name="Investigation">...</stage>
  <stage id="4" name="Analysis">...</stage>
  <stage id="5" name="ReportGeneration">...</stage>
  <stage id="6" name="ReturnFormatting">...</stage>
  <stage id="7" name="Postflight">...</stage>
  <stage id="8" name="Cleanup">...</stage>
</workflow_execution>
```

---

## Validation Template

**Purpose**: Check and verify artifacts for quality and correctness

### Frontmatter

```yaml
---
name: "domain-validator"
version: "1.0.0"
description: "Validates artifacts for quality and correctness"
mode: subagent
agent_type: validation
temperature: 0.1
max_tokens: 2000
timeout: 1200
tools:
  read: true
permissions:
  allow:
    - read: ["**/*"]
  deny: []
context_loading:
  strategy: lazy
  index: ".opencode/context/index.md"
  required:
    - "core/standards/validation-criteria.md"
  max_context_size: 30000
delegation:
  max_depth: 3
  can_delegate_to: []
  timeout_default: 1200
  timeout_max: 1200
lifecycle:
  stage: 8
  return_format: "subagent-return-format.md"
---
```

---

## Processing Template

**Purpose**: Transform and analyze data or artifacts

### Frontmatter

```yaml
---
name: "domain-processor"
version: "1.0.0"
description: "Processes and transforms data or artifacts"
mode: subagent
agent_type: processing
temperature: 0.2
max_tokens: 3000
timeout: 1800
tools:
  read: true
  write: true
permissions:
  allow:
    - read: ["**/*"]
    - write: ["specs/**/*"]
  deny: []
context_loading:
  strategy: lazy
  index: ".opencode/context/index.md"
  required:
    - "core/standards/delegation.md"
  max_context_size: 40000
delegation:
  max_depth: 3
  can_delegate_to: []
  timeout_default: 1800
  timeout_max: 1800
lifecycle:
  stage: 8
  return_format: "subagent-return-format.md"
---
```

---

## Generation Template

**Purpose**: Create new artifacts (code, documentation, etc.)

### Frontmatter

```yaml
---
name: "domain-generator"
version: "1.0.0"
description: "Generates new artifacts based on specifications"
mode: subagent
agent_type: generation
temperature: 0.4
max_tokens: 4000
timeout: 2400
tools:
  read: true
  write: true
permissions:
  allow:
    - read: ["**/*"]
    - write: [".opencode/**/*"]
  deny: []
context_loading:
  strategy: lazy
  index: ".opencode/context/index.md"
  required:
    - "core/standards/delegation.md"
    - "domain/generation-templates.md"
  max_context_size: 50000
delegation:
  max_depth: 3
  can_delegate_to: []
  timeout_default: 2400
  timeout_max: 2400
lifecycle:
  stage: 8
  return_format: "subagent-return-format.md"
---
```

---

## Common Workflow Stages

All templates follow the 8-stage workflow pattern:

### Stage 1: Input Validation
- Verify all required parameters provided
- Validate parameter types and formats
- Check prerequisites
- Return error if validation fails

### Stage 2: Context Loading
- Load context index
- Load required context files
- Load optional context on-demand
- Validate context within size limits

### Stage 3: Core Execution
- Execute primary task logic
- Process inputs
- Generate intermediate results
- Handle errors gracefully

### Stage 4: Output Generation
- Format results
- Generate artifacts
- Prepare return data
- Validate outputs

### Stage 5: Artifact Creation
- Write files to disk
- Create directory structure
- Validate file writes
- Track artifact paths

### Stage 6: Return Formatting
- Format response per subagent-return-format.md
- Include status, summary, artifacts, metadata
- Ensure summary <100 tokens
- Validate return structure

### Stage 7: Postflight (Critical)
- Validate all artifacts created
- Update specs/TODO.md and specs/state.json (via status-sync-manager)
- Create git commit (via git-workflow-manager)
- Log errors to errors.json

### Stage 8: Cleanup
- Clean up temporary files
- Release resources
- Log completion
- Return final result

---

## Related Templates

- **Interview Patterns**: `.opencode/context/core/workflows/interview-patterns.md`
- **Architecture Principles**: `.opencode/context/core/standards/architecture-principles.md`
- **Domain Patterns**: `.opencode/context/core/standards/domain-patterns.md`

---

**Maintained By**: Logos/Theory Development Team
