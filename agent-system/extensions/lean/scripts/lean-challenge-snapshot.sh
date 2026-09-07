#!/usr/bin/env bash
# lean-challenge-snapshot.sh -- establishes the trusted Challenge module that Comparator
# integration requires (constraint C1: "no Challenge exists today").
#
# Given a task number and a target Lean project root, this script:
#   (a) resolves the task's plan file the same way lean-implementation-agent.md already does
#       (specs/{padded}_{slug}/plans/*.md, sort -V | tail -1),
#   (b) extracts the intended theorem STATEMENTS (route R1: the plan's own
#       `## Lean Challenge Statements` section) or, only as a loudly-degraded fallback for plans
#       authored before this feature existed, extracts them from the target project's git tree at
#       the plan's approval commit (route R2),
#   (c) cross-validates the declared identifier set against the plan's `**Goals**:` identifier
#       list, failing loudly on any disagreement,
#   (d) writes the assembled Challenge module, commits it into the TARGET PROJECT'S OWN git
#       history (the immutability mechanism `lean-comparator-run.sh --commit REF` already trusts),
#       and records a manifest pinning the resulting commit SHA plus an independent content hash,
#   (e) offers a Comparator-independent `--check` drift mode that compares the pinned Challenge
#       against the project's current working tree, so statement fidelity is enforceable today
#       with no Comparator binaries present.
#
# Full design record (R1-vs-R2 decision, storage/immutability mechanism, manifest schema,
# exit-code vocabulary, advisory-only gate decision, demonstrated behaviour):
#   agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md
#
# GATE STRENGTH: this script's `--check` verdict is ADVISORY ONLY, exactly like
# lean-comparator-run.sh's own verdict. A drift finding (exit 65) MUST NOT be interpreted by any
# caller as grounds to set verification_passed false, downgrade a task's status, or block
# completion -- that promotion is a separate, later, not-yet-made decision. This script is a
# standalone CLI, not wired into any completion gate by this script or by anything else in this
# source tree.
#
# Usage:
#   lean-challenge-snapshot.sh <task_number> <project_root> [--commit REF]
#     [--challenge-module NAME] [--force] [--dry-run] [--json]
#   lean-challenge-snapshot.sh --check <task_number> <project_root> [--json]
#
# Required (both modes):
#   task_number    The task's plain integer task number (used to resolve its plan file and
#                  specs/{padded}_{slug}/ directory; also the source of the status-gate check).
#   project_root   Path to the target Lean project (a git repo) where the Challenge module is (or
#                  will be) committed.
#
# Snapshot-mode optional flags:
#   --commit REF          Commit/ref the R2 fallback resolves declarations against, and the ref
#                          the assembled module is written on top of. Default: HEAD of
#                          project_root at invocation time.
#   --challenge-module NAME
#                          The Lean module name (and, with a .lean suffix, the file name) the
#                          assembled Challenge is written as. Default: Challenge -- matching the
#                          vendored tests/fixtures/comparator/*/Challenge.lean fixtures.
#   --force                Bypass the status-gate refusal (task status past `planned`) and the
#                          existing-manifest-overwrite refusal. Always prints a loud,
#                          incident-shaped warning when used past `planned` -- never a silent
#                          success. See the design record's "What Stops Regeneration" section.
#   --dry-run              Print the assembled module and the resolved theorem_names to stdout;
#                          perform NO filesystem or git side effects. Exits 0 on success.
#   --json                  Emit the verdict record as one JSON object instead of key: value lines.
#
# Check-mode:
#   --check                Read-only statement-drift check against an existing manifest. Compares
#                          each named theorem's pinned (git-committed) signature against the
#                          same-named declaration in project_root's CURRENT working tree.
#                          Never writes, commits, or mutates anything, including the manifest.
#
# Exit codes (see the design record's "Exit-Code Vocabulary" section for the full table and the
# intentional alignment with lean-comparator-run.sh's own codes):
#   0   OK (snapshot succeeded, or --check found no drift)
#   64  Usage error
#   65  Statement drift detected (--check mode only)
#   71  Config error -- identifier-set mismatch between `## Lean Challenge Statements` and
#       `**Goals**:`, or an identifier resolvable by neither R1 nor R2, or (in --check mode) a
#       named identifier absent from the current working tree
#   73  Snapshot refused -- status-gate refusal (regeneration attempted past `planned`), or an
#       existing manifest without --force
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Repo root: three levels up from agent-system/extensions/lean/scripts/ when run from the source
# store, OR the project root when run from a deployed .claude/scripts/ copy (this script is not
# itself deployed as a Claude Code artifact -- see manifest.json -- but is invoked directly by
# task number against a repo checkout, so it resolves specs/ relative to the CURRENT WORKING
# DIRECTORY, exactly like lean-comparator-run.sh's own plan-resolution convention. Callers MUST
# invoke this script from the repo root that owns the specs/{padded}_{slug}/ directory.

usage() {
  echo "Usage: lean-challenge-snapshot.sh <task_number> <project_root> [--commit REF] [--challenge-module NAME] [--force] [--dry-run] [--json]" >&2
  echo "       lean-challenge-snapshot.sh --check <task_number> <project_root> [--json]" >&2
  exit 64
}

CHECK_MODE=false
DRY_RUN=false
FORCE=false
JSON_OUT=false
COMMIT_REF=""
CHALLENGE_MODULE="Challenge"
TASK_NUMBER=""
PROJECT_ROOT=""

POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK_MODE=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --force) FORCE=true; shift ;;
    --json) JSON_OUT=true; shift ;;
    --commit)
      [ $# -ge 2 ] || usage
      COMMIT_REF="$2"; shift 2 ;;
    --challenge-module)
      [ $# -ge 2 ] || usage
      CHALLENGE_MODULE="$2"; shift 2 ;;
    -h|--help) usage ;;
    --*) echo "ERROR: unknown flag: $1" >&2; usage ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

if [ "${#POSITIONAL[@]}" -ne 2 ]; then
  echo "ERROR: expected exactly two positional arguments (task_number, project_root), got ${#POSITIONAL[@]}" >&2
  usage
fi
TASK_NUMBER="${POSITIONAL[0]}"
PROJECT_ROOT="${POSITIONAL[1]}"

if ! [[ "$TASK_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "ERROR: task_number must be a positive integer, got: $TASK_NUMBER" >&2
  usage
fi
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "ERROR: project_root does not exist or is not a directory: $PROJECT_ROOT" >&2
  usage
fi
if $CHECK_MODE && { $DRY_RUN || $FORCE; }; then
  echo "ERROR: --check is read-only and cannot be combined with --dry-run or --force" >&2
  usage
fi

PADDED_NUM=$(printf '%03d' "$TASK_NUMBER")

# ---------------------------------------------------------------------------
# Plan resolution -- reused verbatim from lean-implementation-agent.md's own convention.
# ---------------------------------------------------------------------------
PLAN_FILE=$(ls "specs/${PADDED_NUM}_"*/plans/*.md 2>/dev/null | sort -V | tail -1)
if [ -z "$PLAN_FILE" ]; then
  echo "ERROR: no plan file found for task $TASK_NUMBER (expected specs/${PADDED_NUM}_*/plans/*.md)" >&2
  exit 71
fi
TASK_DIR=$(dirname "$(dirname "$PLAN_FILE")")
PROJECT_NAME=$(basename "$TASK_DIR" | sed "s/^${PADDED_NUM}_//")

# ---------------------------------------------------------------------------
# Goal identifiers -- the existing backtick regex, reused VERBATIM (not reinvented).
# ---------------------------------------------------------------------------
extract_goal_names() {
  sed -n '/^\*\*Goals\*\*:/,/^\*\*[^G]/p' "$PLAN_FILE" \
    | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' | tr -d '`' | sort -u
}

# ---------------------------------------------------------------------------
# R1: plan-declared statements -- extract every ```lean fenced block under
# `## Lean Challenge Statements`, concatenate in document order, and force every declaration
# body to `sorry` regardless of what the block actually contains.
#
# Exit status of extract_r1 (via the embedded python3 helper):
#   0  section found, at least one lean block present -> names/module written to the two temp
#      files passed as argv
#   1  section absent entirely -> caller falls back to R2 (Phase 3)
#   2  section present but contains zero ```lean fenced blocks -> hard error (malformed R1
#      section is never silently treated as "R1 absent")
# ---------------------------------------------------------------------------
extract_r1() {
  local plan_file="$1" names_out="$2" module_out="$3"
  python3 - "$plan_file" "$names_out" "$module_out" <<'PYEOF'
import re
import sys

plan_path, names_out, module_out = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(plan_path, encoding="utf-8").read()

m = re.search(r'^## Lean Challenge Statements\s*$', text, re.MULTILINE)
if not m:
    sys.exit(1)

rest = text[m.end():]
m2 = re.search(r'^## ', rest, re.MULTILINE)
section = rest[: m2.start()] if m2 else rest

blocks = re.findall(r'```lean\n(.*?)```', section, re.DOTALL)
if not blocks:
    sys.stderr.write(
        "ERROR: '## Lean Challenge Statements' section is present but contains no ```lean "
        "fenced blocks -- a malformed R1 section is never treated as R1-absent.\n"
    )
    sys.exit(2)

module_body = "\n".join(b.rstrip("\n") for b in blocks) + "\n"


def find_top_level_assign(s):
    depth = 0
    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif depth == 0 and s[i : i + 2] == ":=":
            return i
        i += 1
    return -1


DECL_RE = re.compile(
    r"(?m)^\s*(?:@\[[^\]]*\]\s*\n?\s*)?"
    r"(?:(?:private|protected|noncomputable)\s+)*"
    r"(?:theorem|lemma|def|instance)\s+([A-Za-z_][A-Za-zA-Z0-9_']*)"
)

matches = list(DECL_RE.finditer(module_body))
declared_names = [mm.group(1) for mm in matches]

# Force every declaration body to `sorry`.
if matches:
    pieces = [module_body[: matches[0].start()]]
    for idx, mm in enumerate(matches):
        start = mm.start()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(module_body)
        chunk = module_body[start:end]
        assign_pos = find_top_level_assign(chunk)
        if assign_pos == -1:
            pieces.append(chunk)
        else:
            head = chunk[:assign_pos].rstrip()
            trailing_newline = "\n" if chunk.endswith("\n") else ""
            pieces.append(head + " := sorry\n" + trailing_newline)
    module_body = "".join(pieces)

with open(module_out, "w", encoding="utf-8") as f:
    f.write(module_body)
with open(names_out, "w", encoding="utf-8") as f:
    f.write("\n".join(sorted(set(declared_names))) + ("\n" if declared_names else ""))
sys.exit(0)
PYEOF
}

# ---------------------------------------------------------------------------
# Cross-validation: the R1/R2-declared identifier set MUST equal the **Goals**: identifier set.
# Hard 71 failure naming the specific offending identifiers on disagreement -- never a silent
# union, intersection, or warning.
# ---------------------------------------------------------------------------
cross_validate_identifiers() {
  local goals_file="$1" declared_file="$2"
  local only_in_goals only_in_declared
  only_in_goals=$(comm -23 "$goals_file" "$declared_file")
  only_in_declared=$(comm -13 "$goals_file" "$declared_file")
  if [ -n "$only_in_goals" ] || [ -n "$only_in_declared" ]; then
    echo "ERROR: identifier-set mismatch between **Goals**: and the Challenge declarations." >&2
    if [ -n "$only_in_goals" ]; then
      echo "  named in **Goals**: but not declared: $(echo "$only_in_goals" | tr '\n' ' ')" >&2
    fi
    if [ -n "$only_in_declared" ]; then
      echo "  declared but not named in **Goals**:  $(echo "$only_in_declared" | tr '\n' ' ')" >&2
    fi
    exit 71
  fi
}

# ---------------------------------------------------------------------------
# Main resolution: R1 first, R2 fallback only when the R1 section is entirely absent.
# ---------------------------------------------------------------------------
GOALS_FILE=$(mktemp)
NAMES_FILE=$(mktemp)
MODULE_FILE=$(mktemp)
cleanup_tmp() { rm -f "$GOALS_FILE" "$NAMES_FILE" "$MODULE_FILE"; }
trap cleanup_tmp EXIT

extract_goal_names > "$GOALS_FILE"

ROUTE=""
extract_r1 "$PLAN_FILE" "$NAMES_FILE" "$MODULE_FILE"
r1_status=$?
if [ "$r1_status" -eq 0 ]; then
  ROUTE="plan-declared"
elif [ "$r1_status" -eq 2 ]; then
  exit 71
else
  # R1 section entirely absent -> R2 fallback (Phase 3).
  extract_r2 "$PLAN_FILE" "$GOALS_FILE" "$NAMES_FILE" "$MODULE_FILE"
  ROUTE="git-baseline"
fi

if [ ! -s "$GOALS_FILE" ]; then
  echo "ERROR: no identifiers found under **Goals**: in $PLAN_FILE -- nothing to snapshot." >&2
  exit 71
fi

cross_validate_identifiers "$GOALS_FILE" "$NAMES_FILE"

THEOREM_NAMES=$(tr '\n' ',' < "$NAMES_FILE" | sed 's/,$//')

if $DRY_RUN; then
  echo "# route: $ROUTE"
  echo "# theorem_names: $THEOREM_NAMES"
  echo "---"
  cat "$MODULE_FILE"
  exit 0
fi
