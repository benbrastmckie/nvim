# Research Report: Task #418

**Task**: 418 - Add postflight self-execution fallback to skill wrapper pattern
**Started**: 2026-04-13T00:00:00Z
**Completed**: 2026-04-13T00:30:00Z
**Effort**: ~2 hours implementation
**Dependencies**: None
**Sources/Inputs**:
- Codebase: skill-implementer/SKILL.md, skill-researcher/SKILL.md, skill-planner/SKILL.md
- Codebase: postflight-control.md, return-metadata-file.md, thin-wrapper-skill.md
- Codebase: subagent-postflight.sh hook script
- Codebase: postflight-tool-restrictions.md standard
- Codebase: 43 extension SKILL.md files (pattern verification)
**Artifacts**:
- specs/418_add_postflight_fallback_to_skill_wrapper/reports/01_postflight-fallback.md
**Standards**: report-format.md, artifact-management.md, tasks.md

## Executive Summary

- The three core skills (skill-researcher, skill-planner, skill-implementer) and all extension skills share a common thin-wrapper pattern where Stage 5 delegates to a subagent via the Task tool, and Stages 6-10 (postflight) execute after the subagent returns.
- The fundamental vulnerability is structural: Stages 6-10 are written as sequential prose after Stage 5, but nothing in the skill document enforces that the Task tool must actually be invoked. If the skill executor performs work inline (reading files, writing artifacts, updating metadata) without spawning a subagent, Stages 6-10 are simply never reached because there is no subagent return event.
- The SubagentStop hook (`.claude/hooks/subagent-postflight.sh`) only fires when a subagent session stops -- it has no mechanism to detect that work was done inline without a subagent.
- The recommended fix is **Approach A (unconditional postflight)**: restructure skills so postflight is a mandatory final section that always executes, checking the metadata file regardless of how it was created.
- This affects all 3 core skills and approximately 20+ extension skills that follow the thin-wrapper pattern.

## Context & Scope

### Problem Statement

The skill wrapper pattern assumes a strict execution flow:

```
Stage 1-4: Preflight (validate, update status, create marker, prepare context)
Stage 5:   Invoke subagent via Task tool  <-- ASSUMPTION: always happens
Stage 6:   Read .return-meta.json         <-- NEVER REACHED if no subagent
Stage 7:   Update task status
Stage 8:   Link artifacts
Stage 9:   Git commit
Stage 10:  Cleanup
```

When Claude executes a skill, it reads the SKILL.md as instructions. If the model decides to do the work inline rather than spawning a subagent (which happens occasionally with simpler tasks), Stages 6-10 never execute because:

1. No subagent was spawned, so there is no "subagent return" event.
2. The skill's instructions for Stages 6-10 are written as "after subagent returns, do X" -- they are conditional on the subagent having been invoked.
3. The SubagentStop hook only triggers on subagent session stop events.

### Scope of Impact

Files affected by this pattern:
- `.claude/skills/skill-researcher/SKILL.md` (Stages 6-10)
- `.claude/skills/skill-planner/SKILL.md` (Stages 6-11)
- `.claude/skills/skill-implementer/SKILL.md` (Stages 6-11)
- ~20 extension skills in `.claude/extensions/*/skills/` following the same pattern
- `.claude/context/patterns/thin-wrapper-skill.md` (pattern documentation)
- `.claude/context/patterns/postflight-control.md` (architecture description)

### Consequences of Postflight Skip

When postflight is skipped, the following state corruption occurs:

1. **Status stuck at in-progress**: state.json shows "researching"/"planning"/"implementing" permanently
2. **TODO.md desync**: Status marker stays at `[RESEARCHING]`/`[PLANNING]`/`[IMPLEMENTING]`
3. **Artifacts not linked**: state.json `artifacts` array never updated
4. **No git commit**: Changes remain uncommitted
5. **Marker file orphaned**: `.postflight-pending` file left behind, causing future SubagentStop hook interference
6. **Metadata file orphaned**: `.return-meta.json` left behind

## Findings

### Finding 1: All Three Core Skills Have Identical Vulnerability

Each core skill has the same structural gap. The critical transition is between Stage 5 (invoke subagent) and Stage 6 (read metadata). The SKILL.md files use language like:

- skill-researcher Stage 6: "After subagent returns, read the metadata file"
- skill-planner Stage 6: "After subagent returns, read the metadata file"
- skill-implementer Stage 6: "After subagent returns, read the metadata file"

This conditional phrasing makes postflight contingent on subagent invocation.

### Finding 2: The SubagentStop Hook Cannot Detect Inline Execution

The hook at `.claude/hooks/subagent-postflight.sh` only fires on `SubagentStop` events. Its entire purpose is to block premature stop when a subagent returns so that postflight can run. If no subagent is ever spawned, the hook never fires, and there is nothing to block the skill from simply finishing without postflight.

### Finding 3: The Postflight Marker Creates a Partial Safety Net (But Insufficient)

The `.postflight-pending` marker file is created at Stage 3 (before subagent invocation). If the skill does work inline and then the session stops, the orphaned marker would cause the SubagentStop hook to block the next subagent stop in any future session. This is a side effect, not a safety mechanism -- it does not cause postflight to run for the current operation.

### Finding 4: Extension Skills All Follow the Same Pattern

Checked `skill-neovim-research`, `skill-lean-research`, and several others. All extension wrapper skills use the identical thin-wrapper pattern with the same Stage 5 -> Stage 6 assumption. The fix must propagate to all of them.

### Finding 5: Stage 5a in skill-implementer Only Validates Return Format

skill-implementer has a Stage 5a "Validate Subagent Return Format" that checks if the return is JSON. This only runs after the subagent returns -- it does not detect whether a subagent was spawned at all.

### Finding 6: The Thin-Wrapper-Skill Pattern Doc Confirms the Assumption

`thin-wrapper-skill.md` section 3 explicitly says: "CRITICAL: Use the Task tool to spawn the subagent." and "DO NOT use Skill({agent-name}) - this will FAIL." However, there is no mechanism to enforce this -- it is instructional only.

## Approach Evaluation

### Approach A: Unconditional Postflight (RECOMMENDED)

**Concept**: Restructure the skill so that Stages 6-10 always execute as a final block, regardless of how the work was done. The skill checks whether `.return-meta.json` exists and processes it, whether it was written by a subagent or by the skill executor itself.

**Implementation**:
1. Add a "Postflight Gate" section after Stage 5 that is framed unconditionally: "Regardless of how the work was performed, execute the following postflight steps."
2. Ensure Stage 6 (read metadata) gracefully handles the case where the metadata file was written by the skill executor inline.
3. Add a check: "If you performed the work in Stages 1-5 without using the Task tool, you MUST still write a .return-meta.json file before proceeding to Stage 6."

**Complexity**: Low-medium. Requires editing 3 core SKILL.md files and the thin-wrapper-skill.md pattern doc. Extension skills should be batch-updated.

**Robustness**: High. Even if the model ignores the "use Task tool" instruction, postflight still runs because it is not framed as conditional on subagent return.

**SubagentStop hook impact**: Minimal. The hook still works for the subagent case. For the inline case, the postflight marker is cleaned up during Stage 10 regardless.

**Postflight-control pattern impact**: Compatible. The marker file still serves its purpose for the subagent path. For the inline path, the marker is created at Stage 3 and cleaned up at Stage 10 as normal.

**Key changes needed**:
- Add Stage 5b: "Self-execution fallback" -- if you did the work inline, write .return-meta.json now
- Reframe Stages 6-10 header from "After subagent returns" to "Postflight (always execute)"
- Add bold warning at Stage 5 reinforcing that Task tool is required
- Update thin-wrapper-skill.md to document the fallback

### Approach B: Inline Detection (Stage 5a)

**Concept**: Add a detection mechanism after Stage 5 that checks whether the Task tool was actually invoked. If not, explicitly trigger postflight.

**Implementation**:
1. After Stage 5, add Stage 5a: "Check if Task tool was used. If not, write .return-meta.json with appropriate status and fall through to postflight."
2. The detection relies on the skill executor being aware of whether it used the Task tool -- which is inherently self-referential and unreliable.

**Complexity**: Medium. The detection logic is subtle and depends on model self-awareness.

**Robustness**: Low-medium. The model that did inline work might also skip the detection check, since both are instructional. There is no programmatic way to check "did I use the Task tool?" from within a SKILL.md.

**SubagentStop hook impact**: None.

**Postflight-control impact**: None.

**Weakness**: If the model is willing to skip "use Task tool", it may equally skip "check if you used Task tool." The detection is not enforceable.

### Approach C: Enforcement (Prevent Inline Execution)

**Concept**: Make it structurally impossible for the skill to do work inline. Restrict the skill's allowed tools to only `Task`, so it cannot read/write files directly.

**Implementation**:
1. Change `allowed-tools: Task, Bash, Edit, Read, Write` to `allowed-tools: Task` in skill frontmatter.
2. Move all postflight operations (jq, git commit, cleanup) into a separate postflight skill or script that runs after the Task tool returns.

**Complexity**: High. Postflight operations currently use Bash (jq, git), Read (metadata file), and Edit (TODO.md). These cannot be done with only the Task tool. A separate postflight mechanism would need to be created.

**Robustness**: High in theory -- if the skill literally cannot read/write files, it must delegate. But the postflight operations themselves need file access, creating a chicken-and-egg problem.

**SubagentStop hook impact**: Significant. Would need a new mechanism to invoke postflight operations.

**Postflight-control impact**: Would require architectural redesign.

**Weakness**: The `allowed-tools` field currently needs `Bash, Edit, Read, Write` for postflight operations. Removing them breaks postflight. A two-phase skill (delegate-only phase + postflight-only phase) would require a new skill execution model that does not currently exist.

## Decisions

1. **Approach A is the recommended fix**. It is the simplest, most robust, and most compatible with the existing architecture.
2. **Approach B is rejected** because detection of inline execution is fundamentally unreliable in an instruction-following model.
3. **Approach C is rejected** because it requires architectural changes disproportionate to the problem and creates a new chicken-and-egg issue with postflight tool access.

## Recommendations

### Priority 1: Restructure Core Skills (Approach A)

For each of the 3 core skills:

1. **Add Stage 5b (Self-Execution Fallback)**: After Stage 5, add:
   ```markdown
   ### Stage 5b: Self-Execution Fallback

   **CRITICAL**: If you performed the work above WITHOUT using the Task tool
   (i.e., you did not spawn a subagent), you MUST write a .return-meta.json
   file now with the appropriate status and artifacts before proceeding to
   Stage 6. The postflight stages below ALWAYS execute regardless of whether
   a subagent was used.
   ```

2. **Reframe Stages 6-10 header**: Change from "After subagent returns" phrasing to unconditional phrasing:
   ```markdown
   ## Postflight (ALWAYS EXECUTE)

   The following stages MUST execute after work is complete, whether the work
   was done by a subagent (Stage 5) or inline (Stage 5b).
   ```

3. **Strengthen Stage 5 language**: Add a boxed warning:
   ```markdown
   **MANDATORY**: You MUST use the Task tool here. Do NOT perform implementation
   work inline. If you find yourself reading source files, writing code, or
   creating artifacts at this stage, STOP and use the Task tool instead.
   ```

### Priority 2: Update Pattern Documentation

Update these files to reflect the fallback pattern:
- `.claude/context/patterns/thin-wrapper-skill.md` -- add fallback section
- `.claude/context/patterns/postflight-control.md` -- note that postflight runs unconditionally

### Priority 3: Batch Update Extension Skills

Apply the same Stage 5b / unconditional postflight restructuring to all ~20 extension wrapper skills. This can be done programmatically since they follow a consistent template.

### Priority 4: Consider Postflight Validation Hook (Future)

A PostToolUse hook on the Skill tool could check whether a `.return-meta.json` exists when a skill session ends. This would be a programmatic safety net independent of instruction following. This is out of scope for this task but worth noting for future work.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Model ignores Stage 5b and still skips postflight | Low | High | Unconditional framing of Stages 6-10 makes this less likely than current pattern |
| Batch extension update introduces inconsistencies | Medium | Medium | Use template-based find-and-replace; validate with grep |
| Added prose makes SKILL.md too long | Low | Low | Stage 5b is ~5 lines; header reframing is cosmetic |
| Self-written .return-meta.json has wrong schema | Medium | Medium | Stage 5b should reference return-metadata-file.md for schema |

## Appendix

### Files Examined

| File | Purpose | Lines |
|------|---------|-------|
| `.claude/skills/skill-implementer/SKILL.md` | Core implementation skill | 438 |
| `.claude/skills/skill-researcher/SKILL.md` | Core research skill | 397 |
| `.claude/skills/skill-planner/SKILL.md` | Core planning skill | 458 |
| `.claude/context/patterns/postflight-control.md` | Marker file protocol | 266 |
| `.claude/context/formats/return-metadata-file.md` | Metadata file schema | 503 |
| `.claude/context/patterns/thin-wrapper-skill.md` | Wrapper pattern reference | 185 |
| `.claude/hooks/subagent-postflight.sh` | SubagentStop hook | 109 |
| `.claude/context/standards/postflight-tool-restrictions.md` | Postflight boundary rules | 203 |
| `.claude/settings.json` | Hook configuration | ~140 |

### Extension Skills Verified

All follow the thin-wrapper pattern with identical Stage 5 -> Stage 6 vulnerability:
- nvim: skill-neovim-research, skill-neovim-implementation
- lean: skill-lean-research, skill-lean-implementation
- python: skill-python-research, skill-python-implementation
- latex: skill-latex-research, skill-latex-implementation
- typst: skill-typst-research, skill-typst-implementation
- web: skill-web-research, skill-web-implementation
- z3: skill-z3-research, skill-z3-implementation
- nix: skill-nix-research, skill-nix-implementation
- founder: skill-founder-implement, skill-founder-plan, skill-deck-research, skill-deck-plan, skill-deck-implement
- epidemiology: skill-epi-research, skill-epi-implement

### Search Queries Used

1. Glob for all SKILL.md files across core and extensions
2. Read of all 3 core skill SKILL.md files
3. Read of postflight-control.md, return-metadata-file.md, thin-wrapper-skill.md
4. Read of subagent-postflight.sh hook script
5. Read of postflight-tool-restrictions.md standard
6. Grep for SubagentStop in settings.json
7. Head of extension SKILL.md files to verify pattern consistency
