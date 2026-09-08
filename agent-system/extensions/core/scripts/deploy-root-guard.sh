#!/usr/bin/env bash
# Sourced by core scripts immediately after their SCRIPT_DIR / root computation.
#
# Those scripts resolve their repo root as "${SCRIPT_DIR}/../..", a depth that is correct ONLY
# in a deploy tree (.claude/scripts/ or .opencode/scripts/, two levels under the repo root). Run
# from the agent-system source store the same expression silently resolves to
# agent-system/extensions/ instead of failing, and the script then writes stray artifacts under
# a bogus root. This guard makes that invocation fail loudly instead.
#
# Structural check only: no filesystem I/O, so it cannot false-negative on a fresh repo that has
# no specs/ yet or has loaded no extensions. Deliberately NOT `git rev-parse --show-toplevel`,
# which would silently succeed by finding the true repo root and mask the invocation error.
#
# Callers MUST use `. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1` — several callers do not
# set -e, so the `|| exit 1` is what makes a missing helper fail closed rather than continue.

__guard_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${__guard_dir%/*}" in
  */.claude | */.opencode)
    unset __guard_dir
    ;;
  *)
    echo "ERROR: ${0##*/} must run from a deployed scripts/ tree (.claude/scripts/ or" >&2
    echo "       .opencode/scripts/), not '${__guard_dir}'." >&2
    echo "       This looks like the agent-system source store, where '../..' resolves to a" >&2
    echo "       bogus repo root. Deploy first via <leader>al ('Reload All' / 'Regenerate') or" >&2
    echo "       'bash .claude/scripts/deploy-headless.sh', then run the deployed copy." >&2
    exit 1
    ;;
esac
