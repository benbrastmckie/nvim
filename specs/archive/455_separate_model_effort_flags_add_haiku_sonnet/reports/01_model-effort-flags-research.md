# Research Report: Task #455

**Task**: 455 - Separate model/effort flags, add --haiku and --sonnet
**Started**: 2026-04-16T12:00:00Z
**Completed**: 2026-04-16T12:30:00Z
**Effort**: 2-4 hours implementation
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.claude/commands/research.md`, `implement.md`, `plan.md`
- Codebase: `.claude/skills/skill-researcher/SKILL.md`, `skill-implementer/SKILL.md`, `skill-planner/SKILL.md`
- Codebase: `.claude/skills/skill-team-research/SKILL.md`, `skill-team-implement/SKILL.md`, `skill-team-plan/SKILL.md`
- Codebase: `.claude/skills/skill-orchestrator/SKILL.md`
- Codebase: `.claude/docs/reference/standards/agent-frontmatter-standard.md`
- Codebase: All `.claude/agents/*.md` files (7 core agents)
- Codebase: All `.claude/extensions/*/agents/*.md` files (extension agents)
- Codebase: `.claude/CLAUDE.md` (documentation tables)
**Artifacts**: - `specs/455_separate_model_effort_flags_add_haiku_sonnet/reports/01_model-effort-flags-research.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The current flag system conflates two independent concerns: model selection and effort level. `--fast` maps to Sonnet (cheaper model + less effort), while `--hard` and `--opus` both map to Opus (expensive model + more effort).
- There is a significant documentation inconsistency: CLAUDE.md says "All agents default to Opus" while agent-frontmatter-standard.md says "Non-Lean agents default to Sonnet" -- meanwhile all actual agent files declare `model: opus`.
- The `/plan` command is missing model flags entirely (no `--fast`, `--hard`, or `--opus`), unlike `/research` and `/implement`.
- Extension commands and extension agents all use `model: opus` and none parse model flags.
- The recommended approach introduces two orthogonal flag dimensions: effort (`--fast`/`--hard`) and model (`--haiku`/`--sonnet`/`--opus`), with approximately 20-25 files requiring changes.

## Context & Scope

This research examines every file involved in the flag parsing, model selection, and agent spawning pipeline to create a complete inventory for the refactoring task. The goal is to separate model selection from effort level into two independent dimensions.

## Findings

### Current Flag Parsing in Command Files

**research.md** (STAGE 1.5: PARSE FLAGS, lines 265-298):
- Parses `--fast` -> `model_flag = "fast"` (described as "uses Sonnet, explicit low-cost mode")
- Parses `--hard` -> `model_flag = "hard"` (described as "uses Opus, explicit high-effort mode")
- Parses `--opus` -> `model_flag = "opus"` (described as "uses Opus, alias for --hard")
- Default when none provided: `model_flag = null` (comment says "use agent default, which is Sonnet")
- Passthrough in STAGE 2: `model_flag="fast"` -> `model: sonnet`; `model_flag="hard"/"opus"` -> `model: opus`

**implement.md** (STAGE 1.5: PARSE FLAGS, lines 325-342):
- Identical flag parsing and passthrough logic to research.md
- Same three flags, same mapping, same default comment about Sonnet

**plan.md** (STAGE 1.5: PARSE FLAGS, lines 266-285):
- No model flags at all -- only parses `--team` and `--team-size`
- No `model_flag` variable, no model passthrough to skill invocation

### Current Flag Handling in Skill Files

**skill-researcher/SKILL.md**:
- No model_flag handling -- the skill is a "thin wrapper" that delegates to `general-research-agent` via the Task tool
- The model_flag from the command is passed in the delegation context but the skill itself does not interpret it
- The Task tool's `subagent_type` parameter implicitly uses the agent's frontmatter `model:` value

**skill-implementer/SKILL.md**:
- Same pattern as skill-researcher -- thin wrapper, no model_flag interpretation
- Delegates to `general-implementation-agent` via Task tool

**skill-planner/SKILL.md**:
- Same thin-wrapper pattern, delegates to `planner-agent` via Task tool
- No model_flag in its input parameters or delegation context

**skill-orchestrator/SKILL.md**:
- Pure routing skill -- looks up task type and routes to appropriate skill
- No model_flag parsing, interpretation, or passthrough logic
- The model_flag is passed at the command level, not through the orchestrator

### Current Model Defaults in Team Skills

**skill-team-research/SKILL.md** (Stage 5b, lines 176-192):
- Hardcodes `default_model="sonnet"` for both meta and general task types
- Creates `model_preference_line` string for teammate prompts (secondary guidance)
- Stage 5 note: "Use `model: "sonnet"` for all tasks (cost-effective for non-Lean work)"
- No `model_flag` input parameter -- ignores any model override from the command

**skill-team-plan/SKILL.md**:
- Uses `{model_preference_line}` in teammate prompts but does not define it explicitly
- Stage 5 note: "Use `model: "sonnet"` for all tasks"
- No model_flag input parameter

**skill-team-implement/SKILL.md**:
- Uses `{model_preference_line}` in teammate prompts but does not define it explicitly
- No model_flag input parameter

### Current Agent Frontmatter Model Values

**Core agents (all 7 declare `model: opus`)**:
- `general-research-agent.md`: `model: opus`
- `general-implementation-agent.md`: `model: opus`
- `planner-agent.md`: `model: opus`
- `meta-builder-agent.md`: `model: opus`
- `code-reviewer-agent.md`: `model: opus`
- `reviser-agent.md`: `model: opus`
- `spawn-agent.md`: `model: opus`

**Extension agents (all declare `model: opus`)**:
- `lean-research-agent.md`: `model: opus`
- `lean-implementation-agent.md`: `model: opus`
- `neovim-research-agent.md`: `model: opus`
- `latex-research-agent.md`: `model: opus`
- `formal-research-agent.md`: `model: opus`
- `physics-research-agent.md`: `model: opus`
- `math-research-agent.md`: `model: opus`
- `logic-research-agent.md`: `model: opus`
- `epi-implement-agent.md`: `model: opus`
- `epi-research-agent.md`: `model: opus`
- `deck-planner-agent.md`: `model: opus`
- `timeline-agent.md`: `model: opus`
- `grant-agent.md`: `model: opus`
- `pptx-assembly-agent.md`: `model: opus`
- `slide-critic-agent.md`: `model: opus`
- `budget-agent.md`: `model: opus`
- `funds-agent.md`: `model: opus`
- `slidev-assembly-agent.md`: `model: opus`
- `slides-research-agent.md`: `model: opus`
- `slide-planner-agent.md`: `model: opus`

**Extension commands with `model: opus` in frontmatter**:
- `epi.md`, `grant.md`, `funds.md`, `budget.md`, `slides.md`, `timeline.md`

### Documentation Inconsistencies

**CLAUDE.md** (line 196):
> "All agents default to Opus. Use `--fast` flag with `/research` or `/implement` to use Sonnet for cost savings."

**agent-frontmatter-standard.md** (line 44):
> "Non-Lean agents default to Sonnet for cost efficiency. All 7 core agents and all non-Lean extension agents declare `model: sonnet`."

**Reality**: Every single agent file (core and extension) declares `model: opus`. The frontmatter standard document is wrong -- it describes a migration to Sonnet that never happened (or was reverted). CLAUDE.md is correct about the current state.

**CLAUDE.md Skill-to-Agent table** (lines 165-182):
- Lists skill-researcher with model "opus" and skill-planner with model "opus" -- these are correct
- Lists skill-implementer with model "-" -- inconsistent (agent declares opus)
- Lists team skills with model "sonnet" -- this refers to the TeammateTool model parameter, not agent frontmatter

**research.md and implement.md comments**:
- Both say `model_flag = null` means "use agent default, which is Sonnet"
- This is incorrect -- the agent default is actually Opus per all frontmatter

### Extension Commands and Model Flags

No extension commands parse `--fast`, `--hard`, or `--opus` flags. The 6 extension commands that have `model: opus` in their own frontmatter (epi.md, grant.md, funds.md, budget.md, slides.md, timeline.md) set the model for the command itself, not for delegated agents.

## Decisions

- The two dimensions should be: **effort** (how deeply the model reasons) and **model** (which model family)
- Effort flags should affect prompting/behavior, not model selection
- Model flags should affect which model is used, not effort level
- The `model:` frontmatter field in agents should remain as-is (opus) since it represents the default -- the override mechanism at invocation time is what needs the new dimensions

## Recommendations

### Target State: Two Orthogonal Flag Dimensions

**Effort flags** (affect reasoning depth, prompt strategy):
- `--fast` -- Reduce effort (faster, less thorough)
- `--hard` -- Increase effort (slower, more thorough)
- Default: standard effort

**Model flags** (affect which model is invoked):
- `--haiku` -- Use Haiku (cheapest)
- `--sonnet` -- Use Sonnet (mid-tier)
- `--opus` -- Use Opus (highest capability)
- Default: use agent frontmatter default (currently opus for all agents)

**Combination examples**:
- `/research 42 --fast --sonnet` -- Quick Sonnet research
- `/research 42 --hard --opus` -- Deep Opus research
- `/research 42 --haiku` -- Default effort, cheapest model
- `/research 42 --fast` -- Quick, default model (opus)
- `/research 42` -- Default effort, default model (opus)

### Complete File Inventory

**Command files (3 files)**:
1. `.claude/commands/research.md` -- Update Options table, STAGE 1.5 flag parsing, STAGE 2 model passthrough
2. `.claude/commands/implement.md` -- Same changes as research.md
3. `.claude/commands/plan.md` -- Add model flags (currently missing entirely)

**Core skill files (6 files)**:
4. `.claude/skills/skill-researcher/SKILL.md` -- Add effort_flag/model_flag to delegation context
5. `.claude/skills/skill-implementer/SKILL.md` -- Same as skill-researcher
6. `.claude/skills/skill-planner/SKILL.md` -- Same as skill-researcher
7. `.claude/skills/skill-team-research/SKILL.md` -- Add model_flag input, update Stage 5b routing to use model_flag instead of hardcoded sonnet
8. `.claude/skills/skill-team-implement/SKILL.md` -- Add model_flag input, update model passthrough
9. `.claude/skills/skill-team-plan/SKILL.md` -- Add model_flag input, update model passthrough

**Documentation files (3 files)**:
10. `.claude/CLAUDE.md` -- Update Skill-to-Agent table model column, update Model Enforcement paragraph, update command reference usage hints
11. `.claude/docs/reference/standards/agent-frontmatter-standard.md` -- Fix "Non-Lean agents default to Sonnet" to match reality (all opus), update Runtime Override Flags section to show two dimensions
12. `.claude/commands/research.md` argument-hint line (frontmatter) -- Already counted above

**No changes needed for**:
- Agent files (`.claude/agents/*.md`) -- Keep `model: opus` as default; the override mechanism is in commands/skills
- Extension agent files -- Same reasoning
- Extension commands -- They do not parse model flags and use their own frontmatter model
- `skill-orchestrator/SKILL.md` -- Pure routing, does not interpret flags

### Recommended Implementation Approach

**Phase 1: Update command flag parsing (3 files)**
- Add two separate flag extraction blocks: one for effort (`--fast`/`--hard`), one for model (`--haiku`/`--sonnet`/`--opus`)
- Update the Options tables in all three commands
- Update frontmatter `argument-hint` lines
- Pass both `effort_flag` and `model_flag` to skills

**Phase 2: Update core skills (6 files)**
- Add `effort_flag` and `model_flag` to delegation context in skill-researcher, skill-implementer, skill-planner
- Update team skills to accept and use `model_flag` instead of hardcoding sonnet
- For effort_flag: pass through to agent prompts (agents can adjust their behavior)

**Phase 3: Update documentation (2 files)**
- Fix CLAUDE.md tables and model enforcement description
- Fix agent-frontmatter-standard.md to match reality and describe two-dimensional system

**Phase 4: Validation**
- Verify no file references the old single-dimension mapping
- Grep for stale "which is Sonnet" comments
- Verify `/plan` now supports model flags

## Risks & Mitigations

- **Backward compatibility**: Users with muscle memory for `--fast` meaning "use Sonnet" will now get "default model with fast effort". Mitigation: Document the change clearly; the old behavior of `--fast` -> Sonnet can be achieved with `--fast --sonnet`.
- **Effort flag has no runtime effect yet**: The `effort_flag` dimension is conceptually clean but the Claude Code Task tool does not support an "effort" parameter. Mitigation: Pass effort as part of the prompt context so agents can adjust their thoroughness. This is a soft signal, not enforced.
- **Haiku model availability**: Claude Code may not support Haiku as a model for the Task tool. Mitigation: Validate that `model: haiku` is a valid value for Task tool before adding `--haiku`. If not supported, document it as aspirational or omit.

## Appendix

### Search Queries Used
- `Grep --fast|--hard|--opus|model_flag` across `.claude/commands/`, `.claude/skills/`, `.claude/extensions/`
- `Grep model: (opus|sonnet)` across all agent and extension files
- `Grep "All agents default|default to Opus|default to Sonnet"` for documentation inconsistency detection
- Direct reads of all 3 command files, 7 skill files, 7 core agent frontmatters, and 20+ extension agent frontmatters

### Current vs Target Flag Mapping

| Current Flag | Current Meaning | Target Effort | Target Model |
|-------------|----------------|---------------|-------------|
| `--fast` | Use Sonnet | `--fast` (less effort) | (no model change) |
| `--hard` | Use Opus | `--hard` (more effort) | (no model change) |
| `--opus` | Use Opus (alias for --hard) | (no effort change) | `--opus` (use Opus) |
| (none) | Agent default (opus) | Standard effort | Agent default (opus) |
| N/A | N/A | (no effort change) | `--sonnet` (use Sonnet) |
| N/A | N/A | (no effort change) | `--haiku` (use Haiku) |
