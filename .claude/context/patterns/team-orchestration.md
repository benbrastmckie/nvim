# Team Orchestration Patterns

Wave-based coordination patterns for multi-agent team execution.

## Overview

Team orchestration uses a wave-based model where agents work in parallel within waves, and waves execute sequentially when dependencies exist.

## Wave Execution Model

```
Wave 1:
+----------------+  +----------------+  +----------------+  +----------------+
| Teammate A     |  | Teammate B     |  | Teammate C     |  | Teammate D     |
| Primary Angle  |  | Alternatives   |  | Critic         |  | Horizons       |
+-------+--------+  +-------+--------+  +-------+--------+  +-------+--------+
        |                   |                   |                   |
        +-------------------+-------------------+-------------------+
                           |
                    +------+------+
                    |   Lead      |
                    | Synthesis   |
                    +------+------+
                           |
              (Optional Wave 2 if gaps exist)
```

## Coordination Responsibilities

### Lead Agent (Orchestrator)

The lead agent (skill) is responsible for:

1. **Wave Planning**
   - Analyze dependencies to identify parallelization opportunities
   - Group independent work into waves
   - Calculate team size per wave (max 4 concurrent)

2. **Teammate Spawning**
   - Create prompts with specific angles/roles
   - Enforce model selection via TeammateTool parameter
   - Pass run-scoped output paths

3. **Synthesis**
   - Collect teammate results after wave completion
   - Detect and resolve conflicts
   - Identify coverage gaps
   - Generate unified output

4. **Postflight**
   - Update task status
   - Link artifacts
   - Commit changes
   - Cleanup temporary files

### Teammates

Each teammate is responsible for:

1. **Focused Execution**
   - Execute assigned angle/phase only
   - Avoid duplicating other teammates' work
   - Write output to specified path

2. **Status Reporting**
   - Write results to assigned output file
   - Include confidence level
   - Note any blockers or issues

## Dependency Analysis

### Explicit Dependencies

Dependencies declared in plan metadata:

```markdown
### Phase 3: Configure Integration [NOT STARTED]

**Dependencies**: Phase 1, Phase 2
```

### Implicit Dependencies

Dependencies inferred from file modifications:

- Phases modifying the same files are dependent
- Cross-phase imports create dependencies
- Shared state modifications create dependencies

### Parallelization Decision

```
parallelizable(phase) =
  all dependencies completed AND
  no file conflict with concurrent phases
```

## Error Handling

### Teammate Failure

When a teammate fails or times out:

1. Continue with available results
2. Note gap in synthesis
3. Consider if gap is critical
4. Optionally trigger Wave 2

### Synthesis Failure

If lead cannot synthesize:

1. Preserve raw teammate outputs
2. Mark as partial
3. Return with available findings

### Team Creation Failure

If TeammateTool fails (feature unavailable):

1. Log warning
2. Fall back to single-agent execution
3. Mark `degraded_to_single: true`

## Performance Considerations

### Token Usage

Team mode uses approximately 5x tokens compared to single-agent:
- Each teammate has full context
- Synthesis adds overhead
- Use team mode only when parallelization benefit justifies cost

### Timeout Configuration

- Wave timeout: 30 minutes (1800 seconds)
- Poll interval: 30 seconds
- Total operation timeout: Inherited from skill

## Best Practices

1. **Minimize team size** - Default to 2 teammates, increase only when needed
2. **Clear role separation** - Avoid overlap between teammate responsibilities
3. **Run-scoped outputs** - Use unique paths to avoid conflicts
4. **Graceful degradation** - Always have single-agent fallback
5. **Targeted commits** - Use git staging scope to avoid race conditions
