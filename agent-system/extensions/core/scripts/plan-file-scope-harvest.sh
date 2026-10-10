#!/usr/bin/env bash
# plan-file-scope-harvest.sh - Harvest the deduplicated union of every phase's "Files to modify"
# path list from a plan file, emitting a JSON array of strings on stdout.
#
# This formalizes an already-universal convention (see context/formats/plan-format.md's
# "Files to modify" per-phase field) rather than inventing a new one -- see this task's own
# reports/plans for the coverage measurement. It is the ONE consumer of that field that depends
# on list-item shape rather than only the heading string; see plan-format.md's "Consumers of this
# field" subsection for the other three (heading-name-stability-only) consumers, which this
# script's own output feeds (via callers) but never itself parses their code paths.
#
# Contract:
#   Usage:  plan-file-scope-harvest.sh <plan-file-path>
#   stdout: a compact JSON array of strings, sorted and deduplicated, e.g. ["a/b.sh","c/d.md"].
#           `[]` when the plan carries no harvestable "Files to modify" path -- this is a normal,
#           exit-0 outcome, never an error.
#   Exit codes: 0 on success (including the empty-result case above); non-zero is reserved for
#           genuine usage errors (missing argument, unreadable/missing file) and is NEVER used to
#           signal "found nothing".
#
# This script deliberately does NOT distinguish "no Files to modify header anywhere in a phase"
# from "header present, zero paths" (e.g. a pure-verification phase, or a `- none planned ...`
# prose sentinel) -- both return `[]` for that phase's contribution, by design. That distinction
# is made exactly once, in scripts/validate-artifact.sh's per-phase presence check (see
# plan-format.md's "Enforcement level (Files to modify)" subsection under "## Verification
# Tiers"), never here.
#
# Grammar accepted (mirrors plan-format.md's "Files to modify" field definition verbatim -- do
# not let this comment and that definition drift apart):
#   - Block header: `**Files to modify**:` or `**Files to modify:**` (both accepted punctuation
#     forms per plan-format.md's "Field-punctuation tolerance" rule), optionally prefixed by a
#     single leading list marker (`- **Files to modify**:`) -- plan-format.md's own compact
#     example template renders every per-phase field this way, and at least one real local plan
#     (found during this phase's verification, not the research report) does too, so both the
#     bare and list-item-wrapped header forms are accepted.
#   - Inside a block, a NEW path entry starts on a line matching `^[ \t]*-[ \t]*\`` (optional
#     leading indentation, a list marker, then a backtick, allowing optional whitespace between);
#     the first backtick-delimited token on that line is the path. Any trailing
#     ` - {description}` text after the closing backtick is discarded. Leading indentation is
#     tolerated because the list-item-wrapped header form above indents its entries one level.
#   - Every other line inside the block -- an indented wrapped continuation line, a "none
#     planned" prose sentinel, or a blank line not immediately followed by another entry --
#     contributes no path. This is not a parse error; it is the documented "contributes nothing"
#     behavior from plan-format.md and this task's Risk table.
#   - The block ends at the first of: a `###` heading, a new bolded field label line (`**Field**:`
#     / `**Field:**`, itself optionally list-marker-prefixed the same way the header can be), or a
#     blank line NOT immediately followed by another entry line.
#   - `**Scope Hypothesis**:` is deliberately never treated as a second harvest source (see
#     plan-format.md's "Counts-are-hypotheses obligation" cross-reference) -- only the
#     `Files to modify` block above is read.
#
# Never stats, resolves, or filesystem-validates a harvested path. `file_scope` is documented
# "prospective, not filesystem-validated" (context/schemas/state-schema.json), and a path a plan
# names for a file it will CREATE is exactly what must be harvested, not filtered out.
#
# Generated-surface appending:
#   Any `.lean` path in the harvested set mechanically forces regeneration of a fixed set of
#   derived surfaces in this repository's generator toolchain (`scripts/check-module-invariants.sh`
#   and `scripts/typst-sync-check.sh`): the status-table typst file, every markdown README whose
#   `<!-- BEGIN GENERATED: inventory -->` block covers a directory on the edited file's
#   ancestor-directory chain, and (narrowly) the automation module map and the machine-readable
#   axiom appendix. A plan that harvests a `.lean` path but omits these either blocks on the
#   pre-commit `typst-sync-check.sh` gate or fails `check-module-invariants.sh`'s INV check
#   mid-implementation -- this has happened twice independently. This stage appends them so the
#   plan's declared `file_scope` already carries what the edit will force.
#
#   Trigger: the harvested array contains at least one `*.lean` path.
#   Guard 1 (capability): both generator scripts must exist as regular files under the resolved
#     repo root, or the entire addition is skipped. This is what keeps the behavior inert in a
#     sibling repository that carries no such generators.
#   Guard 2 (root resolution): the repo root is resolved fail-soft (see `resolve_repo_root()`
#     below) -- an unresolvable root is a skip, never an error.
#   Env override: `PLAN_FILE_SCOPE_HARVEST_ROOT` lets the test suite drive this logic against a
#     synthetic fixture repo without threading a root flag through this script's seven callers.
#   `file_scope`-overlap consequence: the appended surfaces are ordinary `file_scope` entries (the
#     schema has no per-entry provenance field), so two concurrent `.lean`-touching tasks will now
#     both carry e.g. `typst/generated/status.typ` and collide in `orchestrate-batch-admit.sh`'s
#     `file_scope_collision` check and in `task-lock.sh`. This is accepted, not engineered around:
#     both tasks really do force regeneration of the same shared surface and really do fight the
#     same pre-commit gate over it, so serializing them is the correct outcome. See
#     `context/reference/state-management-schema.md`'s file-scope section for the durable record
#     of this consequence.
#   Universal vs. narrow surfaces: `status.typ` and the ancestor-chain READMEs are appended
#     unconditionally (once the trigger and both guards pass), because `status.typ`'s counts
#     cover `FormalSystem/`, `Tests/`, and `BimodalTools/` recursively -- essentially any `.lean`
#     edit forces it. `automation-module-map.typ` and `machine-appendix.{jsonl,typ}` are instead
#     glob-gated to the narrow scope their own generators actually depend on (three
#     `FormalSystem/Automation/*` globs; `FormalSystem/ProofSystem/{Axioms,Derivation}.lean`
#     respectively), because most `.lean` edits cannot make them stale. `machine-appendix`
#     regeneration additionally needs a Lean build (`lake env lean --run`), not a line-count
#     scan -- a cost the implementer of a future Axioms/Derivation-touching task should expect.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <plan-file-path>" >&2
  exit 1
fi

PLAN_FILE="$1"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "ERROR: plan file not found or not a regular file: $PLAN_FILE" >&2
  exit 1
fi
if [[ ! -r "$PLAN_FILE" ]]; then
  echo "ERROR: plan file not readable: $PLAN_FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to emit the harvested JSON array and is not on PATH" >&2
  exit 1
fi

# awk state machine: in_block tracks whether we are currently inside a "Files to modify" block.
# One path per output line; sorting/deduplication/JSON-encoding is left to the jq stage below so
# this stage stays a pure line-oriented extractor.
#
# `strip_marker()` removes a single optional leading list marker ("- ", with any leading
# whitespace) so the header and field-label checks work identically whether a generator rendered
# the field bare (`**Files to modify**:`) or as its own list item (`- **Files to modify**:`, the
# form plan-format.md's own compact example template uses for every field). Entry-line detection
# is handled separately (it must recognize the marker, not strip it, since the marker is what
# identifies a line as an entry in the first place) and tolerates leading indentation, since the
# list-item-wrapped header form indents its entries one level.
extract_paths() {
  awk '
    function strip_marker(l,    s) {
      s = l
      sub(/^[ \t]*-[ \t]+/, "", s)
      return s
    }
    function emit_entry(l,    rest, idx, path) {
      rest = l
      sub(/^[ \t]*-[ \t]*`/, "", rest)
      idx = index(rest, "`")
      if (idx > 0) {
        path = substr(rest, 1, idx - 1)
        if (path != "") print path
      }
    }
    BEGIN { in_block = 0 }
    {
      line = $0
      stripped = strip_marker(line)
      if (in_block == 0) {
        if (stripped ~ /^\*\*Files to modify\*\*:/ || stripped ~ /^\*\*Files to modify:\*\*/) {
          in_block = 1
        }
        next
      }
      # in_block == 1 from here down.
      if (line ~ /^### /) { in_block = 0; next }
      if (stripped ~ /^\*\*[A-Za-z]/) { in_block = 0; next }
      if (line ~ /^[ \t]*-[ \t]*`/) {
        emit_entry(line)
        next
      }
      if (line ~ /^[ \t]*$/) {
        # Blank line: only stays inside the block if the very next line is another entry.
        if ((getline nextline) > 0) {
          if (nextline ~ /^[ \t]*-[ \t]*`/) {
            emit_entry(nextline)
            next
          }
          in_block = 0
          next
        }
        in_block = 0
        next
      }
      # Continuation line (wrapped description text) or a prose sentinel: contributes nothing.
      next
    }
  ' "$1"
}

# resolve_repo_root: fail-soft repo root resolution for the generated-surface stage below.
# Honors PLAN_FILE_SCOPE_HARVEST_ROOT (if set and a directory) first, so the test suite can drive
# a synthetic fixture repo without a flag threaded through every caller. Otherwise resolves via
# git from the plan file's own directory, falling back to a git resolve from CWD. Never writes to
# stderr and never a non-zero exit propagates as an error -- an unresolvable root is a skip,
# signaled only by this function's own return code, which callers must check.
resolve_repo_root() {
  if [[ -n "${PLAN_FILE_SCOPE_HARVEST_ROOT:-}" && -d "${PLAN_FILE_SCOPE_HARVEST_ROOT}" ]]; then
    printf '%s\n' "${PLAN_FILE_SCOPE_HARVEST_ROOT}"
    return 0
  fi
  local root
  root="$(git -C "$(dirname "$PLAN_FILE")" rev-parse --show-toplevel 2>/dev/null)" || root=""
  if [[ -n "$root" ]]; then
    printf '%s\n' "$root"
    return 0
  fi
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || root=""
  if [[ -n "$root" ]]; then
    printf '%s\n' "$root"
    return 0
  fi
  return 1
}

# generated_surfaces_available: the capability gate. Succeeds only when BOTH generator scripts
# this stage mirrors are present as regular files under $1 -- this is what keeps the entire
# addition inert in a repository (or fixture) that carries neither generator.
generated_surfaces_available() {
  local root="$1"
  [[ -f "$root/scripts/check-module-invariants.sh" && -f "$root/scripts/typst-sync-check.sh" ]]
}

# generated_inventory_readmes: mirrors check-module-invariants.sh's own BEGIN_RE/fence/dir=
# parsing (never its rows=/cols=/filter=/sort= rendering semantics) to find every markdown file
# whose generated-inventory block covers a directory on one of the given `.lean` paths'
# ancestor-directory chains. Deliberately does NOT match the separate
# `<!-- INVENTORY: hand-maintained (dir=...) -->` opt-out marker -- that marker uses a different
# comment pattern entirely, so a hand-maintained table is never mistaken for a generated one.
#
# $1 = repo root; $2 = JSON array of repo-relative `.lean` paths. Prints a JSON array of
# repo-relative markdown paths (possibly empty) on stdout.
generated_inventory_readmes() {
  local root="$1" lean_paths_json="$2"
  python3 - "$root" "$lean_paths_json" <<'PYEOF'
import json, os, re, sys

root, lean_paths_json = sys.argv[1], sys.argv[2]
lean_paths = json.loads(lean_paths_json)

BEGIN_RE = re.compile(r'^<!--\s*BEGIN GENERATED:\s*inventory\s*(?P<opts>[^>]*?)\s*-->\s*$')

def markdown_targets(root):
    out = []
    for r, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs
                   if d not in (".git", "specs", ".claude", ".lake", "node_modules")]
        for f in files:
            if f.endswith(".md"):
                out.append(os.path.relpath(os.path.join(r, f), root))
    return sorted(out)

def parse_opts(raw):
    opts = {}
    for tok in raw.split():
        if "=" in tok:
            k, v = tok.split("=", 1)
            opts[k] = v
    return opts

def ancestor_chain(lean_path):
    d = os.path.dirname(lean_path)
    if d == "":
        d = "."
    chain = []
    cur = os.path.normpath(d)
    while True:
        chain.append(cur)
        if cur == ".":
            break
        parent = os.path.dirname(cur)
        if parent == "":
            parent = "."
        cur = parent
    return chain

chain_members = set()
for p in lean_paths:
    chain_members.update(ancestor_chain(p))

result = []
for target in markdown_targets(root):
    full = os.path.join(root, target)
    try:
        with open(full, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
    except OSError:
        continue
    in_fence = False
    hit = False
    for line in lines:
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = BEGIN_RE.match(line)
        if not m:
            continue
        dir_val = parse_opts(m.group("opts")).get("dir")
        if dir_val and os.path.normpath(dir_val) in chain_members:
            hit = True
    if hit:
        result.append(target)

print(json.dumps(sorted(result)))
PYEOF
}

HARVESTED="$(extract_paths "$PLAN_FILE" | jq -R -s -c 'split("\n") | map(select(length > 0)) | unique')"

# Generated-surface post-processing stage. Inert (emits $HARVESTED unchanged) unless the
# harvested array contains at least one `.lean` path, a repo root resolves, and that root passes
# the capability gate. See the header "Generated-surface appending" subsection above for the full
# contract.
EXTRA=()
if echo "$HARVESTED" | jq -e 'any(.[]; test("\\.lean$"))' >/dev/null 2>&1; then
  if ROOT="$(resolve_repo_root)" && generated_surfaces_available "$ROOT"; then
    # status.typ: forced by essentially any `.lean` edit (FORMALSYSTEM_FILE/LINE_COUNT,
    # TESTS_FILE/LINE_COUNT, and TOOLS_FILE/LINE_COUNT in scripts/typst-status-counts.sh cover
    # the entirety of FormalSystem/, Tests/, and BimodalTools/ recursively). Existence-conditional
    # on the file being present under $ROOT, matching the narrow-glob surfaces below.
    if [[ -f "$ROOT/typst/generated/status.typ" ]]; then
      EXTRA+=("typst/generated/status.typ")
    fi

    # Ancestor-chain generated-README scan: every README whose generated-inventory block covers
    # a directory on an edited `.lean` path's ancestor chain.
    LEAN_PATHS_JSON="$(echo "$HARVESTED" | jq -c '[.[] | select(test("\\.lean$"))]')"
    README_HITS="$(generated_inventory_readmes "$ROOT" "$LEAN_PATHS_JSON")"
    while IFS= read -r readme; do
      [[ -n "$readme" ]] && EXTRA+=("$readme")
    done < <(echo "$README_HITS" | jq -r '.[]')

    # Narrow-glob conditional surfaces: genuinely conditional, unlike status.typ and the README
    # scan above. automation-module-map.typ covers only typst-module-map.sh's own declared glob
    # scope (FormalSystem/Automation/{Tactics,ProofSearch}/*.lean, never Boneyard/, plus the
    # single pinned file SuccessPatterns.lean); machine-appendix.{jsonl,typ} is tied to
    # MachineAppendixMain.lean's own two imports (Axioms.lean, Derivation.lean) -- its
    # regeneration needs a Lean build (`lake env lean --run`), not a line-count scan, a cost the
    # implementer of a future Axioms/Derivation-touching task should expect. Both appends are
    # existence-conditional, matching status.typ's own treatment.
    AUTOMATION_HIT=0
    APPENDIX_HIT=0
    while IFS= read -r lean_path; do
      [[ -z "$lean_path" ]] && continue
      dir="${lean_path%/*}"
      base="${lean_path##*/}"
      if [[ "$lean_path" == "FormalSystem/Automation/SuccessPatterns.lean" ]]; then
        AUTOMATION_HIT=1
      elif { [[ "$dir" == "FormalSystem/Automation/Tactics" ]] || [[ "$dir" == "FormalSystem/Automation/ProofSearch" ]]; } && [[ "$base" == *.lean ]]; then
        AUTOMATION_HIT=1
      fi
      if [[ "$lean_path" == "FormalSystem/ProofSystem/Axioms.lean" || "$lean_path" == "FormalSystem/ProofSystem/Derivation.lean" ]]; then
        APPENDIX_HIT=1
      fi
    done < <(echo "$LEAN_PATHS_JSON" | jq -r '.[]')

    if [[ "$AUTOMATION_HIT" -eq 1 && -f "$ROOT/typst/generated/automation-module-map.typ" ]]; then
      EXTRA+=("typst/generated/automation-module-map.typ")
    fi
    if [[ "$APPENDIX_HIT" -eq 1 ]]; then
      if [[ -f "$ROOT/typst/generated/machine-appendix.jsonl" ]]; then
        EXTRA+=("typst/generated/machine-appendix.jsonl")
      fi
      if [[ -f "$ROOT/typst/generated/machine-appendix.typ" ]]; then
        EXTRA+=("typst/generated/machine-appendix.typ")
      fi
    fi
  fi
fi

EXTRA_PATHS="$(printf '%s\n' "${EXTRA[@]+"${EXTRA[@]}"}" | jq -R -s -c 'split("\n") | map(select(length > 0))')"
jq -n --argjson base "$HARVESTED" --argjson extra "$EXTRA_PATHS" '($base + $extra) | unique'
