#!/usr/bin/env bash
# test-lint-deploy-caller-wrap.sh - Mechanical class guard for the SELF-OVERWRITE HAZARD
# (see deploy-headless.sh's own "SELF-OVERWRITE HAZARD" header comment, and the matching headers
# this task added to orchestrate-cycle-plan.sh and command-gate-out.sh). Closes the hazard class
# by CONSTRUCTION rather than by memory: any script that GENUINELY invokes deploy-headless.sh
# while it is itself a deployed, still-running script must wrap everything from that invocation
# through true EOF inside one top-level function, invoked as the file's last physical statement
# -- or this lint fails, loudly, naming the offending file and line.
#
# Two independent things this script does, on purpose:
#   (1) CLASSIFY every textual reference to "deploy-headless.sh" across
#       agent-system/extensions/*/scripts/**/*.sh (excluding tests/ fixtures) into GENUINE
#       (a line that actually EXECUTES the script: `bash <path ending in deploy-headless.sh>`,
#       a direct `./`-style call, or a command substitution around either) or MENTION (a comment,
#       or a string literal handed to a reporting/messaging call or a plain variable assignment --
#       remedy text, usage examples, doc pointers). This is re-derived from the file contents
#       every run, never a hardcoded path list, so a new caller is discovered automatically.
#   (2) For every GENUINE caller (plus deploy-headless.sh itself, asserted unconditionally --
#       it must satisfy the identical rule for the identical reason: it overwrites its own
#       deployed copy while running), verify the STRUCTURAL wrap: the invocation lies inside a
#       top-level function; that function's closing brace is a LONE, UNINDENTED `}` (this
#       codebase's own convention, used by deploy-headless.sh's original main() and by this
#       task's two new wraps -- deliberately NOT re-indenting the wrapped body, so a nested `}`
#       from an `if`/`{ ... } >&2` group or a jq `'{...}'` literal is always either indented or
#       inline, never a bare `}` alone on its own line); and after that closing brace, EOF holds
#       nothing but blank lines, comments, and EXACTLY ONE bare invocation of that same function
#       (optionally with `"$@"`).
#
# Classification is a heuristic, not a full bash parser (parsing bash correctly in general
# requires an actual shell parser, not a regex) -- but it is deliberately conservative in the
# direction that matters: it demands the invocation-shaped token sit in genuine COMMAND position
# (line start, after a subshell/control-flow opener, or as the target of a plain/command-
# substitution assignment) with NOTHING else -- no sentence words, no extra quote -- between that
# anchor and the `bash`/`./` token. Every one of this repository's current remedy/doc/comment
# references fails that test (see the self-test below, which also exercises the FALSE-NEGATIVE
# direction: deliberately unwrapping a real caller in a scratch copy and confirming the lint then
# fails it).
#
# Exit codes: 0 -- lint clean; 1 -- at least one violation; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTENSIONS_DIR="$(cd "$CORE_DIR/../.." && pwd)"

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

# ── (1) Classification ───────────────────────────────────────────────────────────────────────
# GENUINE_ANCHOR_RE: what may sit immediately before the `bash <path>` / `./ <path>` token, with
# only whitespace (and, for the assignment/subst form, an optional quote + `$(`) in between:
#   - line start
#   - a subshell/group/statement-separator opener: ( ; & |  {
#   - a control-flow keyword: if / elif / while / until
#   - a plain or `+=` variable assignment, optionally opening a command substitution: NAME=,
#     NAME+=, NAME="$(, NAME+="$(
GENUINE_ANCHOR_RE='(^|[(;&|{]|(^|[[:space:]])(if|elif|while|until)[[:space:]])[[:space:]]*\$?\(?[[:space:]]*'
GENUINE_ANCHOR_ASSIGN_RE='^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*\+?=\"?\$?\(?[[:space:]]*'
GENUINE_CMD_RE='(bash[[:space:]]+\"?[^[:space:]\"'"'"']*deploy-headless\.sh|\.\/[^[:space:]\"'"'"']*deploy-headless\.sh)'

classify_line() {
  # Usage: classify_line "<line text>"  -- echoes "genuine" or "mention"
  local line="$1"
  local trimmed="${line#"${line%%[![:space:]]*}"}"
  if [[ "$trimmed" == \#* ]]; then
    echo "mention"; return
  fi

  # Syntactic candidacy: does the line match one of the two anchor+command shapes at all? The
  # anchor alternation's punctuation characters (`(`, `;`, `&`, `|`) match ANYWHERE in the line,
  # not just at true line start, so this alone is not sufficient -- English punctuation inside a
  # message string (e.g. `echo "Deploy first (bash ... deploy-headless.sh), then ..."`) can also
  # satisfy it. BASH_REMATCH[0] captures the exact matched substring so the quote-parity veto
  # below can check what precedes THAT match, not merely what precedes "deploy-headless.sh".
  # Try the assignment anchor FIRST: it is always anchored at true line start (^), so when it
  # matches, `matched` starts at position 0 and the quote-parity veto below sees an empty prefix.
  # The general punctuation anchor (tried second) matches its `(`/`;`/`&`/`|` alternatives
  # ANYWHERE in the line, including a `(` that is itself part of a `"$(...)"` command-substitution
  # opener already covered by the assignment anchor -- trying it first would let that `(` win the
  # match instead, truncating the prefix mid-string and producing a false quote-parity veto.
  local matched=""
  if [[ "$line" =~ ${GENUINE_ANCHOR_ASSIGN_RE}${GENUINE_CMD_RE} ]]; then
    matched="${BASH_REMATCH[0]}"
  elif [[ "$line" =~ ${GENUINE_ANCHOR_RE}${GENUINE_CMD_RE} ]]; then
    matched="${BASH_REMATCH[0]}"
  else
    echo "mention"; return
  fi

  # Quote-parity veto: reject the candidate if the matched anchor+command substring itself begins
  # INSIDE an unclosed quoted string -- i.e. if the portion of the line strictly BEFORE the match
  # has an odd number of quote characters. Scope is further narrowed to only the portion AFTER the
  # LAST `$(` before the match, since a `$(` always resets quoting context, per normal bash
  # semantics, even when nested inside an outer pair of quotes -- this is what makes
  # `var="$(bash ... deploy-headless.sh)"` genuine rather than a false veto, while still correctly
  # vetoing `echo "Deploy first (bash ... deploy-headless.sh), then ..."` (no `$(` present at all,
  # so the whole prefix is checked, and its lone opening `"` makes the count odd).
  local prefix="${line%%"$matched"*}"
  local window="${prefix##*\$(}"
  local dquotes="${window//[^\"]/}"
  local squotes="${window//[^\']/}"
  if [ $(( ${#dquotes} % 2 )) -eq 1 ] || [ $(( ${#squotes} % 2 )) -eq 1 ]; then
    echo "mention"; return
  fi

  echo "genuine"
}

declare -a candidate_files=()
while IFS= read -r f; do
  [ -n "$f" ] && candidate_files+=("$f")
done < <(find "$EXTENSIONS_DIR" -type d -name tests -prune -o -type f -name '*.sh' -print | sort)

declare -A genuine_lines_by_file=()   # file -> space-separated line numbers
declare -a genuine_files=()
declare -a mention_files=()

for f in "${candidate_files[@]}"; do
  [ -f "$f" ] || continue
  file_has_mention=false
  file_genuine_lines=""
  while IFS=: read -r lineno content; do
    [ -z "$lineno" ] && continue
    verdict="$(classify_line "$content")"
    if [ "$verdict" = "genuine" ]; then
      file_genuine_lines="${file_genuine_lines} ${lineno}"
    else
      file_has_mention=true
    fi
  done < <(grep -n "deploy-headless\.sh" "$f" 2>/dev/null)
  if [ -n "${file_genuine_lines// /}" ]; then
    genuine_lines_by_file["$f"]="${file_genuine_lines# }"
    genuine_files+=("$f")
  elif [ "$file_has_mention" = "true" ]; then
    mention_files+=("$f")
  fi
done

info "Classification: ${#genuine_files[@]} genuine caller file(s), ${#mention_files[@]} mention-only file(s) out of ${#candidate_files[@]} scanned .sh file(s)."
for f in "${genuine_files[@]}"; do
  info "  GENUINE: ${f#"$EXTENSIONS_DIR"/} (line(s): ${genuine_lines_by_file[$f]})"
done

# ── Negative assertion: the two sites this task fixed must be exactly the classified set (today).
# This is a REGRESSION guard, not a hardcoded allowlist that ignores new callers -- a new genuine
# caller widens genuine_files above and is still checked by the structural verification below; if
# a new one appears, the ONLY consequence here is this specific count assertion needing updating,
# which the printed classification (above) makes visible rather than silent.
if [ "${#genuine_files[@]}" -eq 2 ] && \
   printf '%s\n' "${genuine_files[@]}" | grep -q 'orchestrate-cycle-plan\.sh$' && \
   printf '%s\n' "${genuine_files[@]}" | grep -q 'command-gate-out\.sh$'; then
  pass "classification: exactly the two known genuine caller sites (orchestrate-cycle-plan.sh, command-gate-out.sh) were found"
else
  fail "classification: expected exactly {orchestrate-cycle-plan.sh, command-gate-out.sh}, got: ${genuine_files[*]:-<none>}"
fi

# ── (2) Structural verification ──────────────────────────────────────────────────────────────
# verify_wrap <file> [genuine_line_numbers...] -- returns 0/prints pass, or prints a named fail.
# Finds the LAST `^}$` (lone, unindented closing brace) such that everything strictly after it
# through EOF is blank/comment lines followed by exactly one bare invocation of the function that
# brace closes, then confirms that function's span covers every given genuine invocation line.
verify_wrap() {
  local file="$1"; shift
  local -a inv_lines=("$@")
  local relf="${file#"$EXTENSIONS_DIR"/}"
  local total_lines
  total_lines=$(wc -l < "$file")

  local -a brace_lines=()
  while IFS= read -r n; do brace_lines+=("$n"); done < <(grep -nx '}' "$file" | cut -d: -f1)
  if [ "${#brace_lines[@]}" -eq 0 ]; then
    fail "$relf: no lone, unindented closing brace ('}' alone on its own line) found anywhere -- not wrapped"
    return
  fi

  local anchor_line="" funcname=""
  for bl in "${brace_lines[@]}"; do
    # Everything strictly after $bl through EOF must be: blank/comment lines, then exactly one
    # bare invocation line, then nothing.
    local after inv_seen=false candidate_func=""
    while IFS= read -r ln; do
      local t="${ln#"${ln%%[![:space:]]*}"}"
      if [ -z "$t" ] || [[ "$t" == \#* ]]; then
        continue
      fi
      if [ "$inv_seen" = "true" ]; then
        # A second non-blank/comment line after the supposed invocation -- this brace is not it.
        candidate_func=""; inv_seen=false; break
      fi
      if [[ "$t" =~ ^([A-Za-z_][A-Za-z0-9_]*)([[:space:]]+\"\$@\")?$ ]]; then
        candidate_func="${BASH_REMATCH[1]}"
        inv_seen=true
      else
        candidate_func=""; break
      fi
    done < <(tail -n "+$((bl + 1))" "$file")
    if [ "$inv_seen" = "true" ] && [ -n "$candidate_func" ]; then
      anchor_line="$bl"; funcname="$candidate_func"
      # Keep scanning for a LATER qualifying brace (closer to true EOF) in case of a false
      # positive earlier in the file; the true wrap's closing brace is the one nearest EOF.
    fi
  done

  if [ -z "$anchor_line" ]; then
    fail "$relf: found a lone closing brace but no exact 'blank/comment* then one bare invocation, then EOF' tail after any of them -- not wrapped to true EOF"
    return
  fi

  local open_line=""
  open_line=$(grep -nE "^${funcname}\(\) *\{$" "$file" | tail -1 | cut -d: -f1)
  if [ -z "$open_line" ]; then
    fail "$relf: found closing brace + bare invocation of '$funcname' at/after line $anchor_line, but no matching '${funcname}() {' opening at column 0"
    return
  fi
  pass "$relf: wrapped in '$funcname' (lines $open_line-$anchor_line), invoked once as the file's last physical statement"

  for il in "${inv_lines[@]}"; do
    if [ "$il" -gt "$open_line" ] && [ "$il" -lt "$anchor_line" ]; then
      pass "$relf: genuine invocation at line $il lies inside '$funcname' (lines $open_line-$anchor_line)"
    else
      fail "$relf: genuine invocation at line $il does NOT lie inside '$funcname' (lines $open_line-$anchor_line) -- self-overwrite hazard is NOT closed"
    fi
  done
}

for f in "${genuine_files[@]}"; do
  # shellcheck disable=SC2206
  read -r -a inv_lines <<< "${genuine_lines_by_file[$f]}"
  verify_wrap "$f" "${inv_lines[@]}"
done

# deploy-headless.sh itself is asserted unconditionally -- it overwrites its OWN deployed copy
# while running, the identical mechanism, independent of whether it happens to textually
# reference its own filename anywhere (it does not need to invoke itself to be in this hazard
# class).
DEPLOY_HEADLESS="$CORE_DIR/deploy-headless.sh"
if [ -f "$DEPLOY_HEADLESS" ]; then
  verify_wrap "$DEPLOY_HEADLESS"
else
  fail "deploy-headless.sh not found at $DEPLOY_HEADLESS"
fi

# ── Self-test: a deliberately unwrapped copy of a genuine caller must FAIL this same structural
# check, proving the lint has teeth (a permanently-green lint that could never fail is worthless).
# Restored immediately after; never touches the real source-store file.
info "Self-test: unwrapping orchestrate-cycle-plan.sh in a scratch copy must fail verify_wrap"
SELFTEST_DIR="$(mktemp -d)"
selftest_cleanup() { [ -n "${SELFTEST_DIR:-}" ] && [ -d "$SELFTEST_DIR" ] && rm -rf "$SELFTEST_DIR"; }
trap selftest_cleanup EXIT
selftest_file="$SELFTEST_DIR/orchestrate-cycle-plan.sh"
cp "$CORE_DIR/orchestrate-cycle-plan.sh" "$selftest_file"
# Strip the wrap: remove the opening `orchestrate_cycle_plan_main() {` line and the trailing
# `}` + bare invocation pair, restoring a flat, unwrapped top-level script.
sed -i '/^orchestrate_cycle_plan_main() {$/d' "$selftest_file"
# Remove the LAST two lines (the closing brace and the bare invocation) added by Phase 2.
selftest_total=$(wc -l < "$selftest_file")
sed -i "$((selftest_total - 1)),${selftest_total}d" "$selftest_file"
# Run in a command substitution (which forks a subshell) so verify_wrap's own pass()/fail() calls
# mutate only that subshell's copy of PASSED/FAILED, never this suite's real counters -- the
# self-test's OWN expected failure is not a real defect in the actual source tree.
selftest_output="$(verify_wrap "$selftest_file" 2>&1)"
echo "$selftest_output" | sed 's/^/  [self-test scratch copy] /'
if echo "$selftest_output" | grep -q '^\[FAIL\]'; then
  pass "self-test: the deliberately unwrapped scratch copy correctly FAILS verify_wrap (lint has teeth)"
else
  fail "self-test: the deliberately unwrapped scratch copy did NOT fail verify_wrap -- the lint would not have caught the original incident"
fi
rm -rf "$SELFTEST_DIR"
trap - EXIT

echo ""
echo "==================================================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================================================="
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
