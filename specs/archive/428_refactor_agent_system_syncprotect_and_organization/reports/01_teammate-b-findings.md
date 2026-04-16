# Teammate B Findings: Systematic Inventory and Quality Review

**Task**: 428 - Refactor agent system: syncprotect integration, backup elimination, and systematic organization review
**Focus**: Commands, Skills, Agents, Extensions - naming, documentation, cross-reference accuracy
**Date**: 2026-04-14

---

## 1. Commands Analysis

### Inventory (14 commands)

| Command | Model | Argument-Hint | Delegation Pattern |
|---------|-------|---------------|-------------------|
| errors.md | opus | yes | Direct execution |
| fix-it.md | opus | yes | Skill tool |
| implement.md | opus | yes | Skill tool |
| merge.md | **NONE** | yes | Direct execution |
| meta.md | opus | yes | Skill tool |
| plan.md | opus | yes | Skill tool |
| refresh.md | **NONE** | **NONE** | Skill tool |
| research.md | opus | yes | Skill tool |
| review.md | opus | yes | **Direct execution** (no skill) |
| revise.md | opus | yes | Skill tool |
| spawn.md | opus | yes | Skill tool |
| tag.md | **NONE** | **NONE** | Skill tool |
| task.md | opus | yes | Direct execution |
| todo.md | opus | yes | Direct execution |

### Issues Found

**C1 - Missing `model` field in 3 commands** (Confidence: High)
- `merge.md` - no model field; uses `Bash(gh:*), Bash(glab:*)` tools but no model declared
- `refresh.md` - no model field
- `tag.md` - no model field

Most commands use `model: opus` but these 3 are inconsistent. The tag command is user-only and lightweight, but merge and refresh handle meaningful logic where model selection matters.

**C2 - Missing `argument-hint` in 2 commands** (Confidence: High)
- `refresh.md` - has flags (`--dry-run`, `--force`) but no `argument-hint` in frontmatter
- `tag.md` - has flags (`--patch`, `--minor`, `--major`, `--force`, `--dry-run`) but no `argument-hint`

This is purely a documentation gap visible in CLI help output.

**C3 - `/review` does not delegate via Skill tool** (Confidence: High)
- `review.md` uses `allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), TaskCreate, TaskUpdate, AskUserQuestion` - it executes directly at command level without delegating to a skill.
- This breaks the command-skill-agent delegation chain that all other substantive commands follow.
- `code-reviewer-agent` exists but is never called by `/review` (see Agents section).
- CLAUDE.md Skill-to-Agent mapping table does NOT list a review skill, confirming this gap.

**C4 - `skill-batch-dispatch` referenced but does not exist** (Confidence: High)
- `research.md`, `plan.md`, and `implement.md` all invoke `skill: "skill-batch-dispatch"` in their multi-task dispatch sections.
- No `skill-batch-dispatch` directory exists in `.claude/skills/`.
- The context file `.claude/context/patterns/multi-task-operations.md` notes it as `"skill-batch-dispatch" # or integrated into skill-orchestrator`, indicating this is an open design question rather than a completed implementation.
- The multi-task batch dispatch logic is currently unimplemented/aspirational in all three commands.

**C5 - `/errors` outputs to `specs/errors/analysis-{DATE}.md`** (Confidence: Medium)
- The errors command writes to a `specs/errors/` directory that does not currently exist in the repository.
- The path is different from where `errors.json` is tracked (`specs/errors.json`), creating a two-path inconsistency. The directory `specs/errors/` would need to be created on first use.

**C6 - CLAUDE.md Command Reference table is incomplete** (Confidence: High)
- CLAUDE.md lists 15 commands in the Command Reference table: includes `/spawn` and `/merge`.
- The grep-based count failed (0 matches) because the table uses backtick formatting, not pipe-start; manual review confirms the table is actually accurate.
- However, `/tag`'s table entry shows `argument-hint` in CLAUDE.md but the command file has none.

**C7 - Inconsistent structure: `tag.md` uses different documentation style** (Confidence: Medium)
- `tag.md` uses heading style `# Command: /tag` with `**Purpose**:` and `**Layer**:` metadata inline, rather than the standard frontmatter + `# /tag Command` pattern used by all other commands.
- The body content is less standardized than peer commands.

---

## 2. Skills Analysis

### Inventory (16 core skills)

| Skill | Type | Delegates To | Model Override |
|-------|------|-------------|----------------|
| skill-fix-it | Direct execution | (none) | no |
| skill-git-workflow | Direct execution | (none) | no |
| skill-implementer | Thin wrapper | general-implementation-agent | no |
| skill-meta | Thin wrapper | meta-builder-agent | no |
| skill-orchestrator | Direct execution | (routing) | no |
| skill-planner | Thin wrapper | planner-agent | no |
| skill-refresh | Direct execution | (none) | no |
| skill-researcher | Thin wrapper | general-research-agent | no |
| skill-reviser | Thin wrapper | reviser-agent | **opus** |
| skill-spawn | Thin wrapper | spawn-agent | no |
| skill-status-sync | Direct execution | (none) | no |
| skill-tag | Direct execution | (none) | no |
| skill-team-implement | Team orchestration | (teammates) | no |
| skill-team-plan | Team orchestration | (teammates) | no |
| skill-team-research | Team orchestration | (teammates) | no |
| skill-todo | Direct execution | (none) | no |

### Issues Found

**S1 - `skill-fix-it` missing from CLAUDE.md Skill-to-Agent mapping table** (Confidence: High)
- The CLAUDE.md mapping table lists 15 skills but omits `skill-fix-it`.
- `skill-fix-it` exists as a core skill, is used by `/fix-it`, and is a direct execution skill (no agent delegation), but it is not documented in the central reference table.

**S2 - `skill-reviser` has `model: opus` but peer thin-wrappers do not** (Confidence: Medium)
- `skill-reviser` is the only thin-wrapper skill with a `model: opus` declaration.
- Other thin-wrappers (`skill-implementer`, `skill-meta`, `skill-planner`, `skill-researcher`, `skill-spawn`) do not specify a model, deferring to default.
- `skill-reviser` delegates to `reviser-agent` which already declares `model: opus`.
- The model override at the skill level is redundant and potentially confusing. If it's intentional (to ensure the thin-wrapper itself runs on opus), it should be documented; if not, it should be removed for consistency.

**S3 - `skill-spawn` has `version: "1.0"` and `author: meta-builder-agent` fields** (Confidence: Medium)
- `skill-spawn` is the only core skill with `version` and `author` metadata in its frontmatter.
- All other skills lack these fields. This is likely a leftover from when spawn was created by meta-builder-agent as a test, but it creates inconsistency.
- These non-standard frontmatter fields are not part of the documented skill format.

**S4 - `skill-batch-dispatch` is referenced but missing** (Confidence: High)
- See C4 above. This is both a command issue and a skills gap.
- The multi-task flow in research/plan/implement depends on this skill to parallelize across tasks. Without it, multi-task mode is effectively unimplemented.

**S5 - CLAUDE.md documents `skill-orchestrator` purpose inaccurately** (Confidence: Low)
- CLAUDE.md says skill-orchestrator: "Route commands to appropriate workflows". The skill's actual description says "Route commands to appropriate workflows based on task type and status. Invoke when executing /task, /research, /plan, /implement commands."
- However, in practice the routing is embedded directly in research.md/plan.md/implement.md via extension manifest lookups. The orchestrator skill may be vestigial or for a different use pattern. Needs clarification.

---

## 3. Agents Analysis

### Inventory (7 agents + README)

| Agent | Model | Invoked By | Purpose |
|-------|-------|-----------|---------|
| code-reviewer-agent | opus | **NOTHING** | Code quality review |
| general-implementation-agent | **NONE** | skill-implementer | General implementation |
| general-research-agent | opus | skill-researcher | Research |
| meta-builder-agent | **NONE** | skill-meta | System building |
| planner-agent | opus | skill-planner | Planning |
| reviser-agent | opus | skill-reviser | Plan revision |
| spawn-agent | opus | skill-spawn | Blocker analysis |

### Issues Found

**A1 - `code-reviewer-agent` is orphaned** (Confidence: High)
- `code-reviewer-agent.md` exists and declares `model: opus`.
- It is listed in CLAUDE.md's Agents table, context/index.json, and core-index-entries.json.
- However, **no skill invokes it**. The `/review` command executes directly without delegating to this agent.
- The agent is essentially dead code from an architectural standpoint.
- Either: (a) `/review` should be refactored to delegate via `skill-reviewer -> code-reviewer-agent`, matching the pattern of all other command-skill-agent chains; or (b) `code-reviewer-agent` should be removed if `/review` intentionally remains a direct-execution command.

**A2 - `general-implementation-agent` and `meta-builder-agent` missing `model` field** (Confidence: High)
- 5 of 7 agents declare `model: opus`.
- `general-implementation-agent` and `meta-builder-agent` have no `model` field.
- CLAUDE.md's mapping table shows them with `-` for model (which is accurate but inconsistent with the pattern of declared models).
- Per the agent frontmatter standard, agents should explicitly declare their model. "Use default" should be a documented intent, not an omission.

**A3 - `spawn-agent` uses `tools:` frontmatter (YAML list), unlike all other agents** (Confidence: Medium)
- `spawn-agent` specifies tools in frontmatter as:
  ```yaml
  tools:
    - Read
    - Write
    - Glob
    - Grep
    - Bash(jq:*)
  ```
- No other agent in the core or any extension uses this frontmatter pattern for tools.
- The standard for agents appears to be embedding tool restrictions in prose or relying on the skill's `allowed-tools` to constrain the agent.
- This may be a format inconsistency from an older standard or a test format.

**A4 - CLAUDE.md mapping table does not show `code-reviewer-agent` as invoked by any skill** (Confidence: High)
- The Skill-to-Agent mapping table correctly omits a skill-reviewer row, but lists code-reviewer-agent in the Agents table below without any skill mapping.
- This creates a documented but unreachable agent.

---

## 4. Extension Components Analysis

### Summary of Extension-Provided Skills and Agents

| Extension | Task Type | Skills | Agents |
|-----------|-----------|--------|--------|
| epidemiology | epi | 2 (epi-research, epi-implement) | 2 |
| filetypes | null | 5 (filetypes, spreadsheet, presentation, scrape, docx-edit) | 6 |
| formal | formal | 4 (formal-, logic-, math-, physics-research) | 4 |
| founder | founder | 14 | 14 |
| latex | latex | 2 (latex-research, latex-implementation) | 2 |
| lean | lean4 | 4 (lean-research, lean-implementation, lake-repair, lean-version) | 2 |
| memory | null | 1 (memory) | 0 |
| nix | nix | 2 (nix-research, nix-implementation) | 2 |
| nvim | neovim | 2 (neovim-research, neovim-implementation) | 2 |
| present | present | 7 (grant, budget, timeline, funds, slides, slide-planning, slide-critic) | 9 |
| python | python | 2 (python-research, python-implementation) | 2 |
| typst | typst | 2 (typst-research, typst-implementation) | 2 |
| web | web | 3 (web-research, web-implementation, **skill-tag**) | 2 |
| z3 | z3 | 2 (z3-research, z3-implementation) | 2 |

**Total extension-provided skills**: ~54
**Total extension-provided agents**: ~53 (rough count)

### Issues Found

**E1 - `web` extension provides `skill-tag` which duplicates the core `skill-tag`** (Confidence: High)
- Core `.claude/skills/skill-tag/` exists with `user-only: true`.
- `web` extension also provides a `skill-tag` directory with its own `SKILL.md`.
- Both have the same name, `user-only: true`, and appear identical in content.
- The web extension also provides a `tag.md` command, which appears to be the same as the core `commands/tag.md`.
- This duplication is confusing: when the web extension is loaded, which `skill-tag` takes precedence? The extension loader behavior needs to be clarified.
- **Root cause**: The web extension likely copied the core tag skill/command wholesale rather than depending on the core version.

**E2 - `filetypes` and `founder` extensions both define `spreadsheet-agent` with the same name** (Confidence: High)
- `filetypes/agents/spreadsheet-agent.md`: "Convert spreadsheets to LaTeX/Typst tables"
- `founder/agents/spreadsheet-agent.md`: "Cost breakdown spreadsheet generation with forcing questions"
- Both have `name: spreadsheet-agent` in frontmatter.
- When both extensions are loaded, there is a naming collision. The context index would have two entries with the same agent name but different purposes.
- Similarly, both provide `skill-spreadsheet` directories with different SKILL.md content.

**E3 - `present` extension uses colon-suffixed skill routing (`skill-grant:assemble`, `skill-slides:assemble`)** (Confidence: Medium)
- The manifest routes `present:grant -> skill-grant:assemble` and `present:slides -> skill-slides:assemble` in implement routing.
- `skill-grant:assemble` is not a separate skill directory - it's an internal workflow mode within `skill-grant`.
- This is an undocumented routing pattern (colon suffix on skill name to indicate sub-workflow) not used by any other extension.
- The commands (research.md, plan.md, implement.md) do direct string lookup `'.routing.implement[$tt]'` from the manifest and pass the result directly to `Skill tool`. If a `skill-grant:assemble` string is returned, the Skill tool would look for a skill named `skill-grant:assemble` - which does not exist as a directory.
- This appears to be a bug or an undocumented convention that needs to be validated.

**E4 - `memory` extension provides no agents (only a skill)** (Confidence: Low)
- All other extensions with skills follow the pattern: skills delegate to agents.
- `memory` extension only provides `skill-memory` with no agent. This means either `skill-memory` is a direct execution skill (reasonable) or it delegates to a non-extension agent (ambiguous).
- This is a minor deviation from the extension convention but may be intentional.

**E5 - Extension naming is mostly consistent but has minor variations** (Confidence: Low)
- Most extensions follow `skill-{ext}-{role}` pattern (e.g., `skill-nix-research`, `skill-latex-implementation`).
- Founder extension uses `skill-market`, `skill-analyze`, `skill-strategy` (no `founder-` prefix) for its research skills.
- Present extension uses `skill-grant`, `skill-budget`, etc. (no `present-` prefix).
- These flat names risk collision if multiple extensions are used together. The `skill-spreadsheet` collision between filetypes and founder is a real example of this risk.

---

## 5. Cross-Cutting Issues

**X1 - `skill-batch-dispatch` is a critical missing component** (Confidence: High)
- Three major commands (`/research`, `/plan`, `/implement`) document multi-task parallel dispatch but cannot execute it because `skill-batch-dispatch` does not exist.
- The context document notes it as "or integrated into skill-orchestrator," suggesting this was intentionally deferred but never completed.
- Multi-task syntax (`/research 7, 22-24, 59`) is advertised in CLAUDE.md but partially broken - the single-task fallthrough works, but the multi-task batch path calls a nonexistent skill.

**X2 - `/review` breaks the command-skill-agent pattern** (Confidence: High)
- Every substantive command delegates via Skill tool to a skill which delegates to an agent.
- `/review` is the exception: it executes entirely at command level with direct tool access.
- `code-reviewer-agent` exists but is never called.
- The architecture should either (a) create `skill-reviewer` + connect to `code-reviewer-agent`, or (b) document `/review` as intentionally a direct-execution command and remove the orphaned agent.

**X3 - Two agents missing explicit `model` field** (Confidence: High)
- `general-implementation-agent` and `meta-builder-agent` have no model declared.
- CLAUDE.md shows these as `-` (default), which is accurate but the agent frontmatter standard should be followed consistently.
- Implementation agents intentionally use default (sonnet) for cost efficiency. This should be explicitly documented in the agents with a comment: `# model: default (intentional - cost optimization)` or similar.

**X4 - CLAUDE.md skill-to-agent mapping table omits `skill-fix-it`** (Confidence: High)
- 16 core skills exist but only 15 appear in CLAUDE.md's table.
- `skill-fix-it` is missing from documentation.

**X5 - `skill-spawn` has non-standard frontmatter** (Confidence: Medium)
- Extra `version` and `author` fields not present in any other skill.
- No documentation standard defines these fields for skills.

**X6 - `tag.md` uses inconsistent command documentation format** (Confidence: Medium)
- Uses `# Command: /tag` with inline metadata instead of the `# /tag Command` pattern and CHECKPOINT structure used by other commands.
- Missing `model` and `argument-hint` frontmatter fields.

**X7 - Extension collision risk for `spreadsheet-agent` and `skill-spreadsheet`** (Confidence: High)
- Two extensions define components with identical names for different purposes.
- The extension loader likely last-write-wins, creating unpredictable behavior when both are loaded.

**X8 - Present extension's colon-suffix routing (`skill-grant:assemble`) is unvalidated** (Confidence: Medium)
- If the Skill tool receives `skill-grant:assemble` as the skill name, it will fail to find the skill directory.
- This routing pattern is unique to the present extension and appears to be an internal convention not supported by the dispatch mechanism.

---

## 6. Recommended Improvements

### Priority 1: Critical (System Correctness)

**R1 - Implement or remove `skill-batch-dispatch`**
- Either implement `skill-batch-dispatch` as a standalone skill in `.claude/skills/skill-batch-dispatch/`, or integrate batch logic into `skill-orchestrator`.
- The multi-task syntax in CLAUDE.md should not be documented as working if it isn't.
- Alternatively, add a note that multi-task mode requires this skill to be created first.

**R2 - Resolve `code-reviewer-agent` orphan**
- Option A (preferred): Create `skill-reviewer` (thin wrapper) + update `/review` to delegate via `skill-reviewer -> code-reviewer-agent`. This gives `/review` the same pattern as all other commands.
- Option B: Remove `code-reviewer-agent.md`, update CLAUDE.md agents table, keep `/review` as direct execution.
- Remove the agent from context/index.json load_when entries if unused.

**R3 - Fix `web` extension `skill-tag` duplication**
- Remove `skill-tag` from the web extension's `provides.skills` and remove the `web/skills/skill-tag/` directory.
- Remove `tag.md` from `web/commands/` if it's identical to core `commands/tag.md`.
- The web extension should depend on the core skill-tag rather than duplicating it.

**R4 - Fix `spreadsheet-agent`/`skill-spreadsheet` naming collision between `filetypes` and `founder` extensions**
- Rename one or both: `filetypes/agents/spreadsheet-agent.md` -> `filetypes/agents/document-spreadsheet-agent.md` (or similar), and update manifest accordingly.
- Follow the extension-prefixed naming convention (`skill-filetypes-spreadsheet`, `skill-founder-spreadsheet`).

### Priority 2: Documentation and Consistency

**R5 - Add missing frontmatter fields to 3 commands**
- Add `model: opus` to `merge.md` and `refresh.md` (or a justified alternative).
- Add `argument-hint` to `refresh.md` (`[--dry-run] [--force]`) and `tag.md` (`[--patch|--minor|--major] [--force] [--dry-run]`).

**R6 - Standardize `tag.md` command documentation format**
- Rewrite to use `# /tag Command` heading and standard CHECKPOINT structure.
- Add `model` and `argument-hint` frontmatter.

**R7 - Add `skill-fix-it` to CLAUDE.md Skill-to-Agent mapping table**
- Add row: `| skill-fix-it | (direct execution) | - | Scan for FIX:/NOTE:/TODO:/QUESTION: tags |`

**R8 - Document intentional missing `model` fields in implementation agents**
- Add comment to `general-implementation-agent.md` and `meta-builder-agent.md` frontmatter: `# model: (default) - intentional for cost optimization`
- Or explicitly add `model: claude-sonnet-4-5` (or whatever the intended default is).

**R9 - Remove non-standard `version` and `author` fields from `skill-spawn`**
- These fields have no documented meaning in the skill frontmatter standard.

**R10 - Remove redundant `model: opus` from `skill-reviser`**
- The reviser-agent already declares opus. The skill wrapper doesn't need to override.

### Priority 3: Architecture Clarification

**R11 - Document or fix `skill-orchestrator` role**
- Clarify whether `skill-orchestrator` is actively used in the dispatch chain or vestigial.
- The routing logic appears embedded in individual commands (manifest lookups), not routed through skill-orchestrator.

**R12 - Validate `present` extension's colon-suffix skill routing**
- Determine if `skill-grant:assemble` in the manifest routing is a supported feature or a bug.
- If unsupported, fix to use `skill-grant` with a `workflow_type=assemble` argument.
- If supported, document the pattern in the extension manifest specification.

**R13 - Enforce extension-prefixed naming for extension skills**
- Extensions with short skill names (`skill-grant`, `skill-budget`, `skill-market`) risk future collisions.
- Establish a naming convention requiring extension prefix: `skill-present-grant`, `skill-founder-market`.
- This is a breaking change requiring manifest and routing updates, so defer to a dedicated refactor task.

---

## 7. Confidence Summary

| Finding | Confidence | Impact |
|---------|-----------|--------|
| C4/S4: skill-batch-dispatch missing | **High** | Critical - multi-task broken |
| A1/X2: code-reviewer-agent orphaned | **High** | Medium - dead code |
| E1: web/skill-tag duplication | **High** | Medium - load conflict risk |
| E2: spreadsheet-agent collision | **High** | High - active collision when both loaded |
| A2/X3: Missing model fields in agents | **High** | Low - documentation gap |
| S1/X4: skill-fix-it missing from CLAUDE.md | **High** | Low - documentation gap |
| C1: Missing model in 3 commands | **High** | Low - inconsistency |
| C2: Missing argument-hint in 2 commands | **High** | Low - CLI help gap |
| C3: /review direct execution | **High** | Medium - pattern break |
| S2: skill-reviser redundant model | **Medium** | Low - minor inconsistency |
| S3/X5: skill-spawn non-standard frontmatter | **Medium** | Low - maintenance noise |
| C6/X6: tag.md format inconsistency | **Medium** | Low - documentation |
| E3/X8: present colon-suffix routing | **Medium** | Medium - potential runtime failure |
| S5/X11: skill-orchestrator role unclear | **Low** | Low - architecture question |
| E4: memory has no agents | **Low** | Low - intentional |
| E5: Extension naming inconsistency | **Low** | Medium - future collision risk |
