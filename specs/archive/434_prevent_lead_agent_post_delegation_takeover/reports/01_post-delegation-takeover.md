# Research Report: Prevent Lead Agent Post-Delegation Takeover

- **Task**: 434 - Prevent lead agent post-delegation takeover after subagent returns
- **Started**: 2026-04-14T21:00:00Z
- **Completed**: 2026-04-14T21:15:00Z
- **Effort**: Small (5-8 targeted edits across existing files)
- **Dependencies**: None (task 430 fixed the pre-delegation mirror problem)
- **Sources/Inputs**:
  - `.claude/skills/skill-implementer/SKILL.md` (454 lines) -- Core implementation skill
  - `.claude/skills/skill-team-implement/SKILL.md` (686 lines) -- Team implementation skill
  - `.claude/agents/general-implementation-agent.md` (245 lines) -- General implementation agent
  - `.claude/commands/implement.md` (575 lines) -- /implement command orchestrator
  - `.claude/context/standards/postflight-tool-restrictions.md` (203 lines) -- Existing postflight standard
  - 11 extension implementation skills (lean, nvim, python, nix, web, typst, latex, z3, epi, founder, deck)
- **Artifacts**: This report: `specs/434_prevent_lead_agent_post_delegation_takeover/reports/01_post-delegation-takeover.md`
- **Standards**: report-format.md, artifact-formats.md

## Project Context

- **Upstream Dependencies**: Task 430 (pre-delegation boundary), `postflight-tool-restrictions.md`
- **Downstream Dependents**: All implementation skills and extension implementation skills
- **Alternative Paths**: None -- this is the standard enforcement path
- **Potential Extensions**: Could add automated GATE OUT detection of tool-call violations

## Executive Summary

- The existing "MUST NOT (Postflight Boundary)" sections in skills list prohibited actions but lack an explicit **PROHIBITION** block with the specific violation pattern (lead agent continuing subagent work after return).
- `skill-implementer/SKILL.md` has a compressed one-line postflight boundary (line 453) that lacks the structured prohibition format used elsewhere.
- `skill-team-implement/SKILL.md` has a well-structured postflight boundary (lines 648-666) but does not name the specific takeover violation or state the "proceed immediately to postflight" requirement.
- `general-implementation-agent.md` does not explicitly state that partial results are acceptable and the agent should return `status: "partial"` rather than leaving work for the caller.
- Three extension skills (epi-implement, founder-implement, deck-implement) lack the "MUST NOT (Postflight Boundary)" section entirely.
- Five extension skills (lean, nvim, nix, web, python, typst, latex, z3) have postflight boundary sections but lack the specific "proceed immediately" language and PROHIBITION block.
- `implement.md` (GATE OUT) could add a defensive check noting that if the skill return metadata indicates the skill (not the agent) performed source operations, the result is suspect.

## Context & Scope

When a subagent returns with `status: "partial"` or `status: "failed"`, the lead skill should proceed immediately to postflight operations: read metadata, update state, link artifacts, commit, cleanup. The observed violation pattern is that the lead agent instead "picks up where the subagent left off" -- reading source files, running builds, analyzing patterns, and attempting to complete the work itself. This violates the delegation model and produces untracked, unvalidated changes.

Task 430 fixed the pre-delegation boundary (lead reading codebase before spawning agent). This task fixes the post-delegation boundary -- the mirror problem. The fix involves adding explicit PROHIBITION blocks with the specific takeover violation pattern to all implementation skills.

## Findings

### Finding 1: skill-implementer/SKILL.md -- Postflight Boundary Is One-Line

**Location**: Line 453 (end of file)

The current postflight boundary is a single compressed sentence:

```
After the agent returns, this skill is LIMITED TO: reading metadata, updating state.json/TODO.md,
linking artifacts, git commit, cleanup. No source edits, builds, MCP tools, or analysis.
```

This is buried at the end of the file and lacks the structured "MUST NOT" list format used by the pre-delegation boundary (lines 436-449) and by other skills. It does not name the specific violation pattern (lead continuing subagent work) and does not include the **PROHIBITION** keyword that `implement.md` uses for its anti-bypass constraint.

**Required change**: Replace the one-line postflight boundary with a full "MUST NOT (Postflight Boundary)" section matching the format of the pre-delegation boundary above it. Add an explicit **PROHIBITION** block naming the specific violation.

### Finding 2: skill-team-implement/SKILL.md -- Missing PROHIBITION Block

**Location**: Lines 648-666 (MUST NOT (Postflight Boundary))

The section has the correct structure (numbered list of prohibitions) but:
1. Does not include a **PROHIBITION** block with the specific takeover pattern
2. Does not state "proceed immediately to postflight"
3. Does not mention the partial/failed status handling requirement

**Required change**: Add a PROHIBITION block before the numbered list, stating: after any Agent/Task tool returns (regardless of status), the lead MUST proceed immediately to postflight. No source reading, no builds, no "let me tackle the problem myself."

### Finding 3: general-implementation-agent.md -- No "Partial Is Acceptable" Guidance

**Location**: Lines 219-244 (Error Handling and Critical Requirements)

The agent's error handling mentions returning `partial` status (line 223-224), but the "Critical Requirements" section focuses on what the agent MUST DO and MUST NOT DO without explicitly stating that partial results are the correct response when work cannot be completed. The agent should be encouraged to write metadata with `status: "partial"` and return rather than attempting to force completion.

**Required change**: Add to the Critical Requirements MUST DO list: "Return `status: partial` with `partial_progress` when work cannot be completed within timeout or after errors -- partial results are preferred over forced/incomplete completion."

### Finding 4: Extension Skills -- Three Missing Postflight Boundary Sections

**Affected files** (no "MUST NOT (Postflight Boundary)" section):
1. `.claude/extensions/epidemiology/skills/skill-epi-implement/SKILL.md`
2. `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md`
3. `.claude/extensions/founder/skills/skill-deck-implement/SKILL.md`

These skills have `## Postflight (ALWAYS EXECUTE)` sections but lack the explicit prohibition block.

**Required change**: Add "MUST NOT (Postflight Boundary)" section with PROHIBITION block to each.

### Finding 5: Extension Skills -- Eight With Postflight Boundary But Missing PROHIBITION

**Affected files** (have postflight boundary but missing PROHIBITION block):
1. `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` (lines 260-278)
2. `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` (lines 331-349)
3. `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` (lines 378-396)
4. `.claude/extensions/web/skills/skill-web-implementation/SKILL.md` (lines 378-396)
5. `.claude/extensions/python/skills/skill-python-implementation/SKILL.md` (lines 60-78)
6. `.claude/extensions/typst/skills/skill-typst-implementation/SKILL.md` (lines 71-89)
7. `.claude/extensions/latex/skills/skill-latex-implementation/SKILL.md` (lines 71-89)
8. `.claude/extensions/z3/skills/skill-z3-implementation/SKILL.md` (lines 60-78)

These all have the "MUST NOT" list but not the specific "proceed immediately" PROHIBITION block or the takeover-specific language.

**Required change**: Add PROHIBITION block to each, following the same pattern.

### Finding 6: implement.md (GATE OUT) -- No Post-Delegation Detection

**Location**: Lines 423-506 (CHECKPOINT 2: GATE OUT)

The GATE OUT validates artifacts, status, completion summary, and plan file status -- but does not detect whether the skill itself (rather than the subagent) performed source-file operations. While this would require tool-call introspection that may not be available, a note could document the desired check for future implementation.

**Required change**: Add a comment/note in GATE OUT about the desired future validation: "If the skill return indicates source-file reads or builds were performed by the skill (not the agent), log a warning about potential postflight boundary violation."

### Finding 7: postflight-tool-restrictions.md -- Standard Needs PROHIBITION Template

**Location**: Lines 156-179 (MUST NOT Section Template)

The existing template shows the numbered MUST NOT list but does not include a PROHIBITION block template. Since all skills should use the same PROHIBITION format, the template should be updated.

**Required change**: Add PROHIBITION block to the template in postflight-tool-restrictions.md.

## Decisions

1. **PROHIBITION block format**: Reuse the format from `implement.md` (lines 35-39) -- bold `**PROHIBITION**:` keyword followed by specific violation description, `**Why**:` explanation, and `**Required**:` correct behavior.
2. **Specific language**: "After any Task/Agent tool returns -- whether with status implemented, partial, or failed -- the lead skill MUST proceed immediately to postflight (Stage 6). The lead MUST NOT read source files, grep/glob the codebase, run build/test commands, use MCP tools, edit source files, or attempt to continue/complete the subagent's work."
3. **Partial encouragement in agent**: Add explicit encouragement that returning partial is preferred over forced completion.
4. **GATE OUT detection**: Document as a future enhancement (comment only), not implement it now.

## Recommendations

1. **[P0] Add PROHIBITION block to skill-implementer/SKILL.md** -- Replace one-line postflight boundary with full structured section including PROHIBITION block
2. **[P0] Add PROHIBITION block to skill-team-implement/SKILL.md** -- Add before existing numbered list
3. **[P0] Update general-implementation-agent.md** -- Add "partial is acceptable" to Critical Requirements
4. **[P1] Add MUST NOT section to 3 extension skills missing it** -- epi-implement, founder-implement, deck-implement
5. **[P1] Add PROHIBITION block to 8 extension skills** -- lean, nvim, nix, web, python, typst, latex, z3
6. **[P2] Update postflight-tool-restrictions.md template** -- Add PROHIBITION block to the MUST NOT Section Template
7. **[P2] Add GATE OUT note to implement.md** -- Document desired future detection

## Risks & Mitigations

- **Risk**: Adding more text to already-long SKILL.md files could reduce readability
  - **Mitigation**: PROHIBITION block is short (4-5 lines) and uses distinctive bold formatting for high salience
- **Risk**: Extension skills may diverge in PROHIBITION language over time
  - **Mitigation**: The template in postflight-tool-restrictions.md provides a canonical reference

## Appendix

### Current Postflight Boundary Coverage Matrix

| Skill | Has MUST NOT | Has PROHIBITION | Has "proceed immediately" |
|-------|-------------|-----------------|--------------------------|
| skill-implementer | One-line | No | No |
| skill-team-implement | Yes | No | No |
| lean-implementation | Yes | No | No |
| nvim-implementation | Yes | No | No |
| nix-implementation | Yes | No | No |
| web-implementation | Yes | No | No |
| python-implementation | Yes | No | No |
| typst-implementation | Yes | No | No |
| latex-implementation | Yes | No | No |
| z3-implementation | Yes | No | No |
| epi-implement | No | No | No |
| founder-implement | No | No | No |
| deck-implement | No | No | No |

### PROHIBITION Block Template (Proposed)

```markdown
**PROHIBITION**: After any Task/Agent tool returns -- whether with status implemented, partial,
or failed -- the lead skill MUST proceed immediately to postflight (Stage 6). The lead MUST NOT
read source files, grep/glob the codebase, run build/test commands, use MCP tools, edit source
files, or attempt to continue/complete the subagent's work. If the subagent returned partial
results, the lead reports partial status. The user re-runs /implement to resume.

**Why**: The lead agent taking over after delegation produces untracked, unvalidated changes that
bypass format enforcement, phase checkpointing, and the commit protocol. Partial status with
proper metadata is always preferable to ad-hoc continuation by the lead.

**Required**: Proceed directly to Stage 6 (read metadata file) after any subagent return.
```
