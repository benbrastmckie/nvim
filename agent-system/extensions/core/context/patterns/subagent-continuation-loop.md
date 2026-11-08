# Subagent Continuation Loop Pattern

**Created**: 2026-05-04
**Purpose**: Enable automatic multi-subagent sequential continuation when a single subagent exhausts context during long-running implementation tasks
**Audience**: Skill implementers, agent developers
**Related**: `handoff-artifact.md`, `progress-file.md`, `postflight-control.md`, `checkpoint-execution.md`

---

## Overview

When a subagent approaches context limits during implementation, it writes a **handoff artifact** and returns `partial` status with a `handoff_path`. The lead skill detects this and automatically spawns a **successor subagent** with minimal context (handoff + progress file) rather than requiring user intervention. This pattern turns context exhaustion from a user-blocking event into an automatic handoff.

**Max continuations**: 3 (aligns with `postflight-control.md` loop guard convention)

---

## Loop Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  CONTINUATION LOOP                                                  │
│                                                                     │
│  Stage 5c: Init loop guard (continuation_count = 0)                │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  LOOP (while true)                                          │   │
│  │                                                             │   │
│  │  Stage 6:  Parse subagent metadata (.return-meta.json)      │   │
│  │  Stage 6a: Validate artifact content                        │   │
│  │  Stage 6b: Commit phase progress (git checkpoint)           │   │
│  │                                                             │   │
│  │  Stage 7:  Update task status                               │   │
│  │            ├─ "implemented" → break loop                    │   │
│  │            ├─ "partial" + handoff_path + count < 3         │   │
│  │            │   → increment count                            │   │
│  │            │   → spawn successor (goto Stage 5)             │   │
│  │            │   → continue loop                              │   │
│  │            ├─ "partial" + no handoff_path → break           │   │
│  │            ├─ "partial" + count >= 3 → break                │   │
│  │            └─ "failed" → break loop                         │   │
│  │                                                             │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  Stage 8:  Link artifacts (after loop)                             │
│  Stage 9:  Final git commit                                        │
│  Stage 10: Cleanup (remove marker, metadata, loop guard)           │
│  Stage 11: Return brief summary                                    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Loop Guard File

**Location**: `specs/{NNN}_{SLUG}/.continuation-loop-guard`

The loop guard tracks `continuation_count` across potential skill interruptions:

```json
{
  "session_id": "sess_20260504_495_impl",
  "continuation_count": 1,
  "max_continuations": 3,
  "created": "2026-05-04T10:00:00Z",
  "last_updated": "2026-05-04T11:00:00Z"
}
```

**Behavior**:
- Created in Stage 5c before the first subagent is spawned
- Updated on each continuation iteration
- Removed in Stage 10 cleanup (after loop exit)
- If the skill is interrupted mid-loop, the next invocation reads the guard and respects the count

---

## Successor Delegation Context

When spawning a successor, the delegation context includes a `continuation_context` field:

```json
{
  "session_id": "sess_20260504_495_impl",
  "delegation_depth": 2,
  "delegation_path": ["orchestrator", "implement", "general-implementation-agent", "successor-1"],
  "timeout": 7200,
  "task_context": { ... },
  "artifact_number": "01",
  "plan_path": "specs/495_.../plans/01_...md",
  "metadata_file_path": "specs/495_.../.return-meta.json",
  "continuation_context": {
    "is_successor": true,
    "continuation_number": 1,
    "handoff_path": "specs/495_.../handoffs/phase-2-handoff-20260504T120000Z.md",
    "progress_path": "specs/495_.../progress/phase-2-progress.json",
    "previous_phases_completed": 1
  }
}
```

**Key invariants**:
- `session_id` is preserved across the entire continuation chain
- `delegation_depth` increments by 1 for each successor
- `artifact_number` stays consistent (all successors use the same round number)
- The successor reads the handoff artifact FIRST, then the progress file, before resuming work

---

## Handoff Consumption by Successors

Successors follow a progressive disclosure protocol when reading handoffs:

1. **Quick Start**: Read `Immediate Next Action` + `Current State` (sufficient for 80% of resumes)
2. **If Stuck**: Read `Key Decisions Made` + `What NOT to Try`
3. **Escape Hatch**: Read `References` section (only if truly stuck)

The successor MUST NOT re-read the full plan unless the handoff explicitly indicates it is necessary. The handoff's `References` section points to deeper context.

---

## Per-Continuation Git Commits

Each iteration of the continuation loop includes a git checkpoint (Stage 6b). Apply the
`implement` scope from `.claude/context/standards/git-staging-scope.md` — task dir + plan_path +
self-reported `modified_files` — never a repo-wide add:

```bash
stage_paths=("specs/${padded_num}_${project_name}/" "specs/TODO.md" "specs/state.json" "$plan_path")
while IFS= read -r f; do
  [ -n "$f" ] && stage_paths+=("$f")
done < <(jq -r '.modified_files[]? // empty' "specs/${padded_num}_${project_name}/.return-meta.json" 2>/dev/null)
bash .claude/scripts/git-commit-scoped.sh \
  --message "task ${task_number} phase ${phases_completed}: implementation progress" \
  --session "${session_id}" \
  --honest-index-rows "${task_number}" \
  -- "${stage_paths[@]}"
```

This ensures:
- Each subagent's progress is committed before spawning a successor
- If a later continuation fails, earlier progress is preserved
- Git history reflects the incremental nature of the work

After the loop exits, a final commit (Stage 9) captures completion (same scope as above):
```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task ${task_number}: complete implementation" \
  --session "${session_id}" \
  --honest-index-rows "${task_number}" \
  -- "${stage_paths[@]}"
```

---

## Status Transitions During Loop

| Subagent Return | Action | Loop Behavior | Final Status |
|-----------------|--------|---------------|--------------|
| `implemented` | Mark completed, break loop | Exit | `completed` |
| `partial` + handoff_path + count < 3 | Update resume point, spawn successor | Continue | (loop continues) |
| `partial` + no handoff_path | Update resume point, break loop | Exit | `implementing` (user resume) |
| `partial` + count >= 3 | Update resume point, break loop | Exit | `implementing` (max reached) |
| `failed` | Keep implementing for retry, break loop | Exit | `implementing` (retry) |

---

## Error Handling

### Missing or Malformed Handoff

If `handoff_path` is missing from partial metadata:
- The skill falls back to the progress file + plan file
- If neither is available, report partial and require user resume
- The agent should always write a progress file, so this fallback is reliable

### Session ID Mismatch

If the session_id in the loop guard does not match the current session:
- Abort the continuation loop
- Report partial status
- This prevents race conditions when the user re-runs an implement dispatch (via `/orchestrate`) while a continuation is in progress

### Context Exhaustion During Handoff Writing

If the agent runs out of context while writing the handoff:
- Handoff artifacts are short (~40 lines)
- The agent writes the handoff BEFORE attempting any large file operations
- If even the handoff fails, the agent returns partial with `details` describing the state

---

## Reuse Guidelines

This pattern can be reused by any skill that delegates to long-running subagents:

1. **general-research-agent**: For long research tasks that exhaust context
2. **planner-agent**: For complex multi-domain planning
3. **Domain-specific implementers**: For large codebases or complex configurations

To adopt this pattern in another skill:
1. Add Stage 5c (loop guard init) before subagent spawning
2. Wrap postflight Stages 6, 6a, 6b, and 7 in a loop
3. Add continuation logic to Stage 7 (detect handoff_path, spawn successor)
4. Move cleanup to after loop exit
5. Update the skill's prohibition/continuation policy text

---

## Related Documentation

- [Handoff Artifact Schema](../formats/handoff-artifact.md) - Handoff document template
- [Progress File Schema](../formats/progress-file.md) - Progress tracking format
- [Return Metadata Format](../formats/return-metadata-file.md) - Metadata schema with `handoff_path`
- [Postflight Control Pattern](postflight-control.md) - Marker file protocol
- [Context Exhaustion Detection](context-exhaustion-detection.md) - Agent heuristics for detecting context pressure
