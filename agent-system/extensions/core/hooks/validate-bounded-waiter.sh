#!/usr/bin/env bash
# validate-bounded-waiter.sh
# PreToolUse hook (matcher "Bash"): BLOCKS a command that conjoins a wait-loop construct with a
# process-name-matching liveness test -- the "self-match waiter" shape forbidden by
# context/patterns/bounded-build-waiter.md's Rule 2 ("never use ps | grep, pgrep -f, or any
# process-name-matching test").
#
# Motivating incident (re-confirmed, not re-derived): a dispatched agent wrote
#   until ! pgrep -f 'distsys/check.sh' >/dev/null 2>&1; do sleep 20; done
# twice, with Rule 2 live and reachable in its own reference chain. `pgrep -f` matches full
# command lines, and the watcher's own `bash -c` argv contains the literal pattern it searches
# for -- `pgrep` excludes only itself, never its parent shell, so each watcher matched itself (and,
# with two running, each other) and neither ever resolved. One spun 17 minutes on an already-exited
# gate process before an operator killed it by hand. Documentation-as-prohibition had already
# failed for this exact command shape, which is why this hook exists: mechanical teeth, not a
# sixth restatement of Rule 2.
#
# Structural model: hooks/guard-destructive-git.sh, NOT hooks/detect-noop-bash.sh. The latter is
# PostToolUse, advisory-only, and exits 0 unconditionally -- it structurally cannot block.
# guard-destructive-git.sh (and hooks/validate-no-task-references.sh, the closer single-hazard
# precedent this file actually follows) is PreToolUse, matcher "Bash", blocks via exit code 2 +
# a stderr message -- NEVER `permissionDecision: deny`, which is documented-buggy for
# allow-listed Bash tool calls -- and fails OPEN on every internal error: a broken guard that
# blocks every Bash call in the repo is a worse outcome than no guard at all. Registered BARE
# (no `2>/dev/null || echo '{}'` wrapper): that wrapper converts exit 2 into exit 0 and silently
# disables the block.
#
# --- The blocking conjunction (all three legs required) ---
#   (a) a loop construct: the `until` or `while` keyword;
#   (b) a `sleep` call;
#   (c) a name-match liveness test: `pgrep` at a word boundary (any flags, or none -- see
#       "bare-word ruling" below), OR a `ps` invocation piped into `grep`.
# The narrow three-way conjunction is what makes this mechanically safe to block: a bare `pgrep`,
# a bare `ps aux | grep`, or a name-match in a one-shot conditional outside a loop legitimately
# stays legal (diagnostic uses the orchestrator's own tooling performs), because at least one leg
# is always absent. A false positive here is treated as worse than no hook.
#
# --- Bare-word ruling (deliberate, stricter than a flag-narrowed match) ---
# Leg (c)'s `pgrep` test matches the bare token with ANY flags or none -- it is NOT narrowed to a
# `-f`/`--full` flag check. Rule 2's own text forbids "any process-name-matching test", the
# three-way conjunction already supplies all the false-positive safety needed, and a bare-word
# match makes every flag-clustering variant (`-af`, `-fa`, `-x -f`, `--full`, no flags at all) a
# non-issue by construction instead of an enumerated flag list that must be kept current.
#
# --- The [b]racket variant blocks by construction (no special case) ---
# This hook does NOT inspect the contents of the `grep` pattern. `bounded-build-waiter.md` is
# explicit that the bracket trick (`grep '[b]ash check.sh'`) does not fix the self-match: it stops
# GREP matching itself in `ps aux | grep <pattern>`'s own process listing, but it does nothing
# about the watcher's PARENT SHELL, whose argv still contains the literal `pgrep`/`ps`/loop text
# and which the liveness test can still match. A hook that treated the bracket form as safe would
# reproduce the exact bug it exists to stop. Leg (c)'s `ps`-piped-into-`grep` test matches
# regardless of what the grep pattern contains, so the bracket variant is covered with no extra
# logic.
#
# --- No exemption for kill -0 ---
# The presence of `kill -0` in a command grants NO exemption: a command carrying both `kill -0`
# and a name-match test inside a loop still blocks. `kill -0` is the correct liveness primitive
# ONLY when paired with a captured PID (the canonical idiom below), never as a decoration next to
# a name-match test.
#
# --- Deliberately NOT classified here (recorded, not hand-waved) ---
#   - A bare `pgrep` or `ps aux | grep` with no loop and no `sleep` -- legitimate diagnostic use.
#   - A one-shot name-match conditional outside a loop (e.g. `if pgrep -f x; then ...; fi`).
#   - `ps -p "$pid"` in a loop -- a PID test, not a name match; it has no self-match mechanism.
#   - A log-sentinel poll, e.g. `until grep -q DONE log; do sleep 10; done` -- no process-name
#     match and no self-match mechanism. `scripts/claude-refresh.sh`'s `build_waiter_family()`
#     Family B classifier DOES lump this shape in with the `ps|grep` self-match shape (its test is
#     `(until|while) && "grep -q" && sleep`, with no `ps`/`pgrep` requirement at all) -- this is
#     one half of a deliberate, two-way asymmetry between this hook's inventory and the reaper's,
#     see "Family B relationship" below.
#   - No-op filler (`echo idle`, bare `true`) and absent-waiter parking -- both adjacent tasks'
#     territory (the no-op-spin and backgrounded-wait-parking defects), never this hook's.
#
# --- Rule 4 ("one waiter per log") ruling: SCOPED OUT, not implemented ---
# A PreToolUse hook observes waiter STARTS and never waiter EXITS. A naive "this log/PID already
# has a waiter" record would go stale the instant that waiter exits, with no event to clear it --
# and would then falsely refuse a legitimate SEQUENTIAL wait on the same log, a false positive
# this task treats as worse than no hook. A fixed TTL does not rescue it either: Rule 1 sizes the
# legitimate wait to the command's own expected run time, so no single bound is safely shorter
# than every legitimate wait and longer than every dead-waiter gap. Rule 4 is enforceable only at
# REAP time, against a live process snapshot, where the liveness signal write-time observation
# structurally cannot have -- and `scripts/claude-refresh.sh`'s `BUILD_WAITER_REAP_MIN`-gated
# `run_build_waiter_pass` is exactly where that enforcement already lives. This hook does not
# duplicate it.
#
# --- Shared-pattern-library question: REJECTED, not adopted ---
# The `validate-no-task-references.sh` / `scripts/lib/task-reference-patterns.sh` split is the
# established precedent for a shared pattern library with two consumers -- it does not apply here.
# A library sourced by only this hook would not be shared; the only candidate second consumer is
# `scripts/claude-refresh.sh`'s `build_waiter_family()`, which is both outside this hook's own
# file scope and an explicit non-goal to modify (cleanup and prevention are separate layers, and
# changing the reaper's behavior is out of bounds). The two consumers also receive structurally
# different input: `build_waiter_family()` reads a `ps -eo args` column at REAP time against a
# live process snapshot, while this hook reads a `tool_input.command` string at WRITE time before
# any process exists -- a harder split than `task-reference-patterns.sh`'s two consumers, which
# both receive plain prose text. No shared library; the drift path is closed by this
# cross-reference instead (see "Family B relationship" immediately below), named in both
# directions so an editor of either file sees the other.
#
# --- Family B relationship (the drift-closure mechanism, both asymmetries recorded) ---
# `build_waiter_family()` in `scripts/claude-refresh.sh` (its Family B test:
# `(until|while) && "grep -q" && sleep`) is an INPUT to this hook's design -- a validated pattern
# inventory already exercised against real process tables -- never a target to modify. The
# relationship is asymmetric in BOTH directions, by design, not by oversight:
#   1. The reaper's Family B MISSES this hook's own motivating incident: `grep -c pgrep` over the
#      whole file returns zero matches, and the reaper also misses a `ps aux | grep -i ...` loop
#      that lacks the literal `-q` flag. This hook classifies both.
#   2. This hook deliberately does NOT classify the reaper's log-sentinel-poll half of Family B
#      (`until grep -q DONE log; do sleep N; done` with no `ps`/`pgrep` at all) -- see "Deliberately
#      NOT classified here" above.
# Cleanup (the reaper, reclaiming an already-orphaned waiter) and prevention (this hook, refusing
# one before it starts) are intentionally separate layers; this hook changes no reaper behavior.
#
# --- Known limitation (text-level shape test, not a shell parser) ---
# This hook pattern-matches the raw command STRING; it does not parse shell structure. A `sleep`
# and a loop keyword belonging to unrelated statements within one command string could in
# principle coincide without being the same wait loop. The third conjunction leg (an actual
# process name-match test) makes that coincidence implausible in practice, and a refusal is always
# recoverable by rewriting to the canonical idiom below -- it never silently swallows the command.
#
# Fails OPEN (exit 0, never a crash) on: `jq` absent, stdin absent/empty, an unparseable payload,
# or a missing/empty `tool_input.command`. Every `jq` call is guarded with `|| true` under
# `set -euo pipefail`, mirroring `validate-no-task-references.sh`'s and `detect-noop-bash.sh`'s
# own established idiom -- `jq` exits 2 on a usage/system error, and under `-e` an unguarded `jq`
# failure would abort this hook with exit 2, which PreToolUse reads as BLOCK, inverting fail-open
# into fail-closed for every matching Bash call in the repo.

set -euo pipefail

# ─── Fail-open guards ─────────────────────────────────────────────────────────────────────────

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat) || INPUT=""
if [ -z "$INPUT" ]; then
  exit 0
fi

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || COMMAND=""
if [ -z "$COMMAND" ]; then
  exit 0
fi

# ─── The three-way conjunction ────────────────────────────────────────────────────────────────
# (a) loop construct
LOOP=0
if printf '%s' "$COMMAND" | grep -qE '\b(until|while)\b'; then
  LOOP=1
fi

# (b) sleep call
SLEEP=0
if printf '%s' "$COMMAND" | grep -qE '\bsleep\b'; then
  SLEEP=1
fi

# (c) name-match liveness test: bare-word `pgrep` (any flags, or none -- see bare-word ruling
# above), OR a `ps` invocation piped into `grep` anywhere downstream. Neither branch inspects the
# grep pattern's own contents, so the [b]racket variant blocks by construction.
NAME_MATCH=0
if printf '%s' "$COMMAND" | grep -qE '\bpgrep\b'; then
  NAME_MATCH=1
elif printf '%s' "$COMMAND" | grep -qE '\bps\b[^|]*\|[^|]*\bgrep\b'; then
  NAME_MATCH=1
fi

if [ "$LOOP" -eq 1 ] && [ "$SLEEP" -eq 1 ] && [ "$NAME_MATCH" -eq 1 ]; then
  echo "BLOCKED: this command waits in a loop using a process-NAME match (pgrep/ps|grep) as its liveness test." >&2
  echo "Self-match mechanism: the waiter's own argv contains the literal pattern it searches for, so the" >&2
  echo "name-match test matches the waiter itself (and, with two running, each other) and never resolves --" >&2
  echo "see context/patterns/bounded-build-waiter.md Rule 2 (\"never use ps | grep, pgrep -f, or any" >&2
  echo "process-name-matching test\"). Bracketing the grep pattern does NOT fix this: it only stops grep" >&2
  echo "matching itself in the process listing, never the parent shell." >&2
  echo "Use the canonical PID-liveness idiom instead:" >&2
  echo "  cmd >log 2>&1 & pid=\$!" >&2
  echo "  timeout N bash -c 'while kill -0 \"\$1\" 2>/dev/null; do sleep 10; done' _ \"\$pid\"" >&2
  exit 2
fi

exit 0
