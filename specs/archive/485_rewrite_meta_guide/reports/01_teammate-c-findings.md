# Teammate C Findings: Task 485 - Rewrite meta-guide.md (Critic Angle)

**Date**: 2026-04-19
**Teammate**: C (Critic)
**Focus**: Gaps, shortcomings, blind spots, and rewrite risks

---

## Key Findings

### Finding 1: The meta-guide is actively harmful, not merely outdated

The current `meta-guide.md` is not just stale -- it is **loaded for every invocation of meta-builder-agent** and contains directly contradictory information. When the agent receives its context, it sees:

- A phantom 5-phase, 12-question interview (the guide) alongside a real 7-stage workflow (the agent's own implementation)
- An `.opencode/agent/subagents/` directory structure that does not exist in this repository (line 28-47 of meta-guide.md)
- A reference to `.claude/context/standards/commands.md` which does not exist (checked: the directory has `documentation-standards.md`, `interactive-selection.md`, etc. -- no `commands.md`)
- Marketing claims like "+20% routing accuracy" and "Stanford and Anthropic patterns" that bear no relationship to any documented implementation

The context index confirms this file loads for: `agents: ["meta-builder-agent"]`, `commands: ["/meta"]`, `task_types: ["meta"]`. Worse, the CLAUDE.md Core Context Imports section (line 300) lists it as always-available: `@.claude/context/meta/meta-guide.md` -- meaning every agent in the system gets this polluting context.

### Finding 2: meta-builder-agent has a split-brain return protocol

The agent header (line 15) says:
> "IMPORTANT: This agent writes metadata to a file instead of returning JSON to the console."

But Stage 5 of the same agent (line 1257) says:
> "Return ONLY valid JSON matching this schema:"

...and then provides three JSON response schemas for console output.

This is not a documentation inconsistency -- it's a **runtime behavioral ambiguity**. The agent cannot follow both instructions. Task 486's team research confirmed this is the only agent still using v1 console JSON return; all other agents write `.return-meta.json`. The agent header was clearly updated to claim v2 compliance without the body being migrated.

The implications for skill-meta are significant: skill-meta's Section 4 says "Validate return matches `return-metadata-file.md` schema" and tries to read the return. But if the agent returns console JSON (v1), there is no metadata file to read. The postflight then fails silently or reads nothing.

### Finding 3: skill-meta has a phantom postflight with no mechanism

skill-meta claims (line 12-13): "This skill implements the skill-internal postflight pattern... handles all postflight operations (git commit if tasks were created)." But:

1. The skill contains **no postflight marker creation** (`specs/{NNN}_{SLUG}/.postflight-pending`). The postflight-control.md pattern requires creating this marker before the Task tool invocation so the SubagentStop hook blocks premature termination.

2. The skill's "postflight" section merely says "Git commit (if tasks were created)" with no executable steps. Compare with skill-researcher, which has a fully implemented Stage 10+ with explicit bash scripts, `update-task-status.sh` calls, jq artifact linking, and marker cleanup.

3. Because there is **no task number** for /meta operations (meta creates tasks, doesn't operate on existing ones), the standard postflight scripts (`update-task-status.sh`, artifact linking) don't apply. This is a legitimate architectural difference, but it means the phrase "skill-internal postflight pattern" is technically wrong -- meta has a different, simpler model.

4. The git commit is actually performed by **meta-builder-agent Stage 6** (line 1355-1356), not by skill-meta. The skill claims to do it but doesn't implement it. The agent does it instead. This is architecturally inverted from the standard pattern.

### Finding 4: DetectDomainType is vestigial and untested after latex removal

Stage 2.5 `DetectDomainType` in meta-builder-agent classifies task types based on keywords. Task 486 confirmed the `latex` branch was still hardcoded (and that task's research has completed; check 486's summary for whether it was actually removed). Even after removal, the function is peculiar: it only distinguishes "meta" vs "general" based on keywords like "command", "skill", "agent", ".claude/". But:

- Every task created via `/meta` is about the `.claude/` system by definition (that's what /meta does)
- The keyword-based routing adds complexity without clear benefit -- why would a user typing `/meta` get a `general` task type?
- The real routing question is: what task_type should tasks created by /meta have? The answer should almost always be "meta". The DetectDomainType function solving an edge case that rarely matters.

### Finding 5: The 3-mode system description is scattered across too many files

The 3 modes (interactive, prompt, analyze) are described in:
- `commands/meta.md` (user-facing)
- `skills/skill-meta/SKILL.md` (mode detection)
- `agents/meta-builder-agent.md` (execution)
- `context/meta/meta-guide.md` (context, but with WRONG 5-phase description)

Each has slightly different emphasis and terminology. The guide should be the single authoritative prose explanation, but it documents a completely different system (5 phases, 12 questions, `.opencode` paths). The agent's own documentation (the agent file) is more accurate than the "guide."

### Finding 6: The commit format is undocumented in skill-git-workflow

The meta-builder-agent uses commit format `meta: create {N} tasks for {domain}` (line 1356). This format does NOT appear in `skill-git-workflow/SKILL.md`'s commit format table, which documents only `task {N}: {action}` and `todo:`, `errors:`, `review:`, `sync:` prefixes. The meta commit format is an unofficial addition that bypasses the git workflow skill entirely.

---

## System Shortcomings (What's Actually Broken)

### Shortcoming A: v1 return protocol mismatch

**Severity**: High
**Impact**: Postflight validation in skill-meta reads from a `.return-meta.json` file that the agent never writes. Instead, the agent returns console JSON which skill-meta has no code to parse. Whether git commits actually happen depends entirely on whether the agent happens to execute the commit during its Stage 6 before returning -- which appears to be the only mechanism that works, making the skill-meta "postflight" fiction.

**Evidence**: Both the agent body (Stage 5: "Return ONLY valid JSON") and the task 486 team research synthesis confirm v1 protocol. The agent IMPORTANT notice at the top contradicts its own body.

### Shortcoming B: meta-guide.md loaded as "always-available" context

**Severity**: High
**Impact**: CLAUDE.md line 300 lists `@.claude/context/meta/meta-guide.md` as a core context import. This means 462 lines of phantom system documentation pollutes the context for EVERY agent that inherits CLAUDE.md. This includes non-meta agents like planner-agent and general-implementation-agent when they're invoked in the nvim project context.

**Evidence**: The CLAUDE.md Core Context Imports section; the meta-guide's content (`.opencode/` paths, 5-phase interview, "+20% accuracy" marketing claims).

### Shortcoming C: Missing `commands.md` reference

**Severity**: Medium
**Impact**: meta-guide.md line 9 states: "All generated commands must follow `.claude/context/standards/commands.md`". This file does not exist. The standards directory contains: `analysis-framework.md`, `ci-workflow.md`, `code-patterns.md`, `documentation-standards.md`, `error-handling.md`, `git-integration.md`, `git-safety.md`, `interactive-selection.md`, `postflight-tool-restrictions.md`, `status-markers.md`, `task-management.md`, `testing.md`, `xml-structure.md`. No `commands.md`.

### Shortcoming D: skill-meta has no postflight stage implementation

**Severity**: Medium
**Impact**: The skill declares "skill-internal postflight" but has none of the standard machinery: no marker creation, no `update-task-status.sh` call, no artifact linking. Git commits happen inside the agent (if at all). The skill's Section 4-5 are vestigial validation steps that have nothing to validate (no metadata file written by the agent).

### Shortcoming E: Interview stage count inconsistency

**Severity**: Low
**Impact**: The guide describes a 5-phase interview (Phase 1-5, 12 questions). The actual agent implements a 7-stage interview (Stages 0-7: DetectExistingSystem, InitiateInterview, GatherDomainInfo, IdentifyUseCases, AssessComplexity, ReviewAndConfirm, CreateTasks, DeliverSummary). The command file accurately describes 7 stages. The meta-guide is simply wrong.

---

## Rewrite Risks (What Could Go Wrong)

### Risk 1: Documenting aspirational v2 protocol as implemented

The task 485 description says to document "the actual /meta workflow." But the agent IMPORTANT notice (line 15) already claims v2 file-based return. If the rewrite accepts this claim at face value and documents v2 protocol as current reality, it will be wrong -- the agent body still says "Return ONLY valid JSON."

**Recommendation**: The rewrite should document what the system ACTUALLY does (agent returns console JSON, git commit happens inside agent, skill-meta postflight is minimal), NOT what it was aspirationally designed to do. The v1-to-v2 migration is a separate task.

### Risk 2: Scope creep into system redesign

The task description says "rewrite to document the actual /meta workflow." This is clearly a documentation task. But given how many real problems exist (v1 return protocol, missing postflight), there will be pressure to "fix" things in the documentation that are actually broken in the implementation. The guide should document what IS, with a clear note about known gaps, not redesign the system.

**Recommendation**: Include a "Known Limitations" section in the rewritten guide that lists the v1 protocol issue and the minimal postflight -- without pretending they are solved.

### Risk 3: The 7-stage workflow description may contain pseudocode artifacts

The meta-builder-agent's 7-stage workflow is documented in detail but contains large Python-style pseudocode blocks (Kahn's algorithm, graph generation functions). These are aspirational implementation guides for the LLM, not verified runtime behavior. If the rewrite reproduces these as "the actual flow," it may document behavior that the LLM doesn't actually follow consistently.

**Recommendation**: The guide should describe the workflow at a conceptual level (what each stage does, what questions are asked) without reproducing the pseudocode. That belongs in the agent file, not the user-facing guide.

### Risk 4: Failing to update CLAUDE.md's always-available import

If meta-guide.md is rewritten but remains listed in CLAUDE.md as a core always-available import, a well-written guide will still waste 462 lines of context for every agent. The rewrite should be accompanied by an index.json/CLAUDE.md cleanup to make the guide load only for meta tasks and meta-builder-agent (as index.json already specifies, but CLAUDE.md overrides this).

**Recommendation**: Flag this as an essential companion change. The guide should NOT be in CLAUDE.md's "Core context (always available)" list. It belongs only in index.json's conditional loading (which already has the right conditions).

### Risk 5: The updated guide will immediately be wrong again

Both the guide and agent are in extension source copies (`extensions/core/`) AND deployed copies. If the rewrite only updates the deployed copy (`.claude/context/meta/meta-guide.md`), the extension source (`extensions/core/context/meta/meta-guide.md`) will diverge and overwrite on next sync. Task 485's description mentions updating both copies, which is correct.

---

## Questions That Need Answers

1. **Has task 486 been implemented?** If yes, `latex` has been removed from DetectDomainType and `subagent-return.md` references are fixed. The rewrite should not re-document the pre-486 state for these items. Check the 486 summary for what actually changed.

2. **What does the user actually experience when running `/meta` today?** The theoretical protocol mismatch (v1 vs v2) may be masked in practice because: (a) git commits happen inside the agent, (b) skill-meta's "postflight" steps silently succeed or fail without user-visible effects. Has anyone noticed the postflight failing?

3. **Should meta-guide.md be a user-facing guide or an agent context file?** It's currently being used as both (loaded for meta-builder-agent AND listed as always-available in CLAUDE.md). These have different writing styles and appropriate content. The index.json correctly scopes it to meta contexts; CLAUDE.md incorrectly universalizes it.

4. **Is the `--analyze` mode actually implemented and working?** The skill routes to it but there are no meta task outputs in specs/ showing it was used. It's the least-tested mode.

5. **What is the right behavior when `/meta` is called with no existing specs/ structure?** The agent does DetectExistingSystem first, but does it handle the case where `specs/state.json` doesn't exist gracefully?

---

## Confidence Level

| Area | Confidence | Basis |
|------|------------|-------|
| meta-guide.md is phantom/wrong | Very High | Direct file inspection; task 485 description confirms |
| v1 return protocol mismatch | High | Agent Stage 5 text is unambiguous; task 486 team research confirms |
| meta-guide in CLAUDE.md always-available | Very High | CLAUDE.md line 300 is explicit |
| skill-meta postflight is non-functional | High | No marker creation, no executable steps; git commit is in agent Stage 6 |
| `commands.md` reference broken | Very High | Checked standards/ directory; file absent |
| DetectDomainType is vestigial | Medium | Logical analysis; no runtime evidence |
| `context: fork` runtime behavior | Low | Neither confirmed nor denied by codebase |

**Overall confidence**: High that the system has significant implementation-documentation drift. The rewrite must be grounded in direct file inspection of what the system ACTUALLY does, not in what the guide or agent headers claim.

---

## Appendix: Evidence Links

- `/home/benjamin/.config/nvim/.claude/context/meta/meta-guide.md` - Phantom guide (458 lines of wrong info)
- `/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md` - Split-brain: header says v2, body says v1
- `/home/benjamin/.config/nvim/.claude/skills/skill-meta/SKILL.md` - Claims postflight but has no mechanism
- `/home/benjamin/.config/nvim/.claude/CLAUDE.md` line 300 - Meta-guide in always-available core context
- `/home/benjamin/.config/nvim/specs/486_align_skill_meta_frontmatter/reports/01_team-research.md` - Prior team research confirming v1 protocol and other issues
- `/home/benjamin/.config/nvim/.claude/context/index.json` - Correct conditional loading (meta-builder-agent only)
