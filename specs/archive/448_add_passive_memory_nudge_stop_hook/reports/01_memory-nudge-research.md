# Research Report: Task #448

**Task**: 448 - Add passive memory nudge stop hook
**Started**: 2026-04-16T00:00:00Z
**Completed**: 2026-04-16T00:30:00Z
**Effort**: small
**Dependencies**: None (memory extension already exists)
**Sources/Inputs**: Codebase exploration, Claude Code hooks documentation (https://code.claude.com/docs/en/hooks)
**Artifacts**: specs/448_add_passive_memory_nudge_stop_hook/reports/01_memory-nudge-research.md
**Standards**: report-format.md

## Executive Summary

- The Stop hook infrastructure is mature with 3 existing hooks already registered; adding a 4th is straightforward
- Stop hooks receive `last_assistant_message` via stdin JSON, enabling reliable detection of completed lifecycle operations through text pattern matching
- The `transcript_path` field provides access to full conversation history for deeper analysis if needed
- The memory extension (`/learn`, `/distill`) is already deployed; the nudge hook simply prints a one-line reminder
- Recommended approach: lightweight bash script that pattern-matches `last_assistant_message` for lifecycle completion markers, prints reminder to stderr (non-blocking), exits 0

## Context & Scope

The task requires a passive (non-blocking) Stop hook that detects when a lifecycle command (`/research`, `/plan`, `/implement`, `/review`, `/todo`) has completed and prints a one-line reminder about memory capture (e.g., `/learn --task N`). The hook must be lightweight (sub-100ms), never block Claude from stopping, and only trigger for main-session lifecycle operations (not subagent completions).

## Findings

### Codebase Patterns

#### Existing Stop Hook Architecture

Three hooks are currently registered on the Stop event in `.claude/settings.json`:

| Hook | Script | Purpose |
|------|--------|---------|
| 1 | `post-command.sh` | Session logging (appends timestamp to sessions.log) |
| 2 | `tts-notify.sh` | TTS audio notification via Piper |
| 3 | `wezterm-notify.sh` | WezTerm tab status indicator |

All use the same pattern:
- Matcher: `"*"` (fire on every stop)
- Command: `"bash .claude/hooks/{script}.sh 2>/dev/null || echo '{}'"`
- Output: `echo '{}'` for success, `exit 0` to allow normal stop

Key pattern from existing hooks:
- `tts-notify.sh` already detects and suppresses subagent contexts by checking `agent_id` in stdin JSON
- All hooks use `exit_success()` helper that outputs `'{}'` and exits 0
- Error handling via `2>/dev/null || echo '{}'` wrapper in settings.json

#### Stop Hook Input Schema

The Stop hook receives JSON via stdin with these fields:

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/.claude/projects/.../UUID.jsonl",
  "cwd": "/home/benjamin/.config/nvim",
  "permission_mode": "default",
  "hook_event_name": "Stop",
  "last_assistant_message": "Here's what I accomplished...",
  "stop_reason": "end_turn"
}
```

Subagent-specific optional fields:
- `agent_id` - Present only for subagent stops
- `agent_type` - Agent name (e.g., "Explore", "Plan")

#### Stop Hook Output/Control Schema

| Exit Code | Behavior |
|-----------|----------|
| 0 | Allow stop; parse JSON from stdout |
| 2 + stderr | Block stop; continue conversation with stderr as feedback |
| Other | Non-blocking error; stderr shown in transcript |

For a passive nudge, exit code 0 is correct. The nudge text should go to stderr (shown in transcript as informational) while stdout returns `'{}'`.

**Important constraint**: Output injected into context is capped at 10,000 characters. The nudge should be well under this.

#### Lifecycle Command Detection Strategy

The `last_assistant_message` field contains the final text Claude produced before stopping. Lifecycle commands produce distinctive markers in their postflight output. Two detection approaches are viable:

**Approach A: Pattern match on `last_assistant_message`** (recommended)

Lifecycle completions produce characteristic text patterns:

| Command | Completion Markers |
|---------|-------------------|
| `/research N` | "status.*researched", "Research complete", "report.*specs/" |
| `/plan N` | "status.*planned", "Plan complete", "plan.*specs/" |
| `/implement N` | "status.*completed", "Implementation complete", "phase.*complete" |
| `/review` | "Review complete", "codebase analysis" |
| `/todo` | "archived", "CHANGE_LOG", "tasks archived" |

Pattern matching against `last_assistant_message` is fast (single grep/regex) and covers the main lifecycle commands.

**Approach B: Check `transcript_path` for command history**

The transcript is JSONL format at `transcript_path`. The hook could scan for user prompts matching `/research`, `/plan`, `/implement` patterns. This is more reliable but slower (file I/O + jq parsing).

**Recommendation**: Use Approach A with a few broad regex patterns. False positives are harmless (showing a reminder when not needed is low-cost), and false negatives are acceptable (this is a passive nudge, not a gate).

#### Subagent Suppression

The hook must NOT fire for subagent stops. The proven pattern from `tts-notify.sh`:

```bash
AGENT_ID=$(echo "$STDIN_JSON" | jq -r '.agent_id // empty' 2>/dev/null || echo "")
if [[ -n "$AGENT_ID" ]]; then
    exit_success  # Suppress for subagents
fi
```

#### Task Number Extraction

To show `/learn --task N` in the nudge, the hook needs the task number. Options:

1. **Parse from `last_assistant_message`**: Look for "task {N}" or "Task #{N}" patterns
2. **Check WezTerm TASK_NUMBER user var**: Already set by `wezterm-task-number.sh` on UserPromptSubmit
3. **Scan for recent `.return-meta.json`**: Find most recently modified metadata file in specs/

Option 1 is simplest and most portable. Option 3 is most reliable. Recommend option 1 with option 3 as fallback.

#### Memory Extension Integration

The memory extension provides:
- `/learn --task N` - Capture knowledge from task artifacts
- `/learn "text"` - Capture ad-hoc knowledge
- `/distill` - Vault health and maintenance

The nudge message should reference `/learn --task N` when a task number is detected, and `/learn` generically otherwise.

### External Resources

#### Claude Code Hooks Documentation

From https://code.claude.com/docs/en/hooks:
- Stop hooks fire on every turn completion (no matcher filtering)
- Stop hooks can block via exit code 2 or `{"decision": "block"}` JSON
- Environment variables available: `CLAUDE_PROJECT_DIR`, `CLAUDE_CODE_REMOTE`
- `CLAUDE_ENV_FILE` is only available in SessionStart/CwdChanged/FileChanged hooks
- Output cap: 10,000 characters injected into context

#### Hook Best Practices

- Hooks should be fast (<200ms recommended)
- Use `set -uo pipefail` for robustness
- Always output valid JSON to stdout (even empty `{}`)
- Background long-running operations
- Handle missing dependencies gracefully (guard with `command -v`)

### Recommendations

#### Script Design: `.claude/hooks/memory-nudge.sh`

```
Input:  stdin JSON with last_assistant_message, agent_id, stop_reason
Output: stdout '{}', optional stderr nudge message
Exit:   Always 0 (never block)
```

Core logic:
1. Read stdin JSON
2. Guard: exit if `agent_id` present (subagent)
3. Guard: exit if `stop_reason` is not `end_turn`
4. Pattern match `last_assistant_message` for lifecycle completion markers
5. Extract task number if present
6. Print one-line nudge to stderr
7. Exit 0

#### Nudge Message Format

Single line, visually distinct but not intrusive:

```
[memory] Task 448 completed. Consider: /learn --task 448
```

Or without task number:

```
[memory] Lifecycle operation completed. Consider: /learn
```

#### Cooldown Mechanism

To avoid nudge fatigue, use a cooldown file (same pattern as `tts-notify.sh`):

```bash
COOLDOWN_FILE="specs/tmp/memory-nudge-last"
COOLDOWN_SECONDS=300  # 5 minutes between nudges
```

#### Settings Integration

Add to the existing Stop hook array in `.claude/settings.json`:

```json
{
  "type": "command",
  "command": "bash .claude/hooks/memory-nudge.sh 2>/dev/null || echo '{}'"
}
```

**Note**: The `2>/dev/null` in the settings.json wrapper suppresses the stderr from reaching Claude's context. For the nudge to be visible, the script should output via `{"systemMessage": "..."}` JSON on stdout instead. Alternatively, the settings.json entry should NOT suppress stderr if the intent is for Claude to see the nudge.

**Correction on output mechanism**: After reviewing the docs more carefully:
- `stderr` on exit 0 is shown in the transcript as non-blocking
- `{"systemMessage": "..."}` in stdout is shown to the user as a warning
- To inject text into Claude's context (so Claude sees it), use `{"additionalContext": "..."}` -- but this is only for PreToolUse/PostToolUse hooks
- For Stop hooks, the `2>/dev/null` wrapper in settings.json would suppress stderr. The nudge should use stdout JSON with a field that gets displayed.

**Recommended output mechanism**: Since the settings.json wrapper uses `2>/dev/null`, the nudge should output JSON to stdout:

```json
{"systemMessage": "[memory] Task 448 completed. Consider: /learn --task 448"}
```

The `systemMessage` field shows as a warning/info line to the user.

Alternatively, change the settings.json wrapper to NOT suppress stderr for this hook:

```json
{
  "type": "command",
  "command": "bash .claude/hooks/memory-nudge.sh || echo '{}'"
}
```

Then the script can use stderr for the nudge (simpler, matches the "passive" requirement).

## Decisions

1. **Detection approach**: Pattern match on `last_assistant_message` (fast, sufficient accuracy)
2. **Subagent suppression**: Reuse `agent_id` check pattern from `tts-notify.sh`
3. **Task number extraction**: Parse from `last_assistant_message`, fallback to scanning `specs/` for recent `.return-meta.json`
4. **Output mechanism**: Use `systemMessage` JSON field on stdout (works with existing `2>/dev/null` wrapper pattern; alternatively, omit stderr suppression)
5. **Cooldown**: 5-minute cooldown via timestamp file in `specs/tmp/`
6. **Nudge text**: `[memory] Task N completed. Consider: /learn --task N`

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| False positives (nudge on non-lifecycle stops) | Medium | Low | Harmless reminder; cooldown prevents spam |
| False negatives (missed lifecycle completions) | Low | Low | Passive feature; no workflow impact |
| Performance impact | Low | Medium | Script is <50 lines, no heavy I/O; jq is the only dependency |
| Nudge fatigue | Medium | Medium | Cooldown mechanism (5-min default, configurable) |
| stderr suppression by wrapper | N/A | Medium | Use stdout `systemMessage` JSON or adjust wrapper |

## Context Extension Recommendations

- **Topic**: hooks/memory-nudge
- **Gap**: No documentation exists for the nudge hook pattern (passive informational hooks that suggest next actions)
- **Recommendation**: After implementation, add a brief section to the wezterm-integration.md or create a new `hooks/memory-nudge.md` context file

## Appendix

### Search Queries Used

1. Codebase: `Glob .claude/hooks/**/*` -- found 10 existing hook scripts
2. Codebase: `Grep hook|Hook|stop_hook` in `.claude/` -- found 58 files with hook references
3. Codebase: `Read .claude/settings.json` -- full hooks configuration
4. Codebase: `Read .claude/hooks/tts-notify.sh` -- subagent suppression pattern
5. Codebase: `Read .claude/hooks/post-command.sh` -- minimal Stop hook pattern
6. Codebase: `Read .claude/extensions/memory/manifest.json` -- memory extension structure
7. Web: Claude Code hooks documentation (https://code.claude.com/docs/en/hooks) -- Stop hook schema, exit codes, environment variables

### References

- `.claude/settings.json` - Current hooks configuration (lines 92-109 for Stop hooks)
- `.claude/hooks/tts-notify.sh` - Reference for subagent suppression and cooldown patterns
- `.claude/hooks/post-command.sh` - Minimal Stop hook template
- `.claude/context/patterns/postflight-control.md` - Postflight marker protocol
- `.claude/extensions/memory/` - Memory extension providing `/learn` command
- https://code.claude.com/docs/en/hooks - Official hooks documentation

### Lifecycle Detection Regex Patterns

Recommended patterns for `last_assistant_message` matching:

```bash
# Completed lifecycle operations
LIFECYCLE_PATTERNS=(
  'task [0-9]+: complete (research|implementation|plan)'
  'status.*\b(researched|planned|completed)\b'
  '[Rr]esearch complete'
  '[Pp]lan complete'
  '[Ii]mplementation complete'
  'archived.*task'
  'tasks? archived'
)
```

### File Layout

```
.claude/hooks/memory-nudge.sh     # New hook script (~60 lines)
.claude/settings.json             # Add entry to Stop hooks array
specs/tmp/memory-nudge-last       # Cooldown timestamp (auto-created)
```
