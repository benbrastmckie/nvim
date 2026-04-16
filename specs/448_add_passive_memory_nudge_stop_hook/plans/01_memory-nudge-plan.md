# Implementation Plan: Add Passive Memory Nudge Stop Hook

- **Task**: 448 - Add passive memory nudge stop hook
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: Task #446 (memory candidate emission, completed)
- **Research Inputs**: specs/448_add_passive_memory_nudge_stop_hook/reports/01_memory-nudge-research.md
- **Artifacts**: plans/01_memory-nudge-plan.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Create a lightweight Stop hook script that detects completed lifecycle operations (`/research`, `/plan`, `/implement`, `/review`, `/todo`) and displays a one-line memory capture reminder. The hook pattern-matches `last_assistant_message` from stdin JSON, suppresses for subagent contexts, applies a 5-minute cooldown to prevent nudge fatigue, and outputs via `systemMessage` JSON on stdout. No state changes or file writes beyond the cooldown timestamp.

### Research Integration

Key findings from the research report:
- Three existing Stop hooks provide a proven pattern (`post-command.sh`, `tts-notify.sh`, `wezterm-notify.sh`)
- `tts-notify.sh` already implements subagent suppression via `agent_id` check -- reuse this pattern
- Stop hook stdin provides `last_assistant_message`, `agent_id`, and `stop_reason` fields
- Pattern matching on `last_assistant_message` is the recommended detection approach (fast, sufficient accuracy)
- `systemMessage` JSON field on stdout is the correct output mechanism when `2>/dev/null` wrapper is used in settings.json
- Cooldown via timestamp file in `specs/tmp/` prevents nudge fatigue

### Roadmap Alignment

No ROADMAP.md items directly correspond to this task. This is part of the memory system infrastructure (tasks 444-454).

## Goals & Non-Goals

**Goals**:
- Detect completed lifecycle operations via pattern matching on the last assistant message
- Display a one-line reminder suggesting `/learn --task N` when a task number is extractable
- Suppress for subagent contexts and respect a 5-minute cooldown
- Integrate into existing Stop hook array in settings.json

**Non-Goals**:
- Writing to state.json or any persistent state beyond the cooldown timestamp file
- Blocking Claude from stopping (always exit 0)
- Guaranteeing 100% detection accuracy (false positives are harmless, false negatives acceptable)
- Implementing memory retrieval or creation logic (that is `/learn` scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| False positives (nudge on non-lifecycle stops) | L | M | Cooldown limits frequency; harmless reminder |
| `systemMessage` output not displayed by Claude Code | M | L | Test during verification; fall back to stderr without `2>/dev/null` wrapper if needed |
| jq not available on system | H | L | Guard with `command -v jq` check; exit 0 gracefully |
| Cooldown file directory missing | L | L | Create `specs/tmp/` with `mkdir -p` in script |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Create Hook Script [NOT STARTED]

**Goal**: Implement the `memory-nudge.sh` Stop hook script with all detection, suppression, cooldown, and output logic.

**Tasks**:
- [ ] Create `.claude/hooks/memory-nudge.sh` with the following logic:
  - Read stdin JSON into variable
  - Guard: exit if `agent_id` present (subagent suppression, reuse `tts-notify.sh` pattern)
  - Guard: exit if `stop_reason` is not `end_turn`
  - Guard: check 5-minute cooldown via `specs/tmp/memory-nudge-last` timestamp file
  - Pattern match `last_assistant_message` against lifecycle completion regex patterns:
    - `task [0-9]+: complete (research|implementation|plan)`
    - `status.*(researched|planned|completed)`
    - `[Rr]esearch complete`
    - `[Pp]lan complete`
    - `[Ii]mplementation complete`
    - `archived.*task` / `tasks? archived`
  - Extract task number from message (regex for `task [0-9]+` or `Task #[0-9]+`)
  - Output `{"systemMessage": "[memory] Task N completed. Consider: /learn --task N"}` to stdout (or generic message without task number)
  - Update cooldown timestamp file
  - Exit 0 always
- [ ] Ensure script is executable (`chmod +x`)
- [ ] Follow existing hook conventions: `set -uo pipefail`, `exit_success()` helper

**Timing**: 40 minutes

**Depends on**: none

**Files to modify**:
- `.claude/hooks/memory-nudge.sh` - New file (create)

**Verification**:
- Script parses valid stdin JSON without errors
- Script exits 0 for subagent contexts (non-empty `agent_id`)
- Script exits 0 with empty stdout for non-lifecycle messages
- Script outputs valid `systemMessage` JSON for lifecycle completion patterns
- Script respects cooldown (second invocation within 5 minutes produces no output)

---

### Phase 2: Settings Integration and Testing [NOT STARTED]

**Goal**: Register the hook in settings.json and verify end-to-end behavior.

**Tasks**:
- [ ] Add Stop hook entry to `.claude/settings.json` hooks array:
  ```json
  {
    "type": "command",
    "command": "bash .claude/hooks/memory-nudge.sh 2>/dev/null || echo '{}'"
  }
  ```
- [ ] Verify the hook entry is placed in the correct Stop hooks section alongside the 3 existing hooks
- [ ] Test with simulated stdin JSON containing lifecycle completion text
- [ ] Test with simulated stdin JSON containing non-lifecycle text (should produce no output)
- [ ] Test with simulated subagent context (should produce no output)
- [ ] Verify `specs/tmp/memory-nudge-last` cooldown file is created after first trigger

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/settings.json` - Add Stop hook entry to existing hooks array

**Verification**:
- settings.json is valid JSON after edit
- Hook appears in Stop event section alongside existing 3 hooks
- `echo '{"last_assistant_message":"task 448: complete research","stop_reason":"end_turn"}' | bash .claude/hooks/memory-nudge.sh` produces systemMessage output
- `echo '{"last_assistant_message":"Here is some code","stop_reason":"end_turn"}' | bash .claude/hooks/memory-nudge.sh` produces empty JSON or no output
- `echo '{"last_assistant_message":"task 448: complete research","stop_reason":"end_turn","agent_id":"abc"}' | bash .claude/hooks/memory-nudge.sh` produces no nudge

## Testing & Validation

- [ ] Script exits 0 in all code paths (never blocks Claude)
- [ ] Subagent suppression works (agent_id present -> no nudge)
- [ ] Lifecycle detection matches expected patterns from research
- [ ] Task number extraction works for patterns like "task 448:" and "Task #448"
- [ ] Cooldown prevents repeated nudges within 5-minute window
- [ ] settings.json remains valid JSON after hook registration
- [ ] No interference with existing 3 Stop hooks

## Artifacts & Outputs

- `.claude/hooks/memory-nudge.sh` - New hook script (~60 lines)
- `.claude/settings.json` - Modified (one new Stop hook entry)
- `specs/tmp/memory-nudge-last` - Auto-created cooldown timestamp file (runtime)

## Rollback/Contingency

Remove the Stop hook entry from `.claude/settings.json` and delete `.claude/hooks/memory-nudge.sh`. The cooldown file `specs/tmp/memory-nudge-last` can be deleted. No other files are affected. Since the hook is passive (exit 0, no state changes), removing it has zero side effects.
