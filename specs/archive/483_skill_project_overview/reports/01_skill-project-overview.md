# Research Report: Task #483

**Task**: 483 - Create skill-project-overview for interactive repo generation
**Started**: 2026-04-20T12:00:00Z
**Completed**: 2026-04-20T12:15:00Z
**Effort**: Medium
**Dependencies**: Task 482 (completed - detection rule)
**Sources/Inputs**:
- Codebase: existing skills in `.claude/skills/`
- Codebase: `.claude/context/repo/update-project.md` (generation guide)
- Codebase: `.claude/context/repo/project-overview.md` (generic template)
- Codebase: `.claude/rules/project-overview-detection.md` (task 482 output)
- Codebase: `.claude/extensions/core/manifest.json` (registration pattern)
- Codebase: `.claude/context/standards/interactive-selection.md` (AskUserQuestion patterns)
- Codebase: `.claude/agents/meta-builder-agent.md` (interactive interview reference)
**Artifacts**:
- specs/483_skill_project_overview/reports/01_skill-project-overview.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- skill-project-overview should be a **direct-execution skill** (like skill-todo) with `AskUserQuestion` in allowed-tools, NOT a thin-wrapper delegating to a subagent
- The skill implements a 3-stage interactive workflow: auto-scan, user interview, artifact creation
- It should be placed in the **core extension** (`extensions/core/skills/skill-project-overview/`) since it operates on the agent system itself
- The detection rule (task 482) currently suggests `/task "Generate..."` but should be updated to suggest invoking this skill directly
- The skill writes to `.claude/context/repo/project-overview.md` (a `.claude/` path) which requires careful scoping -- unlike meta-builder-agent, this skill is permitted to write this specific file
- A new command `/project-overview` should invoke the skill

## Context & Scope

The goal is to replace the manual process described in `update-project.md` with an interactive skill that:
1. Automatically analyzes the repository (structure, languages, frameworks, key files)
2. Presents findings to the user for verification and correction via AskUserQuestion
3. Creates a task with research artifact summarizing the findings, then guides the user to `/research` or `/plan` then `/implement` to actually write the file

**Important design constraint from task description**: The skill should "create a task with a research artifact summarizing findings, then close with guidance to continue with /research or proceed to /plan then /implement." This means the skill does NOT directly write `project-overview.md` -- it creates a task + research artifact, and the actual file creation happens via the normal task lifecycle.

## Findings

### Existing Skill Patterns

**Thin-wrapper pattern** (skill-researcher, skill-planner, skill-reviser):
- Frontmatter: `name`, `description`, `allowed-tools` (includes Task tool)
- Delegates to a subagent via Task tool
- Handles postflight (status update, artifact linking, git commit)
- Has `.postflight-pending` marker file protocol

**Direct-execution pattern** (skill-todo, skill-fix-it, skill-refresh):
- Frontmatter: `name`, `description`, `allowed-tools` (includes AskUserQuestion)
- Has `context: direct` in frontmatter
- Executes logic inline without subagent
- Uses AskUserQuestion for interactive user input
- Typically creates/manages tasks, not delegated agent work

**Recommended pattern for skill-project-overview**: Direct-execution (like skill-todo/skill-fix-it) because:
- It needs multi-turn interactive dialogue (AskUserQuestion)
- It creates a task and artifact directly
- No heavy research delegation needed -- the scan is mechanical (ls, file extensions, config detection)

### AskUserQuestion Usage Patterns

From `interactive-selection.md`:
```json
{
  "question": "string (required)",
  "header": "string (1-3 words, Title Case)",
  "multiSelect": "boolean (default: false)",
  "options": [{"label": "...", "description": "..."}]
}
```

For the project-overview skill, AskUserQuestion would be used to:
1. Present auto-detected findings for confirmation ("Is this correct?")
2. Ask clarifying questions about project purpose, workflows, etc.
3. Confirm task creation at the end

### update-project.md (Existing Generation Guide)

The existing guide at `.claude/context/repo/update-project.md` documents the manual process:
1. Analyze project (entry points, tech stack, directory structure, dev workflow)
2. Write project-overview.md using a template

The skill should automate Step 1 and make Step 2 happen through the task lifecycle.

### project-overview.md Template Structure

The generic template (with `<!-- GENERIC TEMPLATE` marker) contains:
- Project Overview section
- Two-Layer Extension Architecture explanation
- Repository Structure tree
- Extension-Provided Context
- AI-Assisted Workflow
- Related Documentation

The **target output** (what implementation would produce) follows the template in `update-project.md`:
- Project name and purpose
- Technology stack (language, framework, build system, testing)
- Directory structure tree with descriptions
- Core components breakdown
- Development workflow
- Common tasks
- Verification commands
- Related documentation

### Detection Rule (Task 482)

The rule at `.claude/rules/project-overview-detection.md`:
- Has frontmatter `paths: .claude/context/repo/project-overview.md`
- Fires when the file contains `<!-- GENERIC TEMPLATE`
- Currently suggests: `/task "Generate project-overview.md for this repository"`
- Should be updated to suggest the new skill/command instead

### Extension Placement

The skill belongs in the **core extension** (`extensions/core/`):
- Core extension provides all agent system infrastructure
- `manifest.json` has a `provides.skills` array listing skill directory names
- The skill directory would be `extensions/core/skills/skill-project-overview/`
- After loader runs, it appears at `.claude/skills/skill-project-overview/SKILL.md`

### Command Registration

A new command file is needed: `extensions/core/commands/project-overview.md`
- This would be the user-facing entry point
- Should also be loadable by the detection rule's suggestion
- The manifest's `provides.commands` array needs the new entry

## Decisions

1. **Direct-execution skill** (not thin-wrapper) -- interactive multi-turn workflow without needing a full research agent
2. **Core extension placement** -- this is agent system infrastructure, not domain-specific
3. **Task-creation approach** -- the skill creates a task + research artifact, does NOT write project-overview.md directly
4. **Single command**: `/project-overview` (or potentially just update the detection rule to suggest a task with a known pattern)
5. **No new agent needed** -- the skill executes directly with Bash/Read/Glob for scanning

## Recommendations

### Implementation Plan Outline

**Phase 1: Create the skill**
- Create `extensions/core/skills/skill-project-overview/SKILL.md`
- Frontmatter: `name: skill-project-overview`, `allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion`, `context: direct`
- Three-stage execution flow:
  - Stage 1: Auto-scan (ls, detect languages by extension, find config files, identify frameworks)
  - Stage 2: Interactive interview (present findings, ask verification questions, gather purpose/workflow info)
  - Stage 3: Create task + research artifact with all gathered information, display next-step guidance

**Phase 2: Create the command**
- Create `extensions/core/commands/project-overview.md`
- Simple command that invokes skill-project-overview

**Phase 3: Update detection rule**
- Modify `.claude/rules/project-overview-detection.md` to suggest `/project-overview` instead of `/task "Generate..."`

**Phase 4: Register in manifest**
- Add `skill-project-overview` to `extensions/core/manifest.json` provides.skills
- Add `project-overview.md` to `extensions/core/manifest.json` provides.commands

### Auto-Scan Strategy

The scan in Stage 1 should detect:
1. **Languages**: Count files by extension (.lua, .nix, .py, .ts, .go, .rs, etc.)
2. **Package managers**: package.json, Cargo.toml, go.mod, flake.nix, pyproject.toml
3. **Frameworks**: Next.js (next.config), Rails (Gemfile+config/routes), Flask, etc.
4. **Build tools**: Makefile, justfile, Taskfile, CMakeLists.txt
5. **Testing**: jest.config, pytest.ini, *_test.go, *_spec.lua
6. **CI/CD**: .github/workflows/, .gitlab-ci.yml
7. **Key files**: README.md, CLAUDE.md, init.lua, main.*, src/

### Interactive Questions (Stage 2)

Suggested AskUserQuestion flow:
1. "I detected the following. Is this accurate?" (confirmation with corrections)
2. "What is the primary purpose of this project?" (free text or options)
3. "What is your typical development workflow?" (multi-select from detected options)
4. "Are there additional components I should know about?" (free text)

### Task Creation (Stage 3)

The skill creates:
- A task in state.json + TODO.md (type: "meta", description references project-overview generation)
- A research artifact at `specs/{NNN}_{SLUG}/reports/01_project-overview-scan.md` containing all findings
- Display message: "Task {N} created. Run `/plan {N}` to create an implementation plan, then `/implement {N}` to generate the project-overview.md file."

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Skill writes to `.claude/` path directly | Design enforces task-creation-only approach; actual file writing happens via /implement |
| Detection rule update breaks existing workflow | Keep `/task "Generate..."` as fallback suggestion alongside `/project-overview` |
| Auto-scan misidentifies project type | Interactive verification step (Stage 2) catches errors before artifact creation |
| Skill is too large for direct execution | Keep scan logic simple (bash one-liners); avoid heavy analysis |

## Appendix

### Files to Create
- `.claude/extensions/core/skills/skill-project-overview/SKILL.md`
- `.claude/extensions/core/commands/project-overview.md`

### Files to Modify
- `.claude/extensions/core/manifest.json` (add to provides.skills + provides.commands)
- `.claude/rules/project-overview-detection.md` (update suggestion)

### Reference Files Consulted
- `.claude/skills/skill-todo/SKILL.md` (direct-execution pattern)
- `.claude/skills/skill-fix-it/SKILL.md` (interactive task creation pattern)
- `.claude/skills/skill-meta/SKILL.md` (thin-wrapper pattern, AskUserQuestion usage)
- `.claude/agents/meta-builder-agent.md` (multi-turn interview reference)
- `.claude/context/standards/interactive-selection.md` (AskUserQuestion schema)
- `.claude/context/repo/update-project.md` (generation guide to supersede)
- `.claude/context/repo/project-overview.md` (target template)
- `.claude/extensions/core/manifest.json` (registration pattern)
