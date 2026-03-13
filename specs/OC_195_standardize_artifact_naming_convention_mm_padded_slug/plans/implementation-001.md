# Implementation Plan: Standardize Artifact Naming Convention

- **Task**: 195 - Standardize artifact naming convention with MM_padded_slug format
- **Status**: [NOT STARTED]
- **Effort**: 12 hours
- **Dependencies**: None
- **Research Inputs**: specs/OC_195_standardize_artifact_naming_convention_mm_padded_slug/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Change all artifact naming across the OpenCode agent system from sequential numeric patterns (`research-{NNN}.md`, `implementation-{NNN}.md`, `implementation-summary-{DATE}.md`) to descriptive slug-based patterns (`MM_{short-slug}.md`). This improves artifact discoverability and provides meaningful context in filenames. The implementation spans 53+ files across agents, skills, commands, scripts, and documentation.

### Research Integration

Key findings from research-001.md:
- 53+ files require modification across 7 categories
- New naming scheme: `MM_{short-slug}.md` where MM = zero-padded sequence (01, 02...) and slug = 3-5 word kebab-case description
- Critical challenges: slug generation algorithm, per-task sequential numbering, cross-file consistency
- Risk of partial updates causing system inconsistency

## Goals & Non-Goals

**Goals**:
- Update all agent files to use new naming convention in examples and instructions
- Update all skill files to use new naming convention in postflight scripts
- Update all command documentation files
- Update postflight shell scripts with new file detection patterns
- Update all extension agents and skills (formal, lean, nix, web, etc.)
- Update documentation and context files
- Ensure backward compatibility for existing artifacts (read-only migration)
- Maintain consistency across all file references

**Non-Goals**:
- No renaming of existing artifact files (migration not required)
- No changes to task numbering system
- No changes to directory structure
- No functional changes to agent logic or behavior
- No changes to state.json format

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Partial update leaves system inconsistent | High | Medium | Use atomic phases, complete each category before starting next |
| Slug generation inconsistency between files | Medium | Medium | Define clear slug generation algorithm in Phase 1 |
| Shell script pattern matching failures | High | Low | Test all pattern changes with sample filenames |
| Documentation drift from code | Medium | Medium | Update docs in same phase as related code |
| Missing files in initial count | Medium | Medium | Use grep to verify all references updated |
| Version detection for plan revisions broken | High | Low | Carefully update plan file sorting logic |

## Implementation Phases

### Phase 1: Define Slug Generation Algorithm [NOT STARTED]

**Goal**: Establish clear, consistent rules for generating short slugs from task descriptions

**Tasks**:
- [ ] Document slug generation algorithm:
  - Extract 3-5 most significant words from task title
  - Convert to kebab-case (lowercase, spaces to hyphens)
  - Remove articles (a, an, the), prepositions (in, on, at), conjunctions (and, or)
  - Keep: nouns, verbs, adjectives that capture task essence
  - Examples: "Configure LSP for Python" -> `configure-lsp-python`, "Add Telescope keymaps" -> `add-telescope-keymaps`
- [ ] Create reference table showing old vs new naming for common patterns:
  - Research: `research-001.md` -> `01_{slug}.md`
  - Plans: `implementation-001.md` -> `01_{slug}.md` (plan version becomes part of slug)
  - Plan revisions: `implementation-002.md` -> `02_{slug}.md` or `01_{slug}-v2.md`
  - Summaries: `implementation-summary-20260313.md` -> `03_{slug}-summary.md`
- [ ] Define per-task sequential numbering rules:
  - Reports: 01, 02, 03... (research reports within task)
  - Plans: 01, 02, 03... (plan versions, sequential)
  - Summaries: always follows plan execution (highest number + 1)

**Timing**: 1 hour

**Files to modify**:
- `.claude/context/core/formats/artifact-formats.md` - Document new naming convention
- `.claude/CLAUDE.md` - Update artifact path examples

**Verification**:
- [ ] Algorithm documented with 5+ examples
- [ ] All naming pattern variants covered
- [ ] Reviewed for consistency with filesystem constraints

---

### Phase 2: Update Core Agents (9 files) [NOT STARTED]

**Goal**: Update all core agent files with new naming convention in instructions and examples

**Tasks**:
- [ ] Update `general-research-agent.md`:
  - Change `research-{NNN}.md` references to `MM_{short-slug}.md`
  - Update example paths in research report section
  - Update metadata file examples with new artifact paths
- [ ] Update `planner-agent.md`:
  - Change `implementation-{NNN}.md` references to `MM_{short-slug}.md`
  - Update plan file path examples
  - Update metadata artifact examples
- [ ] Update `general-implementation-agent.md`:
  - Change `implementation-summary-{DATE}.md` references to `MM_{short-slug}-summary.md`
  - Update summary file path examples
  - Update metadata artifact examples
- [ ] Update extension agents (6 files):
  - `neovim-research-agent.md`
  - `neovim-implementation-agent.md`
  - `nix-research-agent.md`
  - `nix-implementation-agent.md`
  - `web-research-agent.md`
  - `web-implementation-agent.md`

**Timing**: 2 hours

**Files to modify**:
- `.claude/agents/general-research-agent.md`
- `.claude/agents/planner-agent.md`
- `.claude/agents/general-implementation-agent.md`
- `.claude/extensions/nvim/agents/neovim-research-agent.md`
- `.claude/extensions/nvim/agents/neovim-implementation-agent.md`
- `.claude/extensions/nix/agents/nix-research-agent.md`
- `.claude/extensions/nix/agents/nix-implementation-agent.md`
- `.claude/extensions/web/agents/web-research-agent.md`
- `.claude/extensions/web/agents/web-implementation-agent.md`

**Verification**:
- [ ] Grep for old patterns returns no results in these files
- [ ] New patterns use consistent format
- [ ] All example paths updated

---

### Phase 3: Update Core Skills (6 files) [NOT STARTED]

**Goal**: Update all core skill files with new naming convention in postflight scripts and user output

**Tasks**:
- [ ] Update `skill-researcher/SKILL.md`:
  - Update postflight script: change artifact detection pattern
  - Update user output messages with new artifact names
  - Update metadata examples
- [ ] Update `skill-planner/SKILL.md`:
  - Update postflight script: change plan file detection
  - Update user output messages
  - Update plan path in metadata examples
- [ ] Update `skill-implementer/SKILL.md`:
  - Update postflight script: change plan file detection and summary naming
  - Update user output messages
  - Update artifact path examples
- [ ] Update `skill-status-sync/SKILL.md`:
  - Update any artifact path references
- [ ] Update `skill-web-research/SKILL.md`:
  - Update artifact references and examples
- [ ] Update `skill-web-implementation/SKILL.md`:
  - Update plan detection and summary naming

**Timing**: 2 hours

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md`
- `.claude/skills/skill-planner/SKILL.md`
- `.claude/skills/skill-implementer/SKILL.md`
- `.claude/skills/skill-status-sync/SKILL.md`
- `.claude/skills/skill-web-research/SKILL.md`
- `.claude/skills/skill-web-implementation/SKILL.md`

**Verification**:
- [ ] All shell commands in skills updated (ls patterns, grep patterns)
- [ ] User-facing output shows new naming
- [ ] Metadata examples use new format

---

### Phase 4: Update Commands (3 files) [NOT STARTED]

**Goal**: Update command documentation with new artifact naming convention

**Tasks**:
- [ ] Update `.claude/commands/research.md`:
  - Change output artifact example: `reports/research-{NNN}.md` -> `reports/MM_{short-slug}.md`
  - Update any ls or file detection patterns
- [ ] Update `.claude/commands/plan.md`:
  - Change output artifact example: `plans/implementation-{NNN}.md` -> `plans/MM_{short-slug}.md`
  - Update plan file detection logic
- [ ] Update `.claude/commands/implement.md`:
  - Change output artifact example: `summaries/implementation-summary-{DATE}.md` -> `summaries/MM_{short-slug}-summary.md`
  - Update summary file detection

**Timing**: 1 hour

**Files to modify**:
- `.claude/commands/research.md`
- `.claude/commands/plan.md`
- `.claude/commands/implement.md`

**Verification**:
- [ ] Command output examples use new naming
- [ ] File detection patterns updated in bash sections

---

### Phase 5: Update Postflight Scripts (4 files) [NOT STARTED]

**Goal**: Update shell scripts with new file detection and naming patterns

**Tasks**:
- [ ] Update `.claude/scripts/postflight-research.sh`:
  - Change artifact detection pattern from `research-*.md` to `*.md` with filtering
  - Update artifact path construction
  - Handle new naming in metadata parsing
- [ ] Update `.claude/scripts/postflight-plan.sh`:
  - Change plan file detection from `implementation-*.md` to `*.md` with filtering
  - Update plan path construction in metadata
  - Handle plan versioning with new naming
- [ ] Update `.claude/scripts/postflight-implement.sh`:
  - Change plan file detection pattern
  - Change summary naming from `implementation-summary-*.md` to `*-summary.md`
  - Update artifact path construction
- [ ] Update `.claude/scripts/execute-command.sh` (if referenced):
  - Update any artifact path patterns

**Timing**: 2 hours

**Files to modify**:
- `.claude/scripts/postflight-research.sh`
- `.claude/scripts/postflight-plan.sh`
- `.claude/scripts/postflight-implement.sh`
- `.claude/scripts/execute-command.sh` (verify if exists)

**Verification**:
- [ ] Scripts can detect new file naming patterns
- [ ] Plan file sorting works correctly (version detection)
- [ ] Test with sample filenames to verify detection

---

### Phase 6: Update Extension Agents (8 files) [NOT STARTED]

**Goal**: Update remaining extension agents with new naming convention

**Tasks**:
- [ ] Update `formal-research-agent.md`:
  - Update research report naming references
- [ ] Update `logic-research-agent.md`:
  - Update research report naming references
- [ ] Update `math-research-agent.md`:
  - Update research report naming references
- [ ] Update `physics-research-agent.md`:
  - Update research report naming references
- [ ] Update `lean-research-flow.md`:
  - Update research report naming
- [ ] Update `lean-implementation-flow.md`:
  - Update plan and summary naming
- [ ] Update `z3-research-agent.md`:
  - Update research report naming
- [ ] Update `z3-implementation-agent.md`:
  - Update summary naming

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/extensions/formal/agents/formal-research-agent.md`
- `.claude/extensions/formal/agents/logic-research-agent.md`
- `.claude/extensions/formal/agents/math-research-agent.md`
- `.claude/extensions/formal/agents/physics-research-agent.md`
- `.claude/extensions/lean/agents/lean-research-flow.md`
- `.claude/extensions/lean/agents/lean-implementation-flow.md`
- `.claude/extensions/z3/agents/z3-research-agent.md`
- `.claude/extensions/z3/agents/z3-implementation-agent.md`

**Verification**:
- [ ] All extension agent examples use new naming
- [ ] Metadata examples updated

---

### Phase 7: Update Extension Skills (6 files) [NOT STARTED]

**Goal**: Update remaining extension skills with new naming convention

**Tasks**:
- [ ] Update `skill-nix-research/SKILL.md`:
  - Update postflight patterns and user output
- [ ] Update `skill-nix-implementation/SKILL.md`:
  - Update plan detection and summary naming
- [ ] Update `skill-neovim-research/SKILL.md`:
  - Update postflight patterns and user output
- [ ] Update `skill-neovim-implementation/SKILL.md`:
  - Update plan detection and summary naming
- [ ] Update `skill-lean-research/SKILL.md`:
  - Update postflight patterns and user output
- [ ] Update `skill-lean-implementation/SKILL.md`:
  - Update plan detection and summary naming

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/extensions/nix/skills/skill-nix-research/SKILL.md`
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md`
- `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md`
- `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`
- `.claude/extensions/lean/skills/skill-lean-research/SKILL.md`
- `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md`

**Verification**:
- [ ] All extension skill scripts updated
- [ ] Shell patterns handle new naming

---

### Phase 8: Update Documentation (18+ files) [NOT STARTED]

**Goal**: Update all documentation and context files with new naming convention

**Tasks**:
- [ ] Update core documentation:
  - `.claude/CLAUDE.md` - Main project documentation
  - `.claude/README.md` - Project overview
  - `.claude/AGENTS.md` - Agent documentation
- [ ] Update context files:
  - `.claude/context/core/formats/plan-format.md`
  - `.claude/context/core/formats/return-metadata-file.md`
  - `.claude/context/core/formats/subagent-return.md`
  - `.claude/context/core/formats/command-output.md`
  - `.claude/context/core/formats/artifact-formats.md`
  - `.claude/context/core/patterns/early-metadata-pattern.md`
  - `.claude/context/core/patterns/inline-status-update.md`
  - `.claude/context/core/validation.md`
  - `.claude/context/core/workflows/implementation-workflow.md`
  - `.claude/context/project/processes/implementation-workflow.md`
- [ ] Update user guides:
  - `.claude/docs/guides/user-guide.md`
- [ ] Update extension documentation:
  - `.claude/extensions/memory/context/project/memory/knowledge-capture-usage.md`

**Timing**: 2 hours

**Files to modify**:
- `.claude/CLAUDE.md`
- `.claude/README.md`
- `.claude/AGENTS.md`
- `.claude/context/core/formats/plan-format.md`
- `.claude/context/core/formats/return-metadata-file.md`
- `.claude/context/core/formats/subagent-return.md`
- `.claude/context/core/formats/command-output.md`
- `.claude/context/core/formats/artifact-formats.md`
- `.claude/context/core/patterns/early-metadata-pattern.md`
- `.claude/context/core/patterns/inline-status-update.md`
- `.claude/context/core/validation.md`
- `.claude/context/core/workflows/implementation-workflow.md`
- `.claude/context/project/processes/implementation-workflow.md`
- `.claude/docs/guides/user-guide.md`
- `.claude/extensions/memory/context/project/memory/knowledge-capture-usage.md`

**Verification**:
- [ ] All documentation examples use new naming
- [ ] All path references updated
- [ ] Grep for old patterns shows no results in docs

---

### Phase 9: Final Verification and Testing [NOT STARTED]

**Goal**: Verify all changes are consistent and complete

**Tasks**:
- [ ] Run comprehensive grep to find any remaining old patterns:
  - `grep -r "research-{NNN}" .claude/`
  - `grep -r "implementation-{NNN}" .claude/`
  - `grep -r "implementation-summary-{DATE}" .claude/`
- [ ] Create test cases for slug generation:
  - Verify algorithm produces expected output for sample tasks
  - Verify uniqueness within task context
- [ ] Verify shell script patterns work:
  - Test plan file detection with new naming
  - Test summary file detection with new naming
  - Test report file detection with new naming
- [ ] Check cross-file consistency:
  - Agent references match skill references
  - Skill references match script patterns
  - Documentation matches code
- [ ] Update `.claude/docs/reference/standards/artifact-formats.md` if exists, or ensure format is documented

**Timing**: 1 hour

**Verification**:
- [ ] Zero occurrences of old naming patterns in code
- [ ] Shell scripts tested with sample filenames
- [ ] All file categories updated (agents, skills, commands, scripts, docs)
- [ ] Implementation summary prepared

## Testing & Validation

- [ ] Grep audit: No remaining `research-{NNN}`, `implementation-{NNN}`, `implementation-summary-{DATE}` patterns
- [ ] Shell script test: postflight scripts correctly detect new file patterns
- [ ] Example verification: All example paths in documentation use new format
- [ ] Cross-reference check: Agent references match skill script patterns
- [ ] Consistency check: All files in each category updated before proceeding to next

## Artifacts & Outputs

- `plans/implementation-001.md` (this file)
- Updated agent files (9 files):
  - `.claude/agents/general-research-agent.md`
  - `.claude/agents/planner-agent.md`
  - `.claude/agents/general-implementation-agent.md`
  - 6 extension agent files
- Updated skill files (12 files):
  - `.claude/skills/skill-researcher/SKILL.md`
  - `.claude/skills/skill-planner/SKILL.md`
  - `.claude/skills/skill-implementer/SKILL.md`
  - 9 extension skill files
- Updated command files (3 files):
  - `.claude/commands/research.md`
  - `.claude/commands/plan.md`
  - `.claude/commands/implement.md`
- Updated postflight scripts (3-4 files):
  - `.claude/scripts/postflight-research.sh`
  - `.claude/scripts/postflight-plan.sh`
  - `.claude/scripts/postflight-implement.sh`
- Updated documentation (18+ files)
- Updated documentation standards in artifact-formats.md

## Rollback/Contingency

If implementation causes issues:

1. **Git rollback**: All changes are to `.claude/` directory files which are version-controlled
   ```bash
   git checkout .claude/agents/
   git checkout .claude/skills/
   git checkout .claude/commands/
   git checkout .claude/scripts/
   git checkout .claude/context/
   git checkout .claude/CLAUDE.md
   git checkout .claude/README.md
   ```

2. **Partial rollback**: If only specific categories have issues, revert those files:
   ```bash
   git checkout .claude/scripts/postflight-*.sh  # Revert scripts only
   ```

3. **Detection of issues**: Monitor for:
   - Postflight scripts failing to find artifacts
   - Commands reporting "artifact not found" errors
   - Agents creating files with wrong naming

4. **Fix forward**: If rollback not desired, run targeted grep to find missed references and update individually.

## Notes

### Per-Task Sequential Numbering

Within each task directory, files are numbered sequentially regardless of type:
- `01_research-topic.md` (first research report)
- `02_revised-approach.md` (second research report or revised plan)
- `03_implementation-plan.md` (implementation plan)
- `04_execution-summary.md` (implementation summary)

This maintains chronological ordering while providing descriptive names.

### Slug Generation Guidelines

When implementing, use these rules for slug generation:
1. Start with task title/description
2. Remove: a, an, the, in, on, at, and, or, of, for, to
3. Keep: main verbs, nouns, adjectives
4. Convert to kebab-case
5. Limit to 3-5 words
6. Ensure uniqueness within task (append -v2, -v3 for revisions)

### Version Handling

For plan revisions with new naming:
- Option A: Sequential numbering (preferred) - `03_plan-name.md`, `04_plan-revision.md`
- Option B: Version suffix - `03_plan-name.md`, `03_plan-name-v2.md`

Decision: Use Option A (sequential) to maintain clear chronological ordering.
