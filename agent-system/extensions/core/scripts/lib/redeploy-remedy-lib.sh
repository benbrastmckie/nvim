#!/usr/bin/env bash
# redeploy-remedy-lib.sh - Single home of the redeploy-remedy text repo-wide. Every runtime
# emission site that tells a reader "the .claude/ deploy tree is stale or missing something;
# regenerate it" composes its remedy from this file instead of carrying its own copy, so the
# remedy text (and the bounded-wait idiom a reader needs to run the regeneration safely) has
# exactly one definition.
#
# Exports TWO functions, for two different caller shapes:
#
#   (a) redeploy_remedy_fragment - the timeout-idiom clause ALONE, for a caller that already
#       has its own site-specific remedy sentence and only wants to APPEND the bounded-wait
#       guidance (e.g. `fail "$rel is missing" "$(redeploy_remedy_fragment)"`).
#   (b) redeploy_remedy - the FULL canonical remedy: the regeneration action plus the fragment,
#       for a site whose entire remedy text today is the identical picker-or-deploy-headless
#       boilerplate (e.g. `echo "  $(redeploy_remedy)" >&2`).
#
# Degrade-safe contract (the structural mitigation for the self-modification hazard this
# library's call sites carry -- see the plan this library was built under, Decision 1(c)):
# every caller sources this file through a guarded snippet, never a bare `source`/`.`:
#
#   _RR_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/redeploy-remedy-lib.sh"
#   [ -f "$_RR_LIB" ] && . "$_RR_LIB"
#   declare -F redeploy_remedy_fragment >/dev/null 2>&1 || redeploy_remedy_fragment() { printf '%s' ""; }
#
# A deploy tree that predates this library, or a partial deploy that is missing it, therefore
# falls back to an empty fragment (pre-change output) rather than a source-time failure. Several
# core scripts do not `set -e`, so an unguarded source of a missing file would print an error to
# stderr and continue in an undefined state -- precisely what this guard prevents. A caller using
# `redeploy_remedy` (not just the fragment) in its degrade path should keep its own pre-change
# remedy sentence as a literal fallback string; this library does not provide a degraded
# `redeploy_remedy` definition because the whole point of (b) is to BE the remedy sentence.
#
# Hard constraints on both functions' output (asserted by this library's own suite,
# tests/test-redeploy-remedy-lib.sh):
#   - contains the literal substring `deploy-headless.sh`
#   - begins NO physical line with `WARN:` (test-deploy-freshness.sh's STALE case asserts
#     exactly one `^WARN:` line; this library's output is always appended to an EXISTING line a
#     caller already started, never a new line of its own)
#   - emits no trailing newline (callers control their own line structure)
#   - contains no task-number reference
#
# Idempotent and side-effect-free on source: no `set -e`/`set -u`, no global variable writes
# beyond these two function definitions, safe to source twice.

redeploy_remedy_fragment() {
  printf 'Bounded-wait idiom required: timeout 540 bash .claude/scripts/deploy-headless.sh (Bash tool `timeout` parameter raised to 600000, NOT its 120000ms default) -- see context/patterns/external-process-wait.md Rule 1.'
}

redeploy_remedy() {
  printf 'regenerate via the picker'"'"'s [Reload All]/[Regenerate] entries, or bash .claude/scripts/deploy-headless.sh. %s' "$(redeploy_remedy_fragment)"
}
