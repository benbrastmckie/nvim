#!/usr/bin/env bash
# lean-comparator-landrun-shim.sh -- the landrun lean-comparator-run.sh points Comparator at.
#
# INTERNAL: Comparator execs this in place of `landrun` when it builds its own internal
# `lake build` sandbox call; it is never run by hand as part of an ordinary invocation.
#
# This shim execs the real `landrun` with Comparator's own arguments, unchanged and in order,
# plus the extra grants Comparator's own sandbox omits but a NixOS host's build needs:
#   - TMPDIR pointed inside the writable .lake directory, because bv_decide writes SAT files to
#     /tmp, which the outer sandbox makes read-only.
#   - One --rox grant per shared library `ldd` reports for the resolved `git` binary, because
#     Lake treats a package whose remote it cannot read as moved and deletes
#     .lake/packages/<dep> -- git needs to actually run inside the sandbox for the pre-flight
#     probe (see lean-comparator-run.sh's outer-landrun layer) and for any Lake operation that
#     shells out to it.
#   - An --rox grant on the pinned toolchain's `lake` ELF interpreter (on NixOS this is nix-ld,
#     which landrun's own -ldd auto-discovery does not find, so the exec of `lake` itself would
#     otherwise be denied before Lake ever starts).
#
# Full design record (why COMPARATOR_LANDRUN is the only injection point into this argument
# vector, and the TMPDIR/git-library/ELF-interpreter rationale in full):
#   agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md
#
# Env var overrides (this extension's own naming, matching lean-comparator-run.sh's
# LEAN_COMPARATOR_RUN_GUARD_BIN convention):
#   LEAN_COMPARATOR_RUN_REAL_LANDRUN
#                        Overrides a bare `landrun` PATH lookup for the real binary this shim
#                        execs. A test seam: lets this shim be exercised with no real landrun
#                        present on PATH.
#   LEAN_COMPARATOR_RUN_LAKE_DIR
#                        When set, prepended to PATH inside the shim (not by the caller) -- see
#                        the PATH-prepend note below for why this must happen here.
#   LEAN_COMPARATOR_RUN_SHIM_LOG
#                        When set, each invocation appends an `extra <grants>` line and a
#                        `comparator <args>` line to it, so a caller (or this suite's regression
#                        cases) can assert on the actual argv without reading source.
#
# Usage: internal only -- Comparator supplies its own landrun argv; this script never takes CLI
# arguments of its own beyond the -h/--help short-circuit below.
# Requires: bash, git, ldd. readelf is optional (its absence only skips the ELF-interpreter
# grant, never a hard failure). Exit: the real landrun's exit code (0 for -h/--help).

set -u

# Comparator's own first argument is always a landrun flag, never -h/--help; answer the flag
# without side effects (mkdir, ldd, readelf) so `--help` stays cheap and safe to run by hand.
case "${1:-}" in
  -h|--help)
    awk 'NR > 2 && !/^#/ { exit } NR > 2 { sub(/^# ?/, ""); print }' "$0"
    exit 0
    ;;
esac

# TMPDIR inside the writable .lake directory: bv_decide writes SAT files to /tmp, which the outer
# sandbox (lean-comparator-run.sh's landrun layer) makes read-only. $PWD here is the sandboxed
# process's own working directory (the clean-room WORKDIR), which the outer sandbox already
# grants read-write on, so no new write access is introduced by this grant -- only a redirection
# of where a write Comparator's internal build already needs lands.
tmp="$PWD/.lake/tmp"
mkdir -p "$tmp"
extra=(--env "TMPDIR=$tmp")

# git shared-library grants: Lake treats a package whose remote it cannot read as moved and
# deletes .lake/packages/<dep>: git itself must be executable, which needs its own shared
# libraries granted (Comparator's sandbox grants execute on git the binary, not on its `ldd`
# closure).
git_bin="$(command -v git 2>/dev/null || true)"
if [ -n "$git_bin" ]; then
  git_bin="$(realpath "$git_bin")"
  for lib in $(ldd "$git_bin" 2>/dev/null | grep -oE '/[^ ]+\.so[^ ]*' | LC_ALL=C sort -u); do
    extra+=(--rox "$lib")
  done
fi

# LEAN_COMPARATOR_RUN_LAKE_DIR: lean-comparator-run.sh sets this when the pinned toolchain's
# `lake` is an elan-wrapper shell script rather than the real ELF binary (see that script's
# elan-unwrapping step); it names a private directory holding a `lake` symlink to the real
# binary. This prepend MUST happen HERE, inside the shim, rather than by the caller setting PATH
# before invoking Comparator: `lake env` reorders PATH, putting the toolchain's own bin directory
# back in front of whatever PATH the caller set, so any ordering decided outside this shim would
# be undone by the time Comparator's internal `lake build` runs.
if [ -n "${LEAN_COMPARATOR_RUN_LAKE_DIR:-}" ]; then
  PATH="$LEAN_COMPARATOR_RUN_LAKE_DIR:$PATH"
  export PATH
fi

# ELF-interpreter grant for the pinned toolchain's `lake`: on NixOS its interpreter is nix-ld,
# which landrun's own -ldd auto-discovery does not find (it is not one of `lake`'s DT_NEEDED
# shared libraries), so the exec of `lake` itself is denied before Lake ever starts. Guarded on
# `readelf` being present: its absence only skips this one grant, never a hard failure.
lake_bin="$(command -v lake 2>/dev/null || true)"
if [ -n "$lake_bin" ] && command -v readelf >/dev/null 2>&1; then
  interp="$(readelf -l "$lake_bin" 2>/dev/null | sed -n 's/.*program interpreter: \(.*\)\]$/\1/p')"
  if [ -n "$interp" ] && [ -e "$interp" ]; then
    extra+=(--rox "$(realpath "$interp")")
  fi
fi

if [ -n "${LEAN_COMPARATOR_RUN_SHIM_LOG:-}" ]; then
  printf 'extra %s\n' "${extra[*]}" >> "$LEAN_COMPARATOR_RUN_SHIM_LOG"
  printf 'comparator %s\n' "$*" >> "$LEAN_COMPARATOR_RUN_SHIM_LOG"
fi

real_landrun="${LEAN_COMPARATOR_RUN_REAL_LANDRUN:-}"
if [ -z "$real_landrun" ]; then
  real_landrun="$(command -v landrun 2>/dev/null || true)"
fi
if [ -z "$real_landrun" ]; then
  echo "lean-comparator-landrun-shim.sh: real 'landrun' not found on PATH; set LEAN_COMPARATOR_RUN_REAL_LANDRUN to its absolute path to override" >&2
  exit 1
fi

exec "$real_landrun" "${extra[@]}" "$@"
