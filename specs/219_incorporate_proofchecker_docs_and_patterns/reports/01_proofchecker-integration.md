# Research Report: Task #219

**Task**: 219 - incorporate_proofchecker_docs_and_patterns
**Started**: 2026-03-16T00:00:00Z
**Completed**: 2026-03-16T00:30:00Z
**Effort**: 2-4 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: ProofChecker .claude/ files, nvim .claude/ files, gh/glab CLI documentation
**Artifacts**: This report
**Standards**: report-format.md

---

## Executive Summary

- ProofChecker has 6 key documentation files that nvim lacks: blocked-mcp-tools.md, state-json-schema.md, mcp-tool-recovery.md, handoff-artifact.md, progress-file.md, and merge.md command
- nvim already has early-metadata-pattern.md (identical content to ProofChecker version)
- The /merge command should auto-detect GitHub vs GitLab via git remote URL and use gh or glab accordingly
- New core/reference directory needs to be created for schema documentation
- Lean extension context needs blocked-mcp-tools.md added

---

## Context & Scope

This research identifies which ProofChecker documentation, patterns, and commands should be ported to nvim to make the agent system more complete and portable across both GitHub and GitLab repositories.

---

## Findings

### Part 1: ProofChecker Source Files Read

| File | Status | Content Summary |
|------|--------|-----------------|
| blocked-mcp-tools.md | EXISTS | MCP tools reference (lean_diagnostic_messages, lean_file_outline blocked) |
| state-json-schema.md | EXISTS | Complete state.json schema with field reference and examples |
| early-metadata-pattern.md | EXISTS | Agent early metadata creation pattern for interruption recovery |
| mcp-tool-recovery.md | EXISTS | MCP AbortError recovery strategies and fallback patterns |
| handoff-artifact.md | EXISTS | Context exhaustion handoff schema for team mode |
| progress-file.md | EXISTS | Phase progress tracking schema for team mode |
| merge.md | EXISTS | GitLab-only /merge command (glab mr create) |
| index.json | EXISTS | 186 entries with full schema definition |

### Part 2: nvim Current State Analysis

| Component | nvim Status | Action Needed |
|-----------|-------------|---------------|
| context/core/reference/ | MISSING | Create directory |
| context/core/patterns/early-metadata-pattern.md | EXISTS (262 lines) | No change needed |
| context/core/patterns/mcp-tool-recovery.md | MISSING | Create file |
| context/core/formats/handoff-artifact.md | MISSING | Create file |
| context/core/formats/progress-file.md | MISSING | Create file |
| extensions/lean/context/ | EXISTS (project/lean4 only) | Add tools/blocked-mcp-tools.md |
| commands/merge.md | MISSING | Create with GitHub/GitLab detection |

### Part 3: File-by-File Adaptation Plan

#### 3.1 blocked-mcp-tools.md -> extensions/lean/context/project/lean4/tools/blocked-mcp-tools.md

**Source**: `/home/benjamin/Projects/ProofChecker/.claude/context/core/patterns/blocked-mcp-tools.md`

**Adaptations needed**:
- Move from core/patterns to lean extension context (lean-specific tools)
- Update related documentation paths to use extension paths
- Keep all tool blocking information (lean_diagnostic_messages, lean_file_outline)
- Update unblocking procedure to reference extension structure

**Line count**: 66 lines

#### 3.2 state-json-schema.md -> context/core/reference/state-json-schema.md

**Source**: `/home/benjamin/Projects/ProofChecker/.claude/context/core/reference/state-json-schema.md`

**Adaptations needed**:
- Remove ProofChecker-specific repository_health fields (sorry_count, axiom_count, build_errors)
- Generalize language enum (remove "lean", keep "general", "meta", "markdown", add placeholder for extensions)
- Keep all status values, artifact schema, completion fields
- Update examples to use nvim-appropriate slugs

**Line count**: 142 lines (will be ~120 after adaptation)

#### 3.3 skill-agent-mapping.md -> context/core/reference/skill-agent-mapping.md (NEW)

This file does not exist in ProofChecker but is referenced in the task description. Create based on CLAUDE.md tables.

**Content**:
- Core skill-to-agent mappings from CLAUDE.md
- Extension skill loading mechanism
- Agent model preferences
- Team mode skill overrides

**Estimated line count**: 80 lines

#### 3.4 mcp-tool-recovery.md -> context/core/patterns/mcp-tool-recovery.md

**Source**: `/home/benjamin/Projects/ProofChecker/.claude/context/core/patterns/mcp-tool-recovery.md`

**Adaptations needed**:
- Generalize from Lean-specific to any MCP tool type
- Remove Lean-specific tool fallback table (move to lean extension)
- Keep error types, recovery strategy pattern, logging format
- Update related documentation paths

**Line count**: 214 lines (will be ~150 after generalization)

**Additional file**: Create extensions/lean/context/project/lean4/patterns/mcp-fallback-table.md with Lean-specific fallbacks

#### 3.5 handoff-artifact.md -> context/core/formats/handoff-artifact.md

**Source**: `/home/benjamin/Projects/ProofChecker/.claude/context/core/formats/handoff-artifact.md`

**Adaptations needed**:
- Keep generic handoff document template
- Remove Lean-specific example (or generalize)
- Keep directory structure, section guidelines, integration patterns
- Add reference to team-orchestration.md pattern

**Line count**: 198 lines

#### 3.6 progress-file.md -> context/core/formats/progress-file.md

**Source**: `/home/benjamin/Projects/ProofChecker/.claude/context/core/formats/progress-file.md`

**Adaptations needed**:
- Keep schema and field specifications
- Remove Lean-specific example (or generalize)
- Keep lifecycle diagram and integration with handoff
- Update related documentation paths

**Line count**: 252 lines

#### 3.7 /merge command -> commands/merge.md

**Source**: `/home/benjamin/Projects/ProofChecker/.claude/commands/merge.md`

**Major redesign needed** - ProofChecker version is GitLab-only. Create unified version:

**Detection Algorithm**:
```bash
# Get origin URL
origin_url=$(git remote get-url origin 2>/dev/null)

# Detect platform
if [[ "$origin_url" == *"github.com"* ]] || [[ "$origin_url" == *"github:"* ]]; then
    platform="github"
    cli_tool="gh"
    create_cmd="gh pr create"
elif [[ "$origin_url" == *"gitlab.com"* ]] || [[ "$origin_url" == *"gitlab:"* ]]; then
    platform="gitlab"
    cli_tool="glab"
    create_cmd="glab mr create"
else
    # Try to detect via CLI availability
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
        platform="github"
    elif command -v glab &>/dev/null && glab auth status &>/dev/null; then
        platform="gitlab"
    else
        # Error: cannot determine platform
    fi
fi
```

**Flag Mapping**:

| Unified Flag | gh pr create | glab mr create |
|--------------|--------------|----------------|
| `--draft` | `--draft` | `--draft` |
| `--assignee USER` | `--assignee USER` | `--assignee USER` |
| `--label LABEL` | `--label LABEL` | `--label LABEL` |
| `--reviewer USER` | `--reviewer USER` | `--reviewer USER` |
| `--fill` | `--fill` | `--fill --yes` |
| `--target BRANCH` | `--base BRANCH` | `--target-branch BRANCH` |
| `--title TITLE` | `--title TITLE` | `--title TITLE` |
| `--body BODY` | `--body BODY` | `--description BODY` |

**Estimated line count**: 350 lines (expanded from 304 for dual-platform)

### Part 4: index.json Entries to Add

New entries for context/index.json:

```json
[
  {
    "path": "core/reference/state-json-schema.md",
    "domain": "core",
    "subdomain": "reference",
    "topics": ["state", "schema", "json"],
    "keywords": ["state.json", "schema", "projects", "status"],
    "summary": "Complete state.json schema reference with field specifications",
    "line_count": 120,
    "load_when": {
      "commands": ["/task", "/todo", "/implement", "/research"],
      "agents": ["meta-builder-agent"]
    }
  },
  {
    "path": "core/reference/skill-agent-mapping.md",
    "domain": "core",
    "subdomain": "reference",
    "topics": ["skills", "agents", "routing"],
    "keywords": ["skill", "agent", "mapping", "delegation"],
    "summary": "Skill-to-agent routing and delegation reference",
    "line_count": 80,
    "load_when": {
      "agents": ["orchestrator", "meta-builder-agent"],
      "languages": ["meta"]
    }
  },
  {
    "path": "core/patterns/mcp-tool-recovery.md",
    "domain": "core",
    "subdomain": "patterns",
    "topics": ["mcp", "recovery", "error-handling"],
    "keywords": ["mcp", "abort", "timeout", "recovery"],
    "summary": "MCP tool failure recovery strategies and fallback patterns",
    "line_count": 150,
    "load_when": {
      "agents": ["general-implementation-agent", "general-research-agent"]
    }
  },
  {
    "path": "core/formats/handoff-artifact.md",
    "domain": "core",
    "subdomain": "formats",
    "topics": ["handoff", "context-exhaustion", "team-mode"],
    "keywords": ["handoff", "context", "successor", "team"],
    "summary": "Handoff artifact schema for context exhaustion recovery",
    "line_count": 198,
    "load_when": {
      "agents": ["skill-team-research", "skill-team-plan", "skill-team-implement"]
    }
  },
  {
    "path": "core/formats/progress-file.md",
    "domain": "core",
    "subdomain": "formats",
    "topics": ["progress", "phases", "team-mode"],
    "keywords": ["progress", "phases", "objectives", "resume"],
    "summary": "Progress file schema for phase tracking and resume",
    "line_count": 252,
    "load_when": {
      "agents": ["skill-team-research", "skill-team-plan", "skill-team-implement"]
    }
  }
]
```

**Note**: blocked-mcp-tools.md goes in lean extension's index-entries.json, not core index.json.

---

## Recommendations

### Implementation Phases

**Phase 1: Create Directory Structure**
- Create `context/core/reference/` directory
- Estimated: 5 minutes

**Phase 2: Port Schema Documentation**
- Create `state-json-schema.md` with generalizations
- Create `skill-agent-mapping.md` (new)
- Estimated: 45 minutes

**Phase 3: Port Pattern Documentation**
- Create `mcp-tool-recovery.md` (generalized)
- Estimated: 30 minutes

**Phase 4: Port Format Documentation**
- Create `handoff-artifact.md`
- Create `progress-file.md`
- Estimated: 30 minutes

**Phase 5: Update Lean Extension**
- Create `extensions/lean/context/project/lean4/tools/blocked-mcp-tools.md`
- Update `extensions/lean/index-entries.json`
- Estimated: 20 minutes

**Phase 6: Create /merge Command**
- Create `commands/merge.md` with GitHub/GitLab detection
- Estimated: 60 minutes

**Phase 7: Update index.json**
- Add all new core entries
- Estimated: 15 minutes

### Total Estimated Effort

3-4 hours implementation time

---

## Decisions

1. **blocked-mcp-tools.md location**: Place in lean extension context (not core) because it documents Lean-specific MCP tools
2. **mcp-tool-recovery.md generalization**: Keep in core with generic patterns, move Lean-specific fallback table to extension
3. **skill-agent-mapping.md**: Create new file (not in ProofChecker) to formalize the mapping documented in CLAUDE.md
4. **/merge command**: Design as platform-agnostic with auto-detection rather than porting GitLab-only version

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| gh/glab CLI not installed | /merge fails | Check for CLI availability and provide install instructions |
| Mixed remote URLs (multiple remotes) | Incorrect platform detection | Use origin by default, add --remote flag option |
| Enterprise GitHub/GitLab URLs | Detection fails | Add pattern matching for common enterprise URL formats |
| index.json schema differences | Validation errors | Review nvim's index.json schema and adapt entries |

---

## Appendix

### Search Queries Used

1. ProofChecker file reads: blocked-mcp-tools.md, state-json-schema.md, early-metadata-pattern.md, mcp-tool-recovery.md, handoff-artifact.md, progress-file.md, merge.md, index.json
2. nvim directory listings: context/core/, context/core/patterns/, context/core/formats/, extensions/lean/
3. Web searches: "gh pr create CLI flags options GitHub 2026", "glab mr create CLI flags options GitLab 2026"

### References to Documentation

- [gh pr create manual](https://cli.github.com/manual/gh_pr_create)
- [glab mr create docs](https://docs.gitlab.com/cli/mr/create/)
- ProofChecker index.json schema (186 entries)
- nvim index.json (57 entries before additions)

### Files Already Present in nvim

- `context/core/patterns/early-metadata-pattern.md` - 262 lines, identical purpose to ProofChecker version
- `context/core/patterns/team-orchestration.md` - Team mode patterns
- `context/core/formats/team-metadata-extension.md` - Team metadata schema

### Extension Structure Reference

The lean extension uses this structure:
```
extensions/lean/
├── agents/          # lean-research-agent, lean-implementation-agent
├── commands/        # /lake, /lean
├── context/project/lean4/
│   ├── agents/      # agent flow docs
│   ├── domain/      # lean4-syntax, mathlib, etc.
│   ├── operations/  # multi-instance-optimization
│   ├── patterns/    # tactic-patterns
│   ├── processes/   # proof workflow
│   ├── standards/   # style guides
│   ├── templates/   # file templates
│   └── tools/       # mcp-tools-guide, search APIs
├── hooks/
├── rules/           # lean4.md
└── skills/          # skill-lean-research, skill-lean-implementation
```

blocked-mcp-tools.md should go in `tools/` alongside mcp-tools-guide.md.
