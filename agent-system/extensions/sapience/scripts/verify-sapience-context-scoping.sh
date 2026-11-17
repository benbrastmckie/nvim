#!/usr/bin/env bash
# verify-sapience-context-scoping.sh - Read-only residual probe for the primary-session
# content-scoping gap on POST /v1/cli/context (the endpoint behind the UserPromptSubmit and
# PreToolUse hooks).
#
# Modeled on verify-sapience-mcp.sh's header/exit-code style. THIS SCRIPT MAKES NO VAULT WRITE
# AND NO LOCAL MUTATION -- it issues two read-shaped POST /v1/cli/context requests (the same
# shape sapience_cli.py's own `hook prompt` handler sends) and compares their responses. A
# "residual holds" result (project still ignored) is the EXPECTED, green state today -- that is
# not a failure of this probe, it is confirmation of the measured gap documented in
# context/project/sapience/domain/injection-site-scoping.md. The day the vendor ask in that file
# lands, this probe's "residual lifted" outcome is what detects it, rather than the gap being
# assumed closed or re-discovered by accident.
#
# Usage: verify-sapience-context-scoping.sh [--repeat N] [--print] [--help]
#
# Options:
#   --repeat N  Repeat the two-call comparison N times (default 3, matching the measured
#               evidence that motivated this flag: a single run is unreliable). Must be an
#               integer >= 1; a non-integer or < 1 value exits 1 with a named reason.
#   --print     Also print the returned `text` block(s) from the FINAL iteration's real-project
#               (and, on RESIDUAL_LIFTED, sentinel-project) call, so a reader can confirm the
#               channel still delivers content (not only that project= is ignored).
#   --help      Show this help message.
#
# Config resolution (mirrors ~/.sapience/sapience_cli.py's config() function exactly):
#   SAPIENCE_HOST env, else ~/.sapience/config.json's .host, else https://app.spnc.ai.
#   SAPIENCE_TOKEN env, else ~/.sapience/config.json's .token.
#   A missing config file, missing host, or missing token exits with a NAMED reason on stderr
#   and no stack trace (exit 3) -- this is a probe, never a gate anything depends on.
#
# The repository slug sent as the "real project" value is resolved the same way
# sapience-remember.sh resolves it: basename of the parent checkout's git toplevel.
#
# N-repeat unanimous-agreement rule: a single run's RESIDUAL_LIFTED is exactly as likely to be
# the server's own per-session repeat-suppression (see "session_id MUST be unique" below) as a
# real lift of the residual -- a single run cannot tell the two apart. So this script repeats
# the comparison --repeat times (fresh session-id pair every iteration) and reports a
# conclusive outcome ONLY when all N iterations agree. A single disagreeing iteration -- not a
# majority vote -- disqualifies agreement, because the measured evidence that motivated this
# flag was precisely a 1-vs-2 split that a majority rule would have (wrongly) called conclusive.
#
# Outcomes (each printed on its own line, exactly one per run):
#   RESIDUAL_HOLDS   - every iteration's two calls returned byte-identical text/visible bodies.
#                       project= is still ignored on this endpoint. Exit 0.
#   RESIDUAL_LIFTED  - every iteration's two calls returned DIFFERENT text/visible bodies,
#                       unanimously. Two explanations remain possible even under unanimous
#                       agreement across iterations: the vendor ask may have landed (see
#                       context/project/sapience/domain/injection-site-scoping.md), OR the
#                       server's own repeat-suppression hid content on the SAME call position in
#                       every iteration for a reason unrelated to `project`. Exit 0 either way
#                       (this outcome is not a failure of the probe).
#   INCONCLUSIVE     - a non-200 status, an empty body, or a network failure on any iteration's
#                       call, OR the N iterations did not unanimously agree. The disagreement
#                       case prints the per-iteration tally (e.g. "2 RESIDUAL_HOLDS, 1
#                       RESIDUAL_LIFTED over 3 iterations"). Exit 2. Never asserts RESIDUAL_HOLDS
#                       or RESIDUAL_LIFTED on partial or disagreeing data.
#
# Exit codes:
#   0 - a conclusive, unanimous outcome was reached (RESIDUAL_HOLDS or RESIDUAL_LIFTED)
#   2 - INCONCLUSIVE (non-200, empty body, network failure on any iteration, or disagreement)
#   3 - config error: missing config file, missing host, or missing token (named reason on
#       stderr, no stack trace)
#   1 - bad arguments (including a bad --repeat value)
#
# The token is read into a shell variable once and is passed ONLY in the Authorization header
# built in-process by curl's -H flag. It is never echoed, never written to a file, and never
# included in any error message or --print output below (preserved under --repeat: --print's
# output is scoped to the final iteration's bodies only).

set -uo pipefail

PRINT_BLOCK="false"
REPEAT_N=3

usage() {
  cat >&2 <<'USAGE'
Usage: verify-sapience-context-scoping.sh [--repeat N] [--print] [--help]

Read-only probe: replays the two-call POST /v1/cli/context "project" comparison --repeat times
(default 3) and reports RESIDUAL_HOLDS or RESIDUAL_LIFTED only on UNANIMOUS agreement across all
iterations, otherwise INCONCLUSIVE with the per-iteration tally. Makes no vault write and no
local mutation.

Options:
  --repeat N  Repeat the comparison N times (default 3). Must be an integer >= 1.
  --print     Also print the final iteration's returned text block(s) (evidence the channel
              still delivers content).
  --help      Show this help message.

Exit codes:
  0 - conclusive, unanimous outcome reached (RESIDUAL_HOLDS or RESIDUAL_LIFTED)
  2 - INCONCLUSIVE (non-200, empty body, network failure on any iteration, or disagreement)
  3 - config error (missing config file, host, or token)
  1 - bad arguments (including a bad --repeat value)
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repeat)
      REPEAT_N="${2:-}"; shift 2 ;;
    --print)
      PRINT_BLOCK="true"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "verify-sapience-context-scoping.sh: unknown flag: $1" >&2
      usage
      exit 1 ;;
  esac
done

case "$REPEAT_N" in
  ''|*[!0-9]*)
    echo "verify-sapience-context-scoping.sh: --repeat requires an integer >= 1, got: '${REPEAT_N}'" >&2
    exit 1 ;;
esac
if [ "$REPEAT_N" -lt 1 ]; then
  echo "verify-sapience-context-scoping.sh: --repeat requires an integer >= 1, got: ${REPEAT_N}" >&2
  exit 1
fi

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"

# === BEGIN sapience-worktree-checkout-resolution (byte-identical in every copy: this hook,
# verify-sapience-mcp.sh, sapience-retrieve.sh, sapience-remember.sh, and
# verify-sapience-context-scoping.sh -- test-sapience-mcp-registration.sh's lockstep case
# extracts this marker-delimited block from each copy and asserts they are all byte-identical).
# Resolves a directory (default: cwd) to its git toplevel, following a linked worktree to its
# PARENT CHECKOUT rather than the worktree itself. Echoes the toplevel path and returns 0, or
# returns 1 with no output when the directory is not inside a git repository at all.
#
# Detection: compare `git rev-parse --git-dir` against `--git-common-dir`. Equal (including
# both failing, on a non-git path) means "not a linked worktree -- behave exactly like a bare
# `git rev-parse --show-toplevel`". Unequal means "linked worktree -- the common dir's PARENT
# directory is the checkout". `--git-common-dir` returns a relative path at a checkout root but
# an absolute path from inside a worktree, so it is absolutized before its parent is taken.
resolve_checkout_toplevel() {
    local dir="${1:-.}" git_dir common_dir
    git_dir="$(git -C "$dir" rev-parse --git-dir 2>/dev/null)" || return 1
    common_dir="$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)" || return 1
    if [ "$git_dir" = "$common_dir" ]; then
        git -C "$dir" rev-parse --show-toplevel 2>/dev/null
        return $?
    fi
    case "$common_dir" in
        /*) : ;;
        *) common_dir="$(cd "$dir" 2>/dev/null && pwd)/$common_dir" ;;
    esac
    (cd "$common_dir/.." 2>/dev/null && pwd)
}
# === END sapience-worktree-checkout-resolution ===

# --- Repo slug (same resolution as sapience-remember.sh: basename of the parent checkout's git
# toplevel -- this mirrors sapience-remember.sh's resolution, and the mirror must stay true) ---
repo_toplevel="$(resolve_checkout_toplevel "${PROJECT_ROOT:-.}" 2>/dev/null)" || repo_toplevel=""
if [ -z "$repo_toplevel" ]; then
  repo_toplevel="$(resolve_checkout_toplevel . 2>/dev/null)" || repo_toplevel=""
fi
if [ -z "$repo_toplevel" ]; then
  echo "verify-sapience-context-scoping.sh: could not resolve a git toplevel (run from inside a git repository)" >&2
  exit 3
fi
repo_slug="$(basename "$repo_toplevel")"
if [ -z "$repo_slug" ]; then
  echo "verify-sapience-context-scoping.sh: empty repo slug resolved from $repo_toplevel" >&2
  exit 3
fi

# --- Config resolution (mirrors sapience_cli.py's config() precedence exactly) ---
CONFIG_FILE="${HOME}/.sapience/config.json"

if [ -z "${SAPIENCE_HOST:-}" ] && [ ! -f "$CONFIG_FILE" ]; then
  echo "verify-sapience-context-scoping.sh: no config file at $CONFIG_FILE and SAPIENCE_HOST not set" >&2
  exit 3
fi

sapience_host="${SAPIENCE_HOST:-}"
if [ -z "$sapience_host" ] && [ -f "$CONFIG_FILE" ]; then
  sapience_host="$(jq -r '.host // empty' "$CONFIG_FILE" 2>/dev/null)" || sapience_host=""
fi
[ -z "$sapience_host" ] && sapience_host="https://app.spnc.ai"
sapience_host="${sapience_host%/}"

sapience_token="${SAPIENCE_TOKEN:-}"
if [ -z "$sapience_token" ] && [ -f "$CONFIG_FILE" ]; then
  sapience_token="$(jq -r '.token // empty' "$CONFIG_FILE" 2>/dev/null)" || sapience_token=""
fi
if [ -z "$sapience_token" ]; then
  echo "verify-sapience-context-scoping.sh: no Sapience token resolved (SAPIENCE_TOKEN env or ${CONFIG_FILE}'s .token)" >&2
  exit 3
fi

# --- The probe request shape, mirroring sapience_cli.py's `hook prompt` handler's own body
# exactly (event, session_id, level, view_lines, prompt, project). VIS_LINES there is 15. ---
PROMPT_TEXT="What is the current state of the roadmap, open tasks, and any recent decisions about Sapience scoping?"
SENTINEL_PROJECT="zzz-nonexistent-sentinel-project-probe"

post_context() {
  # $1 = project value, $2 = session_id suffix
  #
  # session_id MUST be unique per invocation, never a fixed literal: the server tracks
  # already-shown content per session_id (its own response's status.overnight field reports
  # "N repeats hidden") and suppresses a repeated delivery to the SAME session_id across runs.
  # A fixed session_id reused on every invocation of this script accumulates that per-session
  # suppression over repeated runs, which can make the real-project and sentinel-project calls
  # look different for a reason that has nothing to do with the `project` field -- a false
  # RESIDUAL_LIFTED. $$ (this process's PID) plus the current epoch second makes each run's
  # pair of session_ids novel, so this suppression state starts empty every time.
  local project="$1" sid="$2" body run_tag
  run_tag="$$-$(date +%s)"
  body="$(jq -n \
    --arg event "prompt" \
    --arg session_id "verify-sapience-context-scoping-${sid}-${run_tag}" \
    --arg level "rich" \
    --argjson view_lines 15 \
    --arg prompt "$PROMPT_TEXT" \
    --arg project "$project" \
    '{event: $event, session_id: $session_id, level: $level, view_lines: $view_lines, prompt: $prompt, project: $project}')"

  curl -sS --connect-timeout 3 --max-time 8 \
    -w '\n%{http_code}' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${sapience_token}" \
    -H 'User-Agent: verify-sapience-context-scoping.sh/1' \
    --data "$body" \
    "${sapience_host}/v1/cli/context" 2>/dev/null
}

# --- N-repeat loop: each iteration mints its own fresh session-id pair (post_context's own
# $$-plus-epoch run_tag, plus a per-iteration suffix on sid so two iterations landing in the
# same wall-clock second still mint distinct session_ids), so the server's per-session
# repeat-suppression starts empty on every iteration -- never a shared/fixed session_id across
# iterations. A conclusive outcome is reported only when all REPEAT_N iterations agree. ---
OUTCOMES=()
INCONCLUSIVE_ITER="false"
FAIL_REASON=""
FINAL_TEXT_REAL=""
FINAL_TEXT_SENTINEL=""

for i in $(seq 1 "$REPEAT_N"); do
  raw_real="$(post_context "$repo_slug" "real-${i}")" || raw_real=""
  http_real="${raw_real##*$'\n'}"
  body_real="${raw_real%$'\n'*}"

  raw_sentinel="$(post_context "$SENTINEL_PROJECT" "sentinel-${i}")" || raw_sentinel=""
  http_sentinel="${raw_sentinel##*$'\n'}"
  body_sentinel="${raw_sentinel%$'\n'*}"

  # --- Inconclusive gate (per iteration): either call must be a 200 with a non-empty,
  # JSON-parseable body. A single iteration's failure makes the WHOLE run inconclusive -- never
  # discarded as a non-vote and never masked by the other iterations' agreement. ---
  iter_inconclusive="false"
  iter_reason=""

  if [ -z "$raw_real" ] || [ "$http_real" != "200" ]; then
    iter_inconclusive="true"; iter_reason="real-project call: http=${http_real:-none} (network failure or non-200)"
  elif ! echo "$body_real" | jq -e . >/dev/null 2>&1; then
    iter_inconclusive="true"; iter_reason="real-project call: non-JSON body"
  fi

  if [ "$iter_inconclusive" = "false" ]; then
    if [ -z "$raw_sentinel" ] || [ "$http_sentinel" != "200" ]; then
      iter_inconclusive="true"; iter_reason="sentinel call: http=${http_sentinel:-none} (network failure or non-200)"
    elif ! echo "$body_sentinel" | jq -e . >/dev/null 2>&1; then
      iter_inconclusive="true"; iter_reason="sentinel call: non-JSON body"
    fi
  fi

  if [ "$iter_inconclusive" = "true" ]; then
    INCONCLUSIVE_ITER="true"
    FAIL_REASON="iteration ${i}/${REPEAT_N}: ${iter_reason}"
    break
  fi

  text_real="$(echo "$body_real" | jq -r '.text // ""')"
  visible_real="$(echo "$body_real" | jq -r '.visible // ""')"
  text_sentinel="$(echo "$body_sentinel" | jq -r '.text // ""')"
  visible_sentinel="$(echo "$body_sentinel" | jq -r '.visible // ""')"

  if [ "$text_real" = "$text_sentinel" ] && [ "$visible_real" = "$visible_sentinel" ]; then
    OUTCOMES+=("RESIDUAL_HOLDS")
  else
    OUTCOMES+=("RESIDUAL_LIFTED")
  fi

  # --print scopes to the FINAL iteration's bodies only (preserved behavior, generalized to N).
  FINAL_TEXT_REAL="$text_real"
  FINAL_TEXT_SENTINEL="$text_sentinel"
done

if [ "$INCONCLUSIVE_ITER" = "true" ]; then
  echo "INCONCLUSIVE -- ${FAIL_REASON}"
  exit 2
fi

# --- Unanimous-agreement verdict: UNANIMOUS, not majority. The measured evidence that
# motivated this flag was a 1-vs-2 split across 3 runs; a majority rule would have called that
# conclusive (RESIDUAL_HOLDS, 2-1), which is precisely the false confidence this rule exists to
# prevent. Any disagreement, including a single dissenting iteration, is INCONCLUSIVE. ---
HOLDS_COUNT=0
LIFTED_COUNT=0
for o in "${OUTCOMES[@]}"; do
  if [ "$o" = "RESIDUAL_HOLDS" ]; then
    HOLDS_COUNT=$((HOLDS_COUNT + 1))
  else
    LIFTED_COUNT=$((LIFTED_COUNT + 1))
  fi
done

if [ "$HOLDS_COUNT" -eq "$REPEAT_N" ]; then
  echo "RESIDUAL_HOLDS -- project= is still ignored on POST /v1/cli/context (unanimous across ${REPEAT_N} iteration(s): real project '${repo_slug}' and sentinel project both returned byte-identical text/visible bodies every time)"
  if [ "$PRINT_BLOCK" = "true" ]; then
    echo ""
    echo "--- returned text block (final iteration's real-project call; evidence the channel still delivers content) ---"
    echo "$FINAL_TEXT_REAL"
  fi
  exit 0
elif [ "$LIFTED_COUNT" -eq "$REPEAT_N" ]; then
  echo "RESIDUAL_LIFTED -- the real-project and sentinel-project calls returned DIFFERENT text/visible bodies, unanimously across ${REPEAT_N} iteration(s). Either the vendor ask in context/project/sapience/domain/injection-site-scoping.md has landed, or the server's own repeat-suppression hid content on the same call position in every iteration for a reason unrelated to project= -- this probe cannot tell which from repeated runs alone."
  if [ "$PRINT_BLOCK" = "true" ]; then
    echo ""
    echo "--- returned text block (final iteration's real-project call) ---"
    echo "$FINAL_TEXT_REAL"
    echo ""
    echo "--- returned text block (final iteration's sentinel-project call) ---"
    echo "$FINAL_TEXT_SENTINEL"
  fi
  exit 0
else
  echo "INCONCLUSIVE -- ${HOLDS_COUNT} RESIDUAL_HOLDS, ${LIFTED_COUNT} RESIDUAL_LIFTED over ${REPEAT_N} iterations"
  exit 2
fi
