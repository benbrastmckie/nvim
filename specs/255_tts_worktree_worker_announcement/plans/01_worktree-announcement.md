# Implementation Plan: Task #255

- **Task**: 255 - tts_worktree_worker_announcement
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/255_tts_worktree_worker_announcement/reports/01_worktree-detection.md
- **Artifacts**: plans/01_worktree-announcement.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Modify `.claude/hooks/tts-notify.sh` to detect when the Stop hook fires inside a git worktree (sub-agent session) and announce "Tab N worker" instead of "Tab N". This auditory distinction helps users identify sub-agent completions vs final parent completions. The implementation uses git's built-in worktree detection by comparing `--git-dir` with `--git-common-dir`.

### Research Integration

Research report `01_worktree-detection.md` analyzed three worktree detection methods and recommended Method 1 (compare git-dir with git-common-dir) for maximum reliability. Key findings:
- In main worktree: both commands return `.git`
- In linked worktree: `--git-dir` returns `.git/worktrees/<name>`, `--git-common-dir` returns path to main `.git`
- No external dependencies needed - uses built-in git commands

## Goals & Non-Goals

**Goals**:
- Detect when tts-notify.sh runs inside a git worktree
- Announce "Tab N worker" for worktree sessions
- Maintain existing behavior for main sessions
- Handle edge cases gracefully (no git, not in repo)

**Non-Goals**:
- Modifying other hooks (wezterm-notify.sh, subagent-postflight.sh)
- Adding environment variables for worktree detection
- Changing the TTS voice or audio configuration

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| git command unavailable | Low | Low | Check for git binary, fallback to non-worktree message |
| git rev-parse fails (not in repo) | Low | Low | Wrap in conditional with error suppression |
| Performance impact from git calls | Very Low | Very Low | Two fast git commands add <10ms |
| TTS pronunciation issues | Low | Low | "worker" is a simple word, tested with piper TTS |

## Implementation Phases

### Phase 1: Add Worktree Detection [COMPLETED]

**Goal**: Add logic to detect if running inside a git worktree

**Tasks**:
- [ ] Add worktree detection code after line 116 (after TAB_NUM calculation)
- [ ] Use Method 1: compare `git rev-parse --git-dir` with `git rev-parse --git-common-dir`
- [ ] Set `IS_WORKTREE=true` when paths differ
- [ ] Gracefully handle missing git or non-repo scenarios

**Timing**: 15 minutes

**Files to modify**:
- `.claude/hooks/tts-notify.sh` - Add detection logic between lines 116-117

**Verification**:
- Detection code compiles (bash -n syntax check)
- IS_WORKTREE variable set correctly in worktree context

---

### Phase 2: Modify Message Construction [COMPLETED]

**Goal**: Conditionally append "worker" suffix based on worktree detection

**Tasks**:
- [ ] Modify MESSAGE construction (around line 124)
- [ ] If `IS_WORKTREE=true`, set `MESSAGE="$TAB_PREFIX worker"`
- [ ] Otherwise, keep existing `MESSAGE="$TAB_PREFIX"`
- [ ] Update log message to include worktree status

**Timing**: 10 minutes

**Files to modify**:
- `.claude/hooks/tts-notify.sh` - Modify message construction at lines 118-124

**Verification**:
- Script syntax valid (bash -n)
- Log output shows correct message

---

### Phase 3: Testing and Verification [COMPLETED]

**Goal**: Verify the implementation works in all scenarios

**Tasks**:
- [ ] Test in main session (not worktree): expect "Tab N"
- [ ] Test in worktree: expect "Tab N worker"
- [ ] Test outside git repo: expect "Tab" fallback
- [ ] Verify no performance regression

**Timing**: 5 minutes

**Files to modify**:
- None (testing only)

**Verification**:
- All three test scenarios produce expected output
- Script executes in reasonable time (<1 second)

## Testing & Validation

- [ ] Script syntax validation: `bash -n .claude/hooks/tts-notify.sh`
- [ ] Main session test: Run in nvim directory, hear "Tab N"
- [ ] Worktree test: Create worktree, run hook, hear "Tab N worker"
- [ ] Edge case test: Run outside git repo, hear "Tab" fallback
- [ ] Review log output in specs/tmp/claude-tts-notify.log

## Artifacts & Outputs

- `.claude/hooks/tts-notify.sh` - Modified script with worktree detection
- `specs/255_tts_worktree_worker_announcement/summaries/01_worktree-announcement-summary.md` - Execution summary

## Rollback/Contingency

If implementation causes issues:
1. Revert tts-notify.sh to previous version: `git checkout HEAD~1 -- .claude/hooks/tts-notify.sh`
2. The worktree detection is additive and does not modify existing logic flow
3. Setting `IS_WORKTREE=false` as default ensures fallback to existing behavior
