# Research Report: Task #348

**Task**: 348 - Fix /plan command not showing interactive questions for founder:deck tasks
**Started**: 2026-04-01T18:00:00Z
**Completed**: 2026-04-01T18:15:00Z
**Effort**: ~30 minutes
**Dependencies**: Task 347 (compound key routing - completed)
**Sources/Inputs**: Codebase analysis of command routing, skill definitions, agent definitions, extension system architecture
**Artifacts**: specs/348_fix_plan_interactive_questions_founder_deck/reports/01_plan-interactive-questions.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The root cause is that the **founder extension is not currently loaded**, so `skill-deck-plan` and `deck-planner-agent` do not exist in `.claude/skills/` or `.claude/agents/`
- The `/plan` command's routing logic reads manifest.json from the extension source directory (always present), finds the routing entry for `founder:deck` -> `skill-deck-plan`, but the skill is not registered with Claude Code because extensions must be loaded via `<leader>ac` to copy files into the core `.claude/` structure
- Even if the extension were loaded, there is a **secondary gap**: the routing lookup succeeds (it finds the skill name from manifest.json) but does NOT verify that the skill actually exists as a registered skill before attempting invocation
- The fix should add an existence check after routing lookup and provide a clear error message when the extension is not loaded

## Context & Scope

Task 347 implemented compound key routing (`founder:deck`) in `/plan`, `/implement`, and `/research` commands. The routing logic correctly reads manifest.json and resolves `founder:deck` to `skill-deck-plan`. However, the routing logic reads from the extension source directory (`.claude/extensions/founder/manifest.json`) which always exists, regardless of whether the extension is loaded. The extension loading system copies skills and agents from extension directories into the core `.claude/` structure only when activated via `<leader>ac`.

## Findings

### Routing Chain Analysis

The full invocation chain for `/plan` on a `founder:deck` task is:

```
/plan {N}
  -> GATE IN: validate task, check status
  -> STAGE 2: Extension routing lookup
     -> Read .claude/extensions/*/manifest.json
     -> Find routing.plan["founder:deck"] = "skill-deck-plan"
  -> Skill("skill-deck-plan", args)
     -> skill-deck-plan SKILL.md executes
     -> Task("deck-planner-agent", prompt)
        -> deck-planner-agent executes
        -> AskUserQuestion (pattern, theme, content, ordering)
        -> Writes plan artifact
        -> Returns metadata
     -> skill-deck-plan postflight
  -> GATE OUT: verify artifacts
  -> COMMIT: git commit
```

### Finding 1: Extension Not Loaded

The founder extension is not currently loaded:
- No `extensions.json` state file exists
- No files in `.claude/skills/` matching `*deck*` or `*founder*`
- No files in `.claude/agents/` matching `*deck*` or `*founder*`

The extension system requires `<leader>ac` (Neovim picker) to load extensions. Loading copies files from `.claude/extensions/founder/` into the core `.claude/` structure.

### Finding 2: Routing Reads Source Directory, Not Installed Directory

The `/plan` command's routing logic at lines 104-111:

```bash
for manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    ext_skill=$(jq -r --arg lang "$language" \
      '.routing.plan[$lang] // empty' "$manifest")
```

This reads from `.claude/extensions/*/manifest.json` -- the extension SOURCE directory. These files always exist regardless of whether the extension is loaded. So the routing lookup succeeds and sets `skill_name="skill-deck-plan"`, but the skill file does not exist at `.claude/skills/skill-deck-plan/SKILL.md`.

### Finding 3: No Existence Check Before Invocation

After the routing lookup determines `skill_name`, the command immediately invokes `Skill(skill_name)` without checking whether the skill exists. The fallback (line 131) only applies when NO routing match is found:

```bash
skill_name=${skill_name:-"skill-planner"}
```

There is no check like: "if skill_name is set but skill does not exist, fall back to default."

### Finding 4: Interactive Questions Are Correctly Defined in Agent

The `deck-planner-agent` correctly defines 4-5 `AskUserQuestion` interactions:
1. Pattern Selection (single select: YC 10-Slide, Lightning Talk, etc.)
2. Theme Selection (single select: Dark Blue, Minimal Light, etc.)
3. Content Selection (multi select per slide position)
4. Slide Ordering (single select: YC Standard, Story-First, Traction-Led)

The agent uses `AskUserQuestion` which works in `Task`-spawned subagents (confirmed by `meta-builder-agent` which uses the same pattern successfully).

### Finding 5: Task Tool Availability

Both `skill-deck-plan` and `skill-planner` declare `allowed-tools: Task, Bash, Edit, Read, Write`. The `/plan` command declares `allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit`. Skills invoked via the `Skill` tool get their own allowed-tools applied, so `Task` is available within the skill context. This part of the chain works correctly.

### Finding 6: What Likely Happens in Practice

When `/plan` is invoked on a `founder:deck` task with the extension not loaded:

1. Routing finds `skill_name = "skill-deck-plan"` from manifest.json
2. Claude attempts `Skill("skill-deck-plan")`
3. The skill is not found (not registered with Claude Code)
4. Claude likely falls through and either errors out or falls back to `skill-planner` (the default planner) which does NOT have deck-specific interactive questions
5. The default planner creates a generic plan without the 4-5 interactive prompts

### Codebase Patterns

The extension system architecture (`.claude/docs/architecture/extension-system.md`) confirms:
- File-Copy Based: Extensions are loaded by copying files into the core structure
- Claude Code Agnostic: Claude Code sees only standard `.claude/` structure
- Extension routing only works when extension is loaded

### Recommendations

**Option A: Add extension-loaded check to routing** (Recommended)

Add a check in the `/plan` command routing that verifies the resolved skill exists before invocation:

```bash
# After routing lookup, verify skill exists
if [ -n "$skill_name" ] && [ "$skill_name" != "skill-planner" ]; then
  if [ ! -d ".claude/skills/${skill_name}" ]; then
    echo "WARNING: Extension skill '${skill_name}' not found."
    echo "The required extension may not be loaded. Use <leader>ac to load extensions."
    echo "Falling back to default planner."
    skill_name="skill-planner"
  fi
fi
```

**Option B: Check extension state before routing**

Before reading manifest.json, check extensions.json to see if the extension is loaded:

```bash
if [ -f ".claude/extensions.json" ]; then
  # Check if extension providing this language is loaded
  ext_loaded=$(jq -r --arg lang "$base_lang" '...' .claude/extensions.json)
fi
```

**Option C: Move routing lookup to installed skills only**

Instead of reading manifest.json, check installed skills for a matching pattern:

```bash
# Check installed skills for language-specific planner
if [ -d ".claude/skills/skill-${base_lang}-plan" ]; then
  skill_name="skill-${base_lang}-plan"
fi
```

**Recommended approach**: Option A is simplest and addresses the exact failure mode. It preserves the existing manifest-based routing but adds a safety check before invocation.

The same pattern should be applied to `/research` and `/implement` commands which have identical routing logic.

## Decisions

- The root cause is definitively the extension not being loaded, combined with no existence check on the resolved skill
- The fix should be applied to all three routing commands (`/plan`, `/research`, `/implement`) for consistency
- The fix should provide a clear user-facing warning about the missing extension

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Falling back to generic planner loses deck-specific interactive flow | Warning message tells user how to load extension |
| Extension may be intentionally unloaded | Fallback is still useful; user can reload and re-run |
| Other extensions may have same issue | Fix pattern applies generically to all extension routing |
| Checking `.claude/skills/` directory may have race conditions | Skills are loaded via Neovim picker, not during Claude execution |

## Appendix

### Files Examined

| File | Purpose |
|------|---------|
| `.claude/commands/plan.md` | /plan command definition with routing logic |
| `.claude/skills/skill-planner/SKILL.md` | Default planner skill |
| `.claude/extensions/founder/manifest.json` | Founder extension routing table |
| `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md` | Deck planning skill (extension) |
| `.claude/extensions/founder/agents/deck-planner-agent.md` | Deck planner agent with interactive questions |
| `.claude/docs/architecture/extension-system.md` | Extension loading architecture |
| `specs/347_add_interactive_deck_plan_picker/summaries/02_deck-plan-picker-summary.md` | Task 347 implementation summary |
| `.claude/extensions/founder/EXTENSION.md` | Extension description and skill-agent mapping |

### Key File Locations

- Extension routing manifest: `.claude/extensions/founder/manifest.json` (line 54-64)
- Plan command routing: `.claude/commands/plan.md` (lines 98-131)
- Deck planner agent: `.claude/extensions/founder/agents/deck-planner-agent.md`
- Deck plan skill: `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md`
