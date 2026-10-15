#!/usr/bin/env bash
# gate-verdict-extract-lib.sh - Single home of the anchored, SGR-stripping verdict-line
# extraction helper consumed by verify-deploy.sh's gates when folding a producer script's output
# into FINDING rows.
#
# THE DEFECT THIS REPLACES. Every one of verify-deploy.sh's gate blocks previously extracted a
# producer's verdict lines with an UNANCHORED substring match: `grep -F '[FAIL]'` (or
# `grep -F '[VIOLATION]'`). That matches any line CONTAINING the literal token anywhere, not only
# a producer's own line-initial verdict row. Two breach classes were measured live against a real
# batch-gate run: a `[PASS]` narration line whose own message text happens to quote the token
# (e.g. "[PASS] case3: exactly one [FAIL] line for ...") was folded into a FINDING row; and an
# indented, fixture-internal `[FAIL] ...` line emitted by a suite's OWN inner output (not
# run-all.sh's verdict on that suite) was folded in too. Net effect on one real run: 13 "confirmed
# findings" where the true failing-suite count was 4, including a `[PASS]` row -- so a finding row
# could no longer be trusted to denote a failure at all.
#
# WHY A UNIFORM `grep -E '^\[FAIL\] '` IS NOT SUFFICIENT ON ITS OWN. run-all.sh's own
# `[FAIL] $suite_name` row (tests/run-all.sh, around its sequential and parallel result branches)
# is genuinely line-initial and uncolored, so a bare anchor is correct for Gate 8. But of the
# OTHER 13 extraction sites' producers, most emit their verdict row as
# `echo -e "${RED}[FAIL]${NC} $1"` / `echo -e "${RED}[VIOLATION]${NC} $1"` with NO TTY or NO_COLOR
# guard -- so the line begins with an ANSI SGR escape sequence (`\x1b[...m`), not the literal
# token. A bare line-start anchor would reject every one of those rows, silently converting a real
# gate into a zero-finding gate while looking like a hardening fix -- the mirror image of "a
# faster/stricter gate that checks less is a regression." The two-step shape below (strip SGR,
# THEN anchor) is what makes the anchor safe to apply uniformly across both color and no-color
# producers.
#
# CONTRACT (producer side, stated once here so neither side re-derives it independently -- see
# also context/standards/shell-script-testing.md's producer/consumer verdict-row contract):
#   - A producer's verdict row is line-initial modulo a leading SGR sequence: optionally
#     `\x1b[<params>m`, then the literal anchor token (`[FAIL]` or `[VIOLATION]`), then a single
#     space, then the message.
#   - A producer's NARRATION (as opposed to its verdict) uses a visibly distinct prefix, e.g.
#     run-all.sh's `[run-all] [PASS] $suite_name` -- never the bare anchor token at line start.
#   - A producer's own fixture-internal or nested output (e.g. a suite that deliberately prints
#     "[FAIL] ..." as part of exercising its OWN failure-handling assertions) is never line-initial
#     from THIS extraction's point of view, because it is indented/prefixed by the producer's own
#     capture formatting before this helper ever sees it as a candidate line -- the anchor rejects
#     it precisely because it is not at column 0 after SGR-stripping.
#
# CONTRACT (consumer side):
#   - The anchor token is ALWAYS an explicit parameter to this helper -- never inferred, never
#     defaulted. The `[FAIL]` and `[VIOLATION]` token sets used across verify-deploy.sh's 14
#     extraction sites are disjoint and per-producer; a helper that guessed the token from the
#     gate number or from output content would silently miss the actual contract broken here (an
#     unanchored, not-token-aware, match).
#
# Exports ONE function:
#
#   verify_deploy_extract_verdict_lines <anchor_token> <producer_output>
#     Strips ANSI SGR escape sequences from each line of <producer_output>, selects only the
#     lines that then begin with "<anchor_token> " (anchor token followed by exactly one space),
#     strips that prefix, and prints the remainder of each selected line to stdout, one per line,
#     in the original relative order. Never calls `exit`. Sets no shell options a caller
#     inherits. Unsets its own internal variables before returning. Always returns 0 -- a miss
#     (no lines selected) is signalled by empty stdout, never a non-zero exit status, matching
#     every other sourced lib in this directory (see manifest-routing-lib.sh's header).
#
#   Usage:
#     while IFS= read -r line; do
#       FINDINGS_LIST+=("FINDING gate8 $line")
#     done < <(verify_deploy_extract_verdict_lines '[FAIL]' "$run_all_output")
#
# Rejected alternatives (do not re-propose):
#   - Inferring the anchor token from the gate number or from a per-gate lookup table: couples
#     this helper to verify-deploy.sh's gate numbering, which the plan this helper serves
#     explicitly renumbers/migrates in a later phase. The token must travel with the call site.
#   - Stripping SGR only when a producer is known to color its output: requires a maintained
#     per-producer allowlist that silently drifts the moment a producer gains or loses color
#     (exactly the fragility this helper exists to remove). Stripping unconditionally is a no-op
#     on already-plain text and correct on colored text, so there is no reason to special-case it.
#   - Matching `grep -E '\[FAIL\]'` without the leading `^` anchor (today's defect) or without the
#     trailing space (would also match `[FAILURE]`-shaped tokens, or `[FAIL]word` with no
#     separator): both reopen a substring-style false positive this helper exists to close.

verify_deploy_extract_verdict_lines() {
  local _gvel_token="$1"
  local _gvel_output="$2"
  local _gvel_anchor_ere

  if [ -z "$_gvel_token" ]; then
    unset _gvel_token _gvel_output _gvel_anchor_ere
    return 0
  fi

  # Build the anchored ERE: literal token, regex-escaped, then a literal trailing space.
  # sed-based escaping of ERE metacharacters in the token (token is always a bracketed literal
  # like "[FAIL]" or "[VIOLATION]" at every current call site, but this stays generic).
  _gvel_anchor_ere="^$(printf '%s' "$_gvel_token" | sed -e 's/[.[\*^$()+?{|]/\\&/g')"'[[:space:]]'

  printf '%s\n' "$_gvel_output" | sed -E 's/\x1b\[[0-9;]*m//g' | grep -E "$_gvel_anchor_ere" | \
    sed -E "s/$_gvel_anchor_ere//"

  unset _gvel_token _gvel_output _gvel_anchor_ere
  return 0
}
