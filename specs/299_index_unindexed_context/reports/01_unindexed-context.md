# Research Report: Unindexed Context Files in Website .claude/context/

**Task**: 299 - Index 75 unindexed context files
**Date**: 2026-03-26
**Status**: RESEARCHED

---

## Summary

75 markdown files exist under `/home/benjamin/Projects/Logos/Website/.claude/context/` that have no corresponding entry in `index.json`. These are all core agent system files (not extension/project files). They are functional -- agents can reference them via `@`-imports in CLAUDE.md and skill/agent definitions -- but they are invisible to programmatic context discovery queries against `index.json`.

---

## Methodology

1. Extracted all `path` values from `index.json` entries (currently 213 indexed entries)
2. Found all `.md` files on disk under `.claude/context/` via glob
3. Computed the set difference: files on disk NOT in index.json
4. Cross-referenced against `extensions.json` `installed_files` to check extension coverage

---

## Extension Coverage

Of the 75 unindexed files:
- **2 files** are tracked by `extensions.json` installed_files: `project/founder/README.md`, `project/memory/README.md`
- **73 files** are in neither `index.json` nor `extensions.json`

These 73 files are all **core agent system files** (orchestration, patterns, standards, etc.), not extension-specific content. They were likely created during system development but never added to the index.

---

## Unindexed Files by Category

### orchestration/ (12 files)
Files defining the three-layer delegation architecture, session management, and validation.

| File | Content Summary |
|------|----------------|
| `orchestration/architecture.md` | Architecture diagrams and layer descriptions |
| `orchestration/delegation.md` | Delegation patterns and depth limits |
| `orchestration/orchestration-core.md` | Consolidated orchestration patterns (delegation, sessions, routing) |
| `orchestration/orchestration-reference.md` | Quick-reference for orchestration concepts |
| `orchestration/orchestration-validation.md` | Validation rules for orchestration flows |
| `orchestration/orchestrator.md` | Orchestrator agent behavior specification |
| `orchestration/postflight-pattern.md` | Post-execution status update pattern |
| `orchestration/preflight-pattern.md` | Pre-execution validation pattern |
| `orchestration/sessions.md` | Session ID generation and tracking |
| `orchestration/state-management.md` | State synchronization between TODO.md and state.json |
| `orchestration/subagent-validation.md` | Subagent return validation rules |
| `orchestration/validation.md` | General validation patterns |

**Sample**: `orchestration-core.md` -- "Essential orchestration patterns for delegation, session tracking, and routing." Consolidates orchestrator.md, delegation.md, routing.md, and sessions.md (partial).

**Note**: Some of these may be superseded by the consolidated `orchestration-core.md`. Overlap analysis recommended.

### standards/ (12 files)
Core agent system standards not language-specific.

| File | Content Summary |
|------|----------------|
| `standards/analysis-framework.md` | Framework for code analysis and review |
| `standards/ci-workflow.md` | CI/CD workflow standards |
| `standards/code-patterns.md` | General coding patterns |
| `standards/documentation.md` | Documentation writing standards |
| `standards/documentation-standards.md` | Documentation formatting standards |
| `standards/error-handling.md` | Error handling and recovery standards |
| `standards/git-integration.md` | Git workflow integration |
| `standards/git-safety.md` | Git safety rules and guardrails |
| `standards/status-markers.md` | Task status marker definitions |
| `standards/task-management.md` | Task creation, formatting, and management standards |
| `standards/testing.md` | Testing standards and patterns |
| `standards/xml-structure.md` | XML structure standards for agent communication |

**Sample**: `task-management.md` -- "Standards for creating, formatting, and managing tasks within the .opencode system." Defines unique IDs, atomic tasks, status tracking.

**Note**: `documentation.md` and `documentation-standards.md` may overlap. Two indexed standards files exist (`interactive-selection.md`, `postflight-tool-restrictions.md`), suggesting these 12 were missed rather than intentionally excluded.

### patterns/ (10 files)
Agent system behavioral patterns.

| File | Content Summary |
|------|----------------|
| `patterns/checkpoint-execution.md` | Checkpoint-based execution flow |
| `patterns/context-discovery.md` | Context discovery query patterns |
| `patterns/early-metadata-pattern.md` | Early metadata generation for return values |
| `patterns/file-metadata-exchange.md` | File-based metadata exchange between agents |
| `patterns/inline-status-update.md` | Inline status update pattern |
| `patterns/jq-escaping-workarounds.md` | jq != operator escaping workaround |
| `patterns/postflight-control.md` | Postflight control flow patterns |
| `patterns/roadmap-update.md` | Roadmap update patterns |
| `patterns/skill-lifecycle.md` | Self-contained skill lifecycle (preflight/delegate/postflight/return) |
| `patterns/thin-wrapper-skill.md` | Thin wrapper skill pattern |

**Sample**: `skill-lifecycle.md` -- "Skills should be self-contained workflows that own their complete lifecycle: Preflight, Delegate, Postflight, Return."

**Note**: 5 patterns files are already indexed (`anti-stop-patterns.md`, `mcp-tool-recovery.md`, `metadata-file-return.md`, `team-orchestration.md`, plus `context-discovery.md` referenced in CLAUDE.md). The 10 unindexed ones follow the same structure.

### formats/ (8 files)
Output and artifact format specifications.

| File | Content Summary |
|------|----------------|
| `formats/command-output.md` | Command output display format standard |
| `formats/command-structure.md` | Command YAML structure specification |
| `formats/frontmatter.md` | Frontmatter format for agents/skills |
| `formats/report-format.md` | Research report format template |
| `formats/roadmap-format.md` | Roadmap entry format |
| `formats/subagent-return.md` | Subagent JSON return format |
| `formats/summary-format.md` | Execution summary format |
| `formats/task-order-format.md` | Task Order section format in TODO.md |

**Sample**: `command-output.md` -- "Defines the format for command output displayed to users by the orchestrator. Ensures consistent, clear, and concise output."

### templates/ (6 files)
Templates for creating new system components.

| File | Content Summary |
|------|----------------|
| `templates/agent-template.md` | Standard templates for different agent types |
| `templates/command-template.md` | Template for new command definitions |
| `templates/delegation-context.md` | Context template for delegation handoffs |
| `templates/orchestrator-template.md` | Orchestrator agent template |
| `templates/subagent-template.md` | Subagent definition template |
| `templates/thin-wrapper-skill.md` | Thin wrapper skill template |

**Sample**: `agent-template.md` -- "Standard templates for different agent types" with orchestrator, researcher, and implementer variants.

### meta/ (5 files)
Meta-system documentation for building and maintaining the agent system.

| File | Content Summary |
|------|----------------|
| `meta/architecture-principles.md` | Core architecture principles |
| `meta/context-revision-guide.md` | Guide for revising context files |
| `meta/domain-patterns.md` | Domain pattern conventions |
| `meta/interview-patterns.md` | Interview/discovery patterns for new domains |
| `meta/standards-checklist.md` | Checklist for new standards compliance |

**Note**: `meta/meta-guide.md` IS indexed. These 5 supplements are not.

### workflows/ (5 files)
End-to-end workflow documentation.

| File | Content Summary |
|------|----------------|
| `workflows/command-lifecycle.md` | 8-stage command lifecycle (preflight through commit) |
| `workflows/preflight-postflight.md` | Preflight/postflight workflow details |
| `workflows/review-process.md` | Code review workflow |
| `workflows/status-transitions.md` | Valid status transition paths |
| `workflows/task-breakdown.md` | Task decomposition workflow |

**Sample**: `command-lifecycle.md` -- "Describes the lifecycle of workflow commands and the two-phase status update pattern."

### architecture/ (3 files)
System architecture documentation.

| File | Content Summary |
|------|----------------|
| `architecture/component-checklist.md` | Checklist for new component creation |
| `architecture/generation-guidelines.md` | Guidelines for generating new components |
| `architecture/system-overview.md` | Consolidated architecture reference |

**Sample**: `system-overview.md` -- "Consolidated architecture reference for agents generating new components. Three-layer delegation pattern."

**Note**: `architecture/context-layers.md` IS indexed. These 3 are not.

### processes/ (3 files)
Detailed process workflows.

| File | Content Summary |
|------|----------------|
| `processes/implementation-workflow.md` | Implementation execution workflow |
| `processes/planning-workflow.md` | Planning workflow details |
| `processes/research-workflow.md` | Research workflow with language-based routing |

**Sample**: `research-workflow.md` -- "Detailed research workflow for conducting research and creating reports."

### repo/ (3 files)
Repository-specific context.

| File | Content Summary |
|------|----------------|
| `repo/project-overview.md` | Repository layout and project description |
| `repo/self-healing-implementation-details.md` | Self-healing implementation details |
| `repo/update-project.md` | Guidance for generating project-appropriate docs |

**Note**: These are referenced in CLAUDE.md via `@`-imports but not in index.json.

### checkpoints/ (2 files)
Checkpoint execution patterns (2 of 4 checkpoint files are indexed).

| File | Content Summary |
|------|----------------|
| `checkpoints/checkpoint-commit.md` | Commit checkpoint pattern |
| `checkpoints/README.md` | Checkpoint system overview |

### Other (6 files)

| File | Category | Content Summary |
|------|----------|----------------|
| `guides/extension-development.md` | guides | Extension development guide |
| `reference/README.md` | reference | Reference section overview |
| `troubleshooting/workflow-interruptions.md` | troubleshooting | Handling workflow interruptions |
| `validation.md` | root | Validation patterns (root-level) |
| `project/founder/README.md` | project | Founder extension overview (in extensions.json) |
| `project/memory/README.md` | project | Memory extension overview (in extensions.json) |

---

## Analysis

### Why are these files not indexed?

These are all **core agent system files** that predate or were missed during index.json creation. The index.json was likely built incrementally, and these files were either:
1. Created before the index system was established
2. Added during rapid development without corresponding index entries
3. Considered "internal" and referenced only via `@`-imports in CLAUDE.md/skill/agent definitions

### Do they work without indexing?

**Yes, partially**. Files referenced via `@`-imports in CLAUDE.md, agent definitions, or skill definitions load correctly. However, they are **invisible to programmatic discovery** -- any agent or tool querying `index.json` with `jq` to find relevant context by domain, keyword, topic, or agent will not find these files.

### Should ALL be indexed?

**Recommendation: Index all 73 core files** (excluding the 2 extension READMEs already tracked by extensions.json).

Rationale:
- All files contain substantive content relevant to agent system operation
- The index exists specifically for discoverability -- leaving files out defeats its purpose
- Some files may be consolidations that supersede others, but that's an orthogonal cleanup concern
- The 2 extension READMEs (`project/founder/README.md`, `project/memory/README.md`) should be added to their respective extension index entries rather than the core index

### Potential overlap/consolidation concerns

Before blindly indexing, note these potential overlaps:
- `orchestration/orchestration-core.md` explicitly consolidates `orchestrator.md`, `delegation.md`, `routing.md`, `sessions.md`
- `standards/documentation.md` vs `standards/documentation-standards.md`
- `orchestration/validation.md` vs `orchestration/orchestration-validation.md` vs `orchestration/subagent-validation.md`

These overlaps don't block indexing -- they are a separate cleanup concern (and having them indexed makes the overlap more visible).

---

## Proposed Approach for Bulk Indexing

### Strategy

Write a script that:
1. Reads each unindexed `.md` file
2. Extracts frontmatter/title/purpose from the first ~20 lines
3. Determines appropriate `domain`, `subdomain`, `keywords`, `topics`, `summary`
4. Generates `load_when` based on directory category:
   - `orchestration/*` -> agents: ["orchestrator"], commands: ["/research", "/plan", "/implement"]
   - `patterns/*` -> agents: ["meta-builder-agent", "orchestrator"]
   - `standards/*` -> agents: ["meta-builder-agent"], commands: ["/meta", "/review"]
   - `formats/*` -> agents: ["meta-builder-agent", "orchestrator"]
   - `templates/*` -> agents: ["meta-builder-agent"], commands: ["/meta"]
   - `processes/*` -> commands: ["/research", "/plan", "/implement"]
   - `workflows/*` -> commands: ["/research", "/plan", "/implement"]
   - `meta/*` -> agents: ["meta-builder-agent"], commands: ["/meta"]
   - `architecture/*` -> agents: ["meta-builder-agent"]
   - `repo/*` -> always: true (referenced from CLAUDE.md)
   - `checkpoints/*` -> agents: ["orchestrator"]
   - Other -> case-by-case
5. Counts lines for `line_count`
6. Appends entries to index.json

### Dependency on Task 298

Task 298 establishes domain/subdomain metadata conventions. The `domain` and `subdomain` values assigned during bulk indexing should follow whatever conventions task 298 defines. Recommended sequence:
1. Complete task 298 (metadata standards)
2. Use those standards to assign consistent domain/subdomain values
3. Execute bulk indexing with validated metadata

### Script Outline

```bash
#!/usr/bin/env bash
# bulk-index.sh - Add unindexed context files to index.json
# Run AFTER task 298 establishes metadata conventions

CONTEXT_DIR=".claude/context"
INDEX="$CONTEXT_DIR/index.json"

for file in $(comm -23 <(find "$CONTEXT_DIR" -name '*.md' -type f | sed "s|^$CONTEXT_DIR/||" | sort) \
                       <(jq -r '.entries[].path' "$INDEX" | sort)); do
    lines=$(wc -l < "$CONTEXT_DIR/$file")
    title=$(head -1 "$CONTEXT_DIR/$file" | sed 's/^# //')
    dir=$(dirname "$file")

    # Generate entry (domain/subdomain from task 298 conventions)
    # Append to index.json using jq
    jq --arg path "$file" \
       --arg summary "$title" \
       --argjson lines "$lines" \
       '.entries += [{"path": $path, "summary": $summary, "line_count": $lines, "domain": "TBD", "subdomain": "TBD", "keywords": [], "topics": [], "load_when": {}}]' \
       "$INDEX" > "$INDEX.tmp" && mv "$INDEX.tmp" "$INDEX"
done
```

A more sophisticated version would use Claude to generate proper metadata for each file, but the shell script provides the mechanical framework.

---

## Conclusion

73 core context files need index.json entries. 2 additional extension READMEs should be added to their respective extension entries. All files contain substantive, relevant content and should be indexed for programmatic discoverability. The work depends on task 298 (metadata conventions) being completed first to ensure consistent domain/subdomain assignment.
