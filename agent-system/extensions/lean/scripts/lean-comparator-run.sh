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
#   COMPARATOR_LANDRUN         Overrides a bare `landrun` PATH lookup.
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
# Phase 3/4/5 stubs -- filled in by later phases of this same script; kept as explicit,
# loudly-failing stubs here (rather than omitted) so this file is a complete, sourceable,
# `bash -n`-clean script at every intermediate phase boundary.
# ---------------------------------------------------------------------------

clean_room_setup() {
  echo "lean-comparator-run.sh: internal error: clean_room_setup not yet implemented" >&2
  return 1
}

synth_config() {
  echo "lean-comparator-run.sh: internal error: synth_config not yet implemented" >&2
  return 1
}

run_sandboxed() {
  echo "lean-comparator-run.sh: internal error: run_sandboxed not yet implemented" >&2
  return 1
}

classify_verdict() {
  echo "lean-comparator-run.sh: internal error: classify_verdict not yet implemented" >&2
  return 1
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

# ---------------------------------------------------------------------------
# Binary resolution (dispatch item (b)) -- loud, never-silent degradation
# ---------------------------------------------------------------------------

COMPARATOR_PATH="$(resolve_binary COMPARATOR_BIN comparator || true)"
[ -n "$COMPARATOR_PATH" ] || fail_unavailable comparator COMPARATOR_BIN

LANDRUN_PATH="$(resolve_binary COMPARATOR_LANDRUN landrun || true)"
[ -n "$LANDRUN_PATH" ] || fail_unavailable landrun COMPARATOR_LANDRUN

LEAN4EXPORT_PATH="$(resolve_binary COMPARATOR_LEAN4EXPORT lean4export || true)"
[ -n "$LEAN4EXPORT_PATH" ] || fail_unavailable lean4export COMPARATOR_LEAN4EXPORT

NANODA_PATH=""
if [ "$ENABLE_NANODA" -eq 1 ] || printf '%s' "$EXTERNAL_KERNELS" | grep -qi "noda"; then
  NANODA_PATH="$(resolve_binary COMPARATOR_NANODA nanoda_bin || true)"
  [ -n "$NANODA_PATH" ] || fail_unavailable nanoda_bin COMPARATOR_NANODA
fi

have_systemd_run || fail_unavailable "systemd-run (present but unusable, or absent -- requires user-scope cgroup delegation)" ""

# ---------------------------------------------------------------------------
# Main flow (Phases 3-5 fill in the bodies of these calls)
# ---------------------------------------------------------------------------

WORKDIR=""
clean_room_setup
synth_config
run_sandboxed
classify_verdict
