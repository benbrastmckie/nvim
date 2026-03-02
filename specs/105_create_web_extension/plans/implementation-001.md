# Implementation Plan: Task #105 - Create web/ extension from Logos Website .claude configuration

- **Task**: 105 - Create web/ extension from Logos Website .claude configuration
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5-3.5 hours
- **Dependencies**: None (follows pattern established by task 102)
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a `.claude/extensions/web/` extension by extracting and generalizing web development components from the Logos Website `.claude/` configuration at `/home/benjamin/Projects/Logos/Website/.claude/`. The extension includes 24 files total: manifest.json, EXTENSION.md, index-entries.json, 2 agents, 2 skills, 1 rule, and 16 context files covering Astro, Tailwind CSS v4, TypeScript, Cloudflare Pages, accessibility, and performance. Research confirms all source files are substantially project-agnostic; generalization consists primarily of replacing "Logos" branding with generic placeholders and converting core-system path references to extension-relative paths.

### Research Integration

Integrated findings from [research-001.md](../reports/research-001.md):
- Source inventory: 2 agents, 2 skills, 1 rule, 18 context files (including README)
- Generalization assessment: 6 files need no changes, 14 need minor de-branding
- Agent changes: Remove `.claude/context/core/` path references, use extension-relative paths
- No MCP servers in manifest (Astro Docs MCP is optional project-level config)
- Use "web" as language identifier

## Goals & Non-Goals

**Goals**:
- Create a self-contained web extension following the established extension pattern (lean, latex, typst, z3, python, formal)
- Extract all web-relevant agents, skills, rules, and context from the Logos Website source
- Generalize all content to be project-agnostic (no "Logos" branding, no project-specific paths)
- Produce a manifest.json, EXTENSION.md, and index-entries.json consistent with existing extensions

**Non-Goals**:
- Adding MCP server declarations (Astro Docs MCP is project-level, not extension-level)
- Creating extension-specific slash commands (web tasks use standard /research, /plan, /implement)
- Adding scripts or hooks (none present in source)
- Testing the extension in a live web project (verification is structural only)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Context files reference `.claude/context/core/` paths that do not exist at extension scope | Medium | Medium | Review all `@.claude/context/core/` references in agents; convert to notes about core system or remove |
| Agent files reference project-specific MCP tools (Astro Docs MCP) | Low | Medium | Agents already include fallback patterns (WebSearch when MCP unavailable); keep as optional |
| Large volume of files (24 total) increases risk of inconsistency | Medium | Low | Group files by category in phases; verify each phase before proceeding |
| Tailwind v4 content may confuse v3 users | Low | Low | Extension name and docs clearly state "Tailwind CSS v4" |

## Implementation Phases

### Phase 1: Directory Structure and Metadata Files [COMPLETED]

- **Goal:** Create the extension directory tree, manifest.json, EXTENSION.md, and index-entries.json
- **Tasks:**
  - [ ] Create full directory structure under `.claude/extensions/web/` (agents/, skills/skill-web-implementation/, skills/skill-web-research/, rules/, context/project/web/domain/, context/project/web/patterns/, context/project/web/standards/, context/project/web/tools/, context/project/web/templates/)
  - [ ] Create `manifest.json` following the schema from research (name: "web", language: "web", 2 agents, 2 skills, 1 rule, no MCP servers, no commands/scripts/hooks)
  - [ ] Create `EXTENSION.md` with language routing table, skill-agent mapping, build verification commands, and key technologies
  - [ ] Create `index-entries.json` with entries for all 18 context files, mapping each to appropriate agents and language "web"
- **Timing:** 30 minutes
- **Files to create:**
  - `.claude/extensions/web/manifest.json`
  - `.claude/extensions/web/EXTENSION.md`
  - `.claude/extensions/web/index-entries.json`
- **Verification:**
  - manifest.json is valid JSON with all required fields
  - EXTENSION.md follows lean extension pattern
  - index-entries.json has 18 entries with correct agent/language mappings

---

### Phase 2: Agents [COMPLETED]

- **Goal:** Create the two web agents (implementation and research) by adapting source agents to be project-agnostic with extension-relative paths
- **Tasks:**
  - [ ] Read source agent: `/home/benjamin/Projects/Logos/Website/.claude/agents/web-implementation-agent.md`
  - [ ] Adapt web-implementation-agent.md: Remove `.claude/context/core/` path references, replace Logos-specific deployment details, convert context references to extension-relative paths, ensure standard subagent pattern (Stages 0-8, metadata file return)
  - [ ] Read source agent: `/home/benjamin/Projects/Logos/Website/.claude/agents/web-research-agent.md`
  - [ ] Adapt web-research-agent.md: Same generalization as implementation agent, ensure standard subagent pattern
- **Timing:** 45 minutes
- **Files to create:**
  - `.claude/extensions/web/agents/web-implementation-agent.md`
  - `.claude/extensions/web/agents/web-research-agent.md`
- **Verification:**
  - No references to "Logos" or "logos" remain in agent files
  - No references to `.claude/context/core/` paths remain
  - Both agents follow the standard subagent execution flow (parse context, load research/plan, execute, write metadata, return summary)

---

### Phase 3: Skills and Rule [NOT STARTED]

- **Goal:** Create the two skill wrappers and the Astro rule file
- **Tasks:**
  - [ ] Read source skill: `/home/benjamin/Projects/Logos/Website/.claude/skills/skill-web-implementation/SKILL.md`
  - [ ] Adapt skill-web-implementation SKILL.md: Update path references to extension-relative context, keep thin wrapper delegation pattern
  - [ ] Read source skill: `/home/benjamin/Projects/Logos/Website/.claude/skills/skill-web-research/SKILL.md`
  - [ ] Adapt skill-web-research SKILL.md: Same generalization as implementation skill
  - [ ] Read source rule: `/home/benjamin/Projects/Logos/Website/.claude/rules/web-astro.md`
  - [ ] Copy/adapt web-astro.md rule (already project-agnostic per research; verify and copy with minimal changes)
- **Timing:** 30 minutes
- **Files to create:**
  - `.claude/extensions/web/skills/skill-web-implementation/SKILL.md`
  - `.claude/extensions/web/skills/skill-web-research/SKILL.md`
  - `.claude/extensions/web/rules/web-astro.md`
- **Verification:**
  - Skills delegate to correct agent names
  - Skills follow standard preflight/delegation/postflight pattern
  - Rule file has no Logos-specific references
  - Rule file has appropriate path pattern (applies to web source files)

---

### Phase 4: Context Files - Domain and Patterns [NOT STARTED]

- **Goal:** Create the 9 context files under domain/ (4 files) and patterns/ (5 files), generalizing all Logos branding
- **Tasks:**
  - [ ] Read and adapt `domain/astro-framework.md` (no changes needed - pure framework reference)
  - [ ] Read and adapt `domain/tailwind-v4.md` (no changes needed - pure framework reference)
  - [ ] Read and adapt `domain/cloudflare-pages.md` (replace "logos" project names with generic)
  - [ ] Read and adapt `domain/typescript-web.md` (replace "Logos Team" and "Logos website" with generic)
  - [ ] Read and adapt `patterns/astro-component.md` (no changes needed - pure patterns)
  - [ ] Read and adapt `patterns/astro-layout.md` (replace "Logos Laboratories" with "Your Site Name")
  - [ ] Read and adapt `patterns/astro-content-collections.md` (replace "Logos Team" with "Team")
  - [ ] Read and adapt `patterns/tailwind-patterns.md` (replace "Logos" branding in examples)
  - [ ] Read and adapt `patterns/accessibility-patterns.md` (no changes needed - pure WCAG patterns)
- **Timing:** 45 minutes
- **Files to create:**
  - `.claude/extensions/web/context/project/web/domain/astro-framework.md`
  - `.claude/extensions/web/context/project/web/domain/tailwind-v4.md`
  - `.claude/extensions/web/context/project/web/domain/cloudflare-pages.md`
  - `.claude/extensions/web/context/project/web/domain/typescript-web.md`
  - `.claude/extensions/web/context/project/web/patterns/astro-component.md`
  - `.claude/extensions/web/context/project/web/patterns/astro-layout.md`
  - `.claude/extensions/web/context/project/web/patterns/astro-content-collections.md`
  - `.claude/extensions/web/context/project/web/patterns/tailwind-patterns.md`
  - `.claude/extensions/web/context/project/web/patterns/accessibility-patterns.md`
- **Verification:**
  - No references to "Logos", "logos-labs.com", or "logos-laboratories.com" remain
  - Framework and pattern content is preserved intact
  - Files that needed no changes are exact copies of source

---

### Phase 5: Context Files - Standards, Tools, and Templates [NOT STARTED]

- **Goal:** Create the remaining 7 context files under standards/ (3 files), tools/ (5 files), and templates/ (2 files), plus the README
- **Tasks:**
  - [ ] Read and adapt `standards/web-style-guide.md` (replace "Logos website" with "website")
  - [ ] Read and adapt `standards/performance-standards.md` (replace "Logos Website" with "website")
  - [ ] Read and adapt `standards/accessibility-standards.md` (replace "Logos Laboratories" with "Your Organization")
  - [ ] Read and adapt `tools/astro-cli-guide.md` (replace "logos-website" with "my-website", domain with "example.com")
  - [ ] Read and adapt `tools/pnpm-guide.md` (no changes needed - generic tool reference)
  - [ ] Read and adapt `tools/cloudflare-deploy-guide.md` (replace "logos-website" with "my-website")
  - [ ] Read and adapt `tools/cicd-pipeline-guide.md` (generalize GitLab references)
  - [ ] Read and adapt `tools/debugging-utilities.md` (no changes needed - generic CLI tools)
  - [ ] Read and adapt `templates/astro-page-template.md` (replace "Logos Laboratories" with "Your Site Name")
  - [ ] Read and adapt `templates/astro-component-template.md` (replace "Logos Laboratories" with "Your Site Name")
  - [ ] Read and adapt `context/project/web/README.md` (replace "Logos website" with generic)
- **Timing:** 45 minutes
- **Files to create:**
  - `.claude/extensions/web/context/project/web/standards/web-style-guide.md`
  - `.claude/extensions/web/context/project/web/standards/performance-standards.md`
  - `.claude/extensions/web/context/project/web/standards/accessibility-standards.md`
  - `.claude/extensions/web/context/project/web/tools/astro-cli-guide.md`
  - `.claude/extensions/web/context/project/web/tools/pnpm-guide.md`
  - `.claude/extensions/web/context/project/web/tools/cloudflare-deploy-guide.md`
  - `.claude/extensions/web/context/project/web/tools/cicd-pipeline-guide.md`
  - `.claude/extensions/web/context/project/web/tools/debugging-utilities.md`
  - `.claude/extensions/web/context/project/web/templates/astro-page-template.md`
  - `.claude/extensions/web/context/project/web/templates/astro-component-template.md`
  - `.claude/extensions/web/context/project/web/README.md`
- **Verification:**
  - No references to "Logos", "logos-labs.com", or "logos-laboratories.com" remain
  - Technical content is preserved intact
  - README provides accurate overview of context file organization

---

### Phase 6: Final Verification [NOT STARTED]

- **Goal:** Verify the complete extension for structural correctness, consistency, and absence of project-specific references
- **Tasks:**
  - [ ] Count all files in extension directory tree (expect 24 files)
  - [ ] Grep all extension files for "Logos", "logos-labs", "logos-laboratories" (expect 0 matches)
  - [ ] Grep agent files for `.claude/context/core/` references (expect 0 matches)
  - [ ] Validate manifest.json is well-formed JSON with `jq .`
  - [ ] Validate index-entries.json is well-formed JSON with `jq .`
  - [ ] Cross-check manifest.json `provides.agents` matches actual agent files
  - [ ] Cross-check manifest.json `provides.skills` matches actual skill directories
  - [ ] Cross-check manifest.json `provides.rules` matches actual rule files
  - [ ] Cross-check index-entries.json paths against actual context files
  - [ ] Verify EXTENSION.md lists all skills and agents correctly
- **Timing:** 15 minutes
- **Files to verify:**
  - All 24 files in `.claude/extensions/web/`
- **Verification:**
  - File count matches expected 24
  - Zero Logos-specific references
  - All JSON files parse without errors
  - Manifest provides arrays match actual file inventory
  - Index entries cover all context files

## Testing & Validation

- [ ] Structural: Verify 24 files exist in correct directory hierarchy
- [ ] Content: Grep for "Logos" / "logos-labs" / "logos-laboratories" across all extension files (expect 0)
- [ ] JSON validity: `jq . manifest.json` and `jq . index-entries.json` succeed
- [ ] Manifest consistency: Every file listed in `provides` exists on disk
- [ ] Index consistency: Every path in `index-entries.json` exists on disk
- [ ] Pattern conformance: Compare structure against lean extension as reference

## Artifacts & Outputs

- `.claude/extensions/web/` - Complete web extension directory (24 files)
- `specs/105_create_web_extension/plans/implementation-001.md` - This plan
- `specs/105_create_web_extension/summaries/implementation-summary-YYYYMMDD.md` - Post-implementation summary

## Rollback/Contingency

The entire extension is new content in a new directory. Rollback is simply:
```bash
rm -rf .claude/extensions/web/
```
No existing files are modified. The extension does not affect core system behavior until explicitly activated via merge targets.
