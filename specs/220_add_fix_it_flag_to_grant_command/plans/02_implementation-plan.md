# Implementation Plan: Task #220

- **Task**: 220 - Add --fix-it flag to /grant command
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**: [01_fix-it-flag-research.md](../reports/01_fix-it-flag-research.md)
- **Artifacts**: plans/02_implementation-plan.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/formats/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Add a `--fix-it N` mode to the `/grant` command that scans grant project directories for embedded `FIX:`, `TODO:`, `NOTE:`, and `QUESTION:` tags in .tex, .md, and .bib files, then creates structured tasks following the same interactive selection pattern as `/fix-it`. The implementation adds the new workflow to skill-grant as direct execution (no subagent delegation), reusing the tag scanning and interactive selection patterns from skill-fix-it.

### Research Integration

Key findings from research report:
- Approach 1 (add workflow to skill-grant) is recommended for minimal code duplication
- skill-grant already uses thin wrapper pattern; fix_it_scan will be direct execution
- Grant-specific file types: .tex (%), .md (<!--), .bib (%)
- All created tasks use language="grant" (not detected from file type)
- No status change for parent task (non-destructive scan operation)

## Goals & Non-Goals

**Goals**:
- Add `--fix-it N` flag to /grant command with GATE IN/GATE OUT pattern
- Add `fix_it_scan` workflow type to skill-grant with direct execution
- Scan grant directories for FIX:, TODO:, NOTE:, QUESTION: tags
- Present findings interactively using AskUserQuestion
- Create tasks with language="grant" following multi-task creation standard
- Update state.json and TODO.md atomically

**Non-Goals**:
- Modifying the core /fix-it command or skill-fix-it
- Adding new tag types beyond FIX:, TODO:, NOTE:, QUESTION:
- Changing the status of the parent grant task
- Creating a separate skill (rejected in research)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| skill-grant becomes too complex | Medium | Low | Keep fix_it_scan as isolated section with clear boundaries |
| AskUserQuestion compatibility in skill context | Low | Low | Pattern already used in skill-fix-it successfully |
| Grant directory location varies | Medium | Medium | Check both specs/{NNN}_{SLUG}/ and grants/{N}_{slug}/ paths |
| Language detection confusion | Low | Low | Document that --fix-it always creates grant-language tasks |

## Implementation Phases

### Phase 1: Update Command File [NOT STARTED]

**Goal**: Add --fix-it mode detection and delegation to grant.md command

**Tasks**:
- [ ] Add `--fix-it` to Modes table in grant.md
- [ ] Update argument-hint to include `N --fix-it`
- [ ] Add mode detection for `N --fix-it` pattern in Mode Detection section
- [ ] Add Fix-It Scan Mode section with CHECKPOINT 1 (GATE IN), STAGE 2 (DELEGATE), CHECKPOINT 2 (GATE OUT)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/commands/grant.md`
  - Line ~4: Add to argument-hint
  - Line ~14-20: Add to Modes table
  - Line ~36-48: Add mode detection case
  - Line ~410+: Add new Fix-It Scan Mode section

**Verification**:
- grant.md contains --fix-it in Modes table
- Mode detection logic handles `N --fix-it` pattern
- Fix-It Scan Mode section follows GATE IN/GATE OUT pattern

---

### Phase 2: Update Skill Allowed Tools [NOT STARTED]

**Goal**: Add AskUserQuestion to skill-grant allowed-tools

**Tasks**:
- [ ] Add `AskUserQuestion` to allowed-tools in SKILL.md frontmatter
- [ ] Add `fix_it_scan` to workflow_type validation case statement

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/present/skills/skill-grant/SKILL.md`
  - Line ~4: Update `allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion`
  - Line ~107-114: Add `fix_it_scan` to workflow_type case statement

**Verification**:
- AskUserQuestion in allowed-tools
- fix_it_scan accepted as valid workflow_type

---

### Phase 3: Add Workflow Type Routing [NOT STARTED]

**Goal**: Add fix_it_scan routing to workflow type table and status mapping

**Tasks**:
- [ ] Add fix_it_scan row to Workflow Type Routing table
- [ ] Document that fix_it_scan has no status changes (non-destructive scan)
- [ ] Add fix_it_scan to preflight status mapping (no change)
- [ ] Add fix_it_scan to postflight status mapping (no change)

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/present/skills/skill-grant/SKILL.md`
  - Line ~40-50: Add row to Workflow Type Routing table
  - Line ~122-152: Add fix_it_scan case to preflight status
  - Line ~317-358: Add fix_it_scan case to postflight status

**Verification**:
- fix_it_scan documented with (no change) for preflight/postflight
- Status mapping cases include fix_it_scan

---

### Phase 4: Implement fix_it_scan Execution Section [NOT STARTED]

**Goal**: Add the main fix_it_scan execution logic to skill-grant

**Tasks**:
- [ ] Add new section "## Fix-It Scan Workflow (Direct Execution)" after Stage 11
- [ ] Implement grant directory location logic (specs/ or grants/ paths)
- [ ] Implement tag extraction using grep patterns for .tex, .md, .bib files
- [ ] Implement tag summary display (similar to skill-fix-it Step 4)
- [ ] Implement interactive task type selection using AskUserQuestion
- [ ] Implement individual TODO selection (if selected)
- [ ] Implement topic grouping for 2+ TODOs (optional component)
- [ ] Implement individual QUESTION selection (if selected)
- [ ] Implement topic grouping for 2+ QUESTIONs (optional component)
- [ ] Implement task creation with language="grant"
- [ ] Implement state.json and TODO.md atomic updates
- [ ] Implement git commit with session ID
- [ ] Implement brief summary return

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/extensions/present/skills/skill-grant/SKILL.md`
  - Line ~649+: Add new Fix-It Scan Workflow section (~200-300 lines)

**Key implementation details**:

1. **Grant directory location**:
   ```bash
   padded_num=$(printf "%03d" "$task_number")
   if [ -d "specs/${padded_num}_${project_name}" ]; then
     grant_dir="specs/${padded_num}_${project_name}"
   elif [ -d "grants/${task_number}_${project_name}" ]; then
     grant_dir="grants/${task_number}_${project_name}"
   else
     return error "Grant directory not found"
   fi
   ```

2. **Tag extraction patterns** (grant-specific):
   ```bash
   # LaTeX files
   grep -rn --include="*.tex" "% FIX:" "$grant_dir" 2>/dev/null || true
   grep -rn --include="*.tex" "% TODO:" "$grant_dir" 2>/dev/null || true
   # Markdown files
   grep -rn --include="*.md" "<!-- FIX:" "$grant_dir" 2>/dev/null || true
   # BibTeX files
   grep -rn --include="*.bib" "% FIX:" "$grant_dir" 2>/dev/null || true
   ```

3. **Interactive selection** (using AskUserQuestion):
   ```
   question: "Which task types would you like to create?"
   options: ["FIX: Combined fix task", "NOTE: Documentation task", "TODO: Individual tasks", "QUESTION: Research tasks"]
   allowMultiSelect: true
   ```

4. **Task creation** (all with language="grant"):
   - Follow multi-task-creation-standard.md components
   - Use existing /task creation pattern from grant.md

**Verification**:
- Can locate grant directory in specs/ or grants/
- Tags extracted from .tex, .md, .bib files correctly
- AskUserQuestion prompts work for selection
- Tasks created with language="grant"
- State files updated atomically

---

### Phase 5: Add Error Handling [NOT STARTED]

**Goal**: Add error handling for fix_it_scan workflow

**Tasks**:
- [ ] Add grant directory not found error
- [ ] Add no tags found early exit (informational, not error)
- [ ] Add empty selection handling (user selects nothing)
- [ ] Add git commit failure handling (non-blocking)

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/present/skills/skill-grant/SKILL.md`
  - Within fix_it_scan section: Add error handling cases

**Verification**:
- Error messages are clear and actionable
- No tags found returns gracefully with message
- Git failures are logged but don't block success

---

### Phase 6: Testing and Verification [NOT STARTED]

**Goal**: Verify implementation works end-to-end

**Tasks**:
- [ ] Create test grant task with embedded tags in .tex file
- [ ] Run `/grant N --fix-it` and verify tag detection
- [ ] Verify interactive selection prompts appear
- [ ] Select task types and verify tasks are created
- [ ] Verify tasks have language="grant" in state.json
- [ ] Verify TODO.md entries are formatted correctly
- [ ] Verify git commit is created with correct message

**Timing**: 30 minutes

**Test scenario**:
1. Create test task: `/grant "Test grant for fix-it integration"`
2. Create test directory with tags:
   ```bash
   mkdir -p specs/NNN_test_grant_for_fix_it_integration/
   echo '% FIX: Update budget calculations' > specs/NNN_test_grant_for_fix_it_integration/draft.tex
   echo '% TODO: Add methodology section' >> specs/NNN_test_grant_for_fix_it_integration/draft.tex
   ```
3. Run: `/grant N --fix-it`
4. Verify prompts and task creation

**Verification**:
- All test scenarios pass
- No errors or unexpected behavior

## Testing & Validation

- [ ] grant.md contains --fix-it in Modes table and argument-hint
- [ ] Mode detection handles `N --fix-it` syntax correctly
- [ ] skill-grant accepts fix_it_scan workflow_type
- [ ] Tag extraction works for .tex, .md, .bib files
- [ ] AskUserQuestion prompts appear for interactive selection
- [ ] Tasks created have language="grant"
- [ ] state.json and TODO.md updated atomically
- [ ] Git commit created with session ID
- [ ] Error cases handled gracefully

## Artifacts & Outputs

- `.claude/extensions/present/commands/grant.md` - Updated with --fix-it mode
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - Updated with fix_it_scan workflow
- No new files created (modifications to existing files only)

## Rollback/Contingency

If implementation fails:
1. Revert changes to grant.md (git checkout)
2. Revert changes to skill-grant/SKILL.md (git checkout)
3. Both files have clear section boundaries, making partial rollback possible
4. No database or state migration required - pure documentation/skill changes
