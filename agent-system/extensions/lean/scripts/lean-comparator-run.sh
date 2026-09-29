#!/usr/bin/env bash
# lean-comparator-run.sh -- clean-room wrapper CLI around the upstream leanprover/comparator
# judge (Apache-2.0, github.com/leanprover/comparator).
#
# Given a trusted Challenge module, an untrusted Solution module, a theorem-name list and an
# axiom whitelist, this script:
#   (a) materialises a clean-room checking environment (a fresh `git worktree add` of the
#       target project, pre-populated `.lake/` via `lake exe cache get`, BEFORE the Solution
#       module is ever written into it -- see the design record for the full trust-chain
#       reasoning),
#   (b) invokes Comparator inside the upstream README's mandated `systemd-run` sandbox wrapper,
#       nested around `lake-build-guard.sh` for concurrency/memory-pressure serialisation against
#       ordinary agent builds of the same project,
#   (c) synthesises Comparator's `config.json` from this script's own CLI arguments,
#   (d) bounds the run with `--timeout` and serialises it against
#       core/scripts/lake-build-guard.sh (never a second, competing concurrency guard),
#   (e) recovers a closed, machine-readable verdict from Comparator's unstructured stdout/stderr
#       (Comparator itself exposes only a binary exit code -- see classify_verdict() below).
#
# Full design record (clean-room trust chain, verdict-string table with upstream source
# citations, C3 version-coupling caveat, advisory-only gate decision):
#   agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md
#
# GATE STRENGTH: this script's verdict is ADVISORY ONLY. It is a standalone CLI, not wired into
# any completion gate by this script or by anything else in this source tree. A rejection verdict
# from this script MUST NOT be interpreted by a caller as grounds to set verification_passed
# false, downgrade a task's status, or block completion -- that promotion is a separate, later,
# not-yet-made decision.
#
# Usage:
#   lean-comparator-run.sh --project-root DIR --challenge-module NAME --solution-module NAME \
#     --theorems NAME[,NAME...] --permitted-axioms NAME[,NAME...] \
#     [--definitions NAME[,NAME...]] [--commit REF] [--timeout SECS] [--keep-workdir] \
#     [--enable-nanoda] [--external-kernels SPEC] [--json]
#
# Required:
#   --project-root DIR        Path to the target Lean project (a git repo, checked out at some
#                              commit) containing the Challenge and Solution modules.
#   --challenge-module NAME   The Comparator config's `challenge_module` (a Lean module name,
#                              e.g. `Challenge`).
#   --solution-module NAME    The Comparator config's `solution_module` (e.g. `Solution`).
#   --theorems NAME[,...]     Comma-separated `theorem_names` to verify.
#   --permitted-axioms NAME[,...]
#                              Comma-separated axiom whitelist (`permitted_axioms`). May be empty
#                              (pass an empty string) to permit no axioms beyond the kernel's own.
#
# Optional:
#   --definitions NAME[,...]  `definition_names` -- declarations Comparator should ALSO compare
#                              structurally. A non-empty list downgrades an otherwise-`verified`
#                              result to `definition_hole_needs_human` (see the design record's
#                              gaming example) -- Comparator's checks do not evaluate whether a
#                              filled-in definition hole is a LEGITIMATE answer, only that both
#                              sides match each other and the kernel accepts the replay.
#   --commit REF               Commit/ref to check out into the clean-room worktree. Default:
#                              HEAD of --project-root at invocation time.
#   --timeout SECS             Wall-clock budget for the sandboxed Comparator run. Default: 1800
#                              (30 minutes) -- Comparator runs two full sandboxed builds plus two
#                              exports plus a kernel replay (constraint C4); 30 minutes is enough
#                              headroom for a small-to-medium Mathlib-dependent project without
#                              letting a genuinely hung run block a caller indefinitely.
#   --keep-workdir             Do not remove the clean-room worktree/workdir on exit (default:
#                              removed via a trap, including on error).
#   --enable-nanoda            Sets `enable_nanoda: true` in the synthesised config. Mutually
#                              exclusive with --external-kernels (Comparator throws if both are
#                              set) -- this script rejects that combination as a usage error
#                              (exit 64) rather than letting Comparator discover it.
#   --external-kernels SPEC    Raw JSON object literal for the config's `external_kernels` field
#                              (a map from kernel name to its invocation argv array), e.g.
#                              '{"nanoda": ["nanoda_bin", "check"]}'. Mutually exclusive with
#                              --enable-nanoda.
#   --json                     Emit the verdict record as one JSON object instead of key: value
#                              lines.
#
# Env var overrides (Comparator's OWN names, carried through unchanged -- not invented here):
#   COMPARATOR_BIN             Path to the `comparator` binary itself (this script's own name;
#                              upstream has no need to override its own binary). Falls back to a
#                              bare `comparator` PATH lookup.
#   COMPARATOR_LANDRUN         Overrides a bare `landrun` PATH lookup for the REAL binary this
#                              script resolves. The value actually forwarded to Comparator's own
#                              internal build (its own COMPARATOR_LANDRUN env var, read inside the
#                              sandbox) is NOT this real binary directly -- it is
#                              lean-comparator-landrun-shim.sh, which execs this resolved real
#                              landrun with Comparator's own arguments unchanged plus the grants
#                              Comparator's own sandbox omits (TMPDIR inside .lake, git shared
#                              libraries, the pinned toolchain's ELF interpreter). See
#                              LEAN_COMPARATOR_RUN_LANDRUN_SHIM_BIN and
#                              LEAN_COMPARATOR_RUN_REAL_LANDRUN below, and the design record.
#   COMPARATOR_LEAN4EXPORT     Overrides a bare `lean4export` PATH lookup. MUST NOT be defaulted
#                              to a path inside a Comparator checkout by any caller -- see the
#                              design record's C3 version-coupling caveat: `lean4export` must
#                              match the TARGET project's Lean version, not Comparator's own
#                              v4.34.0-rc2.
#   COMPARATOR_NANODA          Overrides a bare `nanoda_bin` PATH lookup (only resolved when
#                              --enable-nanoda is passed, or --external-kernels names a kernel
#                              whose name contains "noda").
#   LEAN_COMPARATOR_RUN_GUARD_BIN
#                              Overrides the dirname-relative-sibling lookup for
#                              core/scripts/lake-build-guard.sh (a test seam; the two scripts ship
#                              from different source-store extensions but land as literal
#                              siblings only post-deploy in .claude/scripts/).
#   LEAN_COMPARATOR_RUN_LANDRUN_SHIM_BIN
#                              Overrides the dirname-relative-sibling lookup for
#                              lean-comparator-landrun-shim.sh (a test seam; same sibling
#                              convention as LEAN_COMPARATOR_RUN_GUARD_BIN above).
#   LEAN_COMPARATOR_RUN_REAL_LANDRUN
#                              Forwarded into the sandbox so the shim (above) knows the real
#                              landrun binary to exec. Set internally by this script from its own
#                              resolved LANDRUN_PATH; not meant to be set by a caller of this
#                              script (set COMPARATOR_LANDRUN instead, which this script reads).
#   LEAN_COMPARATOR_RUN_LAKE_DIR
#                              Forwarded into the sandbox when the pinned toolchain's `lake` is
#                              an elan-wrapper shell script: the private per-run directory holding
#                              the unwrapped `lake` symlink, which the shim re-prepends onto PATH
#                              because `lake env` (Comparator's own internal invocation) reorders
#                              PATH ahead of anything this script sets outside the sandbox.
#
# Output (always, to stdout, on exit): a verdict record -- key: value lines by default, or a
# single JSON object under --json. Fields: `verdict`, `reason_detail` (optional), and
# `underlying_verdict` (optional, only present for `definition_hole_needs_human`), `message`.
#
# Verdict vocabulary and exit codes (see the design record for the full upstream-source-cited
# string table):
#   verified                       0   Comparator printed "Your solution is okay!" and exited 0.
#   statement_mismatch             65  Statement/kind/const-closure mismatch between Challenge
#                                      and Solution.
#   axiom_violation                66  A named theorem's body transitively reaches an axiom
#                                      outside --permitted-axioms.
#   kernel_rejected                67  The Lean kernel (or an external kernel) rejected the
#                                      Solution's replay.
#   definition_hole_needs_human    68  Comparator exited 0 AND --definitions was non-empty;
#                                      `underlying_verdict: verified` is also carried.
#   comparator_unavailable         69  A required binary could not be resolved, or the sandbox
#                                      wrapper (systemd-run) is unusable. `message` names the
#                                      missing binary/capability and, when applicable, its
#                                      override env var.
#   timeout                        70  The sandboxed run exceeded --timeout.
#   config_error                   71  Comparator reported a name in --theorems/--definitions
#                                      absent from one side (an authoring error, not a security
#                                      finding).
#   unclassified_failure           72  INTERNAL escape hatch, distinct from the 8 named
#                                      categories above: Comparator exited non-zero (or
#                                      unexpectedly 0) with output matching NONE of the known
#                                      verdict strings. Never silently reported as `verified` --
#                                      a checker that can only ever say "pass" is not a checker.
#   (usage error)                  64  Bad CLI arguments. Matches lean-sorry-census.sh's own
#                                      convention. 75-79 is reserved by lake-build-guard.sh and
#                                      MUST NOT be reused here.
#
# Exit codes: see the verdict table above; 64 on usage error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

PROJECT_ROOT=""
COMMIT_REF="HEAD"
CHALLENGE_MODULE=""
SOLUTION_MODULE=""
THEOREMS=""
PERMITTED_AXIOMS=""
DEFINITIONS=""
ENABLE_NANODA=0
EXTERNAL_KERNELS=""
TIMEOUT_SECS=1800
KEEP_WORKDIR=0
JSON_OUTPUT=0

# ---------------------------------------------------------------------------
# Usage / verdict emission
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: lean-comparator-run.sh --project-root DIR --challenge-module NAME \
  --solution-module NAME --theorems NAME[,NAME...] --permitted-axioms NAME[,NAME...] \
  [--definitions NAME[,NAME...]] [--commit REF] [--timeout SECS] [--keep-workdir] \
  [--enable-nanoda] [--external-kernels SPEC] [--json]

See the header comment in this script for the full option/env-var/verdict reference, or
agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md for the
design record.
EOF
}

die_usage() {
  echo "lean-comparator-run.sh: $1" >&2
  usage >&2
  exit 64
}

# verdict_exit_code <verdict-name> -- the single place the closed vocabulary's exit codes are
# assigned. Never reuse 75-79 (reserved by lake-build-guard.sh).
verdict_exit_code() {
  case "$1" in
    verified) echo 0 ;;
    statement_mismatch) echo 65 ;;
    axiom_violation) echo 66 ;;
    kernel_rejected) echo 67 ;;
    definition_hole_needs_human) echo 68 ;;
    comparator_unavailable) echo 69 ;;
    timeout) echo 70 ;;
    config_error) echo 71 ;;
    # unclassified_failure is a 9th, INTERNAL escape-hatch verdict -- distinct from the 8 named
    # categories the design record settles on -- for the fail-closed fallthrough in
    # classify_verdict(): a non-zero (or unexpectedly bare-0) Comparator exit matching none of
    # the known verdict strings must never be reported as verified or comparator_unavailable. A
    # checker that can only ever say "pass" is not a checker.
    unclassified_failure) echo 72 ;;
    *)
      echo "lean-comparator-run.sh: internal error: unknown verdict '$1'" >&2
      echo 1
      ;;
  esac
}

# emit_verdict <verdict> [reason_detail] [underlying_verdict] [message] -- the single verdict
# emitter. Prints the machine-readable record (key: value lines by default, one JSON object
# under --json) and exits with the verdict's assigned code. Never returns.
emit_verdict() {
  local verdict="$1" reason_detail="${2:-}" underlying="${3:-}" message="${4:-}" code
  code="$(verdict_exit_code "$verdict")"
  if [ "$JSON_OUTPUT" -eq 1 ]; then
    VERDICT="$verdict" REASON_DETAIL="$reason_detail" UNDERLYING="$underlying" MESSAGE="$message" python3 - <<'PYEOF'
import json
import os

record = {"verdict": os.environ.get("VERDICT", "")}
reason_detail = os.environ.get("REASON_DETAIL", "")
underlying = os.environ.get("UNDERLYING", "")
if reason_detail:
    record["reason_detail"] = reason_detail
if underlying:
    record["underlying_verdict"] = underlying
record["message"] = os.environ.get("MESSAGE", "")
print(json.dumps(record))
PYEOF
  else
    echo "verdict: $verdict"
    [ -n "$reason_detail" ] && echo "reason_detail: $reason_detail"
    [ -n "$underlying" ] && echo "underlying_verdict: $underlying"
    echo "message: $message"
  fi
  exit "$code"
}

# fail_unavailable <capability-name> <override-var-or-empty> -- always a comparator_unavailable
# verdict, naming both the missing capability and (when applicable) the env var that would
# override its resolution. Never a skipped check that reads as a pass.
fail_unavailable() {
  local what="$1" override_var="${2:-}" msg
  if [ -n "$override_var" ]; then
    msg="required binary '$what' not found on PATH; set $override_var to its absolute path to override"
  else
    msg="required capability '$what' is unavailable or unusable"
  fi
  emit_verdict comparator_unavailable "" "" "$msg"
}

# ---------------------------------------------------------------------------
# Binary / capability resolution
# ---------------------------------------------------------------------------

# have_systemd_run -- reuses lake-build-guard.sh's own probe pattern: a REAL invocation, not just
# `command -v`, because presence of the binary does not imply user-scope cgroup delegation.
have_systemd_run() {
  command -v systemd-run >/dev/null 2>&1 || return 1
  systemd-run --user --scope --quiet --collect -- true >/dev/null 2>&1
}

# resolve_binary <override-var-name> <path-lookup-name> -- prints the resolved absolute path on
# stdout and returns 0, or prints nothing and returns 1. An override variable that is set but not
# executable is a resolution FAILURE (not a silent fall-through to PATH) -- a caller who set the
# override clearly meant a specific binary, and falling through would look successful while
# routing to a different, unintended binary.
resolve_binary() {
  local override_var="$1" path_name="$2" override_val
  override_val="${!override_var:-}"
  if [ -n "$override_val" ]; then
    if [ -x "$override_val" ]; then
      echo "$override_val"
      return 0
    fi
    return 1
  fi
  command -v "$path_name" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Clean-room materialisation (dispatch item (a)) -- see the design record
# (agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md) for the
# full trust-chain reasoning behind this exact sequence: fresh worktree, THEN `lake exe cache
# get`, THEN (only if needed) lakefile synthesis and config.json -- never the reverse.
# ---------------------------------------------------------------------------

ABS_PROJECT_ROOT=""
WORKDIR=""

# lakefile_declares_lib <dir> <lib-name> -- true if <dir>'s lakefile already declares <lib-name>
# as a lean_lib target (either lakefile.toml or lakefile.lean shape).
lakefile_declares_lib() {
  local dir="$1" name="$2"
  if [ -f "$dir/lakefile.toml" ]; then
    grep -qE "^[[:space:]]*name[[:space:]]*=[[:space:]]*\"${name}\"[[:space:]]*\$" "$dir/lakefile.toml" 2>/dev/null
  elif [ -f "$dir/lakefile.lean" ]; then
    grep -qE "lean_lib[[:space:]]+\`?${name}\b" "$dir/lakefile.lean" 2>/dev/null
  else
    return 1
  fi
}

cleanup_workdir() {
  [ -n "$WORKDIR" ] && [ -d "$WORKDIR" ] || return 0
  if [ -n "$ABS_PROJECT_ROOT" ] && git -C "$ABS_PROJECT_ROOT" worktree remove --force "$WORKDIR" >/dev/null 2>&1; then
    return 0
  fi
  rm -rf "$WORKDIR"
}

clean_room_setup() {
  ABS_PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)" || \
    emit_verdict comparator_unavailable "" "" "could not resolve --project-root '$PROJECT_ROOT' to an absolute path"

  if ! git -C "$ABS_PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    emit_verdict comparator_unavailable "" "" "--project-root '$ABS_PROJECT_ROOT' is not a git repository; the clean-room route requires 'git worktree add' (see the design record)"
  fi

  WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/lean-comparator-run.XXXXXX")"
  # `git worktree add` requires the target path to not already exist as a non-empty directory;
  # mktemp -d creates it empty, which `git worktree add <path> <ref>` accepts.
  local worktree_log
  worktree_log="$(mktemp)"
  if ! git -C "$ABS_PROJECT_ROOT" worktree add --detach --quiet "$WORKDIR" "$COMMIT_REF" >"$worktree_log" 2>&1; then
    local err
    err="$(cat "$worktree_log")"
    rm -f "$worktree_log"
    rmdir "$WORKDIR" 2>/dev/null || true
    emit_verdict comparator_unavailable "" "" "git worktree add failed for commit '$COMMIT_REF' of '$ABS_PROJECT_ROOT': $err"
  fi
  rm -f "$worktree_log"

  if [ "$KEEP_WORKDIR" -eq 0 ]; then
    trap cleanup_workdir EXIT
  fi

  # Populate .lake BEFORE anything else is written into the worktree -- the clean-room ordering
  # from the design record. Non-fatal on failure: a project with no `cache` executable (no
  # Mathlib-style cache target) is expected to fail here, and forcing a from-source rebuild
  # inside the sandbox is slower (compounds C4) but does not by itself violate the clean-room
  # guarantee -- the worktree is still one that has never compiled Solution.
  local cache_log="$WORKDIR/.lean-comparator-cache-get.log"
  if ! ( cd "$WORKDIR" && lake exe cache get ) >"$cache_log" 2>&1; then
    echo "lean-comparator-run.sh: WARNING: 'lake exe cache get' failed or is unavailable for '$ABS_PROJECT_ROOT' (see $cache_log); proceeding without a prebuilt .lake -- the sandboxed build will build from source, which is slower (compounds cost constraint C4) but does not by itself violate the clean-room guarantee." >&2
  fi

  # Defensive: ensure the checking environment uses the TARGET project's own lean-toolchain,
  # never Comparator's own (C3). `git worktree add` already checks out any git-TRACKED
  # lean-toolchain automatically; this copy is a defensive belt-and-suspenders step for the case
  # it is untracked in this project.
  if [ -f "$ABS_PROJECT_ROOT/lean-toolchain" ]; then
    cp -f "$ABS_PROJECT_ROOT/lean-toolchain" "$WORKDIR/lean-toolchain"
  else
    echo "lean-comparator-run.sh: WARNING: no lean-toolchain found at '$ABS_PROJECT_ROOT'; the sandboxed build will resolve lean/lake however elan/PATH ordinarily would for this directory, which is NOT guaranteed to match any specific target version." >&2
  fi

  # Synthesise a Comparator-shaped lakefile ONLY if the project does not already declare
  # CHALLENGE_MODULE/SOLUTION_MODULE as lean_lib targets. This generalises upstream
  # runtests.lean's exact generated SHAPE (name = "comparatortest", two [[lean_lib]] blocks) to
  # this runner's arbitrary --challenge-module/--solution-module names, rather than hardcoding
  # upstream's literal "Challenge"/"Solution" strings -- upstream's own harness never takes
  # arbitrary module names, so there is no literal precedent to match beyond the shape itself.
  if ! lakefile_declares_lib "$WORKDIR" "$CHALLENGE_MODULE" || ! lakefile_declares_lib "$WORKDIR" "$SOLUTION_MODULE"; then
    cat > "$WORKDIR/lakefile.toml" <<EOF
name = "comparatortest"
version = "0.1.0"

[[lean_lib]]
name = "$SOLUTION_MODULE"

[[lean_lib]]
name = "$CHALLENGE_MODULE"
EOF
  fi
}

# ---------------------------------------------------------------------------
# Toolchain resolution (Fix 1) -- resolves the WORKTREE's own pinned toolchain bin/ directory
# (never the caller's ambient one) and unwraps an elan-shell-wrapper `lake` to the real binary.
# Must run AFTER clean_room_setup() so `lean --print-prefix` reflects the worktree's own
# lean-toolchain (git worktree add already checked it out; clean_room_setup's defensive copy
# covers the case it is untracked). This resolution itself runs OUTSIDE any sandbox -- landrun
# denials do not apply here -- so an ordinary elan/PATH lookup of `lean` is expected to work
# even before the PATH-ordering fix below is in place.
# ---------------------------------------------------------------------------

TOOLCHAIN_BIN=""
LAKE_DIR=""

resolve_toolchain() {
  local prefix
  prefix="$(cd "$WORKDIR" && lean --print-prefix 2>/dev/null)" || true
  [ -n "$prefix" ] || \
    emit_verdict comparator_unavailable "" "" "'lean --print-prefix' failed or produced no output inside the clean-room worktree; the pinned toolchain may not be installed"
  TOOLCHAIN_BIN="$prefix/bin"
  [ -d "$TOOLCHAIN_BIN" ] || \
    emit_verdict comparator_unavailable "" "" "resolved toolchain bin directory '$TOOLCHAIN_BIN' (from 'lean --print-prefix') does not exist"

  # Elan-wrapper case: nixpkgs' elan renames the toolchain's real `lake` binary to `lake.orig`
  # and writes a bash wrapper named `lake` (runs dirname, then execs lake.orig with LEAN_CC
  # preset). A shell script has no ELF interpreter of its own for landrun's -ldd probe to grant,
  # so the sandboxed exec of the wrapper is denied before Lake ever starts ("lake: Permission
  # denied") -- not a missing grant in Comparator's own sandbox. Route around it: a private
  # directory outside every sandboxed room (nothing confined can write to it) holding one
  # symlink to the real binary, put first on PATH below.
  if [ "$(head -c 2 "$TOOLCHAIN_BIN/lake" 2>/dev/null)" = '#!' ]; then
    if [ -x "$TOOLCHAIN_BIN/lake.orig" ]; then
      LAKE_DIR="$WORKDIR/.lean-comparator-lake-bin"
      mkdir -p "$LAKE_DIR"
      ln -sf "$TOOLCHAIN_BIN/lake.orig" "$LAKE_DIR/lake"
    else
      emit_verdict comparator_unavailable "" "" "the pinned toolchain's lake ('$TOOLCHAIN_BIN/lake') is a shell wrapper with no lake.orig beside it; this wrapper cannot be executed under Landlock and there is no real binary to route around it"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Git-remote pre-flight probe -- Lake treats a linked dependency package whose remote it cannot
# read (inside this script's own sandbox grants) as MOVED, and deletes .lake/packages/<dep> to
# re-clone it -- a re-clone the sandbox's own network denial would then also fail, losing a
# dependency Lake cannot get back. Probing first and refusing loudly is cheaper than losing it.
# Must run AFTER clean_room_setup() (needs $WORKDIR/.lake/packages, populated by `lake exe cache
# get`) and AFTER resolve_toolchain() (needs $GIT_PATH's dirname on the probe's own PATH, same
# ordering rationale as Fix 1).
# ---------------------------------------------------------------------------

git_remote_preflight() {
  local pkgs_dir="$WORKDIR/.lake/packages" pkg name bad="" url
  [ -d "$pkgs_dir" ] || return 0
  for pkg in "$pkgs_dir"/*/; do
    [ -d "$pkg" ] || continue
    name="$(basename "$pkg")"
    if [ -x "$LANDRUN_PATH" ]; then
      url="$("$LANDRUN_PATH" --best-effort --ro / --rw /dev --env PATH --env HOME -- \
              env "PATH=$(dirname "$GIT_PATH"):$PATH" "HOME=$HOME" \
              "$GIT_PATH" -C "$pkg" remote get-url origin 2>/dev/null)" || true
    else
      url="$("$GIT_PATH" -C "$pkg" remote get-url origin 2>/dev/null)" || true
    fi
    if [ -z "$url" ]; then
      bad="$name"
      break
    fi
  done
  if [ -n "$bad" ]; then
    emit_verdict comparator_unavailable "" "" "git cannot read the remote of linked package '$bad' under this script's sandbox grants; refusing to proceed, since Lake would otherwise treat the failure as a changed package URL and delete .lake/packages/$bad"
  fi
}

# ---------------------------------------------------------------------------
# Config synthesis (dispatch item (c))
# ---------------------------------------------------------------------------

CONFIG_PATH=""

synth_config() {
  CONFIG_PATH="$WORKDIR/config.json"

  if [ -n "$DEFINITIONS" ]; then
    echo "lean-comparator-run.sh: NOTE: --definitions is non-empty; per Comparator's README, a definition-hole result additionally REQUIRES human (or other additional automated) verification. Comparator's structural/kernel checks alone cannot detect the concrete gaming example where 'def ChallengeSolution : Prop := sorry' in Challenge is answered with 'def ChallengeSolution : Prop := RiemannHypothesis' in Solution and closed by 'rfl' -- both sides match each other and the kernel accepts the replay, yet the filled-in value is not a legitimate answer. A definition_hole_needs_human verdict reflects this; it is not a Comparator failure." >&2
  fi

  CHALLENGE_MODULE="$CHALLENGE_MODULE" SOLUTION_MODULE="$SOLUTION_MODULE" THEOREMS="$THEOREMS" \
  PERMITTED_AXIOMS="$PERMITTED_AXIOMS" DEFINITIONS="$DEFINITIONS" ENABLE_NANODA="$ENABLE_NANODA" \
  EXTERNAL_KERNELS="$EXTERNAL_KERNELS" python3 - "$CONFIG_PATH" <<'PYEOF'
import json
import os
import sys


def csv_list(val):
    return [x.strip() for x in val.split(",") if x.strip()] if val else []


config = {
    "challenge_module": os.environ["CHALLENGE_MODULE"],
    "solution_module": os.environ["SOLUTION_MODULE"],
    "theorem_names": csv_list(os.environ["THEOREMS"]),
    "permitted_axioms": csv_list(os.environ["PERMITTED_AXIOMS"]),
}

definitions = csv_list(os.environ.get("DEFINITIONS", ""))
if definitions:
    config["definition_names"] = definitions

if os.environ.get("ENABLE_NANODA") == "1":
    config["enable_nanoda"] = True

external_kernels_raw = os.environ.get("EXTERNAL_KERNELS", "")
if external_kernels_raw:
    config["external_kernels"] = json.loads(external_kernels_raw)

with open(sys.argv[1], "w", encoding="utf-8") as fh:
    json.dump(config, fh, indent=2)
    fh.write("\n")
PYEOF

  if [ ! -s "$CONFIG_PATH" ] || ! python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$CONFIG_PATH" >/dev/null 2>&1; then
    emit_verdict comparator_unavailable "" "" "internal error: synthesised config.json failed to parse at $CONFIG_PATH"
  fi
}

# ---------------------------------------------------------------------------
# Sandbox invocation, guard serialisation, timeout (dispatch items (b) and (d))
# ---------------------------------------------------------------------------

GUARD_BIN=""
LANDRUN_SHIM_BIN=""
RUN_STDOUT_LOG=""
RUN_STDERR_LOG=""
RUN_EXIT_STATUS=""
TIMED_OUT=0

run_sandboxed() {
  # Resolve the guard the same way lean-sorry-census.sh resolves it: an overridable env var
  # defaulting to a dirname-relative sibling path. This script and lake-build-guard.sh ship from
  # different source-store extensions (lean/ vs core/) but land as literal siblings only
  # post-deploy in .claude/scripts/ -- LEAN_COMPARATOR_RUN_GUARD_BIN exists primarily as a test
  # seam for running this script directly from the source store.
  GUARD_BIN="${LEAN_COMPARATOR_RUN_GUARD_BIN:-$(dirname "${BASH_SOURCE[0]:-$0}")/lake-build-guard.sh}"

  # Same dirname-relative-sibling convention as GUARD_BIN above: this script and the shim ship
  # from the same source-store extension, but the override seam still lets the shim be swapped
  # out in tests without touching PATH.
  LANDRUN_SHIM_BIN="${LEAN_COMPARATOR_RUN_LANDRUN_SHIM_BIN:-$(dirname "${BASH_SOURCE[0]:-$0}")/lean-comparator-landrun-shim.sh}"

  local -a inner_argv
  if [ -x "$GUARD_BIN" ]; then
    # --no-share is a CORRECTNESS requirement at this call site, not a performance choice: the
    # guard's scope_key hashes the argument vector (the config.json PATH, not its content) and
    # its tree fingerprint excludes config.json -- see the design record. Never pass
    # --memory-bound here: the README's OUTER systemd-run wrapper below is a security boundary,
    # not a memory bound, and stacking a second systemd-run --user scope inside it adds
    # complexity with no stated benefit.
    inner_argv=("$GUARD_BIN" build --dir "$WORKDIR" --no-share -- env "$COMPARATOR_PATH" config.json)
  elif command -v lake >/dev/null 2>&1; then
    echo "lean-comparator-run.sh: WARNING: lake-build-guard.sh not found at '$GUARD_BIN' (override via LEAN_COMPARATOR_RUN_GUARD_BIN); running Comparator WITHOUT build serialisation against concurrent agent builds of the same project." >&2
    inner_argv=(lake env "$COMPARATOR_PATH" config.json)
  else
    emit_verdict comparator_unavailable "" "" "neither lake-build-guard.sh nor a bare 'lake' binary is available on PATH; cannot invoke Comparator"
  fi

  # bash -c takes ONE string; quote each inner argv element so embedded spaces/specials in
  # $WORKDIR or a resolved binary path survive the systemd-run -> bash -c boundary intact.
  local inner_cmd
  printf -v inner_cmd '%q ' "${inner_argv[@]}"

  RUN_STDOUT_LOG="$WORKDIR/.comparator-stdout.log"
  RUN_STDERR_LOG="$WORKDIR/.comparator-stderr.log"

  # TMPDIR inside the writable .lake directory: bv_decide writes SAT files to /tmp, which
  # Phase 3's outer landrun layer makes read-only. Created here (not by the shim, which derives
  # the identical path from its own $PWD once systemd-run's --working-directory below places it
  # in $WORKDIR) so the directory exists even for a run that never reaches the shim's own logic
  # (e.g. the guard-absent lake fallback below).
  mkdir -p "$WORKDIR/.lake/tmp"

  # PATH ordering (Fix 1): the pinned toolchain's own bin/ (or, if it needed elan-wrapper
  # unwrapping, LAKE_DIR's real-binary symlink first) goes ahead of everything else, including
  # this script's own ambient PATH -- a bare PATH lookup inside the sandbox otherwise resolves
  # the top-level elan dispatcher shim, which landrun cannot execute (see resolve_toolchain()).
  # git's own dirname is included explicitly: Lake shells out to git, and the git resolved above
  # is not guaranteed to already be first (or present at all) on the ambient PATH forwarded here.
  local sandbox_path="$TOOLCHAIN_BIN:$(dirname "$GIT_PATH"):$PATH"
  [ -n "$LAKE_DIR" ] && sandbox_path="$LAKE_DIR:$sandbox_path"

  # Forward Comparator's own override env vars into the sandbox using RESOLVED absolute paths
  # (not the caller's possibly-unset originals) so the sandboxed process resolves the exact
  # binary this script already validated exists, rather than repeating its own PATH lookup.
  # COMPARATOR_LANDRUN is repointed at the shim (LANDRUN_SHIM_BIN), never at the real landrun
  # binary directly -- see the header comment and lean-comparator-landrun-shim.sh's own header
  # for why COMPARATOR_LANDRUN is the only injection point into Comparator's own internal
  # sandbox argv. LEAN_COMPARATOR_RUN_REAL_LANDRUN forwards the real binary this script already
  # resolved (LANDRUN_PATH) so the shim does not have to re-resolve it from a possibly-different
  # PATH inside the sandbox.
  local -a env_flags=(-E "PATH=$sandbox_path" -E "HOME=$HOME" -E "TMPDIR=$WORKDIR/.lake/tmp" \
    -E "COMPARATOR_LANDRUN=$LANDRUN_SHIM_BIN" -E "LEAN_COMPARATOR_RUN_REAL_LANDRUN=$LANDRUN_PATH" \
    -E "COMPARATOR_LEAN4EXPORT=$LEAN4EXPORT_PATH")
  [ -n "$LAKE_DIR" ] && env_flags+=(-E "LEAN_COMPARATOR_RUN_LAKE_DIR=$LAKE_DIR")
  [ -n "$NANODA_PATH" ] && env_flags+=(-E "COMPARATOR_NANODA=$NANODA_PATH")

  # Outer landrun hardening -- a deliberate design decision this script ADDS, not a deviation
  # from the README's mandated wrapper below: Comparator's own internal sandbox (COMPARATOR_
  # LANDRUN, pointed at the shim) confines only ITS OWN internal `lake build`, never the
  # top-level `lake env`/Comparator process itself, nor any Lake package-management operation
  # that runs before it. This layer confines the WHOLE run -- never trust Lake package management
  # with more room than the clean-room worktree needs. --best-effort matches Comparator's own
  # landrun call: strict mode demands the newest Landlock ABI the installed landrun knows and
  # refuses to start below it. landrun drops every environment variable not explicitly named via
  # --env, so every name systemd-run's own -E flags above set must be re-listed here, or the
  # wrapped process would not see it.
  local -a env_names=(PATH HOME TMPDIR COMPARATOR_LANDRUN LEAN_COMPARATOR_RUN_REAL_LANDRUN COMPARATOR_LEAN4EXPORT)
  [ -n "$LAKE_DIR" ] && env_names+=(LEAN_COMPARATOR_RUN_LAKE_DIR)
  [ -n "$NANODA_PATH" ] && env_names+=(COMPARATOR_NANODA)
  local -a env_pass=() outer_name
  for outer_name in "${env_names[@]}"; do
    env_pass+=(--env "$outer_name")
  done

  # The README's mandated wrapper, verbatim in shape (landrun-escape mitigation -- Comparator
  # never loads .olean files itself on the stated grounds that they are mmapped and dereferenced
  # and are therefore an attack surface). OUTER = this systemd-run invocation (now wrapping this
  # script's OWN landrun layer too); INNER = lake-build-guard.sh (or the ungated fallback above).
  # landrun's absence is kept non-fatal in the same shape as the guard-absent case above: a loud
  # warning, then a degraded-but-proceeding run under systemd-run alone (Comparator's own
  # internal sandbox is unaffected either way) -- never a silent skip. In practice this script's
  # own earlier binary resolution already requires LANDRUN_PATH to be non-empty and executable,
  # so this is defensive belt-and-suspenders, not an expected-to-fire path.
  local -a cmd
  if [ -x "$LANDRUN_PATH" ]; then
    cmd=(systemd-run "--property=RestrictAddressFamilies=~AF_UNIX" --user --pty \
      "${env_flags[@]}" --working-directory "$WORKDIR" -- \
      "$LANDRUN_PATH" --best-effort --rox / --rw /dev --rwx "$WORKDIR" \
      "${env_pass[@]}" -- bash -c "$inner_cmd")
  else
    echo "lean-comparator-run.sh: WARNING: '$LANDRUN_PATH' is not executable; running WITHOUT this script's own outer landrun hardening layer (Comparator's own internal sandbox, wrapping its OWN internal 'lake build' only, is unaffected)." >&2
    cmd=(systemd-run "--property=RestrictAddressFamilies=~AF_UNIX" --user --pty \
      "${env_flags[@]}" --working-directory "$WORKDIR" -- bash -c "$inner_cmd")
  fi

  # NOTE on --pty and stream separation: --pty allocates a pseudo-tty for the WRAPPED command,
  # which merges that command's own stdout and stderr into ONE duplex channel before it ever
  # reaches this script -- systemd-run then forwards that merged pty stream to ITS OWN stdout.
  # So RUN_STDOUT_LOG below receives Comparator's TRUE combined stdout+stderr (everything
  # classify_verdict() needs, including strings the upstream source emits on its own stderr,
  # e.g. "Illegal axiom detected") -- while RUN_STDERR_LOG receives only systemd-run's OWN
  # diagnostic chatter (transient unit name, TTY-disconnect instructions), which is never
  # classification-relevant and is kept only for debugging.
  # This script only ever runs under `set -uo pipefail` (never `-e`, matching
  # lean-sorry-census.sh's own convention -- see the top of this file), so no `set +e`/`set -e`
  # toggle is needed around a command whose non-zero exit is expected and explicitly captured
  # below. (A `set -e` toggle here would be an outright bug: `set -e`/`set +e` are GLOBAL shell
  # attributes, not function-scoped, so turning it ON here would silently activate errexit for
  # the REST of the script after this function returns -- including classify_verdict()'s later
  # substring-matching pipelines, most of which legitimately return non-zero on a non-match.)
  timeout --signal=TERM --kill-after=10 "$TIMEOUT_SECS" "${cmd[@]}" >"$RUN_STDOUT_LOG" 2>"$RUN_STDERR_LOG"
  RUN_EXIT_STATUS=$?

  # `timeout` exits 124 when it had to send SIGTERM, or 128+signal (137 for SIGKILL) if the
  # command was still alive after --kill-after and had to be force-killed.
  if [ "$RUN_EXIT_STATUS" -eq 124 ] || [ "$RUN_EXIT_STATUS" -eq 137 ]; then
    TIMED_OUT=1
  fi
}

# ---------------------------------------------------------------------------
# Verdict classification (dispatch item (e)) -- Comparator itself exposes only a binary exit
# code (every failure path is an uncaught IO.userError -> stderr "uncaught exception: <message>",
# exit 1). This function owns 100% of the classification logic via priority-ordered substring
# matching against RUN_STDOUT_LOG (which -- because the mandated --pty wrapper merges the
# wrapped command's stdout and stderr -- holds Comparator's TRUE combined output regardless of
# which stream upstream's own source writes to). Every arm is quoted verbatim from
# Comparator/Compare.lean or Comparator/Axioms.lean; see the design record's verdict-string table
# for the full per-row upstream source citation.
# ---------------------------------------------------------------------------

classify_verdict() {
  if [ "$TIMED_OUT" -eq 1 ]; then
    emit_verdict timeout "" "" "sandboxed Comparator run exceeded --timeout (${TIMEOUT_SECS}s) and was terminated"
  fi

  local out
  out="$(cat "$RUN_STDOUT_LOG" 2>/dev/null || true)"

  # 1. verified -- the single authoritative positive signal is the FINAL stdout line, checked
  #    in addition to (never instead of) exit 0, since an exit-0 with early-return semantics
  #    anywhere in Comparator's pipeline would itself be a Comparator bug this wrapper should not
  #    paper over.
  if [ "$RUN_EXIT_STATUS" -eq 0 ] && printf '%s' "$out" | grep -qF "Your solution is okay!"; then
    if [ -n "$DEFINITIONS" ]; then
      emit_verdict definition_hole_needs_human "" verified \
        "Comparator verified the named theorems, but --definitions was non-empty; per the design record this REQUIRES additional (potentially human) verification that the filled-in definition(s) are a legitimate answer, not merely structurally/kernel-consistent with the Challenge hole."
    fi
    emit_verdict verified "" "" "Comparator printed 'Your solution is okay!' and exited 0."
  fi

  # 2. kernel_rejected -- default kernel (fixed stdout marker) or an external kernel (name
  #    interpolated into the marker; the THROWN message text itself is not fixed, so match the
  #    stdout marker line, never the exception text).
  if printf '%s' "$out" | grep -qF "Lean default kernel rejects the solution"; then
    emit_verdict kernel_rejected "" "" "the Lean default kernel rejected the Solution's replay"
  fi
  local kernel_name
  kernel_name="$(printf '%s' "$out" | grep -oE '[A-Za-z0-9_]+ kernel rejected the solution' | head -1 | awk '{print $1}')"
  if [ -n "$kernel_name" ]; then
    emit_verdict kernel_rejected "" "" "the external kernel '$kernel_name' rejected the Solution's replay"
  fi

  # 3. axiom_violation -- Axioms.loop walks the FULL TRANSITIVE closure of used constants from
  #    every theorem/definition target, so this arm fires for an axiom reached indirectly, not
  #    just a literal top-level `axiom` declaration.
  local axiom_name
  axiom_name="$(printf '%s' "$out" | grep -oE "Illegal axiom detected: '[^']*'" | head -1 | sed -E "s/Illegal axiom detected: '([^']*)'/\1/")"
  if [ -n "$axiom_name" ]; then
    emit_verdict axiom_violation "" "" "a named theorem's body transitively reaches axiom '$axiom_name', which is outside --permitted-axioms"
  fi

  # 4. config_error -- an authoring error (a name in --theorems/--definitions absent from one
  #    side), not a security finding. Checked BEFORE the statement/kind/const-closure arms below
  #    since it is more specific (a setup failure, not a comparison result).
  local missing_const
  missing_const="$(printf '%s' "$out" | grep -oE "Const not found in (challenge|solution): '[^']*'" | head -1)"
  if [ -n "$missing_const" ]; then
    emit_verdict config_error "" "" "$missing_const -- a name in --theorems/--definitions is absent from one side; this is an authoring error, not a security finding"
  fi

  # 5-7. statement_mismatch -- three textually-distinguishable upstream strings folded into one
  #    verdict, losslessly preserving which one fired via reason_detail (statement / kind /
  #    const_closure).
  if printf '%s' "$out" | grep -qF "Challenge and solution theorem statement do not match"; then
    local name
    name="$(printf '%s' "$out" | grep -oE "Challenge and solution theorem statement do not match: '[^']*'" | head -1 | sed -E "s/.*: '([^']*)'/\1/")"
    emit_verdict statement_mismatch statement "" "theorem statement mismatch for '$name'"
  fi

  if printf '%s' "$out" | grep -qF "Challenge and solution constant kind don't match"; then
    local name
    name="$(printf '%s' "$out" | grep -oE "Challenge and solution constant kind don't match: '[^']*'" | head -1 | sed -E "s/.*: '([^']*)'/\1/")"
    emit_verdict statement_mismatch kind "" "declaration-kind mismatch for '$name' (e.g. theorem vs axiom)"
  fi

  if printf '%s' "$out" | grep -qF "Const does not match between challenge and target"; then
    local name
    name="$(printf '%s' "$out" | grep -oE "Const does not match between challenge and target '[^']*'" | head -1 | sed -E "s/.*target '([^']*)'/\1/")"
    emit_verdict statement_mismatch const_closure "" "constant mismatch for '$name' (may be the definition hole itself, or something it transitively depends on -- this single upstream string cannot distinguish the two)"
  fi

  # Fail-closed fallthrough: a non-zero (or unexpectedly bare-0) exit matching none of the named
  # arms above is NEVER reported as verified or comparator_unavailable. See unclassified_failure
  # in verdict_exit_code() above.
  local truncated
  truncated="$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-2000)"
  emit_verdict unclassified_failure "" "" "Comparator exited $RUN_EXIT_STATUS with output matching none of the known verdict strings; raw output (truncated): $truncated"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

if [ $# -eq 0 ]; then
  die_usage "no arguments given"
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --project-root)
      [ $# -ge 2 ] || die_usage "--project-root requires a value"
      PROJECT_ROOT="$2"; shift 2 ;;
    --commit)
      [ $# -ge 2 ] || die_usage "--commit requires a value"
      COMMIT_REF="$2"; shift 2 ;;
    --challenge-module)
      [ $# -ge 2 ] || die_usage "--challenge-module requires a value"
      CHALLENGE_MODULE="$2"; shift 2 ;;
    --solution-module)
      [ $# -ge 2 ] || die_usage "--solution-module requires a value"
      SOLUTION_MODULE="$2"; shift 2 ;;
    --theorems)
      [ $# -ge 2 ] || die_usage "--theorems requires a value"
      THEOREMS="$2"; shift 2 ;;
    --permitted-axioms)
      [ $# -ge 2 ] || die_usage "--permitted-axioms requires a value"
      PERMITTED_AXIOMS="$2"; shift 2 ;;
    --definitions)
      [ $# -ge 2 ] || die_usage "--definitions requires a value"
      DEFINITIONS="$2"; shift 2 ;;
    --enable-nanoda)
      ENABLE_NANODA=1; shift ;;
    --external-kernels)
      [ $# -ge 2 ] || die_usage "--external-kernels requires a value"
      EXTERNAL_KERNELS="$2"; shift 2 ;;
    --timeout)
      [ $# -ge 2 ] || die_usage "--timeout requires a value"
      TIMEOUT_SECS="$2"; shift 2 ;;
    --keep-workdir)
      KEEP_WORKDIR=1; shift ;;
    --json)
      JSON_OUTPUT=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      die_usage "unrecognized argument: $1" ;;
  esac
done

[ -n "$PROJECT_ROOT" ] || die_usage "--project-root is required"
[ -d "$PROJECT_ROOT" ] || die_usage "--project-root '$PROJECT_ROOT' is not a directory"
[ -n "$CHALLENGE_MODULE" ] || die_usage "--challenge-module is required"
[ -n "$SOLUTION_MODULE" ] || die_usage "--solution-module is required"
[ -n "$THEOREMS" ] || die_usage "--theorems is required (comma-separated, at least one name)"
case "$TIMEOUT_SECS" in
  ''|*[!0-9]*) die_usage "--timeout must be a positive integer number of seconds" ;;
esac
if [ "$ENABLE_NANODA" -eq 1 ] && [ -n "$EXTERNAL_KERNELS" ]; then
  die_usage "--enable-nanoda and --external-kernels are mutually exclusive (Comparator throws if both are set)"
fi
if [ -n "$EXTERNAL_KERNELS" ]; then
  if ! python3 -c 'import json, sys; json.loads(sys.argv[1])' "$EXTERNAL_KERNELS" >/dev/null 2>&1; then
    die_usage "--external-kernels is not valid JSON: $EXTERNAL_KERNELS"
  fi
fi

# ---------------------------------------------------------------------------
# Binary resolution (dispatch item (b)) -- loud, never-silent degradation
# ---------------------------------------------------------------------------

COMPARATOR_PATH="$(resolve_binary COMPARATOR_BIN comparator || true)"
[ -n "$COMPARATOR_PATH" ] || fail_unavailable comparator COMPARATOR_BIN

LANDRUN_PATH="$(resolve_binary COMPARATOR_LANDRUN landrun || true)"
[ -n "$LANDRUN_PATH" ] || fail_unavailable landrun COMPARATOR_LANDRUN

LEAN4EXPORT_PATH="$(resolve_binary COMPARATOR_LEAN4EXPORT lean4export || true)"
[ -n "$LEAN4EXPORT_PATH" ] || fail_unavailable lean4export COMPARATOR_LEAN4EXPORT

# git has no Comparator-defined override env var upstream (unlike the four resolved above); this
# script's own PATH-ordering fix (Fix 1) and Phase 3's outer-landrun git pre-flight probe both
# need its resolved dirname/path regardless, so it is resolved with the same loud-never-silent
# convention.
GIT_PATH="$(command -v git 2>/dev/null || true)"
[ -n "$GIT_PATH" ] || fail_unavailable git ""

NANODA_PATH=""
if [ "$ENABLE_NANODA" -eq 1 ] || printf '%s' "$EXTERNAL_KERNELS" | grep -qi "noda"; then
  NANODA_PATH="$(resolve_binary COMPARATOR_NANODA nanoda_bin || true)"
  [ -n "$NANODA_PATH" ] || fail_unavailable nanoda_bin COMPARATOR_NANODA
fi

have_systemd_run || fail_unavailable "systemd-run (present but unusable, or absent -- requires user-scope cgroup delegation)" ""

# ---------------------------------------------------------------------------
# Main flow (Phases 3-5 fill in the bodies of these calls)
# ---------------------------------------------------------------------------

clean_room_setup
resolve_toolchain
git_remote_preflight
synth_config
run_sandboxed
classify_verdict
