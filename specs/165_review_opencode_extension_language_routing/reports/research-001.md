# Research Report: Task #165

**Task**: 165 - review_opencode_extension_language_routing
**Started**: 2026-03-10T00:00:00Z
**Completed**: 2026-03-10T00:30:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (.opencode/ directory)
**Artifacts**: specs/165_review_opencode_extension_language_routing/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

The .opencode/ agent system has **significant gaps in extension language routing**. While 10 extensions exist (z3, nix, python, epidemiology, typst, latex, lean, web, formal, filetypes) with their own agents, skills, and context files, the core routing infrastructure only handles two specialized languages (lean, neovim) and routes everything else to generic agents. Extension languages provide specialized agents and context but are never invoked because:

1. Commands (`/research`, `/implement`) hardcode delegation to `skill-researcher` / `skill-implementer` regardless of language
2. The routing tables in `orchestration-core.md` only enumerate lean, neovim, and default
3. Extension `index-entries.json` files are not merged into the main `context/index.json`
4. Routing validation only checks lean and neovim language-agent compatibility
5. No extension registration mechanism exists to dynamically expand routing tables

## Context and Scope

This review examines how the .opencode/ agent system routes tasks to specialized agents based on language type, and whether extensions correctly expand the routing when installed. The scope covers:

- Core routing infrastructure (orchestration-core.md, routing.md)
- Command routing logic (/research, /implement)
- Skill-to-agent delegation (core skills and extension skills)
- Context discovery via index.json
- Extension manifest structure and merge_targets

## Findings

### 1. Command Routing is Hardcoded to Generic Skills

**Location**: `.opencode/commands/research.md` (line 100-104), `.opencode/commands/implement.md` (line 80-84)

Both commands hardcode the skill they delegate to:

- `/research` always calls `skill-researcher` (Step 6, line 100-104)
- `/implement` always calls `skill-implementer` (Step 5, line 80-84)

There is NO conditional logic to route to extension skills based on language. The routing tables within these commands only distinguish between `neovim` and `general` for agent_type verification (research.md lines 117-121, implement.md lines 97-101):

| Language | Research subagent_type | Implementation subagent_type |
|----------|------------------------|------------------------------|
| neovim | neovim-research-agent | neovim-implementation-agent |
| general, meta, markdown, latex | general-research-agent | general-implementation-agent |

**Missing from routing tables**: lean4, z3, nix, python, epidemiology, typst, web, formal, logic, math, physics

### 2. Orchestration Core Has Incomplete Routing

**Location**: `.opencode/context/core/orchestration/orchestration-core.md` (lines 182-189)

The routing table only maps:

| Command | Language | Agent |
|---------|----------|-------|
| /research | lean | lean-research-agent |
| /research | neovim | neovim-research-agent |
| /research | default | general-research-agent |
| /implement | lean | lean-implementation-agent |
| /implement | neovim | neovim-implementation-agent |
| /implement | default | general-implementation-agent |

Extension languages are completely absent. A task with language="z3" would route to `general-research-agent` instead of `z3-research-agent`.

### 3. Routing Validation Only Checks Lean and Neovim

**Location**: `orchestration-core.md` (lines 213-224)

Validation only enforces:
- Lean tasks must go to lean-* agents
- Neovim tasks must go to neovim-* agents

No validation exists for z3, nix, python, latex, typst, web, epidemiology, or formal languages. These languages can be silently misrouted to generic agents without any warning.

### 4. Extension index-entries.json Not Merged Into Main Index

**Location**: `.opencode/context/index.json` vs `.opencode/extensions/*/index-entries.json`

The main `context/index.json` has 22 entries. Extension manifests declare `merge_targets.index` pointing from their `index-entries.json` to the main index, but **this merge has not occurred** for many extensions:

**Present in main index (agents referenced)**:
- lean4 (lean-research-agent, lean-implementation-agent)
- neovim (neovim-research-agent, neovim-implementation-agent)
- latex (latex-research-agent, latex-implementation-agent)
- typst (typst-research-agent, typst-implementation-agent)
- logic (logic-research-agent)
- math (math-research-agent)
- epidemiology (epidemiology-research-agent, epidemiology-implementation-agent)
- meta (meta-builder-agent)
- web (general-research-agent -- note: mapped to general, not web-specific)

**Missing from main index despite having extension index-entries.json**:
- z3 (has index-entries.json with 4 entries for z3-research-agent, z3-implementation-agent)
- nix (needs verification)
- python (needs verification)

Even for extensions whose context IS in the main index (e.g., latex, typst), the routing tables never actually send tasks to their specialized agents.

### 5. Extension Skills Exist But Are Never Called

Each extension provides dedicated skills that are structurally correct:

| Extension | Research Skill | Implementation Skill | Agent |
|-----------|---------------|---------------------|-------|
| z3 | skill-z3-research | skill-z3-implementation | z3-*-agent |
| lean | skill-lean-research | skill-lean-implementation | lean-*-agent |
| latex | skill-latex-research | skill-latex-implementation | latex-*-agent |
| typst | skill-typst-research | skill-typst-implementation | typst-*-agent |
| nix | skill-nix-research | skill-nix-implementation | nix-*-agent |
| python | skill-python-research | skill-python-implementation | python-*-agent |
| web | skill-web-research | skill-web-implementation | web-*-agent |
| epidemiology | skill-epidemiology-research | skill-epidemiology-implementation | epidemiology-*-agent |
| formal | skill-formal-research | - | formal-research-agent |

These skills correctly delegate to their specialized agents (e.g., `skill-z3-research` invokes `z3-research-agent` via Task tool). However, the commands never invoke these extension skills.

### 6. No Extension Registration Mechanism

Extension manifests (`manifest.json`) declare their capabilities:
```json
{
  "language": "z3",
  "provides": {
    "agents": ["z3-research-agent.md", "z3-implementation-agent.md"],
    "skills": ["skill-z3-research", "skill-z3-implementation"]
  },
  "merge_targets": {
    "index": {
      "source": "index-entries.json",
      "target": ".opencode/context/index.json"
    }
  }
}
```

But there is **no script, hook, or automated process** that:
1. Reads extension manifests
2. Merges index entries into the main context/index.json
3. Updates routing tables in orchestration-core.md
4. Updates command routing to include extension languages

### 7. Lean Extension Works Only by Coincidence

The lean extension appears to route correctly because:
1. The orchestration-core.md routing table explicitly includes lean
2. The deprecated routing.md also includes lean routing
3. Routing validation explicitly checks lean

But even lean is not routed through the extension skill path. The orchestration-core.md routing bypasses the extension skill (`skill-lean-research`) and routes directly to the agent.

### 8. README Language Routing Table is Aspirational

The `.opencode/README.md` (lines 45-52) shows a language routing table with lean, latex, typst, general, meta, neovim. The `.opencode/CLAUDE.md` equivalent (from .claude/ system) shows a much more comprehensive table with all extension languages. But neither of these tables is actually implemented in the command routing logic.

## Gap Analysis Summary

| Gap | Severity | Impact |
|-----|----------|--------|
| Commands hardcode generic skills | Critical | Extension agents never invoked |
| Routing tables incomplete | Critical | Extension languages route to generic agents |
| No extension manifest processing | High | Extensions cannot self-register |
| index-entries.json not merged | Medium | Extension context not discoverable by agents |
| Routing validation incomplete | Medium | Misrouting not detected for extension languages |
| Agent verification tables incomplete | Low | Postflight cannot verify correct agent was used |

## Recommendations

### Option A: Dynamic Extension Routing (Comprehensive)

1. **Create extension registry script** that reads all `extensions/*/manifest.json` files and generates a unified routing table
2. **Update commands** to use the registry for skill selection based on language
3. **Merge index entries** from all extensions into the main context/index.json
4. **Expand routing validation** to cover all registered languages
5. **Update agent verification** tables in research.md and implement.md

### Option B: Static Routing Table Expansion (Simpler)

1. **Update orchestration-core.md** routing table to include all extension languages
2. **Update /research command** routing table to map each language to its extension skill
3. **Update /implement command** routing table similarly
4. **Manually merge** index-entries.json from each extension
5. **Expand routing validation** for each language

### Option C: Hybrid (Recommended)

1. Expand the static routing tables in commands and orchestration-core.md to cover all current extensions
2. Create a lightweight `merge-extensions.sh` script for index.json merging
3. Add routing validation for all extension languages
4. Document the extension registration process so new extensions can be added systematically

## Decisions

- This is a research-only task; no implementation decisions made
- Recommendation is Option C (Hybrid) for balance of completeness and simplicity

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Extension skills not tested | Each extension skill is structurally identical to core skills; routing is the bottleneck |
| Breaking lean routing | Lean works today; changes must preserve existing lean routing |
| Command files becoming too large | Keep routing tables compact; use a shared routing lookup pattern |
| Missing agent files for some extensions | Verify all agent files exist before updating routing |

## Appendix

### Files Examined

**Core routing infrastructure**:
- `.opencode/context/core/orchestration/orchestration-core.md` - Main routing table
- `.opencode/context/core/orchestration/routing.md` - Deprecated routing guide
- `.opencode/context/core/patterns/context-discovery.md` - Context loading patterns
- `.opencode/context/index.json` - Main context index (22 entries)

**Commands**:
- `.opencode/commands/research.md` - Research command (hardcodes skill-researcher)
- `.opencode/commands/implement.md` - Implement command (hardcodes skill-implementer)

**Core skills**:
- `.opencode/skills/skill-researcher/SKILL.md` - Generic research skill
- `.opencode/skills/skill-implementer/SKILL.md` - Generic implementation skill
- `.opencode/skills/skill-neovim-research/SKILL.md` - Neovim research skill
- `.opencode/skills/skill-orchestrator/SKILL.md` - Routing skill

**Extension manifests and skills examined**:
- `.opencode/extensions/z3/manifest.json`, `index-entries.json`, skills, agents
- `.opencode/extensions/lean/manifest.json`, `EXTENSION.md`, skills, agents
- `.opencode/extensions/latex/manifest.json`, skills, agents

**Agent files**:
- `.opencode/agent/orchestrator.md` (read-only chat agent, not routing orchestrator)
- `.opencode/agent/subagents/` (6 core agents)
- `.opencode/extensions/*/agents/` (24 extension agents across 10 extensions)

### Key Routing Path (Current Behavior)

```
User: /research 165 (language=z3)
  -> research.md: Step 6 -> skill-researcher (hardcoded)
    -> skill-researcher: Stage 3 -> Task(subagent_type="general-research-agent")
      -> general-research-agent executes (z3 context NOT loaded)

Expected:
User: /research 165 (language=z3)
  -> research.md: Step 6 -> skill-z3-research (language-routed)
    -> skill-z3-research: Stage 4 -> Task(subagent_type="z3-research-agent")
      -> z3-research-agent executes (z3 context loaded)
```
