# Implementation Plan: Task #221

- **Task**: 221 - fix_phase_status_markers_implementation_agents
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**: [01_phase-status-markers.md](../reports/01_phase-status-markers.md)
- **Artifacts**: plans/02_implementation-plan.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

This plan addresses inconsistent phase status marker handling across implementation agents and skills. The reference implementation (general-implementation-agent.md) provides complete Phase Checkpoint Protocol with detailed Edit tool patterns and per-phase git commits. Three targets need updates: grant-agent lacks the protocol entirely, skill-grant lacks update-plan-status.sh calls, and latex/typst implementation agents have incomplete phase marker instructions.

### Research Integration

Key findings from research report:
- general-implementation-agent.md provides reference implementation at lines 315-337 (Phase Checkpoint Protocol) and lines 135-141, 168-175 (Stage 4A/4D)
- grant-agent.md has 590 lines but no Phase Checkpoint Protocol section
- skill-grant SKILL.md has workflow-to-status mapping but no update-plan-status.sh calls
- latex-implementation-agent.md (123 lines) and typst-implementation-agent.md (104 lines) have condensed Stage 4 without Edit tool patterns

## Goals & Non-Goals

**Goals**:
- Add Phase Checkpoint Protocol section to grant-agent.md for assemble workflow
- Add update-plan-status.sh calls to skill-grant SKILL.md (Stage 2 preflight, Stage 7 postflight)
- Expand Stage 4 in latex-implementation-agent.md with detailed Edit tool patterns
- Expand Stage 4 in typst-implementation-agent.md with detailed Edit tool patterns
- Ensure all implementation agents update plan file phase markers consistently

**Non-Goals**:
- Modifying general-implementation-agent.md (reference implementation is complete)
- Adding phase tracking to non-assemble grant workflows (funder_research, proposal_draft, etc.)
- Creating new scripts or utilities (update-plan-status.sh already exists)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edit patterns may not match actual file structure | Medium | Low | Verify file structure before editing |
| Over-verbosity in latex/typst agents | Low | Medium | Keep expansion focused on critical patterns only |
| Breaking existing grant workflows | High | Low | Only add to assemble workflow condition |

## Implementation Phases

### Phase 1: Add Phase Checkpoint Protocol to grant-agent.md [COMPLETED]

**Goal**: Add Phase Checkpoint Protocol section to grant-agent following general-implementation-agent reference

**Tasks**:
- [ ] Read grant-agent.md to find insertion point (after Stage 5: Assemble Workflow section, before Stage 6: Write Metadata File or at end before Critical Requirements)
- [ ] Add Phase Checkpoint Protocol section adapted for grant workflows
- [ ] Include Edit tool patterns for `[NOT STARTED]` -> `[IN PROGRESS]` -> `[COMPLETED]`
- [ ] Include per-phase git commit instructions
- [ ] Note applicability to assemble workflow only

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/agents/grant-agent.md` - Add new section after line ~328 (after Assemble Workflow)

**Edit Pattern**:
```
old_string: "### Stage 6: Write Metadata File"
new_string: "## Phase Checkpoint Protocol

For grant tasks with implementation plans (typically `assemble` workflow):

1. **Read plan file**, identify current phase
2. **Update phase status** to `[IN PROGRESS]` in plan file
   - Use Edit tool with:
     - old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
     - new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
   - Phase status lives ONLY in the heading
3. **Execute phase steps** as documented
4. **Update phase status** to `[COMPLETED]` or `[BLOCKED]` or `[PARTIAL]`
   - Use Edit tool with:
     - old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
     - new_string: `### Phase {P}: {Phase Name} [COMPLETED]`
5. **Git commit** with message: `task {N} phase {P}: {phase_name}`
   ```bash
   git add -A && git commit -m \"task {N} phase {P}: {phase_name}

   Session: {session_id}

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>\"
   ```
6. **Proceed to next phase** or return if blocked

**This ensures**:
- Resume point is always discoverable from plan file
- Git history reflects phase-level progress
- Failed phases can be retried from beginning

**Note**: This protocol applies primarily to the `assemble` workflow when following a multi-phase plan. Single-stage workflows (funder_research, proposal_draft, budget_develop, progress_track) may not require phase-level tracking.

---

### Stage 6: Write Metadata File"
```

**Verification**:
- [ ] File contains "## Phase Checkpoint Protocol" section
- [ ] Section appears before Stage 6
- [ ] Edit tool patterns are present with old_string/new_string examples

---

### Phase 2: Add update-plan-status.sh calls to skill-grant [COMPLETED]

**Goal**: Add plan file status updates to skill-grant SKILL.md at preflight and postflight stages

**Tasks**:
- [ ] Add update-plan-status.sh call in Stage 2 (Preflight) for assemble workflow
- [ ] Add update-plan-status.sh call in Stage 7 (Postflight) for assemble workflow success
- [ ] Add update-plan-status.sh call in Stage 7 (Postflight) for assemble workflow partial

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - Add calls in Stage 2 (~line 168) and Stage 7 (~line 378)

**Edit Pattern for Stage 2** (after the state.json update block):
```
old_string: "**Update TODO.md**: Use Edit tool to change status marker to the workflow-specific in-progress state.

---

### Stage 3: Create Postflight Marker"
new_string: "**Update TODO.md**: Use Edit tool to change status marker to the workflow-specific in-progress state.

**Update plan file** (for assemble workflow only):
```bash
# Update plan file status for assemble workflow
if [ \"$workflow_type\" = \"assemble\" ]; then
    .claude/scripts/update-plan-status.sh \"$task_number\" \"$padded_num\" \"$project_name\" \"IMPLEMENTING\" 2>/dev/null || true
fi
```

---

### Stage 3: Create Postflight Marker"
```

**Edit Pattern for Stage 7** (after the state.json success update block):
```
old_string: "**Update TODO.md**: Use Edit tool to change status marker to the final success state.

**On partial/failed**: Keep status at preflight level for resume."
new_string: "**Update TODO.md**: Use Edit tool to change status marker to the final success state.

**Update plan file** (for assemble workflow):
```bash
# Update plan file status for assemble workflow
if [ \"$workflow_type\" = \"assemble\" ]; then
    if [ \"$meta_status\" = \"assembled\" ]; then
        .claude/scripts/update-plan-status.sh \"$task_number\" \"$padded_num\" \"$project_name\" \"COMPLETED\" 2>/dev/null || true
    elif [ \"$meta_status\" = \"partial\" ]; then
        .claude/scripts/update-plan-status.sh \"$task_number\" \"$padded_num\" \"$project_name\" \"PARTIAL\" 2>/dev/null || true
    fi
fi
```

**On partial/failed**: Keep status at preflight level for resume."
```

**Verification**:
- [ ] Stage 2 contains update-plan-status.sh call with IMPLEMENTING for assemble
- [ ] Stage 7 contains update-plan-status.sh calls with COMPLETED and PARTIAL for assemble
- [ ] Calls are conditional on workflow_type = "assemble"

---

### Phase 3: Expand phase marker instructions in latex-implementation-agent.md [COMPLETED]

**Goal**: Replace condensed Stage 4 with detailed Edit tool patterns and add Phase Checkpoint Protocol

**Tasks**:
- [ ] Replace Stage 4 section with expanded version including A/B/C/D/E substeps
- [ ] Add Edit tool patterns showing old_string/new_string for phase markers
- [ ] Add instruction about phase status living only in heading
- [ ] Add per-phase git commit instructions
- [ ] Add Phase Checkpoint Protocol section

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/latex/agents/latex-implementation-agent.md` - Replace Stage 4 (lines 75-82) and add Phase Checkpoint Protocol

**Edit Pattern for Stage 4**:
```
old_string: "### Stage 4: Execute LaTeX Development Loop

For each phase:
1. Mark phase `[IN PROGRESS]`
2. Create/modify .tex files
3. Run `latexmk -pdf`
4. Check compilation result
5. Mark phase `[COMPLETED]` or `[PARTIAL]`"
new_string: "### Stage 4: Execute LaTeX Development Loop

For each phase starting from resume point:

**A. Mark Phase In Progress**
Edit plan file heading to show the phase is active.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
- new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`

Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.

**B. Execute Steps**
1. Create/modify .tex files per plan instructions
2. Run `latexmk -pdf document.tex` to compile
3. Check for compilation errors
4. Fix errors iteratively

**C. Verify Phase Completion**
- Compilation must succeed
- All specified files must exist
- Cross-references must resolve

**D. Mark Phase Complete**
Edit plan file heading to show the phase is finished.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
- new_string: `### Phase {P}: {Phase Name} [COMPLETED]`

Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.

**E. Git Commit Phase**
```bash
git add -A && git commit -m \"task {N} phase {P}: {phase_name}

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>\"
```"
```

**Add Phase Checkpoint Protocol** after Stage 8 (before Common Errors):
```
old_string: "### Stage 8: Return Brief Text Summary

## Common Errors and Fixes"
new_string: "### Stage 8: Return Brief Text Summary

## Phase Checkpoint Protocol

For each phase in the implementation plan:

1. **Read plan file**, identify current phase
2. **Update phase status** to `[IN PROGRESS]` in plan file
3. **Execute phase steps** as documented
4. **Update phase status** to `[COMPLETED]` or `[BLOCKED]` or `[PARTIAL]`
5. **Git commit** with message: `task {N} phase {P}: {phase_name}`
6. **Proceed to next phase** or return if blocked

**This ensures**:
- Resume point is always discoverable from plan file
- Git history reflects phase-level progress
- Failed phases can be retried from beginning

---

## Common Errors and Fixes"
```

**Verification**:
- [ ] Stage 4 contains A/B/C/D/E substeps
- [ ] Edit tool patterns with old_string/new_string are present
- [ ] Phase Checkpoint Protocol section exists
- [ ] Git commit instruction with session_id placeholder is present

---

### Phase 4: Expand phase marker instructions in typst-implementation-agent.md [COMPLETED]

**Goal**: Replace condensed Stage 4 with detailed Edit tool patterns and add Phase Checkpoint Protocol

**Tasks**:
- [ ] Replace Stage 4 section with expanded version including A/B/C/D/E substeps
- [ ] Add Edit tool patterns showing old_string/new_string for phase markers
- [ ] Add instruction about phase status living only in heading
- [ ] Add per-phase git commit instructions
- [ ] Add Phase Checkpoint Protocol section

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/typst/agents/typst-implementation-agent.md` - Replace Stage 4 (lines 58-64) and add Phase Checkpoint Protocol

**Edit Pattern for Stage 4**:
```
old_string: "### Stage 4: Execute Typst Development Loop
For each phase:
1. Mark phase `[IN PROGRESS]`
2. Create/modify .typ files
3. Run `typst compile`
4. Check compilation result
5. Mark phase `[COMPLETED]` or `[PARTIAL]`"
new_string: "### Stage 4: Execute Typst Development Loop

For each phase starting from resume point:

**A. Mark Phase In Progress**
Edit plan file heading to show the phase is active.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
- new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`

Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.

**B. Execute Steps**
1. Create/modify .typ files per plan instructions
2. Run `typst compile document.typ` to compile
3. Check for compilation errors
4. Fix errors iteratively

**C. Verify Phase Completion**
- Compilation must succeed
- All specified files must exist

**D. Mark Phase Complete**
Edit plan file heading to show the phase is finished.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
- new_string: `### Phase {P}: {Phase Name} [COMPLETED]`

Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.

**E. Git Commit Phase**
```bash
git add -A && git commit -m \"task {N} phase {P}: {phase_name}

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>\"
```"
```

**Add Phase Checkpoint Protocol** after Stage 8 (before Typst vs LaTeX Differences):
```
old_string: "### Stage 8: Return Brief Text Summary

## Typst vs LaTeX Differences"
new_string: "### Stage 8: Return Brief Text Summary

## Phase Checkpoint Protocol

For each phase in the implementation plan:

1. **Read plan file**, identify current phase
2. **Update phase status** to `[IN PROGRESS]` in plan file
3. **Execute phase steps** as documented
4. **Update phase status** to `[COMPLETED]` or `[BLOCKED]` or `[PARTIAL]`
5. **Git commit** with message: `task {N} phase {P}: {phase_name}`
6. **Proceed to next phase** or return if blocked

**This ensures**:
- Resume point is always discoverable from plan file
- Git history reflects phase-level progress
- Failed phases can be retried from beginning

---

## Typst vs LaTeX Differences"
```

**Verification**:
- [ ] Stage 4 contains A/B/C/D/E substeps
- [ ] Edit tool patterns with old_string/new_string are present
- [ ] Phase Checkpoint Protocol section exists
- [ ] Git commit instruction with session_id placeholder is present

---

### Phase 5: Verification and Testing [COMPLETED]

**Goal**: Verify all changes are consistent and functional

**Tasks**:
- [ ] Verify grant-agent.md contains Phase Checkpoint Protocol section
- [ ] Verify skill-grant SKILL.md contains update-plan-status.sh calls for assemble workflow
- [ ] Verify latex-implementation-agent.md has expanded Stage 4 and Phase Checkpoint Protocol
- [ ] Verify typst-implementation-agent.md has expanded Stage 4 and Phase Checkpoint Protocol
- [ ] Run grep to confirm all agents have "Phase Checkpoint Protocol" section
- [ ] Verify Edit tool patterns are consistent across all agents

**Timing**: 20 minutes

**Verification Commands**:
```bash
# Check Phase Checkpoint Protocol exists in all implementation agents
grep -l "Phase Checkpoint Protocol" \
  .claude/agents/general-implementation-agent.md \
  .claude/extensions/present/agents/grant-agent.md \
  .claude/extensions/latex/agents/latex-implementation-agent.md \
  .claude/extensions/typst/agents/typst-implementation-agent.md

# Check update-plan-status.sh calls in skills
grep -c "update-plan-status.sh" \
  .claude/skills/skill-implementer/SKILL.md \
  .claude/extensions/present/skills/skill-grant/SKILL.md

# Check Edit tool patterns in all agents
grep -c "old_string:.*Phase.*NOT STARTED" \
  .claude/agents/general-implementation-agent.md \
  .claude/extensions/present/agents/grant-agent.md \
  .claude/extensions/latex/agents/latex-implementation-agent.md \
  .claude/extensions/typst/agents/typst-implementation-agent.md
```

**Verification**:
- [ ] All 4 implementation agents have Phase Checkpoint Protocol section
- [ ] skill-grant has update-plan-status.sh calls (should show 3 occurrences)
- [ ] All agents have Edit tool patterns for phase status markers

---

## Testing & Validation

- [ ] Phase Checkpoint Protocol section appears in grant-agent.md
- [ ] skill-grant SKILL.md contains conditional update-plan-status.sh calls for assemble workflow
- [ ] latex-implementation-agent.md Stage 4 has A/B/C/D/E substeps with Edit patterns
- [ ] typst-implementation-agent.md Stage 4 has A/B/C/D/E substeps with Edit patterns
- [ ] All 4 implementation agents can be found with `grep "Phase Checkpoint Protocol"`
- [ ] Edit patterns are consistent with general-implementation-agent.md reference

## Artifacts & Outputs

- plans/02_implementation-plan.md (this file)
- Modified files:
  - `.claude/extensions/present/agents/grant-agent.md`
  - `.claude/extensions/present/skills/skill-grant/SKILL.md`
  - `.claude/extensions/latex/agents/latex-implementation-agent.md`
  - `.claude/extensions/typst/agents/typst-implementation-agent.md`
- summaries/03_implementation-summary.md (after completion)

## Rollback/Contingency

If implementation causes issues:
1. Git revert the commit for the specific phase
2. Files can be restored to previous state via git checkout
3. Each phase is atomic and independent, allowing selective rollback
