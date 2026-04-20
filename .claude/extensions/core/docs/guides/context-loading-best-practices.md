# Context Loading Best Practices Guide

**Version**: 1.0  
**Created**: 2026-01-06 (Task 327)  
**Purpose**: Best practices for context loading strategy in .opencode systems

---

## Table of Contents

1. [Introduction](#introduction)
2. [Loading Strategies](#loading-strategies)
3. [File Organization](#file-organization)
4. [Context Configuration](#context-configuration)
5. [Optimization Techniques](#optimization-techniques)
6. [Monitoring and Metrics](#monitoring-and-metrics)
7. [Common Patterns](#common-patterns)
8. [Troubleshooting](#troubleshooting)

---

## 1. Introduction

### Why Context Loading Matters

Context loading directly impacts:
- **Performance**: Large context = slower processing, higher costs
- **Accuracy**: Too little context = missing information, errors
- **Reliability**: Broken references = silent failures
- **Maintainability**: Clear patterns = easier debugging

### Key Principles

1. **Load only what you need** - Minimize context window usage
2. **Load when you need it** - Lazy loading over eager loading
3. **Validate all references** - Broken references fail silently
4. **Document loading patterns** - Make intent explicit
5. **Monitor context usage** - Track and optimize over time

### Context Budget Guidelines

- **Routing Stage** (Orchestrator Stages 1-3): <10% context window
  - Use frontmatter only, no context file loading
  - Make routing decisions based on command metadata
  
- **Execution Stage** (Agent Stage 4+): <90% context window
  - Load only files needed for specific workflow
  - Use conditional loading based on task type
  - Prefer summary files over full documentation

---

## 2. Loading Strategies

### 2.1 Lazy Loading (Recommended)

**When to use**: Default strategy for most agents and commands

**How it works**: Load context files only when needed, on-demand

**Example**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "core/orchestration/delegation.md"
    - "core/orchestration/state-management.md"
  optional:
    - "core/standards/git-safety.md"  # Only if git operations needed
  max_context_size: 30000
```

**Benefits**:
- Minimal context window usage
- Faster initial loading
- Lower token costs

**Drawbacks**:
- May need multiple loads during execution
- Requires careful planning of required vs optional

### 2.2 Eager Loading

**When to use**: When you know all context is needed upfront

**How it works**: Load all context files at initialization

**Example**:
```yaml
context_loading:
  strategy: eager
  index: ".claude/context/index.json"
  required:
    - "core/orchestration/delegation.md"
    - "core/orchestration/state-management.md"
    - "core/standards/git-safety.md"
    - "core/formats/plan-format.md"
  max_context_size: 50000
```

**Benefits**:
- All context available immediately
- No mid-execution loading delays
- Simpler to reason about

**Drawbacks**:
- Higher initial context usage
- May load unnecessary files
- Higher token costs

### 2.3 Conditional Loading

**When to use**: When context needs vary by task type or language

**How it works**: Load different files based on runtime conditions

**Example**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "core/orchestration/delegation.md"
    - "core/orchestration/state-management.md"
  conditional:
    - condition: "language == 'lean'"
      files:
        - "project/lean4/standards/lean4-style-guide.md"
        - "project/lean4/tools/lsp-integration.md"
    - condition: "task_type == 'meta'"
      files:
        - "meta/meta-guide.md"
        - "meta/domain-patterns.md"
  max_context_size: 40000
```

**Benefits**:
- Optimized for specific scenarios
- Avoids loading irrelevant context
- Flexible and adaptive

**Drawbacks**:
- More complex configuration
- Requires runtime condition evaluation
- Harder to debug

### 2.4 Summary-First Loading

**When to use**: When full documentation is large but summary suffices

**How it works**: Load summary file first, full file only if needed

**Example**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "core/orchestration/delegation.md"
  optional:
    - "core/orchestration/orchestrator.md"  # 870 lines - load only if needed
  summaries:
    - "core/orchestration/orchestrator.md": "core/orchestration/orchestrator-summary.md"
  max_context_size: 30000
```

**Benefits**:
- Reduces context usage for large files
- Provides overview without full details
- Can escalate to full file if needed

**Drawbacks**:
- Requires maintaining summary files
- May miss important details in summary
- More files to manage

### 2.5 Section-Based Loading

**When to use**: When only specific sections of a file are needed

**How it works**: Load specific sections using grep or similar tools

**Example**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "core/orchestration/delegation.md"
  sections:
    - file: "specs/TODO.md"
      pattern: "grep -A 50 '^### {task_number}\\.'"
      description: "Load only the specific task entry"
  max_context_size: 30000
```

**Benefits**:
- Minimal context usage for large files
- Precise targeting of needed information
- Efficient for structured files

**Drawbacks**:
- Requires structured file format
- May miss context from other sections
- More complex to implement

---

## 3. File Organization

### 3.1 When to Split Files

**Guideline**: Split files when they exceed 700 lines

**Reasons**:
- Large files are harder to navigate
- Loading large files wastes context window
- Splitting enables more granular loading

**Example Split**:
```
Before:
- orchestration.md (2000 lines)

After:
- orchestration/delegation.md (654 lines)
- orchestration/routing.md (699 lines)
- orchestration/validation.md (466 lines)
```

### 3.2 When to Create Summaries

**Guideline**: Create summaries for files >500 lines that are frequently referenced

**Summary Structure**:
```markdown
# File Summary

**Full File**: core/orchestration/orchestrator.md (870 lines)
**Summary**: 100 lines

## Key Concepts
- Orchestrator pattern
- Stage-based workflow
- Delegation mechanisms

## When to Load Full File
- Creating new orchestrators
- Debugging orchestrator issues
- Understanding delegation patterns

## Quick Reference
- Stage 1: Parse and validate
- Stage 2: Route to agent
- Stage 3: Execute workflow
...
```

### 3.3 When to Use Examples Files

**Guideline**: Create separate examples file when examples exceed 200 lines

**Pattern**:
```
Main file:
- delegation.md (654 lines) - Concepts and patterns

Examples file:
- delegation-examples.md (300 lines) - Detailed examples
```

**Benefits**:
- Main file stays focused on concepts
- Examples can be loaded separately
- Easier to maintain and update

### 3.4 Directory Structure Guidelines

**Recommended Structure**:
```
.claude/context/
├── core/                      # Core system context
│   ├── orchestration/         # Orchestration patterns (8 files)
│   ├── formats/               # File format specs (7 files)
│   ├── standards/             # Coding standards (8 files)
│   ├── workflows/             # Workflow patterns (5 files)
│   └── templates/             # File templates (5 files)
├── project/                   # Project-specific context
│   ├── lean4/                 # Lean 4 language context
│   ├── logic/                 # Logic domain context
│   ├── meta/                  # Meta-programming context
│   └── repo/                  # Repository context
└── index.json                   # Context index
```

**Principles**:
- Group by category (orchestration, formats, standards, etc.)
- Separate core from project-specific
- Use clear, descriptive directory names
- Keep directory depth ≤3 levels

### 3.5 File Size Limits by Type

| File Type | Target Size | Max Size | Action if Exceeded |
|-----------|-------------|----------|-------------------|
| Standards | 300-500 lines | 700 lines | Split into multiple files |
| Formats | 200-400 lines | 600 lines | Create summary file |
| Templates | 200-300 lines | 400 lines | Split examples to separate file |
| Workflows | 300-500 lines | 700 lines | Split into phases |
| Orchestration | 500-700 lines | 900 lines | Create summary or split |

---

## 4. Context Configuration

### 4.1 Frontmatter Syntax

**Basic Structure**:
```yaml
context_loading:
  strategy: lazy                          # lazy | eager | conditional
  index: ".claude/context/index.json"     # Context index file
  required: []                            # Always load these files
  optional: []                            # Load if needed
  conditional: []                         # Load based on conditions
  max_context_size: 30000                 # Max tokens to load
```

### 4.2 Required vs Optional Files

**Required Files**:
- Files that are ALWAYS needed for the workflow
- Missing required files should cause errors
- Examples: delegation.md, state-management.md

**Optional Files**:
- Files that are SOMETIMES needed
- Missing optional files should not cause errors
- Examples: git-safety.md (only if git operations), lean4-style-guide.md (only for Lean tasks)

**Example**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "core/orchestration/delegation.md"      # Always needed
    - "core/orchestration/state-management.md" # Always needed
  optional:
    - "core/standards/git-safety.md"          # Only if git operations
    - "project/lean4/standards/lean4-style-guide.md"  # Only for Lean tasks
  max_context_size: 30000
```

### 4.3 Conditional Loading Rules

**Condition Types**:
1. **Language-based**: Load based on task language
2. **Task-type-based**: Load based on task type (meta, implementation, etc.)
3. **Operation-based**: Load based on operation (git, file, API, etc.)

**Example**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "core/orchestration/delegation.md"
  conditional:
    # Language-based
    - condition: "language == 'lean'"
      files:
        - "project/lean4/standards/lean4-style-guide.md"
        - "project/lean4/tools/lsp-integration.md"
    
    # Task-type-based
    - condition: "task_type == 'meta'"
      files:
        - "meta/meta-guide.md"
        - "meta/domain-patterns.md"
    
    # Operation-based
    - condition: "requires_git == true"
      files:
        - "core/standards/git-safety.md"
  max_context_size: 40000
```

### 4.4 Max Context Size Guidelines

**By Operation Type**:

| Operation Type | Max Context Size | Reasoning |
|----------------|------------------|-----------|
| Research | 50,000 tokens | Needs broad context for exploration |
| Planning | 40,000 tokens | Needs task context + planning patterns |
| Implementation | 30,000 tokens | Focused on specific task |
| Review | 30,000 tokens | Focused on specific artifacts |
| Meta | 40,000 tokens | Needs architecture patterns |
| Utility | 20,000 tokens | Simple operations |

**Calculation**:
```
max_context_size = base_context + language_context + operation_context

Example (Lean implementation):
- base_context: 10,000 (delegation, state-management)
- language_context: 10,000 (lean4-style-guide, lsp-integration)
- operation_context: 10,000 (git-safety, plan-format)
- Total: 30,000 tokens
```

---

## 5. Optimization Techniques

### 5.1 Caching

**Pattern**: Cache frequently loaded context files in memory

**Implementation**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  cache:
    enabled: true
    ttl: 3600  # Cache for 1 hour
    files:
      - "core/orchestration/delegation.md"
      - "core/orchestration/state-management.md"
  required:
    - "core/orchestration/delegation.md"
    - "core/orchestration/state-management.md"
  max_context_size: 30000
```

**Benefits**:
- Faster loading for repeated operations
- Reduced file I/O
- Lower latency

**Drawbacks**:
- Stale cache if files change
- Memory usage
- Cache invalidation complexity

### 5.2 Compression

**Pattern**: Compress large context files to reduce token usage

**Techniques**:
1. Remove comments and whitespace
2. Abbreviate common terms
3. Use references instead of duplication

**Example**:
```markdown
Before (100 lines):
# Delegation Pattern

The delegation pattern allows an orchestrator to delegate work to subagents.
When delegating, the orchestrator must:
- Validate the subagent exists
- Check delegation depth
- Set timeout
- Track session
...

After (50 lines):
# Delegation Pattern

Orchestrator → subagent delegation:
- Validate: subagent exists, depth < max, timeout set
- Track: session ID, delegation path
- Return: standardized format (see subagent-return.md)
...
```

### 5.3 Indexing

**Pattern**: Use index file to enable fast lookup and selective loading

**Index Structure**:
```markdown
# Context Index

## Orchestration
- delegation.md (654 lines) - Delegation patterns and return format
- routing.md (699 lines) - Language extraction and agent mapping
- state-management.md (916 lines) - Status markers and state schemas

## When to Load
- **Research**: delegation.md, state-management.md
- **Planning**: delegation.md, state-management.md, plan-format.md
- **Implementation**: delegation.md, state-management.md, git-safety.md
```

**Benefits**:
- Fast lookup of file locations
- Clear loading recommendations
- Enables lazy loading

### 5.4 Pruning

**Pattern**: Remove unused or deprecated context files

**Process**:
1. Identify files with 0 references (use validation script)
2. Mark as deprecated with 1-month notice
3. Remove after deprecation period
4. Update all references

**Example**:
```bash
# Find files with 0 references
for file in .claude/context/**/*.md; do
  ref_count=$(grep -r "$(basename $file)" .claude/command .claude/agent | wc -l)
  if [ $ref_count -eq 0 ]; then
    echo "UNUSED: $file"
  fi
done
```

---

## 6. Monitoring and Metrics

### 6.1 Telemetry

**Metrics to Track**:
1. **Context size per operation** - How much context is loaded
2. **Loading time** - How long it takes to load context
3. **Cache hit rate** - How often cache is used
4. **Broken reference count** - How many references fail

**Implementation**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  telemetry:
    enabled: true
    log_file: ".claude/logs/context-loading.log"
    metrics:
      - context_size
      - loading_time
      - cache_hit_rate
      - broken_references
  required:
    - "core/orchestration/delegation.md"
  max_context_size: 30000
```

### 6.2 Size Tracking

**Pattern**: Track context file sizes over time

**Script**:
```bash
#!/bin/bash
# Track context file sizes

echo "=== Context Size Report ===" > specs/tmp/context-sizes.txt
echo "Generated: $(date)" >> specs/tmp/context-sizes.txt
echo "" >> specs/tmp/context-sizes.txt

for dir in orchestration formats standards workflows templates; do
  echo "## $dir/" >> specs/tmp/context-sizes.txt
  find .claude/context/$dir -name "*.md" -exec wc -l {} + | \
    sort -n >> specs/tmp/context-sizes.txt
  echo "" >> specs/tmp/context-sizes.txt
done

cat specs/tmp/context-sizes.txt
```

### 6.3 Performance Monitoring

**Metrics**:
1. **Time to first token** - How long until first response
2. **Total operation time** - End-to-end duration
3. **Context loading time** - Time spent loading files
4. **Context window usage** - Percentage of window used

**Targets**:
- Time to first token: <2 seconds
- Context loading time: <1 second
- Context window usage: <90%

---

## 7. Common Patterns

### 7.1 Research Operations Pattern

**Context Needs**:
- Delegation patterns (for subagent calls)
- State management (for task lookup)
- Report format (for output)
- Language-specific tools (for research)

**Configuration**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "core/orchestration/delegation.md"
    - "core/orchestration/state-management.md"
    - "core/formats/report-format.md"
  conditional:
    - condition: "language == 'lean'"
      files:
        - "project/lean4/tools/leansearch-api.md"
        - "project/lean4/tools/loogle-api.md"
  max_context_size: 50000
```

**Rationale**:
- Research needs broad context for exploration
- Language-specific tools enable targeted research
- Report format ensures consistent output

### 7.2 Planning Operations Pattern

**Context Needs**:
- Delegation patterns (for subagent calls)
- State management (for task lookup)
- Plan format (for output)
- Task breakdown (for decomposition)

**Configuration**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "core/orchestration/delegation.md"
    - "core/orchestration/state-management.md"
    - "core/formats/plan-format.md"
    - "core/workflows/task-breakdown.md"
  max_context_size: 40000
```

**Rationale**:
- Planning needs task context and decomposition patterns
- Plan format ensures consistent output
- Task breakdown enables effective decomposition

### 7.3 Implementation Operations Pattern

**Context Needs**:
- Delegation patterns (for subagent calls)
- State management (for task lookup)
- Git safety (for commits)
- Language-specific standards (for code quality)

**Configuration**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "core/orchestration/delegation.md"
    - "core/orchestration/state-management.md"
    - "core/standards/git-safety.md"
  conditional:
    - condition: "language == 'lean'"
      files:
        - "project/lean4/standards/lean4-style-guide.md"
        - "project/lean4/tools/lsp-integration.md"
  max_context_size: 30000
```

**Rationale**:
- Implementation needs focused context for specific task
- Git safety ensures proper commits
- Language standards ensure code quality

### 7.4 Review Operations Pattern

**Context Needs**:
- Delegation patterns (for subagent calls)
- State management (for task lookup)
- Review process (for review criteria)

**Configuration**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "core/orchestration/delegation.md"
    - "core/orchestration/state-management.md"
    - "core/workflows/review-process.md"
  max_context_size: 30000
```

**Rationale**:
- Review needs focused context for specific artifacts
- Review process ensures consistent criteria
- Minimal context for efficient review

### 7.5 Meta Operations Pattern

**Context Needs**:
- Delegation patterns (for subagent calls)
- State management (for task creation)
- Architecture principles (for system design)
- Domain patterns (for domain-specific design)
- Interview patterns (for requirement gathering)

**Configuration**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "core/orchestration/delegation.md"
    - "core/orchestration/state-management.md"
    - "core/formats/subagent-return.md"
  conditional:
    - condition: "stage >= 4"  # Only load in execution stage
      files:
        - "meta/meta-guide.md"
        - "meta/domain-patterns.md"
        - "meta/context-revision-guide.md"
  max_context_size: 40000
```

**Rationale**:
- Meta operations need architecture and design patterns
- Interview patterns enable effective requirement gathering
- Conditional loading avoids loading during routing

---

## 8. Troubleshooting

### 8.1 Broken References

**Symptom**: Context files fail to load, silent errors

**Diagnosis**:
```bash
# Run validation script
bash .claude/scripts/validate-context-refs.sh

# Check for broken references manually
grep -r "core/system/" .claude/command .claude/agent
```

**Solutions**:
1. Run reference update script: `bash update-context-refs.sh`
2. Manually fix broken references
3. Add validation to CI/CD pipeline

**Prevention**:
- Run validation script before commits
- Use reference update script for bulk updates
- Document file moves and renames

### 8.2 Context Bloat

**Symptom**: Context window usage >90%, slow performance

**Diagnosis**:
```bash
# Check context file sizes
find .claude/context -name "*.md" -exec wc -l {} + | sort -n

# Check context loading configuration
grep -A 20 "context_loading:" .claude/command/*.md
```

**Solutions**:
1. Switch from eager to lazy loading
2. Move optional files to conditional loading
3. Create summary files for large files
4. Split large files into smaller files

**Prevention**:
- Set max_context_size limits
- Use lazy loading by default
- Monitor context usage metrics

### 8.3 Loading Failures

**Symptom**: Context files fail to load, errors in logs

**Diagnosis**:
```bash
# Check file permissions
ls -la .claude/context/**/*.md

# Check file existence
for file in $(grep -rh '"core/[^"]*\.md"' .claude/command | sed 's/.*"\(core\/[^"]*\.md\)".*/\1/'); do
  if [ ! -f ".claude/context/$file" ]; then
    echo "MISSING: $file"
  fi
done
```

**Solutions**:
1. Fix file permissions: `chmod 644 .claude/context/**/*.md`
2. Restore missing files from git history
3. Update references to correct paths

**Prevention**:
- Use validation script before commits
- Document file structure in index.json
- Use version control for all context files

### 8.4 Performance Issues

**Symptom**: Slow context loading, high latency

**Diagnosis**:
```bash
# Measure loading time
time grep -r "core/orchestration/delegation.md" .claude/command

# Check file sizes
find .claude/context -name "*.md" -exec wc -l {} + | sort -n | tail -10
```

**Solutions**:
1. Enable caching for frequently loaded files
2. Use summary files for large files
3. Switch to section-based loading for large files
4. Reduce max_context_size limits

**Prevention**:
- Monitor loading time metrics
- Set file size limits
- Use lazy loading by default

### 8.5 Diagnostic Commands

**Validate all references**:
```bash
bash .claude/scripts/validate-context-refs.sh
```

**Count broken references**:
```bash
grep -r "core/system/" .claude/command .claude/agent | grep -v "status-markers.md" | wc -l
```

**List large files**:
```bash
find .claude/context -name "*.md" -exec wc -l {} + | sort -n | tail -10
```

**Check context loading configurations**:
```bash
grep -A 20 "context_loading:" .claude/command/*.md .claude/agent/subagents/*.md
```

**Generate context inventory**:
```bash
for dir in orchestration formats standards workflows templates; do
  count=$(find .claude/context/$dir -name "*.md" | wc -l)
  lines=$(find .claude/context/$dir -name "*.md" -exec wc -l {} + | tail -1 | awk '{print $1}')
  echo "$dir/: $count files, $lines lines"
done
```

---

## Summary

**Key Takeaways**:

1. **Use lazy loading by default** - Load only what you need, when you need it
2. **Validate all references** - Broken references fail silently
3. **Set max_context_size limits** - Prevent context bloat
4. **Monitor context usage** - Track metrics and optimize over time
5. **Document loading patterns** - Make intent explicit in frontmatter
6. **Split large files** - Keep files <700 lines
7. **Use conditional loading** - Optimize for specific scenarios
8. **Run validation before commits** - Catch broken references early

**Quick Reference**:

- **Validation script**: `.claude/scripts/validate-context-refs.sh`
- **Update script**: `update-context-refs.sh`
- **Context index**: `.claude/context/index.json`
- **Max context sizes**: Research (50k), Planning (40k), Implementation (30k)
- **File size limits**: Standards (700), Formats (600), Templates (400)

---

**END OF GUIDE**
