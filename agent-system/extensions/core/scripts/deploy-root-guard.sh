#!/usr/bin/env bash
# Sourced by core scripts immediately after their SCRIPT_DIR / root computation.
#
# Those scripts resolve their repo root as "${SCRIPT_DIR}/../..", a depth that is correct ONLY
# in a deploy tree (.claude/scripts/ or .opencode/scripts/, two levels under the repo root). Run
# from the agent-system source store the same expression silently resolves to
# agent-system/extensions/ instead of failing, and the script then writes stray artifacts under
# a bogus root. This guard makes that invocation fail loudly instead, by default.
#
# Default path is a structural check only: no filesystem I/O, so it cannot false-negative on a
# fresh repo that has no specs/ yet or has loaded no extensions. Deliberately NOT
# `git rev-parse --show-toplevel` on this path, which would silently succeed by finding the true
# repo root and mask the invocation error.
#
# Opt-in self-correcting path: a caller that sets DEPLOY_ROOT_GUARD_SELF_CORRECT=1 before
# sourcing this guard is declaring itself eligible to run unmodified from EITHER tree, with no
# REPO_ROOT override required. On that opt-in, and only when the default structural check above
# already failed, the guard additionally tries `git -C "$__guard_dir" rev-parse --show-toplevel`
# and accepts the result as REPO_ROOT ONLY when `agent-system/extensions` exists directly under
# it -- the same directory an opted-in caller already requires for its own EXT_DIR default. This
# acceptance test is why a bare `git rev-parse --show-toplevel` remains the wrong default above:
# an unvalidated toplevel would mask a genuine invocation error (nested repo, submodule, detached
# checkout), whereas a candidate gated on the presence of `agent-system/extensions` cannot. A
# caller that does not opt in, or whose candidate root fails that test, sees today's refusal
# unchanged -- byte-identical message and exit status.
#
# Callers MUST use `. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1` — several callers do not
# set -e, so the `|| exit 1` is what makes a missing helper fail closed rather than continue. On
# the opt-in acceptance path this guard always completes with status 0, so that `|| exit 1` never
# fires for a successfully self-corrected caller.

__guard_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${__guard_dir%/*}" in
  */.claude | */.opencode)
    unset __guard_dir
    ;;
  *)
    __guard_self_corrected=0
    if [[ "${DEPLOY_ROOT_GUARD_SELF_CORRECT:-}" == "1" ]]; then
      __guard_candidate="$(cd "$__guard_dir" && git rev-parse --show-toplevel 2>/dev/null)" || __guard_candidate=""
      if [[ -n "$__guard_candidate" && -d "$__guard_candidate/agent-system/extensions" ]]; then
        REPO_ROOT="$__guard_candidate"
        __guard_self_corrected=1
      fi
      unset __guard_candidate
    fi
    if [[ "$__guard_self_corrected" == "1" ]]; then
      unset __guard_dir __guard_self_corrected DEPLOY_ROOT_GUARD_SELF_CORRECT
    else
      unset __guard_self_corrected
      # Degrade-safe guarded source (context/patterns/regeneration-is-manual-only.md's
      # "Redeploy-Remedy Emission Sites" subsection, Decision 1(c)): a missing lib falls back to
      # a no-op fragment rather than a source-time failure. Sibling-lib-relative only, reusing
      # __guard_dir (this file's own already-resolved directory) before it is unset above.
      __rr_lib="${__guard_dir}/lib/redeploy-remedy-lib.sh"
      # shellcheck source=lib/redeploy-remedy-lib.sh
      [ -f "$__rr_lib" ] && . "$__rr_lib"
      declare -F redeploy_remedy_fragment >/dev/null 2>&1 || redeploy_remedy_fragment() { printf '%s' ""; }
      echo "ERROR: ${0##*/} must run from a deployed scripts/ tree (.claude/scripts/ or" >&2
      echo "       .opencode/scripts/), not '${__guard_dir}'." >&2
      echo "       This looks like the agent-system source store, where '../..' resolves to a" >&2
      echo "       bogus repo root. Deploy first via <leader>al ('Reload All' / 'Regenerate') or" >&2
      echo "       'bash .claude/scripts/deploy-headless.sh', then run the deployed copy." >&2
      echo "       $(redeploy_remedy_fragment)" >&2
      exit 1
    fi
    ;;
esac
