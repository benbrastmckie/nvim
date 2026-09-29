#!/usr/bin/env bash
# Vendored verbatim from leanprover/comparator (Apache-2.0), scripts/fake-landrun.sh,
# commit 2312244ac716564a61cc0bf4e107d9abf1757a61 (2026-08-30). See fixtures/comparator/README.md for full provenance.
#
# insecure and vibesick landrun shim that doesn't sandbox
# don't use if you want any security obviously, intended for development on 
# systems that don't support landrun (i.e. OSX)

set -euo pipefail

# Flags that take a value (consume the next arg).
# Add more here if anything's missing.
flags_with_value=(
  --ro --rox --rw --rwx
  --bind-tcp --connect-tcp
  --log-level
  --env
)

is_value_flag() {
  local f="$1"
  for vf in "${flags_with_value[@]}"; do
    [[ "$f" == "$vf" ]] && return 0
  done
  return 1
}

# Handle subcommands / help / version like the real binary. Sorta.
case "${1:-}" in
  -h|--help)
    cat <<'EOF'
fake landrun shim/fake/stub - does nothing, runs your command unsandboxed

Usage: landrun [flags] <command> [args...]

Flags are accepted and ignored.
EOF
    exit 0
    ;;
  -V|--version)
    echo "XXX NOT LANDRUN, FAKE SHIM XXX" >&2
    exit 0
    ;;
esac

# Parse and discard landrun's own flags until we hit `--` or a non-flag token.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --) shift; break ;; # End of flags
    -*)
      # Drop twice if it's a value-taking flag, always drop once
      is_value_flag "$1" && shift
      shift
      ;;
    *) break ;; # First non-flag token is the command to run
  esac
done

if [[ $# -eq 0 ]]; then
  echo "landrun shim: no command given" >&2
  exit 2
fi

echo "WARNING: THIS IS NOT REAL LANDRUN! UNSAFELY RUNNING exec $*" >&2
exec "$@"
