# Implementation Plan: Task #202

- **Task**: 202 - Implement trailing-edge debounce for TTS session.idle notifications
- **Status**: [COMPLETE]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: [01_tts-debounce-research.md](../reports/01_tts-debounce-research.md)
- **Artifacts**: plans/02_tts-debounce-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Implement trailing-edge debounce for TTS notifications in the opencode wezterm-hooks plugin. The current leading-edge debounce fires immediately on `session.idle`, which causes premature TTS announcements when sub-agents complete mid-operation. The fix adds a 1.5-second trailing delay that cancels if `session.status` fires with a non-idle status before the timer expires. Permission and question events continue to fire immediately since they require user input.

### Research Integration

Key findings from research report:
- Current implementation uses leading-edge debounce (fires first, ignores subsequent for 3s)
- OpenCode fires `session.status` events with `status.type` property
- JavaScript `setTimeout`/`clearTimeout` pattern is standard for trailing debounce
- Timer should be configurable via `TTS_TRAILING_DELAY` environment variable

## Goals & Non-Goals

**Goals**:
- TTS fires only after session is truly idle (no activity for 1.5 seconds)
- TTS fires immediately for permission/question events (user-blocking)
- Timer cancels when session becomes busy again
- Delay is configurable via environment variable

**Non-Goals**:
- Changing the TTS shell scripts themselves
- Modifying WezTerm status indicator behavior
- Adding complex retry or queue logic

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `session.status` events not fired reliably | TTS never cancelled mid-operation | Low | Trailing delay still groups rapid idle events even without cancellation |
| Timer too short (< 1.5s) | Still fires mid-operation | Low | Default 1.5s tested in similar patterns; configurable via env var |
| Timer too long (> 2s) | User annoyed by notification delay | Low | 1.5s is reasonable; document the delay exists |
| Async/await with setTimeout | Promise handling issues | Low | Use standard async pattern with stored timer handle |

## Implementation Phases

### Phase 1: Implement Trailing-Edge Debounce [COMPLETED]

**Goal**: Replace leading-edge debounce with trailing-edge debounce in wezterm-hooks.js

**Tasks**:
- [ ] Remove `lastTtsMs` and `TTS_DEBOUNCE_MS` variables
- [ ] Add `pendingTtsTimer` state variable (null initially)
- [ ] Add `TTS_TRAILING_DELAY_MS` constant (configurable via env var, default 1500)
- [ ] Modify `session.idle` handler to use setTimeout with trailing delay
- [ ] Add `session.status` handler to cancel pending timer when not idle
- [ ] Preserve immediate TTS for `permission.asked` and `question.asked` events

**Timing**: 30-45 minutes

**Files to modify**:
- `.opencode/plugins/wezterm-hooks.js` - Main implementation changes

**Verification**:
- Plugin loads without syntax errors
- `session.idle` starts a timer instead of firing immediately
- `session.status` with non-idle type cancels pending timer

---

### Phase 2: Update Documentation [COMPLETED]

**Goal**: Document the new trailing-edge debounce behavior

**Tasks**:
- [ ] Update TTS section in tts-stt-integration.md to describe trailing delay
- [ ] Document `TTS_TRAILING_DELAY` environment variable
- [ ] Add note about immediate firing for permission/question events
- [ ] Remove references to old 3-second leading-edge debounce

**Timing**: 15-20 minutes

**Files to modify**:
- `.opencode/docs/guides/tts-stt-integration.md` - Documentation updates

**Verification**:
- Documentation accurately reflects new behavior
- Environment variable is documented with default value
- No stale references to old debounce logic

---

### Phase 3: Test and Verify [COMPLETED]

**Goal**: Verify the implementation works correctly in real usage

**Tasks**:
- [ ] Run a simple command and verify TTS fires ~1.5s after completion
- [ ] Run `/research` or `/implement` with sub-agents and verify only ONE TTS at end
- [ ] Trigger a permission prompt and verify TTS fires immediately
- [ ] Check TTS notification log for expected behavior

**Timing**: 15-20 minutes

**Files to modify**:
- None (testing only)

**Verification**:
- Simple commands: TTS fires after 1.5s delay
- Multi-agent operations: Single TTS at final completion
- Permission prompts: Immediate TTS (no delay)
- Log shows consolidated notifications, not rapid duplicates

## Testing & Validation

- [ ] Plugin loads without errors: `opencode` starts with plugin enabled
- [ ] Single command test: Run `/help`, TTS fires once after ~1.5s
- [ ] Multi-agent test: Run `/research N`, TTS fires once at end (not per sub-agent)
- [ ] Permission test: Trigger a tool that asks permission, TTS fires immediately
- [ ] Log verification: `tail -f specs/tmp/claude-tts-notify.log` shows expected pattern

## Artifacts & Outputs

- `.opencode/plugins/wezterm-hooks.js` - Modified plugin with trailing debounce
- `.opencode/docs/guides/tts-stt-integration.md` - Updated documentation
- `specs/OC_202_debounce_tts_session_idle/summaries/03_tts-debounce-summary.md` - Execution summary

## Rollback/Contingency

If the trailing debounce causes issues:
1. Revert `.opencode/plugins/wezterm-hooks.js` to previous version via git
2. The leading-edge debounce will be restored
3. File an issue describing the failure mode for further investigation

Alternatively, increase `TTS_TRAILING_DELAY` via environment variable if timer is too short.
