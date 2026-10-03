#!/usr/bin/env bash
# books-certify.sh -- resolve-and-passthrough wrapper for the consuming repository's book
# certification driver.
#
# PURPOSE. The `books` extension's `/certify` command needs to name a real, invocable script in
# its own docs (agents/skills/commands/README.md/EXTENSION.md), but the real certifier
# (`books/scripts/certify.sh` in the consuming repository) is not this extension's own file --
# it belongs to whatever repository the extension is deployed into, and `check-extension-docs.sh`
# Rule E (check_referenced_scripts_declared) hard-fails on any bare `<name>.sh` token in those
# five doc locations that is not declared in some extension's provides.scripts/provides.hooks.
# This script is the ONE extension-local script declared in provides.scripts specifically to
# satisfy that constraint: it resolves the repository root, locates the real driver under
# `books/scripts/`, and forwards every argument verbatim.
#
# The acceptance-suite-only graph-injection flag (`--graph-from FILE`) is deliberately NOT
# forwarded: it exists only to exercise a dependency-cycle detection path that cannot be
# constructed from real Lean source (Lean's import graph is acyclic by construction), and is
# reserved for the certifier's own acceptance suite, not for ordinary invocation through this
# extension.
#
# Usage:
#   books-certify.sh [OPTIONS] [ROOT]...
#
# All OPTIONS and ROOT arguments are forwarded verbatim to the real driver EXCEPT --graph-from,
# which is refused here (loud failure, exit 2) before any forwarding happens.
#
# Exit codes:
#   Whatever the real driver exits with (0 every book certified, 1 a book was refused or a build
#   failed, 2 usage error) when it is found and invoked.
#   2 - usage error: a refused flag (--graph-from) was passed.
#   3 - the real driver could not be found under the resolved repository root (the extension may
#       be loaded in a repository that has no books tooling).
#
# No interactive prompts.

set -euo pipefail

# ─── Resolve the repository root ───────────────────────────────────────────────────────────────
# Prefer git's own notion of the toplevel (works from any cwd inside the repo); fall back to the
# current working directory when not inside a git repository at all.
repo_root=""
if repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
  :
else
  repo_root="$(pwd)"
fi

driver="${repo_root}/books/scripts/certify.sh"

# ─── Refuse the acceptance-suite-only graph-injection flag before any forwarding ───────────────
for arg in "$@"; do
  if [ "$arg" = "--graph-from" ]; then
    echo "books-certify.sh: --graph-from is reserved for the certifier's own acceptance suite" \
      "and is not forwarded by this wrapper." >&2
    exit 2
  fi
done

# ─── Fail loudly, actionably, when the real driver is absent ──────────────────────────────────
if [ ! -f "$driver" ]; then
  echo "books-certify.sh: no book certification driver found at '${driver}'." >&2
  echo "  This repository does not appear to have the books/ tooling tree, or the repository" >&2
  echo "  root resolved to '${repo_root}', which is not the books-tooling repository's root." >&2
  echo "  Run this command from inside the repository that carries books/scripts/certify.sh," >&2
  echo "  or confirm the tree has been checked out." >&2
  exit 3
fi

exec bash "$driver" "$@"
