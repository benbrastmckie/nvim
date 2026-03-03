# Research Report: Task #113 - Feature Parity Analysis

**Task**: 113 - review_proofchecker_opencode_virtues
**Started**: 2026-03-02T00:00:00Z
**Completed**: 2026-03-02T00:30:00Z
**Effort**: 1-2 hours
**Dependencies**: Task 111 (completed)
**Sources/Inputs**: Codebase analysis of nvim/.claude/ and nvim/.opencode/ directories
**Artifacts**: This report
**Standards**: report-format.md

---

## Executive Summary

- The .opencode/ system (321 files, 16 agents, 22 skills) has achieved baseline functional parity with .claude/ core (6 agents, 11 skills) but falls significantly short when compared against .claude/ with extensions (25 agents, 32 skills across 9 extension domains)
- The single largest architectural gap is the absence of an **extension system** in .opencode/ -- all domain-specific content lives flat in the main directories instead of being modular and composable
- **Context discovery** differs fundamentally: .claude/ uses machine-readable `index.json` with jq queries; .opencode/ uses human-readable `index.md` with manual lookup
- Several important documentation, patterns, and configuration features from .claude/ are absent in .opencode/
- The .opencode/ system has some unique assets (.opencode-specific patterns like blocked-mcp-tools.md, code-reviewer-agent) that could be backported to .claude/

---

## Context and Scope

This analysis compares nvim/.opencode/ (post-task-111 migration from Theory/.opencode/ base) against nvim/.claude/ to identify remaining feature gaps. The .claude/ system was recently restructured (task 110) to separate extension files from core, creating a modular extension architecture.

### Methodology

1. Full directory tree comparison of both systems
2. File-by-file component matching (agents, skills, commands, rules, hooks, scripts, context, docs)
3. Configuration comparison (settings.json, OPENCODE.md vs CLAUDE.md)
4. Architectural pattern analysis

---

## Findings

### 1. Extension System Architecture (CRITICAL GAP)

**.claude/ has a modular extension system; .opencode/ does not.**

The .claude/ system organizes domain-specific content into self-contained extension packages under `.claude/extensions/`:

```
.claude/extensions/
  document-converter/  (agents/, commands/, skills/)
  formal/              (agents/, context/, skills/)
  latex/               (agents/, context/, rules/, skills/)
  lean/                (agents/, commands/, context/, hooks/, rules/, scripts/, skills/)
  nix/                 (agents/, context/, rules/, skills/)
  python/              (agents/, context/, skills/)
  typst/               (agents/, context/, skills/)
  web/                 (agents/, context/, rules/, skills/)
  z3/                  (agents/, context/, skills/)
```

Each extension is a mini-package containing all components needed for that domain. This provides:
- Clean separation of concerns (core vs domain-specific)
- Easy addition/removal of domain support
- Smaller core footprint (6 agents vs 25 total)
- Portable extensions across projects

The .opencode/ system has all content flat in the main directories (16 agents in agent/subagents/, 22 skills in skills/, etc.). This makes it harder to identify which components are core vs domain-specific.

**Impact**: High -- affects maintainability, portability, and clarity of the system boundary.

### 2. Context Discovery Mechanism (SIGNIFICANT GAP)

**.claude/ uses index.json (machine-readable); .opencode/ uses index.md (human-readable)**

The .claude/ `index.json` (56KB) provides structured metadata for each context file:
```json
{
  "path": "core/checkpoints/checkpoint-gate-in.md",
  "domain": "core",
  "subdomain": "checkpoints",
  "topics": ["preflight", "validation", "session-id"],
  "keywords": ["GATE IN", "preflight", "status update"],
  "summary": "GATE IN preflight validation pattern",
  "line_count": 80,
  "load_when": {
    "agents": ["general-implementation-agent", "neovim-implementation-agent"],
    "commands": ["/implement"]
  }
}
```

This enables programmatic context discovery:
```bash
jq -r '.entries[] | select(.load_when.agents[]? == "neovim-research-agent") | .path' .claude/context/index.json
```

The .opencode/ `index.md` (665 lines) is a human-readable guide organized by section with descriptions, but requires manual parsing. There is no equivalent to `validate-context-index.sh` or the jq-based discovery patterns documented in `.claude/context/core/patterns/context-discovery.md`.

**Impact**: Medium-High -- agents in .claude/ can dynamically discover relevant context with budget-aware loading; .opencode/ agents must rely on hardcoded or manually-maintained references.

### 3. Missing Agents from .claude/ Extensions (10 agents)

The following agents exist in .claude/ extensions but have no .opencode/ equivalent:

| Agent | Extension | Purpose |
|-------|-----------|---------|
| python-research-agent | python | Python research |
| python-implementation-agent | python | Python implementation |
| web-research-agent | web | Web/Astro research |
| web-implementation-agent | web | Web/Astro implementation |
| formal-research-agent | formal | Formal methods research (umbrella) |
| physics-research-agent | formal | Physics domain research |
| z3-research-agent | z3 | Z3/SMT research |
| z3-implementation-agent | z3 | Z3/SMT implementation |
| nix-research-agent | nix | Nix/NixOS research |
| nix-implementation-agent | nix | Nix/NixOS implementation |

The .opencode/ system does have one unique agent: **code-reviewer-agent** (not in .claude/).

**Impact**: Medium -- these are domain-specific agents that would be needed when working in those languages. The .opencode/ system covers lean, latex, typst, logic, math, and neovim domains already.

### 4. Missing Skills from .claude/ Extensions (10 skills)

Matching the missing agents, these skills are absent:

| Skill | Extension |
|-------|-----------|
| skill-python-research | python |
| skill-python-implementation | python |
| skill-web-research | web |
| skill-web-implementation | web |
| skill-formal-research | formal |
| skill-physics-research | formal |
| skill-z3-research | z3 |
| skill-z3-implementation | z3 |
| skill-nix-research | nix |
| skill-nix-implementation | nix |

**Impact**: Medium -- same as missing agents above.

### 5. Missing Context Domains (4 domains)

| Domain | Files in .claude/extensions | .opencode/ Status |
|--------|---------------------------|-------------------|
| nix | 8 files (domain, patterns, standards, tools) | Missing entirely |
| python | 6 files (domain, patterns, standards) | Missing entirely |
| physics | 1 file (dynamical-systems) | Missing entirely |
| z3 | 4 files (domain, patterns) | Missing entirely |

**Impact**: Low-Medium -- only relevant if working in those domains.

### 6. Missing Documentation (11 docs)

**.claude/-only documentation files**:

| File | Purpose | Impact |
|------|---------|--------|
| docs/examples/learn-flow-example.md | End-to-end /learn flow | Low |
| docs/examples/research-flow-example.md | End-to-end /research flow | Medium |
| docs/guides/adding-domains.md | How to add new domain support | High |
| docs/guides/context-loading-best-practices.md | Context loading optimization | Medium |
| docs/guides/copy-claude-directory.md | System replication guide | Medium |
| docs/guides/development/context-index-migration.md | Migration to index.json | Medium |
| docs/guides/neovim-integration.md | Neovim-specific integration | Medium |
| docs/guides/permission-configuration.md | Permission setup guide | Medium |
| docs/guides/tts-stt-integration.md | TTS/STT voice integration | Low |
| docs/reference/standards/agent-frontmatter-standard.md | Agent frontmatter spec | High |
| docs/reference/standards/multi-task-creation-standard.md | Multi-task creation | Medium |
| docs/templates/agent-template.md | Agent creation template | Medium |
| docs/templates/command-template.md | Command creation template | Medium |

**Impact**: Medium overall -- the missing "adding-domains" and "agent-frontmatter-standard" guides are the most significant gaps.

### 7. Missing Context Patterns and Files

**.claude/-only context files**:

| File | Purpose |
|------|---------|
| context/core/patterns/context-discovery.md | jq query patterns for index.json |
| context/core/patterns/early-metadata-pattern.md | Interruption recovery pattern |
| context/core/troubleshooting/workflow-interruptions.md | Troubleshooting guide |
| context/project/hooks/wezterm-integration.md | WezTerm hook documentation |
| context/project/repo/update-project.md | Project overview generation |

The .opencode/ system has some unique patterns:
| File | Purpose |
|------|---------|
| context/core/patterns/blocked-mcp-tools.md | MCP tool safety documentation |
| context/core/patterns/mcp-tool-recovery.md | MCP error recovery patterns |
| context/core/patterns/command-execution.sh | Shell execution patterns |
| context/core/patterns/core-command-execution.sh | Core execution patterns |
| context/core/patterns/lean-command-execution.sh | Lean-specific execution |

**Impact**: Medium -- the early-metadata-pattern is important for agent robustness.

### 8. Missing Scripts (4 scripts)

**.claude/-only scripts**:

| Script | Purpose |
|--------|---------|
| export-to-markdown.sh | Export .claude/ to consolidated markdown |
| update-plan-status.sh | Programmatic plan status updates |
| validate-context-index.sh | Validate index.json paths exist |
| migrate-directory-padding.sh | Migration utility |

**.opencode/-unique scripts**:

| Script | Purpose |
|--------|---------|
| execute-command.sh | Command execution wrapper |
| test-command.sh | Command testing |
| test-execution.sh | Execution testing |
| test-execution-system.sh | System-level execution testing |
| validate-docs.sh | Documentation validation |

**Impact**: Low-Medium -- the validate-context-index.sh would become relevant only if .opencode/ migrates to index.json.

### 9. Configuration Differences (settings.json)

Key differences in settings.json:

| Feature | .claude/ | .opencode/ |
|---------|----------|------------|
| Notification hook | Yes (TTS on permission_prompt, idle_prompt) | No |
| SessionStart wildcard matcher | Yes (wezterm-clear-task-number on all) | No (only startup) |
| Ready signal hook | Yes (claude-ready-signal.sh) | No |
| nvim/luac permissions | No | Yes |
| pnpm/npx permissions | No | Yes |
| MCP permissions (astro-docs, context7, playwright) | No | Yes |

The .opencode/ system has broader tool permissions (nvim, luac, pnpm, npx, additional MCP tools) while .claude/ has more hook integration points.

**Impact**: Low -- the Notification hook is a convenience feature; the permission differences reflect different tool usage patterns.

### 10. OPENCODE.md vs CLAUDE.md Feature Coverage

| Feature | CLAUDE.md | OPENCODE.md | Gap |
|---------|-----------|-------------|-----|
| Multi-Task Creation Standards | Full section | Missing | Yes |
| Model Enforcement (opus/sonnet) | Documented per-skill | Not documented | Yes |
| Context Discovery (index.json) | Full section with jq patterns | Not documented | Yes |
| Extension system mention | Documented | Not applicable | N/A |
| roadmap_items in state.json | Documented | Missing | Minor |
| Padding convention ({N} vs {NNN}) | Explicit note | Documented differently | Minor |

### 11. Rules Parity

Both systems have equivalent core rules (6 in .claude/, 8 in .opencode/ -- .opencode/ includes latex.md and lean4.md which are in .claude/ extensions). The .claude/ extensions add nix.md and web-astro.md rules not in .opencode/.

---

## Recommendations

### Priority 1: High Impact, Moderate Effort

1. **Implement Extension System for .opencode/**
   - Create `.opencode/extensions/` directory structure mirroring .claude/
   - Move domain-specific content (lean4, latex, typst, logic, math, web) into extensions
   - Keep core agents/skills/commands minimal
   - Effort: 4-6 hours

2. **Migrate Context Index to JSON Format**
   - Create `.opencode/context/index.json` from current index.md
   - Add context-discovery.md query patterns
   - Create validate-context-index.sh validation script
   - Effort: 2-3 hours

3. **Add Early Metadata Pattern Documentation**
   - Port `early-metadata-pattern.md` to .opencode/context/core/patterns/
   - Port `workflow-interruptions.md` troubleshooting guide
   - Effort: 0.5 hours

### Priority 2: Medium Impact, Low Effort

4. **Add Missing Guide Documentation**
   - Port `adding-domains.md` (critical for extension system)
   - Port `agent-frontmatter-standard.md` (agent quality standard)
   - Port `context-loading-best-practices.md`
   - Port `permission-configuration.md`
   - Effort: 2-3 hours

5. **Add Notification Hook to settings.json**
   - Port the Notification hook configuration for TTS alerts
   - Add SessionStart wildcard matcher for wezterm-clear-task-number
   - Effort: 0.5 hours

6. **Add docs/templates/ Directory**
   - Port agent-template.md and command-template.md
   - Create README.md for templates
   - Effort: 1 hour

### Priority 3: Low Impact or Domain-Specific

7. **Add Missing Domain Extensions (as needed)**
   - nix, python, z3, physics domains
   - Only add when project actually uses these domains
   - Effort: 1-2 hours per domain

8. **Port Missing Scripts**
   - export-to-markdown.sh (useful for documentation)
   - update-plan-status.sh (useful for automation)
   - Effort: 1-2 hours

9. **Update OPENCODE.md**
   - Add Multi-Task Creation Standards section
   - Add Model Enforcement documentation
   - Add Context Discovery section (after index.json migration)
   - Effort: 1 hour

---

## Decisions

1. The extension system architecture should be considered the highest-priority improvement as it affects the long-term maintainability and composability of the .opencode/ system
2. Context discovery via index.json is the second-highest priority as it enables programmatic context loading that improves agent efficiency
3. Missing domain-specific agents/skills/context (nix, python, z3, physics) should only be added when those domains are actively used -- not preemptively
4. The code-reviewer-agent unique to .opencode/ should be preserved and potentially backported to .claude/

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Extension migration breaks existing workflows | Medium | High | Test each extension independently, migrate one at a time |
| index.json migration creates inconsistencies | Low | Medium | Use validate-context-index.sh to verify after migration |
| Missing docs cause agent failures | Low | Low | Agents fall back to codebase patterns when docs missing |
| Permission differences cause tool failures | Low | Medium | Compare settings.json carefully before using tools |

---

## Appendix

### Component Count Summary

| Category | .claude/ (core) | .claude/ (with ext) | .opencode/ | Gap (vs full .claude/) |
|----------|----------------|---------------------|------------|----------------------|
| Agents | 6 | 25 | 16 | -9 |
| Commands | 11 | 14 | 14 | 0 |
| Skills | 11 | 32 | 22 | -10 |
| Rules | 6 | 10 | 8 | -2 |
| Context files | 97 | 221 | 196 | -25 |
| Docs | 22 | 22 | 11 | -11 |
| Hooks | 9 | 9 | 9 | 0 |
| Scripts | 12 | 14 | 13 | -1 |
| **Total** | **174** | **347** | **289** | **-58** |

### Search Queries Used
- `find` for directory tree comparison
- `diff` for file listing comparison
- `ls` for directory enumeration
- Direct file reads for configuration comparison

### References
- `.opencode/docs/parity-summary.md` - Previous parity analysis (2026-02-28)
- `.claude/context/core/patterns/context-discovery.md` - Context discovery patterns
- `.claude/context/core/patterns/early-metadata-pattern.md` - Early metadata pattern
- `.claude/CLAUDE.md` - Current .claude/ configuration
- `.opencode/OPENCODE.md` - Current .opencode/ configuration
