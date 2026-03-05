# Implementation Plan: Fix Agent Delegation System Failure

- **Task**: OC_141 - Fix agent delegation system failure
- **Status**: [NOT STARTED]
- **Effort**: 5 hours
- **Dependencies**: None (foundational infrastructure fix)
- **Research Inputs**: [research-001.md](../reports/research-001.md) - Critical system failure analysis
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**:
  - .opencode/context/core/formats/plan-format.md
  - .opencode/context/core/standards/status-markers.md
  - .opencode/context/core/standards/documentation-standards.md
  - .opencode/context/core/standards/task-management.md
- **Type**: markdown

## Overview

Fix the critical system failure where skills are displayed instead of executed. When workflow commands invoke skills, the skill specification content is output to the terminal rather than delegating to subagents via the Task tool. This breaks all workflow commands (/plan, /implement, /research, etc.).

The fix requires auditing the command-to-skill routing mechanism, identifying where the Task tool invocation should occur, and ensuring skills properly execute their <execution> stages rather than just returning content.

### Research Integration

Based on research-001.md, the root cause is a gap between skill loading and skill execution. The skill tool appears to load skill content for reference but not execute the workflow stages described in the skill's <execution> section. Subagent delegation via Task tool with subagent_type is never triggered.

## Goals & Non-Goals

**Goals:**
- Audit all 12+ command specifications for proper skill invocation patterns
- Audit all 11+ skill definitions for executable <execution> stages
- Identify the exact location where Task tool delegation should occur
- Implement fix to ensure skills execute rather than display
- Verify all workflow commands work end-to-end
- Document the delegation pattern for future reference

**Non-Goals:**
- Rewriting the entire agent system architecture
- Adding new workflow commands or skills
- Changing the plan format or structure standards
- Optimizing context loading (covered by other tasks)

## Risks & Mitigations

- **Risk**: Fix breaks existing working functionality  
  **Mitigation**: Test each workflow command after changes; have rollback plan ready

- **Risk**: Subagent registration/configuration issues prevent delegation  
  **Mitigation**: Verify subagent availability before implementing fix; check AGENTS.md configuration

- **Risk**: Multiple interacting issues complicate fix  
  **Mitigation**: Systematic audit approach; document each finding; fix one issue at a time

- **Risk**: Context injection failures cascade into execution failures  
  **Mitigation**: Test context loading separately from execution; verify context files exist

- **Risk**: Changes require system restart or configuration reload  
  **Mitigation**: Document any reload requirements; minimize disruption to active sessions

## Implementation Phases

### Phase 1: Audit Command Specifications [COMPLETED]
- **Started:** 2026-03-06T18:30:00Z
- **Completed:** 2026-03-06T19:00:00Z
- **Goal:** Identify how commands currently invoke skills and where Task tool should be called
- **Tasks:**
  - [x] Read all 12+ command specifications (.opencode/commands/*.md)
  - [x] Document current skill invocation patterns
  - [x] Identify which commands use → Skill notation vs explicit tool calls
  - [x] Check for Task tool usage with subagent_type parameter
  - [x] Document findings in audit report
- **Timing:** 1 hour
- **Report:** [audit-commands.md](../reports/audit-commands.md)
- **Findings:** ROOT CAUSE IDENTIFIED - Commands describe skill invocation but don't execute skills. Skills are displayed instead of executed.

### Phase 2: Audit Skill Definitions [COMPLETED]
- **Started:** 2026-03-06T19:00:00Z
- **Completed:** 2026-03-06T19:15:00Z
- **Goal:** Understand how skills define execution workflows and verify they are executable
- **Tasks:**
  - [x] Read all 11+ skill definitions (.opencode/skills/skill-*/SKILL.md)
  - [x] Document <execution> stage definitions
  - [x] Check for <context_injection> configurations
  - [x] Identify agent delegation points in each skill
  - [x] Verify subagent types referenced exist
  - [x] Document findings in audit report
- **Timing:** 1 hour
- **Report:** [audit-skills.md](../reports/audit-skills.md)
- **Findings:** ALL SKILLS ARE CORRECTLY DESIGNED! Skills correctly use Task tool with subagent_type. Problem is upstream in command invocation.

### Phase 3: Test Current Behavior [NOT STARTED]
- **Goal:** Confirm the exact failure mode and identify where execution stops
- **Tasks:**
  - [ ] Test /plan command with verbose output to see execution flow
  - [ ] Verify skill content is displayed vs skill being executed
  - [ ] Check if Task tool is ever invoked
  - [ ] Test if subagent delegation fails or never attempted
  - [ ] Document exact failure point for each workflow command
- **Timing:** 30 minutes

### Phase 4: Design Fix Approach [NOT STARTED]
- **Goal:** Determine the minimal fix that makes skills execute their workflows
- **Tasks:**
  - [ ] Review audit findings from Phases 1-3
  - [ ] Compare Option A (explicit tool calls) vs Option D (direct delegation)
  - [ ] Design fix that minimizes changes to existing infrastructure
  - [ ] Document the chosen approach with rationale
  - [ ] Identify which files need modification
- **Timing:** 30 minutes

### Phase 5: Implement Command-Skill Integration Fix [NOT STARTED]
- **Goal:** Add proper Task tool invocation to make skills execute
- **Tasks:**
  - [ ] Update command specifications to explicitly invoke skill tool with parameters
  - [ ] Or update skill definitions to ensure <execution> stages run
  - [ ] Add error handling for failed delegations
  - [ ] Verify context injection works when skills execute
  - [ ] Test one command end-to-end before applying to others
- **Timing:** 1.5 hours

### Phase 6: Test All Workflow Commands [NOT STARTED]
- **Goal:** Verify all workflow commands now work correctly
- **Tasks:**
  - [ ] Test /plan command creates plan files
  - [ ] Test /research command creates research artifacts
  - [ ] Test /implement command executes phases
  - [ ] Test /revise, /meta, /learn, /refresh, /remember, /review, /status, /todo
  - [ ] Verify skills execute <execution> stages
  - [ ] Verify subagents receive proper context injection
  - [ ] Confirm no skill content displayed to user (only execution results)
- **Timing:** 30 minutes

### Phase 7: Document and Commit [NOT STARTED]
- **Goal:** Document the fix and update system state
- **Tasks:**
  - [ ] Create documentation explaining the delegation pattern
  - [ ] Update any affected README files
  - [ ] Create comprehensive test results summary
  - [ ] Update TODO.md status for OC_141 to [COMPLETED]
  - [ ] Update state.json status and add completion summary
  - [ ] Commit all changes with proper message
- **Timing:** 30 minutes

## Testing & Validation

- [ ] Verify /plan OC_139 successfully creates a plan file (using existing researched task)
- [ ] Verify /research creates research artifacts with proper content
- [ ] Verify /implement executes phases and updates state correctly
- [ ] Verify skills execute their <execution> stages (not just display content)
- [ ] Verify subagents receive context injection (plan-format.md, status-markers.md, etc.)
- [ ] Verify no skill specification content is displayed to user
- [ ] Verify Task tool is invoked with proper subagent_type parameter
- [ ] Verify command-to-skill routing works for all 12+ commands
- [ ] Verify backward compatibility with existing task files

## Artifacts & Outputs

- `specs/OC_141_fix_agent_delegation_system_failure/plans/implementation-001.md` (this file)
- `specs/OC_141_fix_agent_delegation_system_failure/reports/audit-commands.md` - Command specification audit findings
- `specs/OC_141_fix_agent_delegation_system_failure/reports/audit-skills.md` - Skill definition audit findings
- `.opencode/commands/*.md` - Updated command specifications (if modified)
- `.opencode/skills/skill-*/SKILL.md` - Updated skill definitions (if modified)
- `specs/OC_141_fix_agent_delegation_system_failure/summaries/implementation-summary-YYYYMMDD.md` - Final summary

## Rollback/Contingency

If the fix causes regressions or breaks existing functionality:

1. **Immediate Rollback**: Revert to last known working commit (before OC_141 changes)
   ```bash
   git log --oneline -5
   git revert HEAD --no-edit  # or git reset --hard <commit>
   ```

2. **Partial Rollback**: If only specific commands affected, revert those files individually
   ```bash
   git checkout <commit> -- .opencode/commands/<affected>.md
   ```

3. **Alternative Approach**: If Option A (explicit tool calls) fails, try Option D (direct agent delegation) or Option C (fix skill execution model)

4. **Documentation**: Document what failed so future attempts can avoid the same issues

5. **System State**: Ensure state.json and TODO.md can be manually reverted if automatic updates fail

## Notes

- **Critical Priority**: This fix is foundational - all other workflow tasks depend on it
- **Verification Required**: Must test ALL workflow commands, not just the one that failed initially
- **Related Work**: OC_135 attempted to fix command routing but didn't solve this core issue
- **Impact**: Without this fix, the entire agent workflow system remains non-functional
