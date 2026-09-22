# Research Report: Task #239

**Task**: 239 - Add no-op Bash detection hook
**Started**: 2026-09-18T00:00:00Z
**Completed**: 2026-09-18T00:00:00Z
**Effort**: small (single new hook + registration + one test file)
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (agent-system/extensions/core/hooks/**,
agent-system/extensions/core/scripts/tests/**, merge-sources/settings-hooks.json,
manifest.json, context/patterns/external-process-wait.md,
context/standards/shell-script-testing.md)
**Artifacts**: specs/239_add_noop_bash_detection_hook/reports/01_noop_bash_detection_hook.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The codebase already has a settled shape for exactly this kind of hook: an advisory-only
  PostToolUse hook that inspects `tool_input`, never blocks, fails open, and injects a
  corrective `additionalContext` string pointing at a named doc. `hooks/validate-meta-write.sh`
  is the closest precedent (matcher-scoped, `set -euo pipefail` with guarded steps, plain
  `{}` JSON on the non-trigger path, non-blocking `additionalContext` cat-heredoc on the
  trigger path) and should be followed structurally.
- Per-session counter state has an established, non-`specs/` convention already in production:
  `.claude/tmp/workflow-active-<CC_SESSION_ID>` (see `hooks/claude-stop-notify.sh`,
  `hooks/events-log-lifecycle.sh`, `hooks/wezterm-preflight-status.sh`). The new hook's
  consecutive-trivial-command counter should live at
  `.claude/tmp/noop-bash-count-<CC_SESSION_ID>` (source-store path
  `agent-system/extensions/core/tmp/` resolved via `$SCRIPT_DIR/../tmp`), keyed off the
  stdin JSON's `.session_id` field the same way `claude-stop-notify.sh` reads it.
- No hook currently registers against the Bash tool for PostToolUse — every existing
  `settings-hooks.json` `PostToolUse` entry matches `"Write|Edit"`. The new hook needs its own
  matcher entry: `{"matcher": "Bash", "hooks": [...]}`, appended as a second array element to
  the existing `PostToolUse` list (deep_merge appends per-matcher, so this does not disturb the
  `Write|Edit` entry).
- `guard-destructive-git.sh` (a PreToolUse Bash hook) is the right model for safely reading
  `tool_input.command`: quote-and-comment-stripping before pattern matching, and
  `&&`/`;`/`|`-based segment splitting, are the established techniques for avoiding false
  positives when a trivial-looking token appears inside a larger, non-trivial command or a
  quoted string.
- Test placement precedent is exact: `guard-destructive-git.sh` (a `hooks/` script) is tested
  from `scripts/tests/test-guard-destructive-git.sh` — a fixture-driven suite that pipes a
  synthetic JSON payload on stdin to the hook run as a real subprocess and asserts on exit
  code / stdout, per `context/standards/shell-script-testing.md`. The new hook's test should
  follow the identical shape at `scripts/tests/test-detect-noop-bash.sh`, and both new files
  need `manifest.json` registration (`provides.hooks` and `provides.scripts`, the latter using
  the `tests/test-detect-noop-bash.sh` relative form already used for the ~90 other suites in
  that array).

## Context & Scope

Researched: how existing hooks in this repo implement (a) advisory-only, non-blocking
PostToolUse behavior, (b) per-session state outside `specs/`, (c) safe parsing of
`tool_input.command` for a Bash-tool hook, and (d) the test/registration conventions a new
hook + test pair must follow. No web research was needed — this is a self-contained,
codebase-pattern task with an already-written external reference doc
(`context/patterns/external-process-wait.md`) as the corrective-message target.

## Findings

### Codebase Patterns

**Advisory PostToolUse hook shape** (`agent-system/extensions/core/hooks/validate-meta-write.sh`):
- `set -euo pipefail` at top, but every stdin-derived extraction is individually guarded with
  `|| true` / `2>/dev/null` so a parse failure can never propagate to a nonzero exit.
- Reads stdin once (`INPUT=$(cat) || true`), then pulls fields via `jq -r '.tool_input.xxx // empty'`
  and `.session_id // empty`.
- Early-exits with bare `echo '{}'; exit 0` on every non-trigger path.
- On the trigger path, emits a single JSON object via a `cat << 'EOF' ... EOF` heredoc with an
  `additionalContext` string naming the specific corrective doc and stating "This is advisory
  only and does not block the write." Always ends `exit 0`.
- Registered in `merge-sources/settings-hooks.json` inside the existing `PostToolUse` /
  `"matcher": "Write|Edit"` array, and the outer wiring in `settings-hooks.json` always wraps
  the call as `bash .claude/hooks/X.sh 2>/dev/null || echo '{}'` — double defense against a
  hook crash breaking the tool call.
- Listed alphabetically in `manifest.json`'s `provides.hooks` array (currently: ...
  `claude-stop-notify.sh`, `events-log-artifact.sh`, `events-log-lifecycle.sh`,
  `guard-destructive-git.sh`, `log-session.sh`, `memory-nudge.sh`, `post-command.sh`,
  `subagent-postflight.sh`, `tts-notify.sh`, `validate-handoff-location.sh`,
  `validate-meta-write.sh`, `validate-no-task-references.sh`, `validate-plan-write.sh`,
  `validate-state-sync.sh`, `wezterm-*.sh` ...) — `detect-noop-bash.sh` sorts between
  `claude-stop-notify.sh` and `events-log-artifact.sh`.

**Per-session, non-`specs/` state** (`hooks/claude-stop-notify.sh`,
`hooks/events-log-lifecycle.sh`, `hooks/wezterm-preflight-status.sh`):
- Convention: `.claude/tmp/<purpose>-<CC_SESSION_ID>`, read/written via
  `$SCRIPT_DIR/../tmp/<name>-${CC_SESSION_ID}` after `mkdir -p "$SCRIPT_DIR/../tmp" 2>/dev/null || true`.
- `CC_SESSION_ID` is read from the hook's own stdin JSON: `jq -r '.session_id // empty'`.
- This is the correct model for the new hook's consecutive-count state — it is
  session-scoped (a fresh session starts a fresh streak), lives outside `specs/` per the
  dispatch's explicit constraint, and matches an existing, reviewed pattern rather than
  inventing a new one. Contrast with `hooks/memory-nudge.sh` and `hooks/tts-notify.sh`, which
  use a **global** cooldown file under `specs/tmp/` — not session-scoped and inside `specs/`,
  so NOT a model to copy here.

**Safe Bash-command parsing** (`hooks/guard-destructive-git.sh`, PreToolUse on Bash):
- Reads `tool_input.command` via the same `jq -r '.tool_input.command // empty'` pattern; empty
  command (non-Bash tool or parse failure) is an immediate allow/no-op.
- Before any pattern matching, strips quoted spans (`sed -z 's/"[^"]*"/""/g' ... "s/'[^']*'/''/g"`,
  slurp-mode via `-z` so multi-line quoted content is not missed) and then bash comments
  (`sed -e 's/\(^\|[[:space:]]\)#.*$//'`), producing a `COMMAND_SCAN` variable that every
  detector reads instead of the raw command. This prevents a trivial-looking token embedded in
  a quoted string or comment (e.g. a commit message containing the word `true`) from
  false-positiving.
- Splits into segments on `;`/`&`/`|` for multi-command detection
  (`grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+add[^;&|]*'`), matching each segment against a
  segment-scoped regex.
- This is directly reusable for the new hook: to classify a whole (possibly compound) command
  as "trivial no-op," strip quotes/comments the same way, split on `;`/`&&`/`||`/`|`, and
  require every segment to match one of the trivial forms (`:`, `true`, bare `date`/`date -u`
  with no redirection, `echo` with only literal — no `$(...)`, no bare `$VAR` — arguments and no
  redirection/pipe, and `sleep` fragments). A single non-trivial segment in an otherwise
  trivial-looking compound command must NOT count as trivial — this is the main
  false-positive risk this task calls out and the segment-driven design in
  `guard-destructive-git.sh` already solves it.

**Test convention** (`context/standards/shell-script-testing.md`,
`scripts/tests/test-guard-destructive-git.sh`):
- Narrow, single-script suites for a script under `hooks/` or `scripts/` live at
  `scripts/tests/test-<script-under-test>.sh`, even when the script under test itself lives in
  `hooks/` rather than `scripts/` — `test-guard-destructive-git.sh` is the exact precedent
  (tests `hooks/guard-destructive-git.sh`, itself lives in `scripts/tests/`).
- Structural convention: `set -uo pipefail`; `SCRIPT_DIR` resolved via
  `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`; `pass()`/`fail()`/`info()` helpers with
  `PASSED`/`FAILED` integer counters; a `mktemp -d` workdir with `trap cleanup EXIT`; drives the
  hook as a real subprocess (never instrumented/modified for testability) by piping a
  `jq`-constructed synthetic JSON payload on stdin; asserts on exit code and/or stdout; exits 0
  iff `FAILED` is 0.
- Registration: both the new hook (`provides.hooks`) and the new test file
  (`provides.scripts`, as `"tests/test-detect-noop-bash.sh"`, alongside the ~90 other entries
  already in that array, e.g. `"tests/test-guard-destructive-git.sh"` at line 183) must be added
  to `agent-system/extensions/core/manifest.json`.

### Settings Wiring

`agent-system/extensions/core/merge-sources/settings-hooks.json`'s `PostToolUse` key currently
holds exactly one array entry:

```json
"PostToolUse": [
  {
    "matcher": "Write|Edit",
    "hooks": [
      { "type": "command", "command": "bash .claude/hooks/validate-handoff-location.sh" },
      { "type": "command", "command": "bash .claude/hooks/validate-meta-write.sh 2>/dev/null || echo '{}'" },
      { "type": "command", "command": "bash .claude/hooks/events-log-artifact.sh 2>/dev/null || echo '{}'" }
    ]
  }
]
```

No `"matcher": "Bash"` PostToolUse entry exists anywhere in this repo's merge-sources today
(searched all `extensions/*/merge-sources/*.json`). The new hook needs a **second array
element** in this `PostToolUse` list:

```json
{
  "matcher": "Bash",
  "hooks": [
    { "type": "command", "command": "bash .claude/hooks/detect-noop-bash.sh 2>/dev/null || echo '{}'" }
  ]
}
```

`manifest.json`'s own inline comment on this merge source already documents that deep_merge
appends array entries per-matcher rather than merging into an existing `"*"`/other-matcher
entry — so adding a distinct `"Bash"` matcher entry is exactly the sanctioned shape, not a
special case.

### External Resources

None needed — `context/patterns/external-process-wait.md` (already committed, dated
2026-09-18, same day as this task) is the exact target doc the corrective `additionalContext`
message must name. Its "Required Rules" section (bounded blocking wait, no no-op filler, no
background/Monitor for CI waits inside a subagent, state-change-only Monitor emission,
do independent work first, ~45-minute total-wait cap) is the content the hook's message should
point a dispatched agent toward once the threshold fires.

### Recommendations

1. **New file**: `agent-system/extensions/core/hooks/detect-noop-bash.sh` — PostToolUse hook,
   matched only against `Bash` tool calls via the settings-hooks.json matcher (the hook itself
   may still defensively check `.tool_name == "Bash"` from stdin, mirroring how
   `validate-meta-write.sh` gates on a derived `FILE` value even though its matcher already
   scopes it to `Write|Edit`).
2. **Classification** (whole-command, segment-aware, using the
   quote/comment-strip + `;`/`&&`/`||`/`|`-split technique from `guard-destructive-git.sh`):
   a command is "trivial no-op" iff every segment is one of:
   - `:` (bare colon)
   - `true`
   - bare `date` or `date -u` with no arguments beyond `-u`, no redirection, no pipe consuming
     its output for a real purpose
   - `echo` whose arguments are pure literal text (no `$(...)`, no bare `$VAR`/`${VAR}`
     expansion, no redirection, no pipe) — this is the main false-positive-avoidance surface
     named in the dispatch ("avoid false positives on legitimate one-off echo/date use"); a
     conservative implementation only needs to fire on the exact filler shapes from the
     incident (`echo waiting`, `echo "waiting for CI"`, etc.), not attempt to catch every
     conceivable literal-echo call, since a false NEGATIVE here is harmless (worst case: one
     real no-op sequence goes uncounted) while a false POSITIVE on legitimate output is the
     defect to avoid.
   - `sleep` (a bare `sleep N` fragment, or `sleep N` as one segment of a compound command) —
     included per the dispatch even though the harness already blocks a plain foreground
     `sleep`; the hook should still count it as trivial so a `sleep 5 && echo waiting`-shaped
     compound command is recognized as 100% filler.
3. **Counter state**: `.claude/tmp/noop-bash-count-<CC_SESSION_ID>` containing a bare integer.
   On a trivial classification, increment (create at 1 if absent). On ANY non-trivial
   classification, delete the file / reset to 0. `CC_SESSION_ID` from stdin's `.session_id`
   field; if absent, fail open (skip counting entirely rather than guessing a session key,
   mirroring the `[ -z "$FILE" ] && exit 0` early-exit shape elsewhere).
4. **Threshold behavior**: dispatch says "about 3 in a row" triggers the message. Two
   defensible designs, left for the planning phase to pick explicitly (this is a genuine
   design choice, not settled by precedent):
   - Fire the `additionalContext` message every time the counter is `>= 3` (simplest;
     advisory-only means repetition is low-risk, and it directly mirrors "reset the counter on
     any non-trivial command" being the only de-escalation path).
   - Fire only when the counter first reaches a multiple of 3 (`count == 3`, `count == 6`, ...)
     to reduce repeated-message noise across a long no-op streak, echoing
     `memory-nudge.sh`'s "prevent nudge fatigue" cooldown rationale (though that hook uses a
     time cooldown, not a modulo-count one).
5. **Fail-open discipline**: every stdin/jq extraction guarded with `|| true`/`2>/dev/null`;
   every file read/write guarded the same way; the script always ends `exit 0`; the
   settings-hooks.json wiring additionally wraps the call with `2>/dev/null || echo '{}'` per
   existing convention (belt-and-suspenders, matching every other advisory hook's
   registration).
6. **Message content**: name `context/patterns/external-process-wait.md` explicitly and
   summarize the bounded-wait idiom (inner `timeout` below the harness's Bash-tool ceiling,
   paired status re-check, no no-op filler, no background/Monitor from inside a subagent),
   using `validate-meta-write.sh`'s heredoc-JSON-with-advisory-disclaimer shape as the literal
   template.
7. **Manifest + settings registration**: add `"detect-noop-bash.sh"` to
   `manifest.json`'s `provides.hooks` array (alphabetically, between `claude-stop-notify.sh`
   and `events-log-artifact.sh`); add `"tests/test-detect-noop-bash.sh"` to
   `provides.scripts`; add the new `"matcher": "Bash"` `PostToolUse` entry to
   `merge-sources/settings-hooks.json` as shown above.
8. **Test file**: `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh`,
   structurally identical to `test-guard-destructive-git.sh` (same helpers, same
   `mktemp -d`/`trap` discipline, same "drive the hook as a real subprocess, pipe a
   `jq`-built synthetic PostToolUse payload, assert on stdout JSON and on the counter file's
   contents/absence" approach). Minimum coverage per the dispatch: classification (each
   trivial form individually, plus at least one compound trivial command, plus at least one
   compound command with one non-trivial segment that must NOT count), threshold (counter
   reaches the configured value and the `additionalContext` message appears, naming
   `external-process-wait.md`), and reset (a non-trivial command after a partial streak zeroes
   the counter, verified by a subsequent trivial command starting back at 1 rather than
   continuing the old streak).
9. **shellcheck clean**: run `shellcheck agent-system/extensions/core/hooks/detect-noop-bash.sh`
   before considering the implementation phase done; existing hooks use targeted
   `# shellcheck disable=SC1090`-style directives only where genuinely needed (dynamic
   `source`), not blanket suppression — follow that precedent rather than disabling checks
   broadly.

## Decisions

- Counter state path: `.claude/tmp/noop-bash-count-<CC_SESSION_ID>`, following the
  `claude-stop-notify.sh`/`events-log-lifecycle.sh` per-session-marker precedent rather than
  the `specs/tmp/`-based global-cooldown precedent (`memory-nudge.sh`/`tts-notify.sh`), because
  the dispatch explicitly requires session-scoped state "never under specs/".
- Test file location: `scripts/tests/test-detect-noop-bash.sh`, matching the exact precedent of
  `guard-destructive-git.sh` (a `hooks/`-resident script tested from `scripts/tests/`), not a
  new `hooks/tests/` directory (no such directory exists anywhere in this codebase).
- Command-parsing technique: reuse `guard-destructive-git.sh`'s quote/comment-strip +
  segment-split approach rather than inventing a new one, since it is the only existing,
  reviewed precedent for safely pattern-matching `tool_input.command` text without
  false-positiving on quoted/commented content.

## Risks & Mitigations

- **False positives on legitimate echo/date use**: mitigated by requiring *pure literal*
  `echo` arguments (no expansion, no redirection/pipe) and *bare* `date`/`date -u` (no
  redirection) — a real diagnostic `echo "Elapsed: $SECONDS"` or `date >> logfile` never
  matches. See Recommendation 2 above.
- **Compound commands with one non-trivial segment miscounted as trivial**: mitigated by the
  segment-split-and-require-all-trivial design (Recommendation 2), directly modeled on
  `guard-destructive-git.sh`'s segment handling rather than a whole-string regex.
- **Cross-task file-scope overlap**: this task's territory context (see dispatch) lists a
  concurrent sibling, task 238, whose declared `file_scope` includes
  `agent-system/extensions/core/scripts/tests/` at **directory** granularity — the same
  directory this task's new test file (`test-detect-noop-bash.sh`) lands in. Per the
  Cross-Task Territory contract, the implementation phase must re-read the directory
  immediately before committing, stage and commit only this task's own new file (never a
  directory-level `git add`), and treat any unexpected foreign change there as a possible
  in-flight sibling edit rather than a regression of this task's own work.
- **`manifest.json` and `merge-sources/settings-hooks.json` are shared, frequently-touched
  files**: both are plain JSON edits (append one array element / one string), which keeps the
  diff surface minimal and easy to re-read-and-reconcile if a sibling task touches the same
  file concurrently (task 237's declared scope is two `agents/*.md` files and does not overlap
  either of these).

## Context Extension Recommendations

- **Topic**: hook-authoring convention (PostToolUse/PreToolUse advisory hooks: stdin JSON
  shape, fail-open discipline, `additionalContext` vs. blocking exit-2, per-session state
  location).
- **Gap**: `.claude/context/index.json` has no `hooks`-subdomain entry and no dedicated
  "how to write a new Claude Code hook in this repo" doc — the convention currently exists only
  as scattered header comments across `validate-meta-write.sh`, `guard-destructive-git.sh`,
  and `claude-stop-notify.sh`, each independently reconstructable but not indexed together.
- **Recommendation**: a future task could extract a
  `context/guides/hook-authoring.md` (or similar) distilling: stdin JSON field names
  (`session_id`, `tool_input.*`, `tool_name`, `agent_id`), the fail-open/`echo '{}'`
  convention, the `.claude/tmp/<purpose>-<CC_SESSION_ID>` per-session-state pattern vs. the
  `specs/tmp/`-based global-cooldown pattern (and when each is appropriate), and the
  matcher/`manifest.json`/`settings-hooks.json` three-point registration checklist. Not
  created here — out of scope for this task's advisory hook itself.

## Appendix

### Search queries / commands used

- `find agent-system/extensions/core/hooks -maxdepth 1 -type f`
- `cat hooks/validate-meta-write.sh`
- `cat hooks/memory-nudge.sh`, `sed -n '1,60p' hooks/guard-destructive-git.sh` (+ later ranges)
- `cat merge-sources/settings-hooks.json`
- `grep -n "validate-meta-write\|hooks" manifest.json`
- `find . -iname "external-process-wait.md"`; full read of that file
- `ls scripts/tests/ | grep -i hook`; `ls scripts/tests/ | grep -i guard`
- `Read scripts/tests/test-guard-destructive-git.sh` (first 120 lines)
- `find . -iname "shell-script-testing.md"` + read
- `grep -n "test-guard-destructive-git\|scripts/tests" manifest.json`
- `grep -rn "shellcheck" scripts/*.sh hooks/*.sh`
- `grep -rln "\"matcher\": \"Bash\"" extensions/*/merge-sources/*.json` (no hits)
- `jq -r '.entries[] | select(.subdomain=="hooks") | .topics[]?' .claude/context/index.json`
  (no hits — informs the Context Extension Recommendation above)

### References

- `agent-system/extensions/core/hooks/validate-meta-write.sh` — primary structural precedent
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` — command-parsing precedent
- `agent-system/extensions/core/hooks/claude-stop-notify.sh`,
  `agent-system/extensions/core/hooks/events-log-lifecycle.sh` — per-session state precedent
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` — test-shape
  precedent
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — test-location and
  helper-naming convention
- `agent-system/extensions/core/merge-sources/settings-hooks.json` — hook registration wiring
- `agent-system/extensions/core/manifest.json` — `provides.hooks` / `provides.scripts` arrays
- `agent-system/extensions/core/context/patterns/external-process-wait.md` — corrective-message
  target doc
