# Implementation Plan: Task #425

- **Task**: 425 - create_skill_slide_critic
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: slide-critic-agent (already created)
- **Research Inputs**: specs/425_create_skill_slide_critic/reports/01_skill-slide-critic-research.md
- **Artifacts**: plans/01_skill-slide-critic-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create skill-slide-critic as a standalone SKILL.md in the present extension that implements an interactive critique feedback loop. The skill delegates to slide-critic-agent for initial material review, parses the structured critique report to extract findings, presents issues to the user via AskUserQuestion grouped by severity/category, collects accept/reject/modify decisions, loops until all issues are addressed, and produces a final filtered critique report consumable by `/plan`.

### Research Integration

Key findings from the research report:
- skill-slides provides the canonical skill-internal postflight pattern (11 stages) with `.postflight-pending` marker files
- skill-slide-planning provides the interactive AskUserQuestion loop pattern with consolidated questions to minimize round-trips
- The slide-critic-agent produces structured per-slide findings with severity tags `[Critical]`, `[Major]`, `[Minor]` and tiered recommendations (Must Fix, Should Fix, Nice to Fix)
- The skill should be standalone (not a new workflow_type in skill-slides) due to its fundamentally different interactive execution pattern
- Response parsing grammar: `{N}: A` (accept), `{N}: R` (reject), `{N}: M {text}` (modify), plus shortcuts like "accept all", "done"

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this plan.

## Goals & Non-Goals

**Goals**:
- Create a complete SKILL.md with proper frontmatter, delegation, interactive loop, and postflight
- Follow established skill patterns (skill-slides for postflight, skill-slide-planning for AskUserQuestion)
- Produce a final filtered critique report that records user decisions alongside original findings
- Support bulk actions and shortcuts to avoid tedious per-issue interaction

**Non-Goals**:
- Modifying the slide-critic-agent (it already produces the needed structured output)
- Updating the present extension manifest (separate task)
- Adding routing to the orchestrator or command infrastructure
- Implementing re-run/resume on partially addressed critique sessions

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| SKILL.md becomes too long and complex | M | M | Keep each stage concise; reference patterns by path rather than inlining |
| Critique report parsing regex is fragile | H | L | Use well-defined patterns matching agent output; include fallback to raw section display |
| AskUserQuestion interaction flow unclear to users | M | M | Include clear instructions and examples in the question text |
| Postflight pattern diverges from skill-slides | M | L | Follow skill-slides stages 6-10 exactly |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Create SKILL.md with Frontmatter and Stages 1-5 (Delegation) [COMPLETED]

**Goal**: Establish the skill file with frontmatter, input validation, preflight, postflight marker, delegation context preparation, and Task tool invocation of slide-critic-agent.

**Tasks**:
- [ ] Create directory `.claude/extensions/present/skills/skill-slide-critic/`
- [ ] Write SKILL.md frontmatter (name, description, allowed-tools including Task and AskUserQuestion, context: fork, agent: slide-critic-agent)
- [ ] Write skill header and context references section (referencing return-metadata-file.md, postflight-control.md, file-metadata-exchange.md, jq-escaping-workarounds.md)
- [ ] Write trigger conditions section
- [ ] Write input parameters section (task_number required; session_id required; focus_categories, audience_context, materials_to_review optional)
- [ ] Write Stage 1: Input Validation (task lookup, task_type validation for present:slides, extract fields)
- [ ] Write Stage 2: Preflight Status Update (set status=researching, marker=[RESEARCHING], create postflight marker `.postflight-pending`)
- [ ] Write Stage 3: Prepare Delegation Context JSON (session_id, delegation_path, task_context, workflow_type=slides_critique, forcing_data with talk_type/materials/focus/audience, metadata_file_path)
- [ ] Write Stage 4: Invoke Subagent via Task tool (with routing note: always slide-critic-agent)
- [ ] Write Stage 4b: Self-Execution Fallback (write .return-meta.json if Task tool not used)

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/skills/skill-slide-critic/SKILL.md` - Create new file with stages 1-5

**Verification**:
- SKILL.md exists with valid frontmatter
- Stages 1-5 follow skill-slides pattern structure
- Delegation context JSON matches slide-critic-agent input contract

---

### Phase 2: Add Stages 5-8 (Report Parsing, Interactive Loop, Filtered Report) [COMPLETED]

**Goal**: Add the core interactive critique loop -- parse agent output, present to user, collect decisions, generate filtered report.

**Tasks**:
- [ ] Write Stage 5: Parse Critique Report -- extract findings from markdown report using regex patterns for `- [{severity}] {category}: {finding}` and slide header `### Slide N` structure; build numbered issue list with fields: id, slide, severity, category, description, suggestion
- [ ] Write Stage 6: Interactive Critique Loop -- present all findings grouped by severity tier (Must Fix / Should Fix / Nice to Fix) in a single consolidated AskUserQuestion; include clear instructions showing `{N}: A`, `{N}: R`, `{N}: M {text}` grammar and shortcuts ("accept all", "reject all minor", "done")
- [ ] Write Stage 6 response parsing logic -- parse user response line by line against the grammar; track decisions per issue (accepted, rejected, modified with user text); handle shortcuts as bulk operations
- [ ] Write Stage 6 loop continuation -- if unaddressed issues remain and user did not say "done", re-present only unaddressed issues; enforce max 3 iterations then auto-accept remaining
- [ ] Write Stage 7: Generate Filtered Critique Report -- write final report to `specs/{NNN}_{SLUG}/reports/{MM}_filtered-critique.md` with sections: Accepted Issues (grouped by tier with user modifications noted), Rejected Issues (for reference), User Notes; format consumable by `/plan`
- [ ] Write Stage 7 metadata update -- update .return-meta.json with final artifact path, findings_count (accepted/rejected/modified/total), and status

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/skills/skill-slide-critic/SKILL.md` - Append stages 5-8

**Verification**:
- Report parsing covers all three severity levels and general/per-slide sections
- AskUserQuestion format matches the research-recommended design
- Response grammar handles all documented patterns including shortcuts
- Filtered report structure matches research recommendation
- Loop has clear termination conditions (all addressed, "done", or max iterations)

---

### Phase 3: Add Postflight Stages and Error Handling [COMPLETED]

**Goal**: Complete the skill with postflight operations (status update, artifact linking, git commit, cleanup), error handling, and return format.

**Tasks**:
- [ ] Write Stage 8: Read Metadata File (postflight entry point, read .return-meta.json, extract status and artifact info)
- [ ] Write Stage 9: Update Task Status (map meta_status to final state.json status and TODO.md marker; researched on success, keep preflight on failure)
- [ ] Write Stage 10: Link Artifacts (add filtered critique report to state.json artifacts array; update TODO.md with artifact link using field_name=**Report**)
- [ ] Write Stage 11: Git Commit (`task {N}: complete slide critique` with session ID)
- [ ] Write Stage 12: Cleanup (remove .postflight-pending, .postflight-loop-guard, .return-meta.json)
- [ ] Write Stage 13: Return Brief Summary (3-6 bullet points covering findings count, user decisions, report path, status)
- [ ] Write Error Handling section (task not found, wrong task_type, metadata missing, no findings from agent, user abandons mid-loop, git failure)
- [ ] Write Return Format section noting brief text summary output

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/present/skills/skill-slide-critic/SKILL.md` - Append postflight and error handling sections

**Verification**:
- Postflight stages 8-12 mirror skill-slides stages 6-10 structure
- Error handling covers all identified risk scenarios
- Return format is brief text (not JSON)
- Complete SKILL.md has all stages numbered and documented

## Testing & Validation

- [ ] SKILL.md frontmatter has all required fields (name, description, allowed-tools, context, agent)
- [ ] All stages are numbered sequentially and have clear entry/exit conditions
- [ ] Delegation context JSON matches slide-critic-agent input contract from the agent definition
- [ ] AskUserQuestion response grammar is fully specified with examples
- [ ] Filtered report format is documented and consumable by /plan
- [ ] Postflight stages match skill-slides pattern (read meta, update status, link artifacts, git commit, cleanup)
- [ ] Error handling covers: task not found, wrong type, empty findings, user abandonment, metadata missing

## Artifacts & Outputs

- `.claude/extensions/present/skills/skill-slide-critic/SKILL.md` - The complete skill definition file

## Rollback/Contingency

The skill is a single new file with no modifications to existing code. Rollback is simply deleting the `.claude/extensions/present/skills/skill-slide-critic/` directory. No existing functionality is affected.
