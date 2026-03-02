# Research Report: Task #104

**Task**: 104 - Fix /implement phase status live updates
**Date**: 2026-03-02
**Focus**: ProofChecker system comparison, plan-level `[IN PROGRESS]` renaming, and centralized helper script architecture

## Summary

This third research report builds on the root cause analysis (research-001) and implementation specification (research-002) by examining the ProofChecker `.claude/` system's approach to status management. The ProofChecker system has already solved the exact same dual-status problem through a **centralized helper script** (`update-plan-status.sh`) and **clean separation between plan-level and phase-level status markers**. The key architectural insight is that plan-level status should use a centralized script callable from any skill, while phase-level status should be managed exclusively by agents via the Edit tool on heading lines. Additionally, this report evaluates the user's preference for `[IN PROGRESS]` over `[IMPLEMENTING]` at the plan level and recommends against that change due to its pervasive impact on the state machine, while noting that `[IN PROGRESS]` is already correctly used at the phase level.

## Findings

### Finding 1: ProofChecker Has a Centralized Plan Status Helper Script

The ProofChecker system at `/home/benjamin/Projects/ProofChecker/.claude/scripts/update-plan-status.sh` provides a centralized, standalone script for plan-level status updates. Key characteristics:

**Architecture**:
- 222-line bash script with validation, fallback, and verification
- Called from skills via: `.claude/scripts/update-plan-status.sh "$task_number" "$project_name" "IMPLEMENTING"`
- Handles plan file discovery (with project_name or glob fallback)
- Maps state.json status strings to plan file markers
- Includes validation mode (`--validate`) for checking/auto-fixing mismatches
- Has idempotency check (skips if already at target status)

**Pattern for plan-level update**:
```bash
sed -i "s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [${new_status}]/" "$plan_file"
```

**Critical observation**: This script uses the SAME overly-broad sed pattern (`\[.*\]`) that the neovim system has. However, in the ProofChecker system this is less dangerous because:
1. The ProofChecker's `plan-format.md` puts phase status ONLY in headings (`### Phase N: Name [STATUS]`), not in `**Status**:` metadata lines per phase
2. There is only ONE `- **Status**: [...]` line in the entire plan file (the plan-level metadata)
3. The agents use the Edit tool with exact heading strings for phase updates, never touching `**Status**:` lines

**Verification pattern** (ProofChecker):
```bash
updated_status=$(grep -m1 "^- \*\*Status\*\*:" "$plan_file" | sed 's/.*\[\([^]]*\)\].*/\1/' || echo "")
if [ "$updated_status" = "$new_status" ]; then
    echo "$plan_file"
fi
```

### Finding 2: ProofChecker's Clean Two-Domain Separation

The ProofChecker enforces a strict separation between plan-level and phase-level status:

| Domain | Location | Who Updates | How Updated | Markers |
|--------|----------|-------------|-------------|---------|
| Plan-level | `- **Status**: [STATUS]` (metadata line 4) | Skills (preflight/postflight) | `update-plan-status.sh` script | [NOT STARTED], [IMPLEMENTING], [COMPLETED], [PARTIAL] |
| Phase-level | `### Phase N: Name [STATUS]` (heading) | Agents (Stage 4 loop) | Edit tool with exact heading match | [NOT STARTED], [IN PROGRESS], [COMPLETED], [PARTIAL] |

This is the same target architecture proposed in research-002, confirming that approach.

**ProofChecker agent pattern** (from `general-implementation-agent.md` Stage 4):
```
Edit:
  file_path: specs/{N}_{SLUG}/plans/implementation-{NNN}.md
  old_string: "### Phase {P}: {exact_phase_name} [NOT STARTED]"
  new_string: "### Phase {P}: {exact_phase_name} [IN PROGRESS]"
```

This is identical to what research-002 recommended for the neovim system.

### Finding 3: ProofChecker Still Uses [IMPLEMENTING] at Plan Level

The ProofChecker system uses `[IMPLEMENTING]` at the plan and task level, NOT `[IN PROGRESS]`:

- `status-markers.md`: `[IMPLEMENTING]` is defined as "Implementation work is actively underway" with state.json value `"implementing"`
- `workflows.md`: "Update status `[IMPLEMENTING]`" at step 2 of implementation workflow
- `state-management.md`: `[PLANNED] -> [IMPLEMENTING] -> [COMPLETED]`
- `update-plan-status.sh`: Maps `"implementing" -> "IMPLEMENTING"`

The ProofChecker uses `[IN PROGRESS]` ONLY at the phase level within plan files (in `artifact-formats.md` and agent instructions). This two-level naming convention is a deliberate design choice:
- `[IMPLEMENTING]` = task/plan is in the implementation lifecycle phase (mirrors the state machine)
- `[IN PROGRESS]` = a specific phase is currently being worked on (a more general "work happening" signal)

### Finding 4: Impact Analysis of Renaming [IMPLEMENTING] to [IN PROGRESS] at Plan Level

The user prefers `[IN PROGRESS]` over `[IMPLEMENTING]` for the plan-level status marker. This would require changes across 20+ files in the neovim system:

**Files containing `[IMPLEMENTING]` in the neovim `.claude/` directory**: 20 files found.

**Categories of impact**:

1. **State machine definitions** (4 files):
   - `.claude/rules/state-management.md` - Status transitions, mapping table
   - `.claude/context/core/standards/status-markers.md` - Complete status definitions
   - `.claude/context/core/workflows/status-transitions.md` - Transition diagram
   - `.claude/context/core/orchestration/state-management.md` - Orchestration state

2. **Skill preflight/postflight** (5 files):
   - `.claude/skills/skill-implementer/SKILL.md`
   - `.claude/skills/skill-neovim-implementation/SKILL.md`
   - `.claude/skills/skill-typst-implementation/SKILL.md`
   - `.claude/skills/skill-latex-implementation/SKILL.md`
   - `.claude/skills/skill-status-sync/SKILL.md`

3. **Command files** (1 file):
   - `.claude/commands/implement.md`

4. **Context/documentation files** (6 files):
   - `.claude/context/core/orchestration/routing.md`
   - `.claude/context/core/patterns/inline-status-update.md`
   - `.claude/context/project/processes/implementation-workflow.md`
   - `.claude/context/core/workflows/command-lifecycle.md`
   - `.claude/docs/guides/user-guide.md`
   - `.claude/docs/guides/creating-commands.md`

5. **Extension skills** (1 file):
   - `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md`

6. **CLAUDE.md and README** (2 files):
   - `.claude/CLAUDE.md`
   - `.claude/rules/workflows.md`

**Semantic problem**: `[IN PROGRESS]` already exists at the phase level and means "currently being worked on within a phase." Using it at BOTH plan and phase levels creates ambiguity:
- Plan status `[IN PROGRESS]` = "some phase is being executed"
- Phase status `[IN PROGRESS]` = "this specific phase is being executed"

These are different concepts. `[IMPLEMENTING]` correctly signals "the task is in the implementation lifecycle phase" which is distinct from "some work unit is actively executing."

**state.json alignment**: The state.json value `"implementing"` maps cleanly to `[IMPLEMENTING]`. If we change to `[IN PROGRESS]`, the state.json value would either remain `"implementing"` (creating a naming mismatch) or change to `"in_progress"` (breaking backward compatibility and requiring migration).

### Finding 5: Recommended Approach - Centralized Helper Script

The most systematic approach, learned from the ProofChecker, is to create a centralized plan status helper script at `.claude/scripts/update-plan-status.sh`.

**Advantages over distributed sed**:
1. Single point of maintenance for the sed pattern
2. Built-in plan file discovery with fallback
3. Idempotency checking (skip if already at target)
4. Verification after update
5. Validation mode for debugging synchronization issues
6. Testable independently of any skill

**Script responsibilities**:
- Discover the plan file for a given task number
- Validate the target status is known
- Update ONLY the plan-level `- **Status**: [...]` line (first occurrence)
- Verify the update succeeded
- Return the updated file path or empty for no-op

**Skills call the script instead of inline sed**:
```bash
# Before (distributed, error-prone):
sed -i "s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [IMPLEMENTING]/" "$plan_file"

# After (centralized, robust):
.claude/scripts/update-plan-status.sh "$task_number" "$project_name" "IMPLEMENTING"
```

### Finding 6: First-Match Sed Remains Important Even With Centralized Script

Even with the centralized script, the sed pattern inside it should use first-match (`0,/pattern/{s/...}`) as a safety measure:

```bash
# Safety: only update first occurrence (plan-level metadata)
sed -i '0,/^\- \*\*Status\*\*: \[.*\]/{s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: ['"${new_status}"']/}' "$plan_file"
```

**Why**: During the transition period, old plans still have per-phase `**Status**:` lines. The first-match ensures only the plan-level line is updated even for legacy plans. The ProofChecker's script does NOT do this (it relies on there being only one such line), which is a minor fragility.

The neovim system should improve on the ProofChecker pattern by including first-match safety.

### Finding 7: The Full Recommended Architecture

Combining insights from both systems and prior research:

```
Layer 1: Centralized Script (.claude/scripts/update-plan-status.sh)
  - Owns all plan-level status sed operations
  - Called by skills and commands
  - Handles plan discovery, validation, first-match sed, verification

Layer 2: Skills (preflight/postflight)
  - Call the centralized script for plan-level status
  - Handle state.json and TODO.md updates inline
  - Do NOT contain any sed patterns for plan files

Layer 3: Agents (phase execution loop)
  - Use Edit tool for phase heading status changes
  - Target exact heading strings: "### Phase N: Name [STATUS]"
  - Never touch plan-level **Status**: line
  - Never use sed for status updates
```

**Comparison with current architecture**:

| Concern | Current (Broken) | ProofChecker | Recommended |
|---------|-----------------|--------------|-------------|
| Plan-level sed | Inline in 5 skills + command (all broken) | Centralized script (single point) | Centralized script with first-match |
| Phase-level update | Ambiguous agent instructions | Edit tool on headings (correct) | Edit tool on headings (same) |
| Per-phase **Status**: line | Exists (dual-status) | Does not exist | Remove from templates |
| Plan discovery | Inline in each skill | Script with fallback | Script with fallback |
| Verification | None | grep after sed | grep after sed |
| Status naming | [IMPLEMENTING] plan / [IN PROGRESS] phase | [IMPLEMENTING] plan / [IN PROGRESS] phase | [IMPLEMENTING] plan / [IN PROGRESS] phase (no change) |

### Finding 8: Revised File Change Inventory

Building on research-002's 16-file inventory, the centralized script approach changes the work breakdown:

**New file to create**:
1. `.claude/scripts/update-plan-status.sh` - Centralized helper (port from ProofChecker with first-match improvement)

**Templates to update** (same as research-002):
2. `.claude/rules/artifact-formats.md` - Remove per-phase `**Status**:` line, add `[NOT STARTED]` to heading
3. `.claude/agents/planner-agent.md` - Ensure heading-only status generation

**Skills to update** (simplified - replace inline sed with script call):
4. `.claude/skills/skill-implementer/SKILL.md` - Replace sed with script call (preflight + postflight)
5. `.claude/skills/skill-neovim-implementation/SKILL.md` - Same
6. `.claude/skills/skill-latex-implementation/SKILL.md` - Same
7. `.claude/skills/skill-typst-implementation/SKILL.md` - Same

**Command to update** (simplified):
8. `.claude/commands/implement.md` - Replace GATE OUT defensive sed with script call

**Agents to update** (clarify phase heading edits):
9. `.claude/agents/general-implementation-agent.md` - Explicit Edit tool examples for heading status
10. `.claude/agents/neovim-implementation-agent.md` - Same
11. `.claude/agents/latex-implementation-agent.md` - Same
12. `.claude/agents/typst-implementation-agent.md` - Same

**Total: 12 files** (down from 16, because the centralized script eliminates duplication).

### Finding 9: The [IN PROGRESS] vs [IMPLEMENTING] Decision

**Recommendation**: Keep `[IMPLEMENTING]` at the plan and task level. Do NOT rename to `[IN PROGRESS]`.

**Rationale**:
1. **Semantic clarity**: `[IMPLEMENTING]` means "in the implementation lifecycle phase" (distinct from research, planning). `[IN PROGRESS]` is too generic -- every in-progress status (researching, planning, implementing) could be described as "in progress."
2. **Two-level distinction**: Both the neovim and ProofChecker systems use `[IN PROGRESS]` at the phase level and `[IMPLEMENTING]` at the plan/task level. Collapsing them creates confusion.
3. **State machine alignment**: The state.json value `"implementing"` maps directly to `[IMPLEMENTING]`. Changing it introduces either a name mismatch or a migration burden.
4. **Scope of change**: 20+ files across the system would need updating, including state machine definitions, transition diagrams, and all documentation. This is a rename-only change with no functional benefit but significant risk of introducing inconsistencies.
5. **ProofChecker precedent**: The same developer's other project uses the same convention, suggesting it is a deliberate and tested design choice.

**If the user still prefers `[IN PROGRESS]`**: It should be treated as a separate task (scope: rename only, no functional changes) to avoid conflating the rename with the bug fix. The bug fix should land first, then the rename can be evaluated independently.

## Recommendations

### Primary Recommendation: Centralized Script + Clean Separation

1. **Create `.claude/scripts/update-plan-status.sh`** -- port from ProofChecker with first-match sed improvement
2. **Update templates** to remove per-phase `**Status**:` lines
3. **Update skills** to call the centralized script instead of inline sed
4. **Update agents** with explicit Edit tool examples for heading-based phase status
5. **Keep `[IMPLEMENTING]`** at plan/task level (do not rename)

### Secondary Recommendation: If User Insists on [IN PROGRESS] Rename

Create a separate follow-up task specifically for the rename:
- Scope: Pure text replacement across 20 files
- No functional changes
- Should NOT be combined with the bug fix
- Requires updating state.json mapping and all transition documentation

### Implementation Order

1. Create centralized script (foundation)
2. Update plan templates (eliminate dual-status source)
3. Update 4 skills + 1 command (replace sed with script call)
4. Update 4 agents (clarify heading-based phase edits)
5. Test with existing plan files (backward compatibility)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Script not found at runtime | High | Use `$CLAUDE_DIR/scripts/` relative path; verify in skill preflight |
| Old plans with per-phase **Status**: lines | Low | First-match sed in script targets only plan-level; stale lines are harmless |
| ProofChecker script has bugs we inherit | Low | Review and improve (add first-match, which ProofChecker lacks) |
| Renaming [IMPLEMENTING] introduces inconsistencies | Medium | Recommend against rename; if done, use separate task |
| Extension-based skills need same pattern | Low | They do not have implementation skills yet; document pattern for future |

## References

- `/home/benjamin/Projects/ProofChecker/.claude/scripts/update-plan-status.sh` - ProofChecker centralized helper (222 lines)
- `/home/benjamin/Projects/ProofChecker/.claude/skills/skill-implementer/SKILL.md` - ProofChecker skill calling the helper
- `/home/benjamin/Projects/ProofChecker/.claude/agents/general-implementation-agent.md` - ProofChecker agent Edit tool pattern
- `/home/benjamin/Projects/ProofChecker/.claude/context/core/formats/plan-format.md` - ProofChecker plan format (heading-only phase status)
- `/home/benjamin/Projects/ProofChecker/.claude/context/core/standards/status-markers.md` - ProofChecker status marker definitions
- `/home/benjamin/Projects/ProofChecker/.claude/rules/artifact-formats.md` - ProofChecker phase status markers (compact)
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` - Neovim skill (current broken sed)
- `/home/benjamin/.config/nvim/.claude/context/core/patterns/inline-status-update.md` - Neovim inline update patterns
- `specs/104_fix_implement_phase_status_live_updates/reports/research-001.md` - Root cause analysis
- `specs/104_fix_implement_phase_status_live_updates/reports/research-002.md` - Implementation specification

## Next Steps

Run `/plan 104` to create an implementation plan incorporating all three research reports. The plan should prioritize the centralized script creation and use findings from this report to reduce the file count from 16 to 12.
