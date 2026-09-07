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

# Path of the plan file EXPRESSED RELATIVE TO PROJECT_ROOT -- required by the R2 fallback, which
# resolves "the plan's approval commit" via `git -C "$PROJECT_ROOT" log -- <path>`. This assumes
# the plan and the target project's .lean sources share ONE git repository (the normal case for a
# lean/lean4 task: its own specs/{padded}_{slug}/ tree lives inside the Lean project it is a task
# for). When the plan is not tracked inside PROJECT_ROOT's own repository at all, R2 cannot find
# an approval commit and fails loudly (see extract_r2 below) rather than silently guessing.
PLAN_FILE_ABS=$(cd "$(dirname "$PLAN_FILE")" && pwd)/$(basename "$PLAN_FILE")
PROJECT_ROOT_ABS=$(cd "$PROJECT_ROOT" && pwd)
PLAN_FILE_REL=$(python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$PLAN_FILE_ABS" "$PROJECT_ROOT_ABS")

MANIFEST_PATH="$TASK_DIR/challenge/manifest.json"
STATE_JSON="specs/state.json"

# ---------------------------------------------------------------------------
# --check: Comparator-independent statement-drift mode -- the task's stated INDEPENDENT VALUE.
# Compares each theorem_names identifier's PINNED signature (retrieved from the manifest's
# recorded commit -- never re-extracted from the current plan) against the same-named
# declaration in PROJECT_ROOT's CURRENT ON-DISK working tree (never git HEAD -- an uncommitted
# weakening must be caught too). Read-only: never writes, commits, or mutates anything, including
# the manifest.
#
# ADVISORY ONLY -- see the file header. A drift finding here MUST NOT be used to fail a task.
#
# Exit: 0 no drift; 65 drift (per-identifier diff on stderr); 71 config error (no manifest, a
# named identifier absent from the current tree, or ambiguous resolution).
# ---------------------------------------------------------------------------
normalize_lean_header() {
  # Strips block comments (/- ... -/) and line comments (-- ...), then collapses all whitespace
  # (including newlines) to single spaces and trims. Documented limitation (stated, not papered
  # over): this does NOT perform alpha-renaming / binder-name normalisation -- a cosmetically
  # renamed bound variable is NOT absorbed and is reported as drift, per the phase's own
  # "anything it cannot decide is reported as drift, never silently passed" contract.
  python3 -c "
import re, sys
text = sys.stdin.read()
text = re.sub(r'/-.*?-/', ' ', text, flags=re.DOTALL)
text = re.sub(r'--[^\n]*', ' ', text)
text = re.sub(r'\s+', ' ', text).strip()
sys.stdout.write(text)
"
}

do_check() {
  local manifest_path="$1"
  echo "# lean-challenge-snapshot.sh --check verdict is ADVISORY ONLY -- see the file header." >&2
  echo "# It MUST NOT be used to set verification_passed false or block completion." >&2

  if [ ! -f "$manifest_path" ]; then
    echo "ERROR: no manifest found at $manifest_path -- run the snapshot (without --check) first." >&2
    exit 71
  fi

  local manifest_json commit challenge_path names_csv
  manifest_json=$(cat "$manifest_path")
  commit=$(python3 -c "import json,sys; print(json.load(sys.stdin)['commit'])" <<<"$manifest_json")
  challenge_path=$(python3 -c "import json,sys; print(json.load(sys.stdin)['challenge_path'])" <<<"$manifest_json")
  names_csv=$(python3 -c "import json,sys; print(','.join(json.load(sys.stdin)['theorem_names']))" <<<"$manifest_json")

  local pinned_module_file
  pinned_module_file=$(mktemp)
  if ! git -C "$PROJECT_ROOT" show "${commit}:${challenge_path}" > "$pinned_module_file" 2>/dev/null; then
    echo "ERROR: could not retrieve the pinned Challenge at commit ${commit}:${challenge_path}" >&2
    echo "       from $PROJECT_ROOT -- the trust anchor itself is unreadable." >&2
    rm -f "$pinned_module_file"
    exit 71
  fi

  python3 - "$PROJECT_ROOT" "$challenge_path" "$names_csv" "$pinned_module_file" <<'PYEOF'
import re
import sys

project_root, challenge_path, names_csv, pinned_module_file = sys.argv[1:5]
names = [n for n in names_csv.split(",") if n]
with open(pinned_module_file, encoding="utf-8") as f:
    pinned_module = f.read()

DECL_HEADER_RE = re.compile(
    r"(?m)^\s*(?:@\[[^\]]*\]\s*\n?\s*)?"
    r"(?:(?:private|protected|noncomputable)\s+)*"
    r"(theorem|lemma|def|instance)\s+([A-Za-z_][A-Za-zA-Z0-9_']*)"
)


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


def headers_by_name(text):
    matches = list(DECL_HEADER_RE.finditer(text))
    out = {}
    for idx, m in enumerate(matches):
        name = m.group(2)
        start = m.start()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(text)
        chunk = text[start:end]
        assign_pos = find_top_level_assign(chunk)
        header = chunk[:assign_pos] if assign_pos != -1 else chunk
        out.setdefault(name, []).append(header)
    return out

pinned_headers = headers_by_name(pinned_module)

import subprocess
import os

def find_lean_files(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in (".git", ".lake", "lake-packages")]
        for fn in filenames:
            if fn.endswith(".lean"):
                yield os.path.join(dirpath, fn)

current_headers = {}  # name -> list of (path, header)
challenge_abs = os.path.normpath(os.path.join(project_root, challenge_path))
for path in find_lean_files(project_root):
    if os.path.normpath(path) == challenge_abs:
        continue  # exclude the pinned Challenge artifact itself from the comparison target
    try:
        with open(path, encoding="utf-8") as f:
            content = f.read()
    except OSError:
        continue
    for name, headers in headers_by_name(content).items():
        if name not in names:
            continue
        for h in headers:
            current_headers.setdefault(name, []).append((path, h))

missing = [n for n in names if n not in current_headers]
ambiguous = {n: locs for n, locs in current_headers.items() if len(locs) > 1}

if missing:
    sys.stderr.write("ERROR: the following identifier(s) are absent from the current working tree ")
    sys.stderr.write(f"(searched under {project_root}, excluding the pinned Challenge itself):\n")
    for n in missing:
        sys.stderr.write(f"  {n}\n")
    sys.exit(71)

if ambiguous:
    for n, locs in ambiguous.items():
        files = ", ".join(loc[0] for loc in locs)
        sys.stderr.write(f"ERROR: '{n}' resolves to more than one declaration in the current tree: {files}\n")
    sys.exit(71)

def norm(s):
    s = re.sub(r"/-.*?-/", " ", s, flags=re.DOTALL)
    s = re.sub(r"--[^\n]*", " ", s)
    return re.sub(r"\s+", " ", s).strip()

drifted = []
for n in names:
    pinned_h = norm(pinned_headers.get(n, [""])[0])
    current_h = norm(current_headers[n][0][1])
    if pinned_h != current_h:
        drifted.append((n, pinned_h, current_h))

if drifted:
    sys.stderr.write("STATEMENT DRIFT DETECTED (advisory only -- see file header):\n")
    for n, pinned_h, current_h in drifted:
        sys.stderr.write(f"  {n}:\n")
        sys.stderr.write(f"    recorded: {pinned_h}\n")
        sys.stderr.write(f"    current:  {current_h}\n")
    sys.exit(65)

sys.stdout.write("no drift: every named statement matches its pinned Challenge signature\n")
sys.exit(0)
PYEOF
  local check_status=$?
  rm -f "$pinned_module_file"
  return $check_status
}

if $CHECK_MODE; then
  do_check "$MANIFEST_PATH"
  exit $?
fi

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
# R2: git-baseline extraction -- the loudly-degraded LEGACY FALLBACK, used only when the plan
# carries no `## Lean Challenge Statements` section at all. Every identifier named under
# **Goals**: must already exist as a real declaration in PROJECT_ROOT's git tree at the plan's
# approval commit; any that does not is a hard 71 failure naming that identifier -- R2 never
# emits a partial Challenge silently omitting an unresolvable name.
#
# extract_r2 <plan_file> <goals_file> <names_out> <module_out>
# ---------------------------------------------------------------------------
extract_r2() {
  local plan_file="$1" goals_file="$2" names_out="$3" module_out="$4"

  echo "================================================================================" >&2
  echo "DEGRADED FALLBACK (R2 -- git-baseline extraction)" >&2
  echo "  Plan file: $plan_file" >&2
  echo "  Reason:    this plan predates the '## Lean Challenge Statements' section (R1) and" >&2
  echo "             carries no such section. Falling back to extracting statements already" >&2
  echo "             present in $PROJECT_ROOT's git tree at the plan's approval commit." >&2
  echo "  R1 (plan-declared statements) is the PRIMARY route and should be used for any new" >&2
  echo "  lean/lean4 plan -- see challenge-snapshot.md for why R2 cannot serve a greenfield" >&2
  echo "  theorem (nothing to extract when no declaration exists yet)." >&2
  echo "================================================================================" >&2

  local approval_commit
  approval_commit=$(git -C "$PROJECT_ROOT" log -1 --format=%H -- "$PLAN_FILE_REL" 2>/dev/null || true)
  if [ -z "$approval_commit" ]; then
    echo "ERROR: R2 fallback could not resolve an approval commit for '$PLAN_FILE_REL' inside" >&2
    echo "       $PROJECT_ROOT's git history. R2 requires the plan and the target project's" >&2
    echo "       .lean sources to share one repository -- see challenge-snapshot.md." >&2
    exit 71
  fi
  echo "  Approval commit: $approval_commit" >&2

  python3 - "$PROJECT_ROOT" "$approval_commit" "$goals_file" "$names_out" "$module_out" <<'PYEOF'
import re
import subprocess
import sys

project_root, commit, goals_file, names_out, module_out = sys.argv[1:6]

with open(goals_file, encoding="utf-8") as f:
    names = [line.strip() for line in f if line.strip()]

def git(*args):
    return subprocess.run(
        ["git", "-C", project_root, *args],
        capture_output=True, text=True, check=False,
    )

tree = git("ls-tree", "-r", "--name-only", commit)
if tree.returncode != 0:
    sys.stderr.write(f"ERROR: R2 fallback could not list the tree at commit {commit}: {tree.stderr}\n")
    sys.exit(71)
lean_files = [p for p in tree.stdout.splitlines() if p.endswith(".lean")]

DECL_HEADER_RE = re.compile(
    r"(?m)^\s*(?:@\[[^\]]*\]\s*\n?\s*)?"
    r"(?:(?:private|protected|noncomputable)\s+)*"
    r"(theorem|lemma|def|instance)\s+([A-Za-z_][A-Za-zA-Z0-9_']*)"
)

def find_top_level_assign_or_by(s):
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

# name -> list of (file, declaration_text, import_lines)
found = {}
file_cache = {}
for path in lean_files:
    show = git("show", f"{commit}:{path}")
    if show.returncode != 0:
        continue
    content = show.stdout
    file_cache[path] = content
    matches = list(DECL_HEADER_RE.finditer(content))
    for idx, m in enumerate(matches):
        decl_name = m.group(2)
        if decl_name not in names:
            continue
        start = m.start()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(content)
        chunk = content[start:end]
        assign_pos = find_top_level_assign_or_by(chunk)
        header = chunk[:assign_pos].rstrip() if assign_pos != -1 else chunk.rstrip()
        decl_text = header + " := sorry\n"
        imports = [l for l in content.splitlines() if l.startswith("import ")]
        found.setdefault(decl_name, []).append((path, decl_text, imports))

missing = [n for n in names if n not in found]
ambiguous = {n: locs for n, locs in found.items() if len(locs) > 1}

if ambiguous:
    for n, locs in ambiguous.items():
        files = ", ".join(loc[0] for loc in locs)
        sys.stderr.write(
            f"ERROR: R2 fallback found more than one declaration named '{n}' at commit "
            f"{commit[:12]}: {files}. Extraction ambiguity is a hard error, never a "
            "best-effort guess.\n"
        )
    sys.exit(71)

if missing:
    sys.stderr.write(
        "ERROR: R2 fallback could not resolve the following identifier(s) as declarations in "
        f"{project_root}'s tree at commit {commit[:12]} (resolvable by neither R1 nor R2):\n"
    )
    for n in missing:
        sys.stderr.write(f"  {n}\n")
    sys.stderr.write("No Challenge content is emitted -- an incomplete Challenge is never produced.\n")
    sys.exit(71)

all_imports = []
seen_imports = set()
decl_texts = []
for n in names:
    path, decl_text, imports = found[n][0]
    for imp in imports:
        if imp not in seen_imports:
            seen_imports.add(imp)
            all_imports.append(imp)
    decl_texts.append(decl_text)

module_body = ""
if all_imports:
    module_body += "\n".join(all_imports) + "\n\n"
module_body += "\n".join(decl_texts)

with open(module_out, "w", encoding="utf-8") as f:
    f.write(module_body)
with open(names_out, "w", encoding="utf-8") as f:
    f.write("\n".join(sorted(names)) + "\n")
sys.exit(0)
PYEOF
  local r2_status=$?
  if [ "$r2_status" -ne 0 ]; then
    exit "$r2_status"
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

# ---------------------------------------------------------------------------
# Status gate -- the process-level guard against regeneration after implementation has started.
# Only {not_started, researching, researched, planning, planned} are allowed without --force; any
# later status (implementing, pr_ready, completed, blocked, partial, abandoned, expanded) is
# refused with exit 73, since a Challenge must predate implementation to certify anything.
# ---------------------------------------------------------------------------
read_task_status() {
  python3 - "$STATE_JSON" "$TASK_NUMBER" <<'PYEOF'
import json
import sys

state_path, task_number = sys.argv[1], int(sys.argv[2])
try:
    with open(state_path, encoding="utf-8") as f:
        data = json.load(f)
except (OSError, json.JSONDecodeError) as e:
    sys.stderr.write(f"ERROR: could not read/parse {state_path}: {e}\n")
    sys.exit(2)

for entry in data.get("active_projects", []):
    if entry.get("project_number") == task_number:
        print(entry.get("status", ""))
        sys.exit(0)
sys.exit(1)
PYEOF
}

PRE_IMPLEMENTATION_STATUSES="not_started researching researched planning planned"

TASK_STATUS=""
if [ -f "$STATE_JSON" ]; then
  set +e
  TASK_STATUS=$(read_task_status)
  status_lookup_rc=$?
  set -e 2>/dev/null || true
  set -uo pipefail
  if [ "$status_lookup_rc" -eq 2 ]; then
    echo "ERROR: could not read $STATE_JSON" >&2
    exit 71
  fi
fi

is_pre_implementation() {
  local s="$1"
  for allowed in $PRE_IMPLEMENTATION_STATUSES; do
    [ "$s" = "$allowed" ] && return 0
  done
  return 1
}

if [ -n "$TASK_STATUS" ] && ! is_pre_implementation "$TASK_STATUS"; then
  if ! $FORCE; then
    echo "ERROR: snapshot refused -- task $TASK_NUMBER's status is '$TASK_STATUS' (past 'planned')." >&2
    echo "       A Challenge must predate implementation to certify anything; re-run with --force" >&2
    echo "       only if you understand the consequences (see below)." >&2
    exit 73
  fi
  echo "================================================================================" >&2
  echo "INCIDENT: --force bypassing the status gate for task $TASK_NUMBER" >&2
  echo "  Current status: $TASK_STATUS (past 'planned')" >&2
  echo "  Any previously recorded manifest SHA at $MANIFEST_PATH is now STALE for any caller" >&2
  echo "  still holding it -- a Challenge produced after implementation has started certifies" >&2
  echo "  nothing about what the implementation agent actually saw." >&2
  echo "================================================================================" >&2
fi

if [ -f "$MANIFEST_PATH" ] && ! $FORCE; then
  echo "ERROR: snapshot refused -- manifest already exists at $MANIFEST_PATH. Use --force to" >&2
  echo "       overwrite (this does NOT change what any already-recorded commit SHA points to)." >&2
  exit 73
fi

# ---------------------------------------------------------------------------
# Write the assembled module, commit it into PROJECT_ROOT's own git history, and record the
# manifest. This is the immutability mechanism itself: `git show <SHA>:<path>` retrieves exactly
# these bytes forever, regardless of what happens to the working tree or HEAD afterward.
# ---------------------------------------------------------------------------
CHALLENGE_REL_PATH="${CHALLENGE_MODULE}.lean"
CHALLENGE_ABS_PATH="$PROJECT_ROOT_ABS/$CHALLENGE_REL_PATH"

CONTENT_SHA256=$(sha256sum "$MODULE_FILE" | awk '{print $1}')

cp "$MODULE_FILE" "$CHALLENGE_ABS_PATH"
git -C "$PROJECT_ROOT" add "$CHALLENGE_REL_PATH"
# --allow-empty: a regeneration whose content happens to be byte-identical to what is already
# committed (e.g. a --force re-run against an unchanged plan) must still produce a genuinely NEW
# commit -- every snapshot run is its own regeneration event and gets its own SHA in the
# manifest, never silently reusing a prior commit just because `git add` staged nothing.
git -C "$PROJECT_ROOT" commit -q --allow-empty -m "task ${TASK_NUMBER}: snapshot lean challenge statements"
COMMIT_SHA=$(git -C "$PROJECT_ROOT" rev-parse HEAD)

CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$(dirname "$MANIFEST_PATH")"
python3 - "$MANIFEST_PATH" <<PYEOF
import json

manifest = {
    "schema_version": 1,
    "task_number": ${TASK_NUMBER},
    "plan_path": "${PLAN_FILE}",
    "project_root": "${PROJECT_ROOT_ABS}",
    "challenge_module": "${CHALLENGE_MODULE}",
    "challenge_path": "${CHALLENGE_REL_PATH}",
    "theorem_names": "${THEOREM_NAMES}".split(",") if "${THEOREM_NAMES}" else [],
    "route": "${ROUTE}",
    "commit": "${COMMIT_SHA}",
    "content_sha256": "${CONTENT_SHA256}",
    "created_at": "${CREATED_AT}",
}
with open("$MANIFEST_PATH", "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")
PYEOF

if $JSON_OUT; then
  python3 -c "
import json
print(json.dumps({
    'route': '$ROUTE',
    'theorem_names': '$THEOREM_NAMES'.split(',') if '$THEOREM_NAMES' else [],
    'commit': '$COMMIT_SHA',
    'content_sha256': '$CONTENT_SHA256',
    'manifest_path': '$MANIFEST_PATH',
    'challenge_path': '$CHALLENGE_REL_PATH',
}))
"
else
  echo "route: $ROUTE"
  echo "theorem_names: $THEOREM_NAMES"
  echo "commit: $COMMIT_SHA"
  echo "content_sha256: $CONTENT_SHA256"
  echo "manifest_path: $MANIFEST_PATH"
  echo "challenge_path: $CHALLENGE_REL_PATH"
fi

exit 0
