#!/usr/bin/env bash
# books-gate.sh -- resolve-and-run wrapper for the advisory intermediate verification tier the
# `--gate` flag surfaces at implement dispatch.
#
# PURPOSE. The `books` extension's implementation agents and skills need to name a real,
# invocable script in their own docs (agents/skills/commands/README.md/EXTENSION.md), but the
# real regex layer lint (`interface/scripts/layer-lint.sh` in the consuming repository) is not
# this extension's own file -- it belongs to whatever repository the extension is deployed into,
# and `check-extension-docs.sh` Rule E (check_referenced_scripts_declared) hard-fails on any
# bare `<name>.sh` token in those five doc locations that is not declared in some extension's
# provides.scripts/provides.hooks. Its sibling `books-certify.sh` exists for exactly the same
# reason and says so in its own header. `scripts/**` and `context/**` are not scanned by Rule E,
# which is why the consuming repository's script names may appear in THIS header and in the
# books context corpus, but must never appear in any of those five doc locations.
#
# WHAT THIS TIER IS FOR. No verification tier existed between `lake build` and the ten-minute
# fail-closed full gate. `lake build` invokes neither the layer lint, nor the certifier, nor the
# Comparator rooms -- which is how 44 layer violations sat undetected across five tagging phases
# that all reported green on `lake build`. This wrapper is the cheap middle tier: two legs, no
# Lean toolchain, no network, no build.
#
#   Leg 1 (layer lint)   -- invoke the consuming repository's shared layer-import rule driver
#                           over derived package roots, and classify its genuinely ambiguous
#                           exit codes into six distinct outcomes.
#   Leg 2 (closure)      -- two grep predicates over the live tree: no `.lean` file carries a
#                           PUBLIC import of the `Books.Meta` provider module, and the provider
#                           package declares no `require`.
#
# ADVISORY ONLY. This script ALWAYS exits 0 in its advisory role (`--json`, the default). A
# finding never blocks a dispatch, never fails one, and never downgrades status; every finding
# travels as a field of the single JSON object written to stdout, for the calling agent to copy
# into `.return-meta.json`'s `gate` block (schema: core's
# `context/formats/return-metadata-file.md`, `### gate (optional)`). A non-zero exit would
# invite a caller to treat the result as a failure, which is precisely what this tier must not
# be. The flag ADDS a tier; it weakens, shortcuts and quietens nothing -- every existing gate
# stays fail-closed by design.
#
# A VACUOUS PASS IS NOT A PASS. The layer lint's `[ok]` line reports module and import counts
# but never rule APPLICABILITY, so neither its exit code nor its output distinguishes "checked
# and clean" from "nothing was checked" (measured: a `books` root matches 0 of 9 rules and still
# exits 0). This wrapper therefore sources the REAL rule set in a SUBSHELL -- never a copy of the
# rules, and never in this shell, because the rule-set library `exit 1`s while being sourced when
# its queue-model derivation yields nothing -- counts how many rules' file-halves match at least
# one discovered `.lean` path, and reports `pass_vacuous` with `rules_matched`/`rules_total`
# rather than `pass`.
#
# Usage:
#   books-gate.sh [--json] [--root DIR] [--package-root DIR]...
#
#   --json              emit one JSON object on stdout and exit 0 (the default and only mode).
#   --root DIR          treat DIR as the repository root instead of resolving it. Primarily for
#                       this script's own fixture suite.
#   --package-root DIR  a package root to lint, relative to the repository root. Repeatable.
#                       When omitted, roots are DERIVED: `interface` plus every `components/*`
#                       directory containing a `lean/` subdirectory. No component name is ever
#                       hardcoded here -- the rule set itself avoids typing one, and so does this.
#
# Exit codes:
#   0 - always, in the advisory role. Read the JSON, not the exit code.
#   2 - usage error in THIS wrapper's own arguments (an unknown flag, or a flag missing its
#       value). Distinct from the linted tree's own `usage_error` status, which is reported in
#       the JSON with exit 0.
#
# No interactive prompts. No network. No build.

set -uo pipefail

# ─── Arguments ─────────────────────────────────────────────────────────────────────────────────
root_arg=""
package_roots=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) shift ;;
    --root)
      if [ "$#" -lt 2 ]; then
        echo "books-gate.sh: --root requires a directory argument" >&2
        exit 2
      fi
      root_arg="$2"; shift 2 ;;
    --package-root)
      if [ "$#" -lt 2 ]; then
        echo "books-gate.sh: --package-root requires a directory argument" >&2
        exit 2
      fi
      package_roots+=("$2"); shift 2 ;;
    -h|--help)
      sed -n '/^# Usage:/,/^# No interactive prompts/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "books-gate.sh: unknown argument: $1" >&2
      echo "  usage: books-gate.sh [--json] [--root DIR] [--package-root DIR]..." >&2
      exit 2 ;;
  esac
done

start_ts=$(date +%s)

# ─── Resolve the repository root ───────────────────────────────────────────────────────────────
# Same shape as books-certify.sh: prefer git's own notion of the toplevel (works from any cwd
# inside the repo); fall back to the current working directory when not inside a git repository.
if [ -n "$root_arg" ]; then
  repo_root="$(cd "$root_arg" 2>/dev/null && pwd)" || repo_root="$root_arg"
elif repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
  :
else
  repo_root="$(pwd)"
fi

lint_script="${repo_root}/interface/scripts/layer-lint.sh"
rules_script="${repo_root}/interface/scripts/layer-rules.sh"

# ─── Derive package roots when none were named ─────────────────────────────────────────────────
# `interface` plus every `components/*` holding a `lean/` subdirectory. Never a hardcoded
# component name: the rule set itself derives rather than types one, and typing one here would
# bake a consuming repository's component layout into this extension.
if [ "${#package_roots[@]}" -eq 0 ]; then
  [ -d "${repo_root}/interface" ] && package_roots+=("interface")
  if [ -d "${repo_root}/components" ]; then
    while IFS= read -r comp_dir; do
      [ -n "$comp_dir" ] || continue
      rel="${comp_dir#"${repo_root}"/}"
      package_roots+=("$rel")
    done <<< "$(find "${repo_root}/components" -mindepth 2 -maxdepth 2 -type d -name lean 2>/dev/null \
                 | sed 's#/lean$##' | LC_ALL=C sort)"
  fi
fi

# ─── Leg 1: the layer lint ─────────────────────────────────────────────────────────────────────
lint_status=""
lint_detail=""
lint_modules="null"
lint_imports="null"
lint_violations=()
rules_matched=0
rules_total=0

if [ ! -f "$lint_script" ]; then
  lint_status="lint_unavailable"
  lint_detail="no layer-import rule driver found under '${repo_root}/interface/scripts/'; this repository does not appear to carry the interface tooling tree"
elif [ "${#package_roots[@]}" -eq 0 ]; then
  lint_status="usage_error"
  lint_detail="no package root could be derived under '${repo_root}' and none was named with --package-root; the lint requires at least one"
else
  lint_out=""
  lint_err=""
  lint_err_file="$(mktemp)"
  lint_out="$(cd "$repo_root" && bash "$lint_script" "${package_roots[@]}" 2>"$lint_err_file")"
  lint_rc=$?
  lint_err="$(cat "$lint_err_file" 2>/dev/null)"
  rm -f "$lint_err_file"

  case "$lint_rc" in
    0)
      # Parse the `[ok]` line's counts when present. Absent counts stay null rather than 0: a
      # missing count is unknown, not zero.
      ok_line="$(printf '%s\n' "$lint_out" | grep -m1 '^\[ok\] layer import rule' || true)"
      if [ -n "$ok_line" ]; then
        m="$(printf '%s' "$ok_line" | sed -n 's/.*(\([0-9]\{1,\}\) modules.*/\1/p')"
        i="$(printf '%s' "$ok_line" | sed -n 's/.*[^0-9]\([0-9]\{1,\}\) imports.*/\1/p')"
        [ -n "$m" ] && lint_modules="$m"
        [ -n "$i" ] && lint_imports="$i"
      fi
      lint_status="pass"   # provisionally; vacuity is decided below
      ;;
    2)
      lint_status="usage_error"
      lint_detail="${lint_err:-the lint rejected its arguments}"
      ;;
    1)
      # Exit 1 is AMBIGUOUS and must be disambiguated before being read as violations: the
      # rule-set library `exit 1`s while being SOURCED when its queue-model derivation yields
      # nothing, which terminates the lint itself with the same code a real violation produces.
      # Classify on stderr content first.
      if printf '%s' "$lint_err" | grep -q 'no queue model found'; then
        lint_status="rule_set_error"
        lint_detail="$lint_err"
      else
        lint_status="violations"
        while IFS= read -r vline; do
          [ -n "$vline" ] || continue
          lint_violations+=("${vline#\[FAIL\] }")
        done <<< "$(printf '%s\n' "$lint_out" | grep '^\[FAIL\]' || true)"
        lint_detail="$(printf '%s\n' "$lint_out" | grep -m1 'layer import violation(s)' || true)"
      fi
      ;;
    *)
      lint_status="rule_set_error"
      lint_detail="the lint exited with the unexpected code ${lint_rc}: ${lint_err}"
      ;;
  esac
fi

# ─── Vacuity detection: source the REAL rule set, in a subshell ────────────────────────────────
# The rule-set library is the record of truth for the rules; this never copies them. It is
# sourced in a SUBSHELL because it `exit 1`s during sourcing when no queue model is found -- in
# this shell that would kill the wrapper outright.
if [ -f "$rules_script" ] && [ "${#package_roots[@]}" -gt 0 ]; then
  vac_out="$(
    (
      set +u
      ROOT="$repo_root"
      export ROOT
      # shellcheck disable=SC1090
      . "$rules_script" >/dev/null 2>&1 || exit 7
      files="$(cd "$ROOT" && find "${package_roots[@]}" -name '*.lean' -not -path '*/.lake/*' 2>/dev/null | LC_ALL=C sort)"
      matched=0
      total=0
      for r in "${LAYER_RULES[@]}" "${LAYER_ALLOW_RULES[@]}"; do
        total=$((total + 1))
        fh="${r%%;*}"   # field 1 of the ';'-delimited rule is its file half
        printf '%s\n' "$files" | grep -qE "$fh" && matched=$((matched + 1))
      done
      printf '%s %s\n' "$matched" "$total"
    ) 2>/dev/null
  )" || vac_out=""
  if [ -n "$vac_out" ]; then
    rules_matched="${vac_out%% *}"
    rules_total="${vac_out##* }"
    case "$rules_matched" in (*[!0-9]*|"") rules_matched=0 ;; esac
    case "$rules_total" in (*[!0-9]*|"") rules_total=0 ;; esac
  else
    # The rule set could not be sourced at all. If the lint itself has not already said so,
    # record it here rather than silently reporting 0 of 0 as a clean pass.
    if [ "$lint_status" = "pass" ]; then
      lint_status="rule_set_error"
      [ -n "$lint_detail" ] || lint_detail="the rule-set library could not be sourced, so rule applicability is unknown"
    fi
  fi
fi

# A vacuous pass is reported as vacuous, never as a pass. This is the whole point of the leg:
# 0 rules matched means NOTHING was checked, however green the exit code looked.
if [ "$lint_status" = "pass" ] && [ "$rules_matched" -eq 0 ]; then
  lint_status="pass_vacuous"
  [ -n "$lint_detail" ] || lint_detail="the lint reported no violations, but 0 of ${rules_total} rules' file-halves match any discovered .lean path under the linted roots -- nothing was actually checked"
fi

# ─── Leg 2: the Books.Meta import-closure check ────────────────────────────────────────────────
# Two predicates, both pure grep, no build:
#   (1) no live `.lean` file carries a PUBLIC import of the provider module (`public import
#       Books.Meta`, including the `public meta import Books.Meta` form). A public import would
#       propagate `Lean` into every consumer's public import closure, which is exactly what the
#       provider's own lakefile header forbids. The sanctioned form is a PRIVATE import, which
#       214 live files use and which is never a violation.
#   (2) the provider package declares no `require` -- it builds against core Lean alone.
# `.lake/` AND `specs/` are both pruned. Pruning `specs/` is mandatory, not cosmetic: archived
# prototype sources under `specs/archive/` carry the public form and would otherwise be reported
# as live violations on the gate's very first run.
closure_status=""
closure_violations=()
private_import_sites=0
provider_require_lines=0
provider_lakefile="${repo_root}/books/lean/lakefile.toml"

if [ ! -d "${repo_root}/books/lean" ]; then
  closure_status="provider_absent"
else
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    closure_violations+=("$hit")
  done <<< "$(cd "$repo_root" && find . -name '*.lean' -not -path '*/.lake/*' -not -path './specs/*' 2>/dev/null \
               | LC_ALL=C sort \
               | while IFS= read -r f; do
                   if grep -qE '^[[:space:]]*public[[:space:]]+(meta[[:space:]]+)?import[[:space:]]+Books\.Meta[[:space:]]*$' "$f" 2>/dev/null; then
                     printf '%s\n' "${f#./}"
                   fi
                 done)"

  private_import_sites="$(cd "$repo_root" && find . -name '*.lean' -not -path '*/.lake/*' -not -path './specs/*' 2>/dev/null \
    | while IFS= read -r f; do
        if grep -qE '^[[:space:]]*(meta[[:space:]]+)?import[[:space:]]+Books\.Meta[[:space:]]*$' "$f" 2>/dev/null; then
          printf 'x\n'
        fi
      done | grep -c . || true)"
  case "$private_import_sites" in (*[!0-9]*|"") private_import_sites=0 ;; esac

  if [ -f "$provider_lakefile" ]; then
    provider_require_lines="$(grep -cE '^[[:space:]]*(\[\[require\]\]|require[[:space:]])' "$provider_lakefile" 2>/dev/null || true)"
    case "$provider_require_lines" in (*[!0-9]*|"") provider_require_lines=0 ;; esac
  fi

  if [ "${#closure_violations[@]}" -gt 0 ] || [ "$provider_require_lines" -gt 0 ]; then
    closure_status="violations"
  else
    closure_status="pass"
  fi
fi

# ─── Emit the single JSON object; exit 0 unconditionally in the advisory role ──────────────────
json_array() {
  # Emits a JSON array of strings from the remaining arguments, with no jq dependency.
  local first=1 item
  printf '['
  for item in "$@"; do
    [ "$first" -eq 1 ] || printf ', '
    first=0
    printf '%s' "$item" \
      | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' \
      | awk 'BEGIN{printf "\""} {printf "%s", $0} END{printf "\""}'
  done
  printf ']'
}

json_string() {
  printf '%s' "$1" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' \
    | awk 'BEGIN{printf "\""} NR>1{printf "\\n"} {printf "%s", $0} END{printf "\""}'
}

end_ts=$(date +%s)
runtime=$((end_ts - start_ts))

{
  printf '{\n'
  printf '  "ran": true,\n'
  printf '  "layer_lint": {\n'
  printf '    "status": %s,\n' "$(json_string "$lint_status")"
  printf '    "package_roots": %s,\n' "$(json_array "${package_roots[@]+"${package_roots[@]}"}")"
  printf '    "modules": %s,\n' "$lint_modules"
  printf '    "imports": %s,\n' "$lint_imports"
  printf '    "rules_matched": %s,\n' "$rules_matched"
  printf '    "rules_total": %s,\n' "$rules_total"
  printf '    "violations": %s,\n' "$(json_array "${lint_violations[@]+"${lint_violations[@]}"}")"
  printf '    "violation_count": %s,\n' "${#lint_violations[@]}"
  printf '    "detail": %s\n' "$(json_string "$lint_detail")"
  printf '  },\n'
  printf '  "books_meta_closure": {\n'
  printf '    "status": %s,\n' "$(json_string "$closure_status")"
  printf '    "public_import_violations": %s,\n' "$(json_array "${closure_violations[@]+"${closure_violations[@]}"}")"
  printf '    "public_import_violation_count": %s,\n' "${#closure_violations[@]}"
  printf '    "private_import_sites": %s,\n' "$private_import_sites"
  printf '    "provider_require_lines": %s\n' "$provider_require_lines"
  printf '  },\n'
  printf '  "runtime_seconds": %s\n' "$runtime"
  printf '}\n'
}

exit 0
