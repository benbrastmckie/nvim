# Implementation Plan: TTS Primary Agent Only Notification Hook

- **Task**: 376 - tts_primary_agent_only_notification_hook
- **Status**: [IMPLEMENTING]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: reports/01_tts-primary-agent-research.md
- **Artifacts**: plans/01_tts-primary-agent.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The tts-notify.sh hook currently fires TTS announcements for both primary and subagent contexts. The `agent_id` field in hook stdin JSON is present only in subagent context, providing a definitive signal to suppress TTS. The Notification hook is **not** configured in settings.json, so it must be added to trigger TTS on interactive feedback events (permission prompts, idle prompts, elicitation dialogs). Additionally, the `auth_success` notification type should be filtered out as a non-actionable event. Done when subagent Stop events produce no TTS output and notification events for the primary agent do produce TTS.

### Research Integration

Key findings from the research report (reports/01_tts-primary-agent-research.md):
- `agent_id` is present in hook stdin JSON only for subagents -- this is the definitive guard signal
- The script already reads stdin and parses JSON fields (`hook_event_name`, `notification_type`)
- The Notification hook is NOT configured in settings.json -- must be added
- The existing worktree detection (lines 118-128) catches git-worktree-based subagents but not in-process subagents
- Optional: filter `auth_success` notification type as non-actionable

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Add `agent_id` guard to tts-notify.sh so subagent events are silently suppressed
- Add Notification hook entry to settings.json for interactive feedback events
- Filter `auth_success` notification type as non-actionable
- Preserve existing worktree detection as a complementary guard

**Non-Goals**:
- Changing TTS message content based on event type (differentiated messages)
- Adding new audio backends or changing the Piper TTS model
- Changing the cooldown mechanism

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `agent_id` field name changes in future Claude Code versions | H | Very Low | Field is documented in official hooks reference; monitor release notes |
| jq not available on target system | M | Low | Script already checks `command -v jq`; guard is inside existing jq block |
| stdin read blocks if no JSON provided | M | Low | Script already uses `read -t 0.1` with timeout; no change needed |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add agent_id Guard, Notification Type Filter, and Notification Hook [COMPLETED]

**Goal**: Suppress TTS for subagent events and non-actionable notification types by adding guard checks to tts-notify.sh, and add Notification hook entry to settings.json.

**Tasks**:
- [ ] Add `agent_id` extraction from stdin JSON using jq (after TTS_ENABLED check, before piper check)
- [ ] Add early exit when `agent_id` is non-empty (indicates subagent context)
- [ ] Add `auth_success` notification type filter with early exit
- [ ] Log both guard activations for debugging
- [ ] Add `Notification` hook entry to `.claude/settings.json` binding tts-notify.sh with `*` matcher

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/hooks/tts-notify.sh` - Insert agent_id guard after line 38 (after TTS_ENABLED check), insert notification type filter after agent_id guard
- `.claude/settings.json` - Add Notification hook entry in hooks object

**Verification**:
- Script contains `agent_id` extraction and conditional exit
- Script contains `auth_success` notification type filter
- settings.json contains Notification hook with tts-notify.sh binding
- Shellcheck passes on modified script (no syntax errors)
- Script still exits with `{}` JSON on suppressed events

---

### Phase 2: Manual Verification and Logging Review [NOT STARTED]

**Goal**: Confirm the guard works correctly in real agent sessions by reviewing log output.

**Tasks**:
- [ ] Run a primary agent session and verify TTS fires on Stop event
- [ ] Verify log file shows no "Subagent detected" message for primary agent
- [ ] If possible, trigger a subagent (e.g., via /research --team) and verify TTS is suppressed
- [ ] Check log file for "Subagent detected" entry from subagent event
- [ ] Verify Notification events (permission_prompt) still trigger TTS for primary agent

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**: None (read-only verification)

**Verification**:
- Log file at `specs/tmp/claude-tts-notify.log` shows correct guard behavior
- Primary agent TTS works as before
- Subagent TTS is suppressed

## Testing & Validation

- [ ] Shellcheck passes on `.claude/hooks/tts-notify.sh`
- [ ] Script exits cleanly with `{}` when `agent_id` is present in stdin JSON
- [ ] Script exits cleanly with `{}` when `notification_type` is `auth_success`
- [ ] Script proceeds to TTS when `agent_id` is absent (primary agent)
- [ ] Existing cooldown and worktree detection logic unaffected
- [ ] Primary agent Stop event still produces TTS announcement
- [ ] Primary agent Notification event (permission_prompt) produces TTS announcement

## Artifacts & Outputs

- `.claude/hooks/tts-notify.sh` - Modified with agent_id guard and notification type filter
- `.claude/settings.json` - Modified with Notification hook entry
- `specs/376_tts_primary_agent_only_notification_hook/plans/01_tts-primary-agent.md` - This plan
- `specs/376_tts_primary_agent_only_notification_hook/summaries/01_tts-primary-agent-summary.md` - Execution summary (after implementation)

## Rollback/Contingency

Revert the tts-notify.sh changes with `git checkout .claude/hooks/tts-notify.sh`. No settings.json changes are required, so rollback is a single-file operation. The script is non-critical infrastructure; if TTS breaks, it does not affect Claude Code functionality.
