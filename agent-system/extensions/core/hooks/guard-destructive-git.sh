#!/usr/bin/env bash
# guard-destructive-git.sh
# PreToolUse Bash hook guarding TWO INDEPENDENT hazard classes:
#
#   1. Destructive commands that discard UNCOMMITTED working-tree changes. This class is
#      scoped by DIRTINESS OF THE TREE: a clean tree has nothing to lose, so these predicates
#      exempt it, and a fresh git-snapshot.sh marker exempts a dirty tree too (see
#      .claude/scripts/git-snapshot.sh for the marker contract).
#   2. History rewrites (bare `git commit --amend`, a HEAD-moving `git reset`) that can
#      silently rewrite a commit made by a DIFFERENT dispatched writer. This class is scoped by
#      CONCURRENCY OF WRITERS, not tree state -- both gated commands are non-destructive to the
#      working tree, so class 1's dirty-tree design would wave them through on a dirty tree or a
#      clean one alike. This predicate therefore runs BEFORE the clean-tree exemption below and
#      consults live task-lock/session-registry evidence instead of `git status --porcelain`; it
#      has no snapshot-marker exemption (a snapshot makes discarded working-tree state
#      recoverable; it does nothing for a commit another writer already made). See
#      .claude/rules/git-workflow.md's "No History Rewrites While Another Writer Is Live" section
#      for the motivating incident and the full rationale.
#
# Blocks via exit code 2 + a stderr message (NOT permissionDecision: deny, which is
# documented-buggy for allow-listed Bash(git:*) commands -- see the rationale two sections below
# ("Response is binary exit 2 + stderr...") for the GH issue numbers and full detail.
#
# Guarded patterns (all git operations that discard uncommitted working-tree changes):
#   - git reset --hard
#   - git checkout -- <path>            (pathspec discard form)
#   - git restore <path>                (without --staged; --staged only unstages, safe)
#   - git clean  -f -d (any flag order/clustering, e.g. -fd, -df, -f -d, -xfd)
#   - git stash drop / git stash clear
#   - forced git checkout / git switch  (-f / --force; can silently overwrite changes)
#
# Exemptions (never blocked):
#   - working tree is already clean (git status --porcelain is empty) -- this also
#     auto-exempts the /todo safety-commit + reset --hard/clean -fd rollback flow
#     (.claude/context/standards/git-safety.md), since the safety commit makes the
#     tree clean before the destructive step runs.
#   - a fresh (<=120s old) .git-snapshot-marker exists under specs/**/ (written by
#     .claude/scripts/git-snapshot.sh); the marker is consumed (deleted) on use so it
#     only authorizes the ONE destructive command it was taken for.
#   - non-Bash tool calls / empty command (parse failure) -- never block.
#
# Over-staging patterns (blocked independently of the snapshot-marker exemption):
#   - git add -A / git add --all         (stages the entire working tree)
#   - git add .                          (bare dot pathspec; stages the entire cwd tree)
#   - git add <dir>/ (or a no-slash on-disk directory) / git add <glob>
#                                         (a directory or glob pathspec stages every modified
#                                          file it expands to, the same over-staging harm as
#                                          -A/--all/bare-dot in a narrower disguise; an explicit
#                                          multi-file list, e.g. `git add -- a.lean b.lean`, is
#                                          the sanctioned form and is NOT matched by this check)
#   - git commit -a / -am / --all        (implicitly stages all tracked-file modifications)
#
# This guard has NO exemption mechanism for over-staging -- unlike the destructive-command
# chain above, a fresh snapshot marker does NOT and must NEVER exempt these four forms.
# A snapshot makes a *destructive* command recoverable (data-loss problem); over-staging is
# a scope-pollution problem that a snapshot does not make acceptable. See
# .claude/context/standards/git-staging-scope.md for the scoped-staging contract these
# patterns enforce.
#
# Directory/glob pathspec detector -- accepted, pre-existing-shaped limitation: like the bare
# `.` check above, this reads $COMMAND_SCAN, whose upfront quote-strip erases quoted spans. A
# QUOTED over-broad pathspec (e.g. `git add -- "some/dir/"`) is therefore invisible to this
# check, exactly as `git add "."` is already invisible to the bare-dot check. This is a known,
# symmetric blind spot, not an oversight, and is not closed here -- see the quote-strip note
# above for why a second, non-quote-stripped scan variable is deliberately not introduced.
#
# git-snapshot.sh's own sanctioned `git add -A` (scripts/git-snapshot.sh, --branch mode
# only, against a throwaway wip-snapshot branch) needs no exemption here: this hook only
# ever observes the literal top-level tool_input.command string of the Bash call actually
# invoked, e.g. `bash .claude/scripts/git-snapshot.sh --branch 884`. The `git add -A` that
# runs as a subprocess *inside* that script is structurally invisible at this observation
# boundary -- it never appears in tool_input.command. Any future legitimate need to bypass
# these detectors must be wrapped in a script the same way, never special-cased in this file.
#
# Concurrency-gated history-rewrite predicate (hazard class 2, see top-of-file header) --
# design summary:
#   - Gates (syntactic, cheap, checked first so no filesystem scan is paid unless the command
#     actually matches): Gate A is `git commit --amend` as a real argv token; Gate B is a
#     HEAD-moving `git reset` (a non-flag commit-ish token before any `--` pathspec separator;
#     bare `HEAD`/`@` are exempt since neither moves HEAD). This deliberately also covers
#     `git reset --hard <commit-ish>`, which the dirty-tree predicate below exempts on a clean
#     tree for an unrelated reason (nothing to lose, not "no history was rewritten"). Both
#     gates read $COMMAND_SCAN only, inheriting the false-positive closure for a commit message
#     that merely contains the text "--amend".
#   - `git-commit-scoped.sh` needs no special case: the same subprocess-invisibility argument
#     above applies unchanged -- its internal git invocations never appear in tool_input.command.
#   - Liveness signal, once a gate matches: a live entry in either specs/{NNN}_{SLUG}/.lock/
#     holder.json (per-task locks) or specs/.sessions/*.json (the session registry), read
#     directly and cwd-relatively -- NEVER via `task-lock.sh`, which sources
#     deploy-root-guard.sh (exit 1 from the source store) and anchors PROJECT_ROOT to its own
#     SCRIPT_DIR rather than the caller's cwd, both fatal for a hermetically testable hook.
#     "Live" means a numeric `pid` for which `kill -0` succeeds AND a `heartbeat_at` within
#     HISTORY_REWRITE_LIVE_MIN minutes (default 30, matching TASK_LOCK_STALE_MIN's semantics).
#   - Threshold is ONE OR MORE live records, with no attempt to exclude "self": this hook
#     cannot correlate its own native Claude Code session UUID to an agent-system `sess_*`
#     identity, and a dispatched agent's own live lock is itself proof it is running under
#     orchestration, where the rule forbids bare rewrites outright. A genuinely solo interactive
#     operator has no live lock and no live session-registry entry.
#   - Fails OPEN (treats as "no live writer", i.e. permits) on any missing specs/, missing jq,
#     unreadable record, or unparseable timestamp -- the file's established
#     `2>/dev/null || true` posture, deliberate for a net layered over a documented rule rather
#     than the rule's sole enforcement.
#   - Response is binary `exit 2` + stderr (no warn tier), naming the matched form, the
#     concurrency (not dirtiness) rationale, `git-commit-scoped.sh` as the sanctioned path, and
#     git-workflow.md's section for the incident. A documented, auditable operator-only override,
#     `GUARD_ALLOW_HISTORY_REWRITE=1` prefixed onto the command, is detected in $COMMAND_SCAN
#     only (never the hook's own environment) so any use stays visible in the transcript --
#     agents MUST NOT use it.

set -euo pipefail

FRESHNESS_WINDOW=120
HISTORY_REWRITE_LIVE_MIN="${HISTORY_REWRITE_LIVE_MIN:-30}"

INPUT=$(cat) || true
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || true

# Allow through if command is empty (non-Bash tool or parse failure).
if [ -z "$COMMAND" ]; then
  exit 0
fi

# --- Argv-anchoring scan string ---
# Strip quoted spans, then bash comments, from the ENTIRE (possibly multi-line) $COMMAND ONCE,
# up front, before any segment extraction or flag-scanning runs. Every detector below reads
# $COMMAND_SCAN instead of raw $COMMAND, so free-text commit-message content (or a comment) can
# never be mistaken for a real argv flag or subcommand.
#
# The quote-strip MUST run in slurp mode (all input treated as one unit) rather than line mode.
# A line-based strip silently fails whenever a quoted span itself contains a newline (a
# multi-paragraph -m message): `grep`/line-mode `sed` never match across a newline, so the
# opening quote is never seen as closed and nothing is stripped -- the message's first line
# (typically the commit subject) then reaches the flag-scanning regexes as if it were argv.
#
# Uses `sed -z` (NUL-delimited "lines") rather than the more commonly cited `:a;N;$!ba` N-loop
# idiom: that idiom has a well-known GNU sed gotcha where `N` on an already-last line (i.e. ANY
# genuinely single-line command, which is the common case here) finds no next line to append,
# auto-prints the pattern space unmodified, and terminates the script WITHOUT ever reaching the
# substitution -- verified by direct reproduction while implementing this fix: it left
# single-line commands like `git commit -m "fix -a bug"` completely unstripped. `sed -z` has no
# such gotcha: with no NUL byte in the input, the entire (possibly multi-line) command is one
# NUL-terminated record regardless of how many embedded newlines it contains, so the
# substitution runs exactly once over the whole thing in a single pass, for both single- and
# multi-line commands alike.
#
# The comment-strip runs strictly AFTER the quote-strip, on a second, ordinary line-mode `sed`
# pass (correct here, since a bash `#` comment runs only to end of its own line; `sed -z`'s
# NUL-delimited "line" is intentionally NOT reused for this pass -- doing so would make `$` match
# only the end of the entire command instead of the end of each real line, wrongly stripping
# everything after the first `#` in the whole command instead of just to end of its own line).
# Ordering matters: a `#` character that is itself inside a quoted string has already been
# neutralized to `""`/`''` by the first pass, so it can never be mistaken for a real comment
# marker by the second. This closes the `--staged` false-exemption inverse in its comment form (a
# bash comment sharing a segment with a real `git restore <path>`, e.g. `git restore foo.txt #
# use --staged next time`) -- the quote-strip alone closes only the quoted form of that bypass.
#
# Out of scope (deliberate, not an oversight): the `[^;&|]*` segment-splitting regexes used by
# every detector below are not themselves quote-aware -- an unquoted `;`, `&`, or `|` character
# still splits a segment early. This upfront strip confines that risk to genuinely *unquoted*
# occurrences of those characters (any that were inside quotes are already gone by this point),
# which is rare and not implicated in any known false positive. Making the splitting itself
# quote-aware would need a real tokenizer applied consistently across all seven detectors -- a
# materially larger, separately-reviewable change -- and is not addressed here.
COMMAND_SCAN=$(printf '%s' "$COMMAND" \
  | sed -z -e 's/"[^"]*"/""/g' -e "s/'[^']*'/''/g" \
  | sed -e 's/\(^\|[[:space:]]\)#.*$//')

# --- Concurrency-gated history-rewrite predicate (hazard class 2) ---
# Runs BEFORE the clean-tree exemption below, deliberately: it is tree-state-blind and must not
# be silent dead code on a clean tree. See the top-of-file header and the design-summary comment
# above `set -euo pipefail` for the full rationale; this is the implementation.

# history_rewrite_live_writer: returns 0 (true) if a live dispatched writer exists in this repo,
# 1 (false, and FAILS OPEN on any read/parse problem) otherwise. Reads both record families
# directly and cwd-relatively -- never via task-lock.sh, see the header note on why.
history_rewrite_live_writer() {
  command -v jq >/dev/null 2>&1 || return 1

  local now then_epoch age pid heartbeat f
  local lock_records session_records records

  now=$(date -u +%s 2>/dev/null) || return 1

  lock_records=$(find specs -maxdepth 3 -name "holder.json" -type f 2>/dev/null) || true
  session_records=$(find specs/.sessions -maxdepth 1 -name "*.json" -type f 2>/dev/null) || true
  records="${lock_records}
${session_records}"

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    pid=$(jq -r '.pid // empty' "$f" 2>/dev/null) || continue
    heartbeat=$(jq -r '.heartbeat_at // empty' "$f" 2>/dev/null) || continue
    [ -z "$pid" ] && continue
    [ -z "$heartbeat" ] && continue
    case "$pid" in
      ''|*[!0-9]*) continue ;;
    esac
    kill -0 "$pid" 2>/dev/null || continue
    then_epoch=$(date -u -d "$heartbeat" +%s 2>/dev/null \
      || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$heartbeat" +%s 2>/dev/null) || true
    [ -z "$then_epoch" ] && continue
    age=$(( (now - then_epoch) / 60 ))
    if [ "$age" -ge 0 ] && [ "$age" -le "$HISTORY_REWRITE_LIVE_MIN" ]; then
      return 0
    fi
  done <<< "$records"

  return 1
}

HISTORY_REWRITE_MATCHED=0
HISTORY_REWRITE_REASON=""

# Gate A: bare `git commit --amend` (a real argv token, never message text -- $COMMAND_SCAN has
# already had quoted/commented spans stripped above).
AMEND_SEGMENTS=$(echo "$COMMAND_SCAN" | grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+commit[^;&|]*') || true
if [ -n "$AMEND_SEGMENTS" ]; then
  while IFS= read -r seg; do
    [ -z "$seg" ] && continue || true
    if echo "$seg" | grep -qE -- '(^|[[:space:]])--amend([[:space:]]|$)'; then
      HISTORY_REWRITE_MATCHED=1
      HISTORY_REWRITE_REASON="git commit --amend rewrites an already-committed commit"
      break
    fi
  done <<< "$AMEND_SEGMENTS"
fi

# Gate B: a HEAD-moving `git reset` -- a non-flag commit-ish token appearing before any `--`
# pathspec separator; bare `HEAD` and bare `@` are explicitly exempt since neither moves HEAD.
# This deliberately also matches `git reset --hard <commit-ish>`, which the dirty-tree predicate
# below exempts on a clean tree for an unrelated reason (nothing to lose, not "no history was
# rewritten"). `read -ra` walks real argv tokens rather than relying on word-splitting, mirroring
# the directory/glob `git add` detector's own per-token idiom below.
if [ "$HISTORY_REWRITE_MATCHED" = "0" ]; then
  RESET_SEGMENTS=$(echo "$COMMAND_SCAN" | grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+reset[^;&|]*') || true
  if [ -n "$RESET_SEGMENTS" ]; then
    while IFS= read -r seg; do
      [ -z "$seg" ] && continue || true
      seg_rest=$(echo "$seg" | sed -E 's/^[;&|]*[[:space:]]*git[[:space:]]+reset[[:space:]]*//')
      read -ra RESET_TOKENS <<< "$seg_rest" || true
      for tok in "${RESET_TOKENS[@]:-}"; do
        [ -z "$tok" ] && continue || true
        if [ "$tok" = "--" ]; then
          break
        fi
        case "$tok" in
          -*) continue ;;
        esac
        if [ "$tok" != "HEAD" ] && [ "$tok" != "@" ]; then
          HISTORY_REWRITE_MATCHED=1
          HISTORY_REWRITE_REASON="git reset $tok moves HEAD, rewriting which commit this branch points at"
          break
        fi
      done
      if [ "$HISTORY_REWRITE_MATCHED" = "1" ]; then
        break
      fi
    done <<< "$RESET_SEGMENTS"
  fi
fi

if [ "$HISTORY_REWRITE_MATCHED" = "1" ]; then
  # Documented, auditable operator-only override -- detected in the scan string only, NEVER from
  # the hook's own environment (the caller's inline env assignment does not reach this process),
  # so any use stays visible in the transcript. Agents MUST NOT use this override.
  if echo "$COMMAND_SCAN" | grep -q 'GUARD_ALLOW_HISTORY_REWRITE=1'; then
    HISTORY_REWRITE_MATCHED=0
  fi
fi

if [ "$HISTORY_REWRITE_MATCHED" = "1" ] && history_rewrite_live_writer; then
  echo "BLOCKED: $HISTORY_REWRITE_REASON" >&2
  echo "A live concurrent writer exists in this repo (a dispatched task lock or session-registry" >&2
  echo "entry with a fresh heartbeat) -- this refusal is due to CONCURRENCY, not tree state; it" >&2
  echo "fires on a clean tree exactly as on a dirty one." >&2
  echo "Route this commit through .claude/scripts/git-commit-scoped.sh instead, which serializes" >&2
  echo "on the commit mutex and path-scopes staging." >&2
  echo "See .claude/rules/git-workflow.md's 'No History Rewrites While Another Writer Is Live'" >&2
  echo "section for the incident and full rationale." >&2
  echo "Operator-only override (agents MUST NOT use this): prefix the command with" >&2
  echo "GUARD_ALLOW_HISTORY_REWRITE=1 if you are a human operator working this branch solo." >&2
  exit 2
fi

# Clean tree -> nothing to lose. Also exempts /todo's post-safety-commit reset --hard
# and git clean -fd (git-safety.md), since the safety commit makes the tree clean first.
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  exit 0
fi

# --- Over-staging detectors ---
# Independent of the destructive-command MATCHED chain below: these block directly via their
# own exit 2 and never set MATCHED/REASON, so a fresh snapshot marker can NEVER exempt
# over-staging (see header comment for the data-loss vs. scope-pollution rationale). Both read
# $COMMAND_SCAN (quoted/commented spans already stripped above), so free-text commit messages
# (e.g. -m "fix -a bug") never false-positive, including when the message spans multiple lines.
OVERSTAGE_REASON=""

# git add -A / --all / bare "." pathspec
ADD_SEGMENTS=$(echo "$COMMAND_SCAN" | grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+add[^;&|]*') || true
if [ -n "$ADD_SEGMENTS" ]; then
  while IFS= read -r seg; do
    [ -z "$seg" ] && continue || true
    if echo "$seg" | grep -qE -- '(^|[^-])-[a-zA-Z]*A[a-zA-Z]*([[:space:]]|$)|--all([[:space:]]|$)'; then
      OVERSTAGE_REASON="git add -A (or --all) stages the entire working tree; stage explicit task-scoped paths instead"
      break
    fi
    if echo "$seg" | grep -qE -- '(^|[[:space:]])\.([[:space:]]|$)'; then
      OVERSTAGE_REASON="git add . stages the entire current directory tree; stage explicit task-scoped paths instead"
      break
    fi
    # Per-token directory/glob pathspec check (see header note above for the quoted-pathspec
    # blind spot). Strip the leading "git add" (and any leading ;/&/| separator this segment's
    # extraction regex may have captured), then skip any flag token (starts with "-", including
    # the bare "--" separator) and test each remaining pathspec token for directory-or-glob
    # shape. `read -ra` (not unquoted word-splitting) is used deliberately so the shell's own
    # pathname expansion never silently consumes a literal glob token before it can be inspected.
    seg_rest=$(echo "$seg" | sed -E 's/^[;&|]*[[:space:]]*git[[:space:]]+add[[:space:]]*//')
    read -ra ADD_TOKENS <<< "$seg_rest" || true
    for tok in "${ADD_TOKENS[@]:-}"; do
      [ -z "$tok" ] && continue || true
      case "$tok" in
        -*) continue ;;
      esac
      if [[ "$tok" == */ ]] || [ -d "$tok" ]; then
        OVERSTAGE_REASON="git add with a directory pathspec ('$tok') stages every modified file under it; stage explicit task-scoped paths instead"
        break
      fi
      if echo "$tok" | grep -q '[*?[]'; then
        OVERSTAGE_REASON="git add with a glob pathspec ('$tok') stages every matching modified file; stage explicit task-scoped paths instead"
        break
      fi
    done
    if [ -n "$OVERSTAGE_REASON" ]; then
      break
    fi
  done <<< "$ADD_SEGMENTS"
fi

# git commit -a / -am / --all (bare -a is as hazardous as -am: both implicitly stage all
# tracked modifications, per git-staging-scope.md)
if [ -z "$OVERSTAGE_REASON" ]; then
  COMMIT_SEGMENTS=$(echo "$COMMAND_SCAN" | grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+commit[^;&|]*') || true
  if [ -n "$COMMIT_SEGMENTS" ]; then
    while IFS= read -r seg; do
      [ -z "$seg" ] && continue || true
      if echo "$seg" | grep -qE -- '(^|[^-])-[a-zA-Z]*a[a-zA-Z]*([[:space:]]|$)|--all([[:space:]]|$)'; then
        OVERSTAGE_REASON="git commit -a/-am (or --all) implicitly stages all tracked-file modifications; stage explicit paths and commit without -a"
        break
      fi
    done <<< "$COMMIT_SEGMENTS"
  fi
fi

if [ -n "$OVERSTAGE_REASON" ]; then
  echo "BLOCKED: $OVERSTAGE_REASON" >&2
  echo "Stage explicit, task-scoped paths per .claude/context/standards/git-staging-scope.md" >&2
  echo "(this guard has no snapshot-marker exemption for over-staging -- a snapshot does not" >&2
  echo "make scope pollution acceptable)." >&2
  exit 2
fi

MATCHED=0
REASON=""

# git reset --hard
if echo "$COMMAND_SCAN" | grep -qE '(^|[;&|][[:space:]]*)git[[:space:]]+reset[^;&|]*--hard\b'; then
  MATCHED=1
  REASON="git reset --hard discards uncommitted working-tree changes"
fi

# git checkout -- <path>  (pathspec discard form)
if [ "$MATCHED" = "0" ] && echo "$COMMAND_SCAN" | grep -qE '(^|[;&|][[:space:]]*)git[[:space:]]+checkout[^;&|]*[[:space:]]--([[:space:]]|$)'; then
  MATCHED=1
  REASON="git checkout -- <path> discards uncommitted changes to that path"
fi

# git restore <path>  (without --staged; --staged only unstages and is safe)
if [ "$MATCHED" = "0" ]; then
  RESTORE_SEGMENTS=$(echo "$COMMAND_SCAN" | grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+restore[^;&|]*') || true
  if [ -n "$RESTORE_SEGMENTS" ]; then
    while IFS= read -r seg; do
      [ -z "$seg" ] && continue || true
      if ! echo "$seg" | grep -q -- '--staged'; then
        MATCHED=1
        REASON="git restore <path> (without --staged) discards uncommitted working-tree changes"
        break
      fi
    done <<< "$RESTORE_SEGMENTS"
  fi
fi

# git clean -f -d (any order/clustering, e.g. -fd, -df, -f -d, -xfd)
if [ "$MATCHED" = "0" ]; then
  CLEAN_SEGMENTS=$(echo "$COMMAND_SCAN" | grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+clean[^;&|]*') || true
  if [ -n "$CLEAN_SEGMENTS" ]; then
    while IFS= read -r seg; do
      [ -z "$seg" ] && continue || true
      HAS_F=0
      HAS_D=0
      echo "$seg" | grep -qE -- '(^|[^-])-[a-zA-Z]*f[a-zA-Z]*([[:space:]]|$)|--force' && HAS_F=1 || true
      echo "$seg" | grep -qE -- '(^|[^-])-[a-zA-Z]*d[a-zA-Z]*([[:space:]]|$)' && HAS_D=1 || true
      if [ "$HAS_F" = "1" ] && [ "$HAS_D" = "1" ]; then
        MATCHED=1
        REASON="git clean -f -d permanently deletes untracked files and directories"
        break
      fi
    done <<< "$CLEAN_SEGMENTS"
  fi
fi

# git stash drop / git stash clear
if [ "$MATCHED" = "0" ] && echo "$COMMAND_SCAN" | grep -qE '(^|[;&|][[:space:]]*)git[[:space:]]+stash[[:space:]]+(drop|clear)\b'; then
  MATCHED=1
  REASON="git stash drop/clear permanently discards stashed changes"
fi

# forced git checkout / git switch (-f / --force) -- can silently overwrite local changes
if [ "$MATCHED" = "0" ]; then
  FORCED_SEGMENTS=$(echo "$COMMAND_SCAN" | grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+(checkout|switch)[^;&|]*') || true
  if [ -n "$FORCED_SEGMENTS" ]; then
    while IFS= read -r seg; do
      [ -z "$seg" ] && continue || true
      if echo "$seg" | grep -qE -- '(^|[^-])-[a-zA-Z]*f[a-zA-Z]*([[:space:]]|$)|--force'; then
        MATCHED=1
        REASON="forced git checkout/switch (-f/--force) can silently overwrite uncommitted changes"
        break
      fi
    done <<< "$FORCED_SEGMENTS"
  fi
fi

if [ "$MATCHED" = "0" ]; then
  exit 0
fi

# Destructive pattern matched on a dirty tree: check for a fresh, unconsumed snapshot marker.
NOW=$(date +%s)
BEST_MARKER=""
BEST_TS=0
MARKERS=$(find specs -maxdepth 3 -name ".git-snapshot-marker" -type f 2>/dev/null) || true
if [ -n "$MARKERS" ]; then
  while IFS= read -r m; do
    [ -z "$m" ] && continue || true
    ts=$(grep -m1 '^TIMESTAMP=' "$m" 2>/dev/null | cut -d= -f2) || true
    if [[ "$ts" =~ ^[0-9]+$ ]] && [ "$ts" -gt "$BEST_TS" ]; then
      BEST_TS="$ts"
      BEST_MARKER="$m"
    fi
  done <<< "$MARKERS"
fi

if [ -n "$BEST_MARKER" ]; then
  AGE=$(( NOW - BEST_TS ))
  if [ "$AGE" -ge 0 ] && [ "$AGE" -le "$FRESHNESS_WINDOW" ]; then
    rm -f "$BEST_MARKER"
    exit 0
  fi
fi

echo "BLOCKED: $REASON" >&2
echo "The working tree has uncommitted changes and this command would discard them." >&2
echo "Run 'bash .claude/scripts/git-snapshot.sh <task-number>' first to take a recoverable" >&2
echo "snapshot (writes a .patch under the task directory + a stash backup), then retry." >&2
echo "Pass the task number explicitly: the no-argument form only resolves when exactly one" >&2
echo "task in specs/state.json is 'implementing', which does not hold with several in flight." >&2
echo "The default mode REVERTS the working tree -- intended here, immediately before a" >&2
echo "destructive command. Use --no-revert only if you intend to keep working afterwards." >&2
exit 2
