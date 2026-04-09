# Implementation Summary: TTS Primary Agent Only Notification Hook

- **Task**: 376 - tts_primary_agent_only_notification_hook
- **Status**: [COMPLETED]
- **Started**: 2026-04-08T00:00:00Z
- **Completed**: 2026-04-08T00:05:00Z
- **Effort**: 15 minutes
- **Dependencies**: None
- **Artifacts**: plans/01_tts-primary-agent.md, reports/01_tts-primary-agent-research.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Configured TTS announcements in tts-notify.sh to suppress output for subagent contexts and non-actionable notification types. Added a Notification hook entry to settings.json so interactive feedback events (permission prompts, idle prompts, elicitation dialogs) trigger TTS for the primary agent.

## What Changed

- Added `agent_id` extraction from stdin JSON with early exit when non-empty (subagent guard) in `.claude/hooks/tts-notify.sh` (lines 63-71)
- Added `auth_success` notification type filter with early exit in `.claude/hooks/tts-notify.sh` (lines 73-76)
- Both guards log their activation for debugging purposes
- Added `Notification` hook entry with `*` matcher binding `tts-notify.sh` in `/home/benjamin/.config/.claude/settings.json`

## Decisions

- Placed guards after the TTS_ENABLED check but before the piper availability check, so subagent suppression happens early without unnecessary work
- Used the existing `STDIN_JSON` variable (already read at script start) rather than introducing a separate `HOOK_INPUT=$(cat)` call, since stdin is already consumed
- Kept the existing worktree detection as a complementary guard (belt and suspenders)
- Settings.json Notification hook uses the same `bash .claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'` pattern as the Stop hook

## Impacts

- Subagent Stop and Notification events will no longer produce TTS output
- Primary agent Stop and Notification events continue to produce TTS as before
- `auth_success` notifications are silently suppressed for all contexts
- No changes to cooldown, worktree detection, or message formatting logic

## Follow-ups

- Phase 2 (manual verification) should be done in a live session to confirm subagent suppression works correctly
- Monitor Claude Code releases for any changes to the `agent_id` field in hook stdin JSON

## References

- `.claude/hooks/tts-notify.sh` -- Modified script with guards
- `/home/benjamin/.config/.claude/settings.json` -- Modified with Notification hook (outside nvim repo)
- `specs/376_tts_primary_agent_only_notification_hook/reports/01_tts-primary-agent-research.md` -- Research findings
- `specs/376_tts_primary_agent_only_notification_hook/plans/01_tts-primary-agent.md` -- Implementation plan
