---
title: "Teammate B: Alternative Patterns and Best-Practice Comparison"
task: 392
artifact: 02
type: research-report
author: teammate-b
date: 2026-04-09
---

# Teammate B Research Findings
## Task 392: Refactor Present Extension Commands

---

## Key Findings

### 1. The Gold Standard Command Pattern: `/market` (founder extension)

The `/market` command is the best example of a mature extension command in this system. Its defining features:

**Pre-task forcing questions before task creation.** Before any task exists, the command asks 3-4 structured questions (mode selection, problem definition, target entity, geography). These answers are stored as `forcing_data` in state.json, so the research phase can use pre-gathered context without asking again.

**Clean input type detection.** Three input modes (description, task number, file path) are handled via clear pattern matching. Legacy `--quick` mode is preserved but clearly demoted. The logic is self-documenting.

**STOP after task creation.** New tasks stop at `[NOT STARTED]` after creation -- they do NOT auto-invoke research. This respects the user's workflow choice and avoids surprise token burns.

**Correct `task_type` field.** Each task created by `/market` sets `task_type: "market"` in state.json, giving downstream routing a precise discriminator beyond just the `language` field.

**The `/talk` command in the present extension already uses this forcing-questions pattern** -- it has Stage 0 pre-task questions (talk type, source materials, audience context). So the present extension is PARTIALLY aligned with the gold standard. The problem is inconsistency: only `/talk` does this; `/grant`, `/budget`, `/timeline`, and `/funds` do not have equivalents.

---

### 2. The Gold Standard Skill Pattern: `skill-researcher` / `skill-planner`

Core skills are textbook thin wrappers. Their defining structure:

1. **Input validation** (task lookup, status check)
2. **Preflight status update** via centralized `update-task-status.sh` script (atomic)
3. **Postflight marker file** (`.postflight-pending`) to prevent premature termination
4. **Artifact number calculation** from `next_artifact_number` in state.json
5. **Format injection** -- reads format spec files and injects them directly into the agent prompt
6. **Task tool invocation** (not Skill tool) to spawn subagent
7. **Metadata file parsing** from `.return-meta.json`
8. **Artifact validation** via `validate-artifact.sh --fix`
9. **Postflight status update** via same centralized script
10. **Artifact linking** in state.json with two-step jq (Issue #1132 avoidance)
11. **TODO.md linking** with count-aware format (inline -> multi-line expansion)
12. **Git commit**
13. **Cleanup** (marker + metadata files)
14. **Return brief text summary** (NOT JSON)

**The `skill-grant` already follows this pattern well.** Its Stages 1-11 are correct. The deviations from the gold standard that I observed are:

- `skill-grant` does **not** use `update-task-status.sh` for preflight/postflight -- it writes status changes inline with raw jq. This diverges from the centralized script pattern used by `skill-researcher` and `skill-planner`. This is a maintenance risk.
- `skill-grant` does **not** call `validate-artifact.sh` after the subagent returns (Stage 6a is absent). Core skills validate; grant skill does not.
- The skills for `skill-budget`, `skill-timeline`, `skill-funds`, and `skill-talk` would need to be verified, but from the manifest structure they appear to follow a similar pattern.

---

### 3. The `task_type` Routing Problem

**This is the central structural defect in the present extension.**

The manifest routing uses `language` as the discriminator:

```json
"routing": {
  "research": {
    "present": "skill-grant",
    "present:grant": "skill-grant",
    "present:budget": "skill-budget",
    "present:timeline": "skill-timeline",
    "present:funds": "skill-funds",
    "present:talk": "skill-talk"
  }
}
```

This is correct -- but the commands don't set `language` consistently to the compound form. `/talk` sets `language: "present"` and `task_type: "talk"`. The routing for `"present"` without a subtype goes to `skill-grant`, which means a talk task with just `language: "present"` would be misrouted if the user runs `/research N` instead of `/talk N`.

**The founder extension handles this correctly:** The `/market` command sets `language: "founder"` AND `task_type: "market"`. The routing uses `"founder:market"` as the compound key. But the commands also set the `task_type` field, which agents can read to determine behavior within the skill.

**Recommended pattern**: Present extension commands should set `language: "present:{subtype}"` (e.g., `"present:talk"`) on all created tasks, not just `"present"`. This makes routing deterministic. `/talk` currently sets `language: "present"` which is ambiguous.

---

### 4. Context Index Organization: `load_when` Patterns

The present extension's `index-entries.json` reveals a significant inconsistency:

**Grant-specific context** (17 entries) uses:
```json
"load_when": {
  "languages": ["grant"],
  "agents": ["grant-agent"],
  "commands": ["/grant"]
}
```

Note: `languages: ["grant"]` not `languages: ["present:grant"]` or `languages: ["present"]`. This means the context only loads when the task language is exactly `"grant"` -- but present extension tasks use `language: "present"` or `language: "present:grant"`. **These contexts may never load.**

**Non-grant context** (budget, timeline, funds, talk entries) uses:
```json
"load_when": {
  "languages": ["present"],
  "agents": ["budget-agent"],
  "commands": ["/budget"]
}
```

This is more correct but inconsistent with the grant entries.

**The gold standard pattern from core context files** uses multi-dimensional `load_when` arrays that match on any of several conditions. The present extension should standardize on `languages: ["present", "present:grant"]` (union of both forms) for grant entries, and similarly for each subtype.

---

### 5. Command Structure Comparison: Present vs. Founder

| Feature | `/market` (founder) | `/grant` (present) | `/talk` (present) |
|---------|--------------------|--------------------|-------------------|
| Pre-task forcing questions | Yes (4 questions) | No | Yes (3 questions) |
| Input type detection | 4 modes | 2 modes (description/task#) | 3 modes |
| `task_type` field set | Yes (`"market"`) | No | Yes (`"talk"`) |
| Language set to compound | No (`"founder"`) | No (`"grant"`) | No (`"present"`) |
| Legacy mode documented | Yes (`--quick`) | Yes (Legacy Mode section) | No |
| STOP after task creation | Yes | Yes | Yes |
| Post-creation guidance | Detailed next-steps | Detailed workflow | Recommended workflow |
| Model specified | Not set (uses default) | `claude-opus-4-5-20251101` | `claude-opus-4-5-20251101` |

**Observation**: Both the `/grant` command and `/market` command use `language` without compound form (they set `"grant"` and `"founder"` respectively). The compound form is only used in the routing table, not in the task metadata. This means the routing relies on the command's choice of skill rather than the language field. This is acceptable but it makes the language field less useful for downstream inspection.

---

### 6. Inconsistencies in Model Specification

Core commands (`/research`, `/plan`, `/implement`, `/task`) declare `model: opus` in frontmatter, instructing Claude Code to use the best model for orchestration.

Present extension commands declare `model: claude-opus-4-5-20251101` -- a specific, pinned version. This is outdated and may route to an older model. The current standard (as shown in the agent system CLAUDE.md) uses `model: opus` as a logical alias.

**Recommendation**: Change all present extension command frontmatter from `claude-opus-4-5-20251101` to `claude-opus-4-6` or simply `opus` to stay current.

---

### 7. What the Present Extension Does Well

Before listing gaps, it's important to note the strong points:

- `skill-grant` is the most mature extension skill in the system. It handles 6 workflow types, revision mode, fix-it scan (with interactive tag selection), and has complete error handling.
- The context coverage for grant domain is comprehensive (17 entries, multiple subdirectories).
- The `/talk` command's forcing-questions pattern is ahead of most other extension commands.
- The `/grant` command's `--revise` mode and `--fix-it` mode are sophisticated features not found in most other commands.

---

## Recommended Approach

### Priority 1: Consistent Language Field
All present commands should set `language` to the compound form: `"present:grant"`, `"present:budget"`, `"present:timeline"`, `"present:funds"`, `"present:talk"`. This makes routing deterministic and context loading reliable.

### Priority 2: Add Pre-task Forcing Questions to Remaining Commands
`/grant`, `/budget`, `/timeline`, and `/funds` should adopt the same Stage 0 pattern as `/talk` and `/market`. Each has domain-specific questions that would improve output quality:
- `/grant`: funder type, mechanism, budget ceiling, timeline
- `/budget`: grant type, institution type, budget category focus
- `/timeline`: project duration, regulatory hurdles (IRB/IACUC), reporting requirements
- `/funds`: analysis mode (landscape/portfolio/gap), focal mechanism type

### Priority 3: Fix Context Index `load_when`
Update grant-specific entries from `languages: ["grant"]` to `languages: ["present", "present:grant"]`. Update all entries to consistently use the compound language form.

### Priority 4: Standardize Skill Preflight/Postflight
Replace inline jq status updates in `skill-grant` (and other present skills) with calls to `update-task-status.sh`, matching the pattern used by `skill-researcher` and `skill-planner`.

### Priority 5: Add Artifact Validation
Add Stage 6a (validate-artifact.sh call) to all present extension skills.

### Priority 6: Update Model Pinning
Change `model: claude-opus-4-5-20251101` to `model: opus` in all present extension command frontmatter.

---

## Evidence / Examples

### Evidence A: Forcing Questions Pattern (`/market`, STAGE 0)
```
/home/benjamin/.config/nvim/.claude/extensions/founder/commands/market.md
Lines 44-107: Stage 0 with 4 structured questions, forcing_data JSON schema
```

### Evidence B: Compound Language Issue (`/talk`)
```
/home/benjamin/.config/nvim/.claude/extensions/present/commands/talk.md
Line 185: "language": "present" (should be "present:talk" for unambiguous routing)
```

### Evidence C: Context Index Language Mismatch
```
/home/benjamin/.config/nvim/.claude/extensions/present/index-entries.json
Lines 11-14: load_when.languages = ["grant"] (no task has language="grant" in present extension)
Lines 252-254: load_when.languages = ["present"] (correct for non-grant entries)
```

### Evidence D: `update-task-status.sh` in gold standard skills
```
/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md
Line 72: bash .claude/scripts/update-task-status.sh preflight "$task_number" research "$session_id"
Line 249: bash .claude/scripts/update-task-status.sh postflight "$task_number" research "$session_id"
```

### Evidence E: `skill-grant` uses raw jq instead (deviation)
```
/home/benjamin/.config/nvim/.claude/extensions/present/skills/skill-grant/SKILL.md
Lines 159-168: Inline jq status update (not using centralized script)
```

### Evidence F: Artifact validation in gold standard (absent from skill-grant)
```
/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md
Lines 229-234: Stage 6a calls validate-artifact.sh --fix
(skill-grant has no equivalent stage)
```

---

## Confidence Level

**High confidence** on:
- The `language` field inconsistency (verified by reading talk.md task creation code and index-entries.json)
- The `update-task-status.sh` deviation in skill-grant (direct comparison with skill-researcher)
- Missing artifact validation in skill-grant
- Model version outdatedness

**Medium confidence** on:
- Whether `skill-budget`, `skill-timeline`, `skill-funds`, `skill-talk` have the same deviations as skill-grant (read skill-grant in detail, others not examined)
- Actual routing behavior when `language: "present"` is used -- depends on how the orchestrator resolves the manifest routing table at runtime

**Low confidence** on:
- Whether the context index entries with `languages: ["grant"]` actually fail to load (depends on runtime loader behavior and whether "grant" is treated as an alias)
