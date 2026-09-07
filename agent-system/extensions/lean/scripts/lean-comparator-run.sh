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
synth_config
run_sandboxed
classify_verdict
