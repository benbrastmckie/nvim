# Research Report: Task #111 (Additional Research)

**Task**: 111 - compare_opencode_agent_systems
**Started**: 2026-03-02
**Completed**: 2026-03-02
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Direct filesystem exploration of Theory/.opencode/, nvim/.opencode/, nvim/.claude/, and nvim/.claude/extensions/
**Artifacts**: specs/111_compare_opencode_agent_systems/reports/research-002.md
**Standards**: report-format.md

## Executive Summary

- The **Theory/.opencode/** system (1016 files, 127 directories excluding specs) is the most mature .opencode/ system, with confirmed feature parity against its companion .claude/ system, deep domain context (lean4, logic, math, physics, latex, typst), Lean-specific commands (/lake, /lean), and comprehensive documentation
- **Replacing nvim/.opencode/ with Theory/.opencode/ would LOSE**: neovim-specific agents (neovim-research, neovim-implementation), web domain agents (web-research, web-implementation, website-orchestrator), the nvim extension system (6 extensions: latex, lean, python, typst, web, z3), neovim domain context (13 files), web domain context (14 files), and MCP permissions for astro-docs, context7, and playwright
- **Replacing nvim/.opencode/ with Theory/.opencode/ would GAIN**: logic-research-agent, math-research-agent, typst-research-agent, latex-research-agent, plus 7 additional specialized skills, comprehensive lean4/logic/math/typst domain context (60+ files baked into core), Lean-specific commands (/lake, /lean), parity-summary.md documentation, and execute-command.sh test infrastructure
- **Recommended approach**: Use Theory/.opencode/ as the new base for nvim/.opencode/, then port the nvim-specific elements back in as modifications. The .opencode/ system for nvim should mirror the .claude/ feature set without an extension system (since .opencode/ does not have that architecture)

## Context and Scope

This additional research focuses on three questions:

1. What is lost if nvim/.opencode/ is replaced by Theory/.opencode/?
2. What is gained from Theory/.opencode/?
3. How to achieve feature parity with nvim/.claude/ in the resulting .opencode/ system?

The prior research (research-001.md) compared nvim/.opencode/ against ProofChecker/.opencode/ and recommended nvim as the superior base. This report re-evaluates that recommendation in light of Theory/.opencode/, which the user identifies as the best system created.

## Findings

### 1. Theory/.opencode/ Architecture

Theory uses a three-layer architecture with an orchestrator-as-chat-agent pattern:

```
Layer 1: orchestrator.md (READ-ONLY chat agent, answers project questions)
Layer 2: Commands (commands/*.md) - full workflow definitions
Layer 3: Skills (skills/*.md) -> Subagents (agent/subagents/*.md)
```

Key structural decision: The orchestrator is NOT a routing hub. It is a read-only assistant (tools: read, glob, grep only; no write, edit, bash, or task). All execution flows through commands -> skills -> subagents. This is different from both:
- The ProofChecker pattern (orchestrator as pure router)
- The nvim pattern (deprecated orchestrator, direct command -> skill -> agent)

Theory's settings.json is almost identical to nvim/.opencode/settings.json:
- Same hook structure (SessionStart, UserPromptSubmit, Stop, SubagentStop, PreToolUse, PostToolUse)
- Same permission model
- Theory adds: pdflatex, latexmk, bibtex, biber permissions (for LaTeX compilation)
- Theory uses `"model": "sonnet"` vs nvim's `"theme": "gruvbox"` (different field)
- nvim adds: mcp__astro-docs__, mcp__context7__, mcp__playwright__, Bash(pnpm), Bash(npx)

### 2. What Would Be LOST Replacing nvim/.opencode/ with Theory/.opencode/

#### A. Neovim-Specific Agents (2 agents)

| Agent | Purpose | Lines |
|-------|---------|-------|
| neovim-research.md | Neovim plugin/Lua research | ~100 |
| neovim-implementation.md | Neovim configuration implementation | ~100 |

These are the core agents for this repository's primary purpose. Theory has no equivalent.

#### B. Web-Specific Agents (3 agents)

| Agent | Purpose | Lines |
|-------|---------|-------|
| web-research.md | Web tech (Astro, Tailwind) research | ~100 |
| web-implementation.md | Web implementation | ~100 |
| website-orchestrator.md | DEPRECATED central orchestrator | ~100 |

These support the personal website project. Theory has no web domain.

#### C. Extension System (6 extensions)

The nvim/.opencode/extensions/ directory provides modular language support:

| Extension | Agents | Context Files | Rules | Skills |
|-----------|--------|---------------|-------|--------|
| lean | 2 | 3+ | 1 | 0 |
| latex | (via core) | (via core) | (via core) | 0 |
| python | (via context) | 6+ | 0 | 0 |
| typst | (via core) | (via core) | 0 | 0 |
| web | (via core context) | 14+ | 0 | 0 |
| z3 | (via context) | 2+ | 0 | 0 |

Theory has NO extension system. All its domain knowledge is embedded directly in core context directories. This means if you replace nvim/.opencode/ with Theory/.opencode/, the extension architecture pattern is lost.

**However**: The extension system in nvim/.opencode/ is much thinner than the one in nvim/.claude/. The .claude/ extensions contain full agents, skills, commands, rules, and context. The .opencode/ extensions primarily just contain agents, context files, and rules, with no skills or commands.

#### D. Neovim Domain Context (13 files)

```
context/project/neovim/
  domain/lsp-overview.md, lua-patterns.md, neovim-api.md, plugin-ecosystem.md
  patterns/autocommand-patterns.md, ftplugin-patterns.md, keymap-patterns.md, plugin-spec.md
  standards/lua-style-guide.md, testing-patterns.md
  templates/ftplugin-template.md, plugin-template.md
  tools/lazy-nvim-guide.md, telescope-guide.md, treesitter-guide.md
  README.md, lua-patterns.md (top-level)
```

This is the heart of the nvim repository's domain knowledge. Theory has none of it.

#### E. Web Domain Context (14+ files)

```
context/project/web/
  domain/astro-framework.md, cloudflare-pages.md, tailwind-v4.md, typescript-web.md
  patterns/accessibility-patterns.md, astro-component.md, astro-content-collections.md, etc.
  standards/accessibility-standards.md, performance-standards.md, web-style-guide.md
  templates/astro-component-template.md, astro-page-template.md
  tools/astro-cli-guide.md, cloudflare-deploy-guide.md, pnpm-guide.md
```

Theory has no web domain context.

#### F. Hooks Context

`context/project/hooks/wezterm-integration.md` - WezTerm integration documentation. Theory's hooks are functionally identical (same 9 hook scripts) but lacks this documentation file.

#### G. nvim-Specific MCP Permissions

nvim/.opencode/settings.json grants access to:
- `mcp__astro-docs__*` - Astro documentation server
- `mcp__context7__*` - Context7 documentation server
- `mcp__playwright__*` - Playwright browser automation
- `Bash(pnpm *)` - pnpm package manager
- `Bash(npx *)` - npx package runner

Theory does not have these (no web development context).

#### H. Code Reviewer Agent

nvim/.opencode/ has a `code-reviewer.md` agent. Theory does not.

#### I. build-prompt.txt

nvim/.opencode/agents/ contains `build-prompt.txt`, a utility for prompt generation. Theory does not have this.

### 3. What Would Be GAINED from Theory/.opencode/

#### A. Specialized Research Agents (4 additional agents)

| Agent | Purpose | Not in nvim/.opencode/ |
|-------|---------|----------------------|
| logic-research-agent.md | Formal mathematical logic research | Correct |
| math-research-agent.md | Mathematical foundations research | Correct |
| latex-research-agent.md | LaTeX documentation research | Correct |
| typst-research-agent.md | Typst documentation research | Correct |

nvim/.opencode/ has only general-research.md for non-neovim/web research.

#### B. Specialized Skills (7 additional skills)

| Skill | Purpose |
|-------|---------|
| skill-logic-research | Route to logic-research-agent |
| skill-math-research | Route to math-research-agent |
| skill-latex-research | Route to latex-research-agent |
| skill-latex-implementation | Route to latex-implementation-agent |
| skill-typst-research | Route to typst-research-agent |
| skill-typst-implementation | Route to typst-implementation-agent |
| skill-lake-repair | Lean build with error repair |
| skill-lean-version | Lean toolchain management |
| skill-lean-research | Lean-specific research |
| skill-lean-implementation | Lean-specific implementation |
| skill-git-workflow | Scoped git commits |
| skill-learn | FIX:/NOTE:/TODO: tag scanning |

nvim/.opencode/ has 14 skills; Theory has 20.

#### C. Lean-Specific Commands (2 additional commands)

| Command | Purpose |
|---------|---------|
| /lake | Build Lean project with automatic error repair |
| /lean | Manage Lean toolchain and Mathlib versions |

nvim/.opencode/ has 12 commands; Theory has 14+.

#### D. Deep Domain Context (60+ files vs nvim's ~13 neovim + 14 web)

Theory provides comprehensive baked-in domain knowledge:

- **lean4/** (22 files): syntax, Mathlib, tactics, proof workflows, MCP tools, style guides, templates
- **logic/** (16 files): Kripke semantics, modal logic, temporal logic, bilateral semantics, proof theory, verification
- **math/** (11 files): algebra, category theory (5 files), lattice theory, order theory, topology, set theory
- **physics/** (1 file): dynamical systems
- **latex/** (8 files): patterns, standards, templates, tools
- **typst/** (15 files): patterns, standards, templates, tools, comparison docs
- **meta/** (6 files): architecture principles, domain patterns, standards checklist

#### E. Confirmed Feature Parity with .claude/

Theory's parity-summary.md documents formal verification that Theory/.opencode/ has achieved parity with its .claude/ companion:
- 14 agents at parity (all 200+ lines)
- 20 skills at parity
- 14+ commands at parity
- 4 WezTerm hooks at parity
- Core and project context at parity

This means Theory is the most battle-tested .opencode/ system.

#### F. Test Infrastructure

- `scripts/execute-command.sh` - Main command router
- `scripts/test-command.sh` - Command testing
- `scripts/test-execution.sh` - Execution testing
- `scripts/test-execution-system.sh` - System-level testing
- `scripts/test-results.md` - Test results documentation
- `scripts/validate-docs.sh` - Documentation validation

nvim/.opencode/ has no test scripts.

#### G. Documentation

Theory has `docs/parity-summary.md` and `QUICK-START.md` that nvim lacks.

#### H. Task Numbering with OC_ Prefix

Theory uses `OC_` prefix for task numbers (e.g., `OC_017`), which disambiguates .opencode/ tasks from .claude/ tasks when both systems coexist. nvim/.opencode/ uses the same numbering space as .claude/, which causes confusion.

### 4. Comparison: nvim/.claude/ vs Theory/.opencode/ (Feature Parity Target)

For the new nvim/.opencode/ to achieve parity with nvim/.claude/, it needs:

#### A. Core Components (Theory provides)

| Component | nvim/.claude/ | Theory/.opencode/ | Gap |
|-----------|---------------|-------------------|-----|
| General research agent | Yes | Yes | None |
| General implementation agent | Yes | Yes | None |
| Planner agent | Yes | Yes | None |
| Meta builder agent | Yes | Yes | None |
| skill-researcher | Yes | Yes | None |
| skill-planner | Yes | Yes | None |
| skill-implementer | Yes | Yes | None |
| skill-meta | Yes | Yes | None |
| skill-status-sync | Yes | Yes | None |
| skill-refresh | Yes | Yes | None |
| skill-git-workflow | Yes | Yes | None |
| /task, /research, /plan, /implement | Yes | Yes | None |
| /revise, /review, /todo, /errors | Yes | Yes | None |
| /meta, /learn, /refresh | Yes | Yes | None |
| WezTerm hooks (4) | Yes | Yes | None |
| TTS notification | Yes | Yes | None |
| State sync validation | Yes | Yes | None |

#### B. Neovim-Specific Components (nvim must add to Theory base)

| Component | nvim/.claude/ | Theory/.opencode/ | Action Needed |
|-----------|---------------|-------------------|---------------|
| neovim-research-agent | Yes | No | Create from nvim/.opencode/ |
| neovim-implementation-agent | Yes | No | Create from nvim/.opencode/ |
| skill-neovim-research | Yes | No | Create |
| skill-neovim-implementation | Yes | No | Create |
| Neovim domain context (13 files) | Yes | No | Port from nvim/.opencode/ |

#### C. Extension-Provided Components in .claude/ (must become core in .opencode/)

The nvim/.claude/ has rich extensions that provide capabilities. Since .opencode/ has no extension system, these must be incorporated directly:

| Extension | .claude/ Extensions | Action for .opencode/ |
|-----------|--------------------|-----------------------|
| lean | agents, skills, commands, context, rules | Already in Theory core |
| latex | agents, skills, context, rules | Already in Theory core |
| typst | agents, skills, context | Already in Theory core |
| formal (logic/math/physics) | agents, skills, context | Already in Theory core |
| python | agents, skills, context | NOT in Theory; add if needed |
| web | agents, skills, context, rules | NOT in Theory; add from nvim/.opencode/ |
| nix | agents, skills, context, rules | NOT in Theory; add if needed |
| z3 | agents, skills, context | NOT in Theory; add if needed |
| document-converter | agent, skill, command | Already in Theory core |

#### D. Documentation Parity

| Component | nvim/.claude/ | Theory/.opencode/ | Gap |
|-----------|---------------|-------------------|-----|
| system-overview.md | Yes | Yes | None |
| creating-agents.md | Yes | Yes | None |
| creating-commands.md | Yes | Yes | None |
| creating-skills.md | Yes | Yes | None |
| user-guide.md | Yes | Yes | None |
| user-installation.md | Yes | Yes | None |
| component-selection.md | Yes | Yes | None |
| parity-summary.md | No | Yes | Theory ahead |
| QUICK-START.md | No | Yes | Theory ahead |
| adding-domains.md | Yes | No | Gap in Theory |
| context-loading-best-practices.md | Yes | No | Gap in Theory |
| copy-claude-directory.md | Yes | No | nvim-specific |
| neovim-integration.md | Yes | No | nvim-specific |
| permission-configuration.md | Yes | No | Gap in Theory |
| tts-stt-integration.md | Yes | No | Gap in Theory |
| multi-task-creation-standard.md | Yes | No | Gap in Theory |
| agent-frontmatter-standard.md | Yes | No | Gap in Theory |

#### E. Unique .claude/ Features Not in .opencode/

| Feature | .claude/ | .opencode/ | Notes |
|---------|----------|------------|-------|
| Extension system (manifest.json) | Yes | No | .opencode/ embeds all in core |
| index.json (JSON context index) | Yes | index.md (markdown) | Different format |
| Notification hook | Yes | No | .claude/ has TTS on permission_prompt/idle_prompt |
| model: field in agent frontmatter | Yes | No | .claude/ enforces opus for research/planning |
| context-discovery.md pattern | Yes | No | .claude/ uses jq queries on index.json |
| docs/templates/ directory | Yes | No | .claude/ has agent-template.md, command-template.md |
| Multi-task creation standard | Yes | No | .claude/ documents 8-component pattern |
| settings.local.json | Yes | No | .claude/ has local override settings |
| .gitignore | Yes | Yes | Both have it |

### 5. OpenCode-Specific Elements That Must Be Preserved

When creating the new nvim/.opencode/, these elements are specific to OpenCode (not Claude Code) and must NOT be disrupted:

1. **Directory structure**: `.opencode/` not `.claude/`; `agent/` not `agents/`; subagents in `agent/subagents/`
2. **OPENCODE.md**: The main configuration file (equivalent to CLAUDE.md)
3. **Context index format**: `context/index.md` (markdown) not `index.json` (JSON)
4. **Orchestrator pattern**: Read-only chat agent in `agent/orchestrator.md`
5. **settings.json format**: OpenCode-native hook format and permissions
6. **Task prefix**: `OC_` prefix for task numbers to disambiguate from .claude/ tasks
7. **Commit format**: `Co-Authored-By: OpenCode <noreply@opencode.ai>` (not Claude)
8. **Package management**: `package.json` and `bun.lock` (OpenCode uses bun/npm ecosystem)
9. **node_modules/**: OpenCode plugin infrastructure
10. **Skill structure**: `skills/skill-*/SKILL.md` format
11. **Templates directory**: `templates/settings.json` for new project setup
12. **Systemd files**: `systemd/opencode-refresh.{service,timer}` for automated maintenance

### 6. Recommended Migration Strategy

#### Phase 1: Copy Theory/.opencode/ as base

Copy the entire Theory/.opencode/ directory to nvim/.opencode/, preserving:
- All core agents and subagents
- All skills (20 skills)
- All commands (14+ commands)
- All hooks (9 hooks)
- All core context (50+ files)
- All project context (lean4, logic, math, physics, latex, typst)
- All rules, scripts, docs, templates, systemd files
- settings.json, OPENCODE.md, README.md, QUICK-START.md

#### Phase 2: Add nvim-specific agents

Create or port from existing nvim/.opencode/:
1. `agent/subagents/neovim-research-agent.md` - Port from nvim/.opencode/agents/neovim-research.md
2. `agent/subagents/neovim-implementation-agent.md` - Port from nvim/.opencode/agents/neovim-implementation.md

#### Phase 3: Add nvim-specific skills

Create:
1. `skills/skill-neovim-research/SKILL.md`
2. `skills/skill-neovim-implementation/SKILL.md`

#### Phase 4: Add nvim domain context

Port from existing nvim/.opencode/:
```
context/project/neovim/ (entire directory, 13+ files)
```

#### Phase 5: Add web domain context (if needed)

Port from existing nvim/.opencode/:
```
context/project/web/ (entire directory, 14+ files)
agent/subagents/web-research-agent.md
agent/subagents/web-implementation-agent.md
skills/skill-web-research/SKILL.md
skills/skill-web-implementation/SKILL.md
```

#### Phase 6: Update OPENCODE.md

Update the main configuration to reference:
- Neovim project structure (not Lean/Theories)
- Neovim language routing (language: neovim, web)
- nvim-specific MCP servers (astro-docs, context7, playwright)
- nvim-specific bash permissions (pnpm, npx)
- Updated skill-to-agent mapping table
- Updated context imports section

#### Phase 7: Update settings.json

Add nvim-specific permissions:
```json
"mcp__astro-docs__*",
"mcp__context7__*",
"mcp__playwright__*",
"Bash(pnpm *)",
"Bash(npx *)"
```

#### Phase 8: Update project-overview.md

Replace Theory's project-overview.md with nvim-specific repository documentation.

#### Phase 9: Remove Theory-specific elements

- Remove or mark as optional: `context/project/physics/` (not relevant to nvim)
- Update `context/project/repo/project-overview.md` for nvim repository
- Consider whether logic/math context is relevant (it IS relevant if nvim is used for Lean projects)

### 7. What NOT to Change

These elements should remain exactly as Theory provides them:
- Core orchestration patterns (context/core/)
- Hook scripts (hooks/)
- Core standards and templates
- Skill lifecycle patterns
- Postflight and preflight patterns
- Git workflow and state management rules
- Systemd service definitions
- Test scripts

## Decisions

1. **Use Theory/.opencode/ as the base**: It is the most mature, battle-tested system with confirmed feature parity against its .claude/ companion
2. **Port nvim-specific agents**: Create neovim-research and neovim-implementation subagents
3. **Port nvim-specific context**: Keep all 13+ neovim domain context files
4. **Keep web context optional**: Only port web agents/context if the personal website project is actively developed from the nvim directory
5. **Keep all Theory domain context**: lean4, logic, math, latex, typst context is valuable when using nvim to work on formal methods projects
6. **Do NOT add extension system to .opencode/**: The extension pattern is a .claude/ innovation; .opencode/ embeds everything in core, which is simpler
7. **Preserve OC_ task prefix**: This is critical for disambiguating .opencode/ tasks from .claude/ tasks

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Lost nvim-specific agents | High if not ported | High | Phase 2 explicitly creates these |
| Lost web domain context | Medium | Low-Medium | Phase 5 is optional but documented |
| OPENCODE.md references Lean/Theory | High if not updated | Medium | Phase 6 updates all references |
| settings.json missing nvim MCP servers | High if not updated | Medium | Phase 7 adds permissions |
| Shared specs/ directory conflicts | Medium | High | OC_ prefix prevents collision |
| Stale project-overview.md | High | Low | Phase 8 updates it |

## Appendix

### File Counts Comparison (excluding node_modules and specs)

| System | Files | Directories | Agents | Skills | Commands | Context |
|--------|-------|-------------|--------|--------|----------|---------|
| Theory/.opencode/ | ~200 | ~127 | 14 | 20 | 14 | 85+ |
| nvim/.opencode/ | ~180 | ~115 | 12 | 14 | 12 | 70+ |
| nvim/.claude/ (core) | ~80 | ~35 | 6 | 11 | 11 | 30+ |
| nvim/.claude/ (with extensions) | ~200+ | ~80+ | 20+ | 25+ | 13 | 80+ |

### Search Queries Used

1. `find` commands to enumerate all files in Theory/.opencode/, nvim/.opencode/, nvim/.claude/, nvim/.claude/extensions/
2. Direct `Read` of: OPENCODE.md (Theory), settings.json (Theory, nvim/.opencode, nvim/.claude), orchestrator.md (Theory), routing.md (Theory), orchestration-core.md (Theory), subagents/README.md, lean-research-agent.md, logic-research-agent.md, math-research-agent.md, neovim-research.md, website-orchestrator.md, parity-summary.md, README.md (Theory), QUICK-START.md, extension manifests
3. Directory structure analysis of all agent/, command/, skill/, context/, docs/, hooks/ directories across all three systems
