# Implementation Plan: Task #239

- **Task**: 239 - Add no-op Bash detection hook
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/239_add_noop_bash_detection_hook/reports/01_noop_bash_detection_hook.md
- **Artifacts**: plans/01_noop-bash-detection-hook.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add an advisory-only PostToolUse hook, `hooks/detect-noop-bash.sh`, that classifies trivial
no-op Bash commands (`:`, `true`, bare `date`/`date -u`, pure-literal `echo`, `sleep N`
fragments), tracks consecutive occurrences per Claude Code session outside `specs/`, and after
3 in a row injects an `additionalContext` message pointing at
`context/patterns/external-process-wait.md` and its bounded-wait idiom. The hook never blocks,
fails open on any internal error, and resets on any non-trivial command. It is registered in
`merge-sources/settings-hooks.json` (new `"Bash"` PostToolUse matcher entry) and in
`manifest.json`, and has a fixture-driven test suite. All edits land in the source store
`agent-system/extensions/core/`, never `.claude/**`.

### Research Integration

The research report settles almost every design point and this plan adopts them all:
structural template `hooks/validate-meta-write.sh` (guarded jq extraction, `echo '{}'` on
non-trigger paths, heredoc JSON with advisory disclaimer, `exit 0`); command parsing reused from
`hooks/guard-destructive-git.sh` (quote-strip, comment-strip, split on `;`/`&&`/`||`/`|`,
require EVERY segment trivial); per-session state following the
`.claude/tmp/<purpose>-<CC_SESSION_ID>` precedent of `claude-stop-notify.sh`; test at
`scripts/tests/test-detect-noop-bash.sh` shaped like `test-guard-destructive-git.sh`; manifest
entries in `provides.hooks` (between `claude-stop-notify.sh` and `events-log-artifact.sh`) and
`provides.scripts` (`tests/test-detect-noop-bash.sh`).

### Decisions (planner-resolved)

1. **Threshold firing rule** (the one choice research left open): fire when the counter reaches
   3, then again every 3 further trivial calls (`count >= 3 && (count - 3) % 3 == 0`, i.e. 3, 6,
   9, ...). Rationale: a single message at 3 can be ignored in a 130-call streak, while firing on
   every call from 3 onward adds message noise to each filler turn. Threshold defaults to 3 and
   is overridable via `NOOP_BASH_THRESHOLD` (validated as a positive integer, else default).
2. **State-directory override for testability**: the state dir defaults to `$SCRIPT_DIR/../tmp`
   (which resolves to `.claude/tmp` in the deploy tree) but honors `NOOP_BASH_STATE_DIR` when
   set. Verified during planning: `agent-system/extensions/core/tmp/` does not exist and is NOT
   gitignored, so a test that ran the hook from the source store without the override would
   create untracked stray files there. The test MUST set `NOOP_BASH_STATE_DIR` to its own
   `mktemp -d` workdir.
3. **Missing `session_id`**: fail open, no counting, emit `{}` (do not invent a session key).
4. **Echo conservatism**: `echo` counts as trivial only when its arguments contain no `$`,
   backtick, `>`/`<` redirection, or glob characters after quote-stripping, and it is not piped
   into another command. A false negative is harmless; a false positive is the defect to avoid.
   `date` counts only as bare `date` or `date -u` (no `+FORMAT` argument, per the dispatch's
   "bare `date`/`date -u`"). `sleep` counts only as `sleep <number>`
   (optionally with an `s`/`m` suffix).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context provided for this dispatch.

## Goals & Non-Goals

**Goals**:
- Detect runs of 3+ consecutive trivial no-op Bash calls per session and inject a corrective,
  advisory message naming `context/patterns/external-process-wait.md`.
- Zero blocking, zero false positives on legitimate compound or expanding `echo`/`date` use.
- Test coverage for classification, threshold, reset, and fail-open paths; shellcheck clean.
- Registration in `merge-sources/settings-hooks.json` and `manifest.json`.

**Non-Goals**:
- Blocking or rate-limiting any command (advisory only).
- Detecting status-only text turns (no hook surface for those) or Monitor-wake storms.
- Editing `context/patterns/external-process-wait.md` or any agent file (sibling task territory
  covers `agents/general-*.md`).
- A general hook-authoring guide (research's Context Extension Recommendation; separate task).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| False positive on legitimate `echo`/`date` | M | M | Segment-level all-trivial rule; strict literal-echo and bare-date patterns; explicit negative test cases |
| Hook error breaks Bash tool calls | H | L | Guarded extraction, always `exit 0`, settings wiring `2>/dev/null \|\| echo '{}'` |
| Test writes stray state into source store | M | M | `NOOP_BASH_STATE_DIR` override; test asserts nothing was created under `agent-system/extensions/core/tmp` |
| Sibling task edits `scripts/tests/` concurrently (directory-scoped territory) | M | M | Re-read before edit; stage only `test-detect-noop-bash.sh` by explicit path; never directory adds |
| Concurrent edits to `manifest.json` / `settings-hooks.json` | M | L | Re-read immediately before editing; minimal single-element insertions; stage explicit paths only |
| Counter race between parallel Bash calls in one session | L | L | Advisory only; last-writer-wins is acceptable; write via temp file + `mv` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Implement detect-noop-bash.sh hook [COMPLETED]

**Goal**: Create the advisory PostToolUse hook with classification, per-session counter,
threshold message, and fail-open behavior.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/hooks/validate-meta-write.sh` and the
      quote/comment-strip + segment-split section of `hooks/guard-destructive-git.sh` *(completed)*
- [x] Create `agent-system/extensions/core/hooks/detect-noop-bash.sh` (executable) with a header
      comment describing purpose, advisory-only contract, state location, env overrides
      *(completed)*
- [x] Read stdin once (`INPUT=$(cat) || true`); extract `.tool_name`, `.tool_input.command`,
      `.session_id` via guarded `jq`; if `jq` missing, tool is not `Bash`, command empty, or
      session id empty/unsafe (restrict to `[A-Za-z0-9_-]`), print `{}` and exit 0 *(completed)*
- [x] Implement `is_trivial_command`: strip quoted spans and comments (guard-destructive-git
      technique), reject if any `$`, backtick, `>`, `<`, `(`, or here-doc marker remains, split on
      `&&`, `||`, `;`, `|`, `&`, trim each segment, and require every non-empty segment to match
      one of: `:`, `true`, `date`, `date -u`, `sleep <N>[smh]?`, `echo`/`echo -n` followed only by
      literal words; a pipe into anything is non-trivial (only pipes between trivial segments are
      tolerated, and a pipe whose right side is non-trivial fails the all-trivial rule anyway)
      *(completed: the `$`/backtick/`>`/`<`/`(` reject scan runs on the raw, non-quote-blanked
      text -- deliberately, since e.g. `echo "$SECONDS"` must be rejected even though the `$` sits
      inside quotes; only segment splitting uses a simple, documented non-quote-aware split, whose
      only failure mode is an extra, safe-direction "non-trivial" verdict)*
- [x] Counter: state file `${NOOP_BASH_STATE_DIR:-$SCRIPT_DIR/../tmp}/noop-bash-count-<sid>`;
      `mkdir -p` guarded; on trivial, read integer (non-integer treated as 0), increment, write via
      temp file + `mv`; on non-trivial, `rm -f` the state file and print `{}` *(completed)*
- [x] Threshold: `NOOP_BASH_THRESHOLD` (positive integer, default 3); when
      `count >= T && (count - T) % T == 0`, emit a single JSON object (built with `jq -n --arg`
      so the count is interpolated safely) whose `hookSpecificOutput.additionalContext` (match the
      exact output key shape `validate-meta-write.sh` uses) states: N consecutive no-op Bash calls
      detected; see `context/patterns/external-process-wait.md`; use a single bounded blocking
      wait (`timeout` below the Bash-tool ceiling paired with a status re-check), do independent
      work first, never fill waits with `:`/`true`/`date`/`echo` filler, never background/Monitor a
      CI wait from inside a subagent; "This is advisory only and does not block." *(completed:
      used the flat top-level `additionalContext` key, matching validate-meta-write.sh's own
      exact output shape, per the parenthetical instruction to match that precedent)*
- [x] Wrap all logic so any failure path prints `{}` and exits 0 (use `set -uo pipefail`
      without `-e`, or `-e` with every risky step guarded, matching precedent) *(completed: used
      `set -euo pipefail` with every risky command guarded via `|| true`/`|| fallback`, matching
      validate-meta-write.sh/guard-destructive-git.sh precedent)*
- [x] Run `shellcheck` on the new hook; fix all findings without blanket disables *(completed:
      one SC2034 unused-variable finding fixed by removing the unused declaration; zero
      disables used)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/hooks/detect-noop-bash.sh` - new file

**Verification**:
- `shellcheck agent-system/extensions/core/hooks/detect-noop-bash.sh` exits 0
- Manual smoke: pipe three `{"tool_name":"Bash","session_id":"t1","tool_input":{"command":"true"}}`
  payloads with `NOOP_BASH_STATE_DIR` set to a scratch dir; third emits the message, first two
  emit `{}`; a malformed stdin payload emits `{}` with exit 0

---

### Phase 2: Add test suite test-detect-noop-bash.sh [COMPLETED]

**Goal**: Fixture-driven test covering classification, threshold, reset, and fail-open, driving
the hook as a real subprocess.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` header
      and `context/standards/shell-script-testing.md`; re-list `scripts/tests/` (sibling territory)
      *(completed)*
- [x] Create `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` (executable):
      `set -uo pipefail`, `SCRIPT_DIR`, `HOOK="$SCRIPT_DIR/../../hooks/detect-noop-bash.sh"`,
      `pass`/`fail`/`info` helpers, `mktemp -d` workdir + `trap cleanup EXIT`, export
      `NOOP_BASH_STATE_DIR` to the workdir, `run_hook <session> <command>` helper building the
      payload with `jq -n --arg` *(completed)*
- [x] Classification positives (each in a fresh session, count file == 1 afterward): `:`,
      `true`, `date`, `date -u`, `echo waiting`, `echo "waiting for CI"`, `sleep 30`,
      `sleep 5 && echo waiting`, `true; date -u` *(completed)*
- [x] Classification negatives (count file absent afterward): `echo "Elapsed: $SECONDS"`,
      `echo $(gh run view 1)`, `echo done > log.txt`, `date >> log`, `date +%s`,
      `sleep 5 && gh run view 1`, `echo x | tee f`, `git status`, `true && make test`,
      a command whose quoted string contains `true` (e.g. `git commit -m "true"`) *(completed)*
- [x] Threshold: 2 trivial calls -> stdout is `{}` both times; 3rd -> stdout contains
      `external-process-wait.md` and is valid JSON (`jq -e .`); 4th and 5th -> `{}`; 6th -> message
      *(completed)*
- [x] Reset: 2 trivial, 1 non-trivial (state file removed), then 1 trivial -> count == 1 and
      no message on the next 2nd call *(completed)*
- [x] Session isolation: streak in session A does not affect session B's count *(completed)*
- [x] Fail-open: empty stdin, non-JSON stdin, non-Bash `tool_name`, missing `session_id`,
      unwritable state dir -> exit 0 and stdout `{}` *(completed)*
- [x] `NOOP_BASH_THRESHOLD=2` override fires on the 2nd call; invalid value falls back to 3
      *(completed: also added a `NOOP_BASH_THRESHOLD=0` case beyond the plan's hypothesis, to
      confirm the fallback covers the zero/negative edge, not just non-numeric strings)*
- [x] Assert `agent-system/extensions/core/tmp` was not created by the run *(completed)*
- [x] Exit 0 iff `FAILED == 0`; run `shellcheck` on the test file *(completed: fixed two SC2016
      info findings with narrowly-scoped, justified disables for intentionally-literal
      single-quoted test data, and converted four `&&`/`||` one-liners flagged by SC2015 to
      explicit if/then/else, matching test-guard-destructive-git.sh's own style)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: roughly 30 assertions across the case groups above; the exact list is a
hypothesis — the implementer may add cases where Phase 1 edge behavior warrants it, confirmed
by the suite's final PASSED count.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` - new file

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` exits 0, all pass
- `shellcheck` clean on the test file
- `git status --short agent-system/extensions/core/` shows only this task's new files (no stray
  `tmp/`)

---

### Phase 3: Register hook in settings-hooks.json and manifest.json [COMPLETED]

**Goal**: Wire the hook into the deploy so it fires on every Bash PostToolUse, and register both
new files in the manifest.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/merge-sources/settings-hooks.json` and
      `agent-system/extensions/core/manifest.json` immediately before editing (shared files)
      *(completed: confirmed no sibling-task changes since the earlier read this dispatch)*
- [x] Append a second element to the `PostToolUse` array:
      `{"matcher": "Bash", "hooks": [{"type": "command", "command": "bash .claude/hooks/detect-noop-bash.sh 2>/dev/null || echo '{}'"}]}`
      *(completed)*
- [x] Add `"detect-noop-bash.sh"` to `provides.hooks` between `claude-stop-notify.sh` and
      `events-log-artifact.sh` *(completed)*
- [x] Add `"tests/test-detect-noop-bash.sh"` to `provides.scripts` in the sorted position near
      the other `tests/test-*` entries *(completed: inserted between
      `tests/test-deploy-verify-wiring.sh` and `tests/test-double-loading-check.sh`,
      alphabetically correct)*
- [x] Validate both files parse: `jq empty` on each *(completed)*
- [x] Locate and run any existing manifest/settings consistency test in `scripts/tests/` (e.g.
      grep for `provides.hooks` or `settings-hooks.json` in test files) and confirm it passes
      *(completed: no dedicated `provides.hooks`/`settings-hooks.json` grep hit under
      `scripts/tests/`; ran the closest wiring-adjacent suites,
      `test-deploy-verify-wiring.sh` (20/20) and `test-double-loading-check.sh` (16/16), both
      pass)*
- [x] Commit with explicit file paths only (`git add -- <each file>`), message
      `task 239 phase 3: register detect-noop-bash hook` *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Scope Hypothesis**: exactly two files change (`settings-hooks.json`, `manifest.json`), each by a
single inserted element/entry; confirm via `git diff --stat` on those two paths.

**Files to modify**:
- `agent-system/extensions/core/merge-sources/settings-hooks.json` - new `Bash` PostToolUse entry
- `agent-system/extensions/core/manifest.json` - `provides.hooks` and `provides.scripts` entries

**Verification**:
- `jq empty` succeeds on both files
- `jq '.hooks.PostToolUse[] | select(.matcher=="Bash")' merge-sources/settings-hooks.json` returns
  the new entry (adjust path to actual top-level key after re-read)
- Any manifest/hook-registration consistency test passes; the new test suite still passes
- No `.claude/**` file was hand-edited

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` passes
- [ ] `shellcheck` clean on hook and test
- [ ] `jq empty` on `settings-hooks.json` and `manifest.json`
- [ ] Existing hook test `scripts/tests/test-guard-destructive-git.sh` still passes (sanity that
      shared parsing idioms were copied, not modified)
- [ ] No task-number references in any deliverable file (`check-task-references.sh` if present)
- [ ] No stray files under `agent-system/extensions/core/tmp/`

## Artifacts & Outputs

- `agent-system/extensions/core/hooks/detect-noop-bash.sh`
- `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh`
- Modified `agent-system/extensions/core/merge-sources/settings-hooks.json`
- Modified `agent-system/extensions/core/manifest.json`
- `specs/239_add_noop_bash_detection_hook/summaries/01_noop-bash-detection-hook-summary.md`

## Rollback/Contingency

All changes are two new files plus two single-element JSON insertions, each committed per phase.
Revert with `git revert <commit>` for the relevant phase commit(s). If the hook misbehaves after
deploy, removing the `"Bash"` PostToolUse entry from `settings-hooks.json` disables it without
touching the script. For any rollback of uncommitted work, follow
`context/contracts/recovery.md`'s rollback rung; never run a default-mode `git-snapshot.sh` as a
routine checkpoint.
