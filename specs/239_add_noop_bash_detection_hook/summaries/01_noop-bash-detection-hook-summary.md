# Implementation Summary: Task #239

- **Task**: 239 - Add no-op Bash detection hook
- **Status**: [COMPLETED]
- **Started**: 2026-09-19T01:30:00Z
- **Completed**: 2026-09-19T02:10:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_noop-bash-detection-hook.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added `hooks/detect-noop-bash.sh`, an advisory-only PostToolUse hook that classifies trivial
no-op Bash commands (`:`, `true`, bare `date`/`date -u`, a pure-literal `echo`, `sleep <N>[smh]?`)
and, after 3 consecutive occurrences per Claude Code session (repeating every 3 further calls),
injects an `additionalContext` message pointing at `context/patterns/external-process-wait.md`.
The hook never blocks and fails open on any internal error. A 40-assertion fixture-driven test
suite exercises classification, threshold, reset, session isolation, and every fail-open path;
both the hook and the test are registered in the deploy manifest and hook wiring.

## What Changed

- `agent-system/extensions/core/hooks/detect-noop-bash.sh` — new advisory PostToolUse hook:
  quote-visible whole-command scan for `$`/backtick/`>`/`<`/`(` (rejects even inside quotes, so
  `echo "$SECONDS"` is correctly non-trivial), non-quote-aware segment split on `&&`/`||`/`;`/`|`/
  `&` (a documented, safe-direction blind spot), per-session counter file under
  `${NOOP_BASH_STATE_DIR:-$SCRIPT_DIR/../tmp}`, `NOOP_BASH_THRESHOLD` override (falls back to 3
  on any non-positive-integer value).
- `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` — new 40-assertion suite
  covering 9 classification positives, 10 classification negatives, the 3/6 threshold-repeat
  behavior, reset-on-non-trivial, session isolation, 5 fail-open paths (empty stdin, non-JSON
  stdin, non-`Bash` `tool_name`, missing `session_id`, unwritable state dir), threshold override
  (valid, non-numeric, and zero), and a check that no stray directory is created under the
  source store's own `tmp/`.
- `agent-system/extensions/core/merge-sources/settings-hooks.json` — added a second `PostToolUse`
  array element: `{"matcher": "Bash", "hooks": [...detect-noop-bash.sh...]}`.
- `agent-system/extensions/core/manifest.json` — added `"detect-noop-bash.sh"` to `provides.hooks`
  (between `claude-stop-notify.sh` and `events-log-artifact.sh`) and
  `"tests/test-detect-noop-bash.sh"` to `provides.scripts` (between
  `tests/test-deploy-verify-wiring.sh` and `tests/test-double-loading-check.sh`).

## Decisions

- Threshold fires at the configured value and repeats every `threshold` further consecutive
  trivial calls (`count >= T && (count - T) % T == 0`), per the plan's resolved design point.
- The `$`/backtick/`>`/`<`/`(` reject scan reads the raw (non-quote-blanked) command text,
  deliberately differing from `guard-destructive-git.sh`'s quote-blanking technique: an echo
  argument's quoted content is what would actually be printed/expanded, so it must stay visible
  to the scan (unlike `guard-destructive-git.sh`'s free-text-commit-message problem, where hiding
  quoted content is the correct behavior).
- Segment splitting is intentionally not quote-aware; this is a documented, safe-direction blind
  spot (it can only ever push a segment toward "non-trivial", never the reverse), consistent with
  the plan's decision that a false negative is harmless while a false positive is the defect to
  avoid.
- Used the flat top-level `additionalContext` JSON key (matching `validate-meta-write.sh`'s own
  exact output shape) rather than a nested `hookSpecificOutput.additionalContext` shape.

## Plan Deviations

- **Task 2.7** (`NOOP_BASH_THRESHOLD=2` / invalid-value test) altered: added an extra
  `NOOP_BASH_THRESHOLD=0` case beyond the plan's literal wording, to confirm the zero/negative
  edge falls back to the default of 3 as well, not just non-numeric strings.
- All other tasks completed as planned; final assertion count (40) exceeds the plan's "roughly
  30" scope hypothesis, which the plan explicitly anticipated as an implementer option.

## Verification

- Build: N/A (shell scripts)
- Tests: Passed — `test-detect-noop-bash.sh` 40/40; `test-guard-destructive-git.sh` 50/50 (sanity,
  unaffected); `test-deploy-verify-wiring.sh` 20/20; `test-double-loading-check.sh` 16/16
- Files verified: Yes
- `shellcheck` clean on both new files (zero disables in the hook; two narrowly-scoped,
  documented `SC2016` disables in the test file for intentionally-literal single-quoted test
  data)
- `jq empty` succeeds on both `settings-hooks.json` and `manifest.json`
- `check-task-references.sh` reports 0 unexempted occurrences under
  `agent-system/extensions/core`
- No stray directory created under `agent-system/extensions/core/tmp`

## Impacts

- Every Bash tool call across every Claude Code session now passes through this hook
  (`2>/dev/null || echo '{}'`-wrapped, so any hook failure is invisible to the caller). It adds a
  small, bounded amount of work (jq parse + string scan) per Bash call but performs no I/O beyond
  a small per-session counter file except when the trivial-streak threshold fires.
- Provides the corrective nudge (naming the bounded-wait idiom) after 3 consecutive filler calls
  instead of the ~130 observed in the motivating incident, without blocking or altering any Bash
  call's actual execution.

## Follow-ups

- None. The plan's stated non-goals (editing `external-process-wait.md`, blocking/rate-limiting,
  detecting status-only text turns or Monitor-wake storms, a general hook-authoring guide) remain
  out of scope by design.

## References

- `specs/239_add_noop_bash_detection_hook/plans/01_noop-bash-detection-hook.md`
- `specs/239_add_noop_bash_detection_hook/reports/01_noop_bash_detection_hook.md`
- `agent-system/extensions/core/hooks/detect-noop-bash.sh`
- `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh`
