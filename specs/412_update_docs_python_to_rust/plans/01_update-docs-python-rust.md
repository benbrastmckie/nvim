# Implementation Plan: Task #412

**Task**: 412 - Update documentation examples from Python to Rust
**Status**: [COMPLETED]
**Created**: 2026-04-13
**Effort**: 1 hour
**Complexity**: simple
**Research**: [01_update-docs-python-rust.md](../reports/01_update-docs-python-rust.md)
**Session**: sess_1776066839_fa4927

## Summary

Replace all hypothetical Python teaching examples with Rust across 7 documentation files (~45 text changes). Python is a real bundled extension, making it confusing as a hypothetical example. Rust is not bundled, making it an ideal replacement. All changes are textual substitutions with no structural modifications.

**Key mapping**: python->rust, Python->Rust, packages->crates, asyncio->tokio, pytest->cargo test, pip->cargo, python-research-agent->rust-research-agent, skill-python-research->skill-rust-research.

---

## Phase 1: Update creating-skills.md [COMPLETED]

**File**: `.claude/docs/guides/creating-skills.md`
**Changes**: ~25 substitutions (trigger conditions + complete example section)

### Edit 1.1: Trigger conditions (lines 185-187)

```
old_string:
- Task language is "python"
- Research involves Python packages or APIs
- Python-specific tooling is needed

new_string:
- Task language is "rust"
- Research involves Rust crates or APIs
- Rust-specific tooling is needed
```

### Edit 1.2: Complete example header (line 308)

```
old_string: Here is a complete skill for Python research:
new_string: Here is a complete skill for Rust research:
```

### Edit 1.3: YAML frontmatter (lines 312-313)

```
old_string:
name: skill-python-research
description: Research Python packages and APIs for implementation tasks. Invoke for Python-language research.

new_string:
name: skill-rust-research
description: Research Rust crates and APIs for implementation tasks. Invoke for Rust-language research.
```

### Edit 1.4: Agent reference in frontmatter (line 316)

```
old_string: agent: python-research-agent
new_string: agent: rust-research-agent
```

### Edit 1.5: Context comment (line 318)

```
old_string: #   - .claude/context/project/python/tools.md
new_string: #   - .claude/context/project/rust/tools.md
```

### Edit 1.6: Skill heading and description (lines 323-325)

```
old_string:
# Python Research Skill

Thin wrapper that delegates Python research to `python-research-agent` subagent.

new_string:
# Rust Research Skill

Thin wrapper that delegates Rust research to `rust-research-agent` subagent.
```

### Edit 1.7: Example trigger conditions (lines 329-332)

```
old_string:
- Task language is "python"
- Research involves Python packages, APIs, or frameworks
- Python-specific tooling documentation is needed

new_string:
- Task language is "rust"
- Research involves Rust crates, APIs, or frameworks
- Rust-specific tooling documentation is needed
```

### Edit 1.8: Delegation path in JSON (line 364)

```
old_string: "delegation_path": ["orchestrator", "research", "skill-python-research"],
new_string: "delegation_path": ["orchestrator", "research", "skill-rust-research"],
```

### Edit 1.9: Task context in JSON (lines 368-370)

```
old_string:
    "task_name": "add_async_support",
    "description": "Add async/await support to API client",
    "language": "python"

new_string:
    "task_name": "add_async_runtime",
    "description": "Add async runtime support to API client",
    "language": "rust"
```

### Edit 1.10: Focus prompt (line 372)

```
old_string: "focus_prompt": "asyncio best practices"
new_string: "focus_prompt": "tokio best practices"
```

### Edit 1.11: Agent invocation (line 378)

```
old_string: Invoke `python-research-agent` via Task tool with:
new_string: Invoke `rust-research-agent` via Task tool with:
```

### Edit 1.12: Subagent actions (lines 384-386)

```
old_string:
- Search for Python-specific documentation
- Analyze package dependencies
- Review asyncio patterns and best practices

new_string:
- Search for Rust-specific documentation
- Analyze crate dependencies
- Review tokio patterns and best practices
```

### Edit 1.13: Return format - summary (line 412)

```
old_string: "summary": "Research completed with 6 findings on asyncio patterns",
new_string: "summary": "Research completed with 6 findings on tokio patterns",
```

### Edit 1.14: Return format - artifact path (line 416)

```
old_string: "path": "specs/450_add_async_support/reports/01_asyncio-patterns.md",
new_string: "path": "specs/450_add_async_runtime/reports/01_tokio-patterns.md",
```

### Edit 1.15: Return format - artifact summary (line 417)

```
old_string: "summary": "Python asyncio research report"
new_string: "summary": "Rust tokio research report"
```

### Edit 1.16: Return format - agent type (line 421)

```
old_string: "agent_type": "python-research-agent",
new_string: "agent_type": "rust-research-agent",
```

### Edit 1.17: Return format - delegation path (line 423)

```
old_string: "delegation_path": ["orchestrator", "research", "python-research-agent"]
new_string: "delegation_path": ["orchestrator", "research", "rust-research-agent"]
```

---

## Phase 2: Update creating-agents.md [COMPLETED]

**File**: `.claude/docs/guides/creating-agents.md`
**Changes**: ~5 substitutions

### Edit 2.1: Task context example (lines 274-277)

```
old_string:
    "task_name": "add_async_support",
    "description": "Add async/await support to API client",
    "language": "python"

new_string:
    "task_name": "add_async_runtime",
    "description": "Add async runtime support to API client",
    "language": "rust"
```

### Edit 2.2: Focus prompt (line 283)

```
old_string: "focus_prompt": "asyncio best practices"
new_string: "focus_prompt": "tokio best practices"
```

### Edit 2.3: Context loading table (line 297)

```
old_string: | python | `project/python/tools.md` |
new_string: | rust | `project/rust/tools.md` |
```

---

## Phase 3: Update component-selection.md [COMPLETED]

**File**: `.claude/docs/guides/component-selection.md`
**Changes**: ~8 substitutions

### Edit 3.1: Skill example (line 105)

```
old_string: - New language support (e.g., `skill-python-research`)
new_string: - New language support (e.g., `skill-rust-research`)
```

### Edit 3.2: Pattern 2 diagram (lines 167-170)

```
old_string:
skill-python-research (new)
    |
    v
python-research-agent (new)

new_string:
skill-rust-research (new)
    |
    v
rust-research-agent (new)
```

### Edit 3.3: Example 1 section (lines 309-315)

```
old_string:
### Example 1: Adding Python Support

**Goal**: Support Python tasks with task-type-specific tooling

**Components needed**:
1. `skill-python-research/SKILL.md` - Routes Python tasks to Python agent
2. `python-research-agent.md` - Uses Python-specific tools

new_string:
### Example 1: Adding Rust Support

**Goal**: Support Rust tasks with task-type-specific tooling

**Components needed**:
1. `skill-rust-research/SKILL.md` - Routes Rust tasks to Rust agent
2. `rust-research-agent.md` - Uses Rust-specific tools
```

---

## Phase 4: Update remaining 4 files [COMPLETED]

**Files**: `adding-domains.md`, `creating-extensions.md`, `system-overview.md`, `component-checklist.md`
**Changes**: ~10 substitutions total

### Edit 4.1: adding-domains.md (line 24)

```
old_string: └── NO (e.g., latex, lean, python, react)
new_string: └── NO (e.g., latex, lean, rust, react)
```

### Edit 4.2: creating-extensions.md (line 14)

```
old_string: - Adding support for a new language/framework (Python, React, Rust)
new_string: - Adding support for a new language/framework (Rust, React, Go)
```

### Edit 4.3: system-overview.md (lines 252-254)

```
old_string:
To add support for a new language (e.g., Python):

1. Create skill: `.claude/skills/skill-python-research/SKILL.md`
2. Create agent: `.claude/agents/python-research-agent.md`

new_string:
To add support for a new language (e.g., Rust):

1. Create skill: `.claude/skills/skill-rust-research/SKILL.md`
2. Create agent: `.claude/agents/rust-research-agent.md`
```

### Edit 4.4: component-checklist.md (line 48)

```
old_string: | Just adding language variant (e.g., Python research) | NO - use existing command |
new_string: | Just adding language variant (e.g., Rust research) | NO - use existing command |
```

### Edit 4.5: component-checklist.md (line 55)

```
old_string: | New language support (e.g., Python, Rust) | YES |
new_string: | New language support (e.g., Rust, Go) | YES |
```

### Edit 4.6: component-checklist.md Pattern 2 (lines 188-192)

```
old_string:
When: Adding support for a new language (e.g., Python)

**Creates**:
1. Skill: `.claude/skills/skill-python-research/SKILL.md`
2. Agent: `.claude/agents/python-research-agent.md`

new_string:
When: Adding support for a new language (e.g., Rust)

**Creates**:
1. Skill: `.claude/skills/skill-rust-research/SKILL.md`
2. Agent: `.claude/agents/rust-research-agent.md`
```

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Inconsistent replacement (Python refs missed) | Low | Final grep verification in validation step |
| Changing a real Python extension reference | Low | Research confirmed all refs are hypothetical |
| Listing Rust twice in `creating-extensions.md` | Low | Replace Python with Go, keep Rust in list |

## Validation

After all phases complete:

1. **Grep verification**: Search for remaining "python" (case-insensitive) in the 7 target files to catch any missed occurrences:
   ```bash
   grep -in "python" .claude/docs/guides/creating-skills.md .claude/docs/guides/creating-agents.md .claude/docs/guides/component-selection.md .claude/docs/guides/adding-domains.md .claude/docs/guides/creating-extensions.md .claude/docs/architecture/system-overview.md .claude/context/architecture/component-checklist.md
   ```

2. **Consistency check**: Verify all rust/Rust references are correctly cased (lowercase in identifiers, title case in prose).

3. **No structural breakage**: Confirm markdown renders correctly (no broken code blocks or tables).
