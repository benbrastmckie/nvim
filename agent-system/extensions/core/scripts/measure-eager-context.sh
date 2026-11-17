#!/usr/bin/env bash
# measure-eager-context.sh - PREDICTS the session-start eager context set from the SOURCE STORE
# alone, plus a modeled regenerate, and reports bytes / bytes-4 token estimates per contributing
# source and in total.
#
# WHY "PREDICT", NEVER "MEASURE THE DEPLOYED TREE": the deployed `.claude/` tree is a disposable
# build artifact (see .claude/rules/source-store-deploy-boundary.md) that routinely lags the
# source store. A script that read `.claude/CLAUDE.md` / `.claude/rules/*.md` directly would
# silently report a stale number the moment any source-store edit landed without an intervening
# redeploy -- exactly the staleness this harness exists to eliminate as a dependency. This script
# therefore reads ONLY agent-system/extensions/** and the project-root state files
# (.claude-extensions.json, the two parent-chain CLAUDE.md files) and MODELS what a regenerate
# would produce by replicating generate_claudemd() (lua/neotex/plugins/ai/shared/extensions/
# merge.lua:768-879) directly in bash.
#
# HARD POLICY CONSTRAINT -- DO NOT "FIX" THIS BY SHELLING OUT: this script MUST NOT invoke
# deploy-headless.sh or nvim (headless or otherwise) to obtain a "real" regenerate.
# context/patterns/regeneration-is-manual-only.md licenses exactly ONE automated caller of
# deploy-headless.sh (skill-orchestrate Stage MT-3); this script is not it, and adding a call here
# would be an out-of-policy new automated caller as well as reintroducing the exact
# deployed-tree/staleness dependency this harness exists to remove.
#
# FOUR CHANNELS MEASURED (see context/architecture/context-layers.md's "Eager vs. Lazy Loading
# Channels" for the canonical description each channel implements):
#   1. parent_chain  - the native CLAUDE.md chain Claude Code walks upward (parent ~/.config/
#                       CLAUDE.md, this repo's root CLAUDE.md). Always eager, unconditionally.
#   2. claudemd      - the PREDICTED assembled `.claude/CLAUDE.md`, computed by replicating
#                       generate_claudemd()'s algorithm against source-store files: read active
#                       extensions from .claude-extensions.json (sorted, core pulled to front),
#                       resolve each extension's merge_targets.claudemd.source from its own
#                       manifest.json, prepend core/templates/claudemd-header.md UNTRIMMED when
#                       core is active, right-trim every fragment (matching Lua's
#                       fragment:gsub("%s+$", "") -- fragments only; the header itself is never
#                       trimmed), join with "\n\n", append one trailing "\n". This is materialized
#                       in a scratch file and measured with `wc -c` rather than computed by
#                       hand-rolled byte arithmetic, because the header is deliberately NOT
#                       trimmed while fragments ARE -- an asymmetry easy to get wrong arithmetically
#                       but trivially correct when the document is actually built and measured.
#   3. at_import     - `@`-prefixed path tokens inside the parent-chain files and the predicted
#                       generated CLAUDE.md, resolved relative to each CONTAINING FILE's OWN
#                       DIRECTORY (never the repo root, never .claude/ unconditionally) and
#                       existence-tested. A resolving ref contributes its bytes; a dangling ref is
#                       reported on its own line contributing 0 B (informational -- a future added-
#                       but-broken ref becomes visible instead of silently inert) and never fails
#                       --check by itself. Currently expected to report 0 resolving and 0 dangling
#                       refs: no `@`-ref exists anywhere in this chain today (context-layers.md
#                       channel 2 explains why merge sources deliberately use plain backticked
#                       paths instead) -- that is the CORRECT result, not evidence the channel is
#                       unexercised.
#   4. rules         - every source-store agent-system/extensions/*/rules/*.md file belonging to a
#                       CURRENTLY ACTIVE extension, classified by glob-MATCHING its `paths:`
#                       frontmatter against a representative touched-path set (see
#                       glob_to_ere()/EAGER_REP_PATHS below), never by hardcoding a rule-name list.
#
# THE CORRECTED `paths:` MODEL (deviation from a naive "absent or `**/*`" reading, recorded here
# per the plan's explicit instruction): checking only for absent-or-universal frontmatter
# undercounts eager rules by ~71%, because rules gated on `specs/**/*` / `.claude/**/*` (e.g.
# git-workflow.md, artifact-formats.md, state-management.md, error-handling.md, workflows.md) are
# ALSO effectively eager -- those globs match virtually any real session. See
# specs/archive/054_split_eager_rules_budget/baseline-bytes.md, section "Eager-Context
# Measurement-Harness Correction", for the full data behind this correction. This script instead
# glob-matches every rule's `paths:` value against EAGER_REP_PATHS (default
# "specs/**,.claude/**", overridable, echoed in every run's output so a reader can audit the
# classification rather than trust a hardcoded list). Consequence, stated plainly rather than
# reconciled away: this script's rule total EXCEEDS measure-eager-surface.sh's hardcoded six-rule
# figure by error-handling.md + workflows.md's combined bytes (both gated on `.claude/**/*` alone,
# which the historical six-rule baseline's `specs/**`-only representative set never caught). This
# is a correct, by-design divergence, not a bug to chase.
#
# VOLATILE-FILE GUARD: specs/TODO.md, specs/state.json (VOLATILE_PATHS array,
# extensible) must never be counted as legitimately eager. Every candidate path considered by any
# channel is checked against this deny-list; a hit emits a loud `FLAG:` line, excludes the file's
# bytes from the eager total, and makes --check exit 1. Today this class is empty in every channel
# (a forward-looking guard, not a fix for an observed violation).
#
# RELATIONSHIP TO measure-eager-surface.sh (both scripts COEXIST; neither supersedes the other):
# measure-eager-surface.sh remains the deployed-tree before/after delta tool with a FIXED
# nine-file/six-rule composition -- useful for apples-to-apples comparison across a single
# before/after cut. This script is the source-store PREDICTIVE harness with DYNAMIC `paths:`
# derivation, intended to answer "what would the eager set be if I redeployed right now" without
# ever requiring an actual redeploy. Its rule total is intentionally wider than
# measure-eager-surface.sh's historical six-rule figure (see the corrected-model paragraph above).
#
# Usage:
#   bash measure-eager-context.sh                 (--check, default) report only, exit 0/1
#   bash measure-eager-context.sh --check          same as above, explicit
#   bash measure-eager-context.sh --write [path]   report + write a timestamped JSON snapshot
#                                                   (default path under specs/ if omitted) for
#                                                   later drift comparison
#
# --check fails ONLY on a volatile-file hit or an unreadable required source -- never merely
# because the total changed from a prior run.
#
# STABLE OUTPUT CONTRACT: one tab-delimited record per contributing source, in the fixed field
# order CHANNEL / LABEL / PATH / BYTES / TOKENS_EST, preceded by a header line naming the fields.
# Per-channel SUBTOTAL rows and one grand TOTAL row (bytes + bytes/4 token estimate) follow. A
# FLAG line (volatile-file hit) and DANGLING lines (unresolved @-refs) use their own leading
# tokens and are never counted in any subtotal/total. This format is designed for `grep`/`cut` or
# `awk -F'\t'` consumption without depending on column alignment.
#
# --write's JSON snapshot models its CONTENT SHAPE on measure-eager-surface.sh's write_json()
# (timestamp, a flat sources array of {channel,label,path,bytes,tokens_est}, per-channel
# subtotals, total_bytes/total_tokens_est) while using THIS script's --check/--write flag
# vocabulary (matching generate-context-line-counts.sh's naming), not
# measure-eager-surface.sh's --baseline/--compare names. It additionally records the active
# representative touched-path set, so a later comparison can tell whether a delta came from
# content drift or from a changed measurement policy.

set -uo pipefail

# Same REPO_ROOT-bypass pattern as generate-context-line-counts.sh / measure-eager-surface.sh: the
# deploy-root-guard only fires when REPO_ROOT is unset, so a deliberate source-store invocation
# (REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh) works
# without tripping the guard.
[[ -n "${REPO_ROOT:-}" ]] || . "$(dirname "${BASH_SOURCE[0]}")/deploy-root-guard.sh" || exit 1
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
EXT_DIR="${EXT_DIR:-$REPO_ROOT/agent-system/extensions}"

MODE="check"
SNAPSHOT_PATH=""
case "${1:-}" in
  --write)
    MODE="write"
    SNAPSHOT_PATH="${2:-$REPO_ROOT/specs/.eager-context-snapshot-$(date -u +%Y%m%dT%H%M%SZ).json}"
    ;;
  --check|"")
    MODE="check"
    ;;
  *)
    echo "Usage: $(basename "$0") [--check|--write [snapshot-path]]" >&2
    exit 2
    ;;
esac

if [[ ! -d "$EXT_DIR" ]]; then
  echo "ERROR: $EXT_DIR does not exist" >&2
  exit 1
fi

# --- Small helpers ------------------------------------------------------------------------------

bytes_of() {
  # Prints 0 (not an error) for a missing file -- absence is reported, not fatal.
  local f="$1"
  if [[ -f "$f" ]]; then
    wc -c < "$f" | tr -d ' '
  else
    echo 0
  fi
}

tokens_of() {
  # Integer bytes/4 token estimate, matching this repo's standing bytes/4 heuristic.
  local b="$1"
  echo $(( b / 4 ))
}

# Volatile-file deny-list: files mutated on every task operation. Must never be counted as
# legitimately eager even if some future channel would otherwise include them. Extensible.
VOLATILE_PATHS=(
  "specs/TODO.md"
  "specs/state.json"
)

is_volatile() {
  # Compares a REPO_ROOT-relative path against VOLATILE_PATHS.
  local rel="$1" v
  for v in "${VOLATILE_PATHS[@]}"; do
    [[ "$rel" == "$v" ]] && return 0
  done
  return 1
}

VOLATILE_HITS=0

# Accumulators for the stable-output records (parallel arrays, one entry per record).
declare -a REC_CHANNEL=()
declare -a REC_LABEL=()
declare -a REC_PATH=()
declare -a REC_BYTES=()
declare -a REC_TOKENS=()

add_record() {
  # add_record <channel> <label> <repo-relative-path-or-marker> <bytes>
  local channel="$1" label="$2" relpath="$3" b="$4"
  if is_volatile "$relpath"; then
    echo "FLAG: volatile file '$relpath' would be eagerly loaded by channel '$channel' ($label) -- excluded from eager total" >&2
    VOLATILE_HITS=$((VOLATILE_HITS + 1))
    return
  fi
  REC_CHANNEL+=("$channel")
  REC_LABEL+=("$label")
  REC_PATH+=("$relpath")
  REC_BYTES+=("$b")
  REC_TOKENS+=("$(tokens_of "$b")")
}

to_rel() {
  # Best-effort REPO_ROOT-relative rendering of an absolute path, for stable/portable output.
  local p="$1"
  printf '%s' "${p#"$REPO_ROOT"/}"
}

# --- Channel 1: parent CLAUDE.md chain -----------------------------------------------------------

PARENT_CLAUDE_MD="$(dirname "$REPO_ROOT")/CLAUDE.md"
ROOT_CLAUDE_MD="$REPO_ROOT/CLAUDE.md"

PARENT_BYTES=$(bytes_of "$PARENT_CLAUDE_MD")
ROOT_BYTES=$(bytes_of "$ROOT_CLAUDE_MD")
add_record "parent_chain" "parent CLAUDE.md" "$(dirname "$REPO_ROOT")/CLAUDE.md" "$PARENT_BYTES"
add_record "parent_chain" "repo CLAUDE.md" "CLAUDE.md" "$ROOT_BYTES"

# --- Channel 2: predicted assembled .claude/CLAUDE.md ---------------------------------------------
#
# Replicates generate_claudemd() (merge.lua:768-879): read active extensions (sorted, core first),
# resolve each one's merge_targets.claudemd.source from ITS OWN manifest.json (never hardcode
# either the shape-(a) `merge-sources/claudemd.md` or shape-(b) `EXTENSION.md` source-path
# convention -- both exist across currently-active extensions), prepend the core header template
# UNTRIMMED, right-trim every fragment, join with "\n\n", append one trailing "\n". Materialized in
# a scratch file and measured with `wc -c` -- this is Phase 1's documented fallback-made-default:
# the header/fragment trim asymmetry is easy to get wrong via hand arithmetic and trivial to get
# right by actually building the document.

PREDICTED_CLAUDEMD_TMP="$(mktemp)"
cleanup_predicted() { rm -f "$PREDICTED_CLAUDEMD_TMP"; }
trap cleanup_predicted EXIT

ACTIVE_EXTENSIONS=()
if [[ -f "$REPO_ROOT/.claude-extensions.json" ]]; then
  while IFS= read -r ext; do
    [[ -n "$ext" ]] && ACTIVE_EXTENSIONS+=("$ext")
  done < <(jq -r '.extensions | to_entries[] | select(.value.status=="active") | .key' "$REPO_ROOT/.claude-extensions.json" 2>/dev/null | sort)
else
  echo "WARNING: $REPO_ROOT/.claude-extensions.json not found -- predicted CLAUDE.md will be empty" >&2
fi

# Core pulled to the front (a no-op today since "core" already sorts first, but the algorithm
# guarantees it regardless of future extension naming).
ORDERED_EXTENSIONS=()
for e in "${ACTIVE_EXTENSIONS[@]}"; do
  [[ "$e" == "core" ]] && ORDERED_EXTENSIONS+=("core")
done
for e in "${ACTIVE_EXTENSIONS[@]}"; do
  [[ "$e" == "core" ]] || ORDERED_EXTENSIONS+=("$e")
done

CORE_ACTIVE=0
for e in "${ORDERED_EXTENSIONS[@]}"; do
  [[ "$e" == "core" ]] && CORE_ACTIVE=1
done

right_trim_file() {
  # Strips ALL trailing whitespace (space/tab/newline/CR/FF/VT) from the end of the file's
  # content, matching Lua's fragment:gsub("%s+$", "") on the whole fragment string.
  perl -0777 -pe 's/\s+\z//' "$1" 2>/dev/null
}

FIRST_PART=1
HEADER_TEMPLATE="$EXT_DIR/core/templates/claudemd-header.md"
if [[ "$CORE_ACTIVE" -eq 1 && -f "$HEADER_TEMPLATE" ]]; then
  cat "$HEADER_TEMPLATE" >> "$PREDICTED_CLAUDEMD_TMP"
  FIRST_PART=0
fi

for e in "${ORDERED_EXTENSIONS[@]}"; do
  manifest="$EXT_DIR/$e/manifest.json"
  [[ -f "$manifest" ]] || continue
  jq empty "$manifest" 2>/dev/null || continue
  source_rel=$(jq -r '.merge_targets.claudemd.source // empty' "$manifest" 2>/dev/null)
  [[ -n "$source_rel" ]] || continue
  source_abs="$EXT_DIR/$e/$source_rel"
  [[ -f "$source_abs" ]] || continue
  if [[ "$FIRST_PART" -eq 1 ]]; then
    FIRST_PART=0
  else
    printf '\n\n' >> "$PREDICTED_CLAUDEMD_TMP"
  fi
  right_trim_file "$source_abs" >> "$PREDICTED_CLAUDEMD_TMP"
done
printf '\n' >> "$PREDICTED_CLAUDEMD_TMP"

PREDICTED_CLAUDEMD_BYTES=$(bytes_of "$PREDICTED_CLAUDEMD_TMP")
add_record "claudemd" "predicted .claude/CLAUDE.md (assembled)" ".claude/CLAUDE.md [predicted]" "$PREDICTED_CLAUDEMD_BYTES"

# --- Channel 3: @-import resolution ---------------------------------------------------------------
#
# An @-ref resolves relative to the CONTAINING FILE's own directory (context-layers.md channel 2).
# For the parent/root CLAUDE.md files that is straightforward; for the predicted generated
# CLAUDE.md the containing directory is the TARGET directory ($REPO_ROOT/.claude), because that is
# where a regenerate would place the file -- the non-obvious half of the directory-relative rule,
# called out explicitly here since the predicted content never actually lives on disk at that path.

AT_IMPORT_TOTAL=0

scan_at_imports() {
  # scan_at_imports <content-file> <containing-dir> <source-label>
  local content_file="$1" containing_dir="$2" source_label="$3"
  [[ -f "$content_file" ]] || return
  local token target rel
  while IFS= read -r token; do
    [[ -n "$token" ]] || continue
    target="$containing_dir/${token#@}"
    if [[ -f "$target" ]]; then
      rel="$(to_rel "$(cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")" 2>/dev/null)"
      [[ -n "$rel" ]] || rel="${token#@}"
      local b
      b=$(bytes_of "$target")
      add_record "at_import" "@-import from $source_label" "$rel" "$b"
    else
      echo "DANGLING: @-ref '$token' in $source_label does not resolve (expected: $target)" >&2
    fi
  done < <(grep -ohE '@[A-Za-z0-9_./-]+' "$content_file" 2>/dev/null | sort -u)
}

scan_at_imports "$PARENT_CLAUDE_MD" "$(dirname "$PARENT_CLAUDE_MD")" "parent CLAUDE.md"
scan_at_imports "$ROOT_CLAUDE_MD" "$(dirname "$ROOT_CLAUDE_MD")" "repo CLAUDE.md"
scan_at_imports "$PREDICTED_CLAUDEMD_TMP" "$REPO_ROOT/.claude" "predicted .claude/CLAUDE.md"

for ((i = 0; i < ${#REC_CHANNEL[@]}; i++)); do
  if [[ "${REC_CHANNEL[$i]}" == "at_import" ]]; then
    AT_IMPORT_TOTAL=$((AT_IMPORT_TOTAL + REC_BYTES[i]))
  fi
done

# --- Channel 4: rules `paths:` glob-match (corrected model) ---------------------------------------
#
# glob_to_ere() translates a `paths:` glob into a POSIX ERE for `[[ str =~ ere ]]` matching.
# Deliberately NOT bash `[[ str == pattern ]]`: inside `[[ ]]`, `**` is treated as a plain `*`
# regardless of `shopt -s globstar`, and `*` does not cross `/`, so `specs/**/*` would silently
# fail to match a nested path (e.g. specs/000_example/reports/01_example.md) under that form.

glob_to_ere() {
  local pat="$1"
  local out="$pat"
  # Escape ERE metacharacters that are not glob wildcards. Order matters: none of these overlap.
  out="${out//"."/"\."}"
  out="${out//"^"/"\^"}"
  out="${out//"\$"/"\\\$"}"
  out="${out//"("/"\("}"
  out="${out//")"/"\)"}"
  out="${out//"+"/"\+"}"
  out="${out//"{"/"\{"}"
  out="${out//"}"/"\}"}"
  out="${out//"|"/"\|"}"
  out="${out//"["/"\["}"
  out="${out//"]"/"\]"}"
  # Translate glob wildcards -> ERE. Order matters: '**/' before '**' before '*'.
  out="${out//"**/"/@@EAGER_DBLSTAR_SLASH@@}"
  out="${out//"**"/@@EAGER_DBLSTAR@@}"
  out="${out//"*"/[^/]*}"
  out="${out//"?"/[^/]}"
  out="${out//"@@EAGER_DBLSTAR_SLASH@@"/(.*/)?}"
  out="${out//"@@EAGER_DBLSTAR@@"/.*}"
  printf '^%s$' "$out"
}

# Representative touched-path set: a policy choice, not a fact (see the research report's Finding
# 3 subtlety on the historical six-rule baseline vs. the correction note's wider "at minimum"
# wording). Default follows the correction's literal wording; overridable via a comma-separated
# EAGER_REP_PATHS env var, following the REPO_ROOT/EXT_DIR override style already used in this
# scripts directory. These are probe STRINGS only -- nothing is read from them.
DEFAULT_REP_PATHS="specs/000_example/reports/01_example.md,.claude/context/example.md"
IFS=',' read -r -a EAGER_REP_PATHS <<< "${EAGER_REP_PATHS:-$DEFAULT_REP_PATHS}"

# normalize_paths_field <raw paths: value> -> newline-separated member globs on stdout.
# Handles both scalar ("specs/**/*", "**/*") and JSON-array (["specs/**/*", ".claude/**/*"]) forms.
normalize_paths_field() {
  local raw="$1"
  raw="${raw%$'\r'}"
  if [[ "$raw" == \[*\] ]]; then
    printf '%s' "$raw" | jq -r '.[]' 2>/dev/null
  else
    # Strip a single layer of surrounding double quotes, if present.
    raw="${raw%\"}"
    raw="${raw#\"}"
    printf '%s\n' "$raw"
  fi
}

rule_matches_rep_paths() {
  # rule_matches_rep_paths <paths-field-raw> -> prints "glob<TAB>probe" of the first match, or
  # nothing (and returns 1) if no member glob matches any representative path.
  local raw="$1" glob probe ere
  while IFS= read -r glob; do
    [[ -n "$glob" ]] || continue
    ere="$(glob_to_ere "$glob")"
    for probe in "${EAGER_REP_PATHS[@]}"; do
      if [[ "$probe" =~ $ere ]]; then
        printf '%s\t%s\n' "$glob" "$probe"
        return 0
      fi
    done
  done <<< "$(normalize_paths_field "$raw")"
  return 1
}

RULES_TOTAL=0

for rule_file in "$EXT_DIR"/*/rules/*.md; do
  [[ -f "$rule_file" ]] || continue
  ext_name="$(basename "$(dirname "$(dirname "$rule_file")")")"

  # Restrict to currently active extensions only -- an inactive extension's rules never deploy.
  is_active=0
  for e in "${ACTIVE_EXTENSIONS[@]}"; do
    [[ "$e" == "$ext_name" ]] && is_active=1
  done
  [[ "$is_active" -eq 1 ]] || continue

  paths_raw=""
  fm_present=0
  # YAML frontmatter is a `---` delimited block at the top of the file; `paths:` may be a scalar
  # (possibly quoted) or a JSON-array-style value, both on a single line in this codebase.
  while IFS= read -r line; do
    [[ "$line" == "---" ]] && { [[ $fm_present -eq 0 ]] && { fm_present=1; continue; }; break; }
    if [[ $fm_present -eq 1 && "$line" == paths:* ]]; then
      paths_raw="${line#paths:}"
      paths_raw="${paths_raw# }"
    fi
  done < "$rule_file"

  rel="agent-system/extensions/$ext_name/rules/$(basename "$rule_file")"
  b=$(bytes_of "$rule_file")
  label=".claude/rules/$(basename "$rule_file")"

  if [[ -z "$paths_raw" ]]; then
    add_record "rules" "$label" "$rel" "$b"
    echo "  rule eager: $label (frontmatter absent)" >&2
    RULES_TOTAL=$((RULES_TOTAL + b))
    continue
  fi

  match_line="$(rule_matches_rep_paths "$paths_raw")"
  if [[ -n "$match_line" ]]; then
    matched_glob="${match_line%%$'\t'*}"
    matched_probe="${match_line#*$'\t'}"
    add_record "rules" "$label" "$rel" "$b"
    echo "  rule eager: $label (matched glob '$matched_glob' against probe '$matched_probe')" >&2
    RULES_TOTAL=$((RULES_TOTAL + b))
  else
    echo "  rule deferred: $label (paths: $paths_raw; no representative-path match)" >&2
  fi
done

# --- Totals ----------------------------------------------------------------------------------

sum_channel() {
  local channel="$1" total=0
  for ((i = 0; i < ${#REC_CHANNEL[@]}; i++)); do
    [[ "${REC_CHANNEL[$i]}" == "$channel" ]] && total=$((total + REC_BYTES[i]))
  done
  echo "$total"
}

PARENT_CHAIN_TOTAL=$(sum_channel "parent_chain")
CLAUDEMD_TOTAL=$(sum_channel "claudemd")
AT_IMPORT_TOTAL=$(sum_channel "at_import")
RULES_TOTAL=$(sum_channel "rules")
GRAND_TOTAL=$((PARENT_CHAIN_TOTAL + CLAUDEMD_TOTAL + AT_IMPORT_TOTAL + RULES_TOTAL))
GRAND_TOKENS=$(tokens_of "$GRAND_TOTAL")

# --- Output ------------------------------------------------------------------------------------

echo "measure-eager-context.sh (predictive; source-store only, never the deployed tree)"
echo "Representative touched-path set (EAGER_REP_PATHS): ${EAGER_REP_PATHS[*]}"
echo
printf '%s\t%s\t%s\t%s\t%s\n' "CHANNEL" "LABEL" "PATH" "BYTES" "TOKENS_EST"
for ((i = 0; i < ${#REC_CHANNEL[@]}; i++)); do
  printf '%s\t%s\t%s\t%s\t%s\n' "${REC_CHANNEL[$i]}" "${REC_LABEL[$i]}" "${REC_PATH[$i]}" "${REC_BYTES[$i]}" "${REC_TOKENS[$i]}"
done
echo
printf '%s\t%s\t%s\n' "SUBTOTAL" "parent_chain" "$PARENT_CHAIN_TOTAL"
printf '%s\t%s\t%s\n' "SUBTOTAL" "claudemd" "$CLAUDEMD_TOTAL"
printf '%s\t%s\t%s\n' "SUBTOTAL" "at_import" "$AT_IMPORT_TOTAL"
printf '%s\t%s\t%s\n' "SUBTOTAL" "rules" "$RULES_TOTAL"
printf '%s\t%s\t%s\n' "TOTAL" "$GRAND_TOTAL" "$GRAND_TOKENS"
echo
echo "=== Summary ($MODE mode) ==="
echo "Parent chain: $PARENT_CHAIN_TOTAL B"
echo "Predicted assembled CLAUDE.md: $CLAUDEMD_TOTAL B"
echo "@-imports resolved: $AT_IMPORT_TOTAL B"
echo "Eager rules: $RULES_TOTAL B"
echo "TOTAL: $GRAND_TOTAL B ($GRAND_TOKENS tokens est.)"
echo "Volatile-file hits: $VOLATILE_HITS"

write_json() {
  local out="$1"
  local sources_json="[]" probes_json
  if [[ ${#REC_CHANNEL[@]} -gt 0 ]]; then
    sources_json="$(
      for ((i = 0; i < ${#REC_CHANNEL[@]}; i++)); do
        jq -n --arg channel "${REC_CHANNEL[$i]}" --arg label "${REC_LABEL[$i]}" \
          --arg path "${REC_PATH[$i]}" --argjson bytes "${REC_BYTES[$i]}" \
          --argjson tokens_est "${REC_TOKENS[$i]}" \
          '{channel: $channel, label: $label, path: $path, bytes: $bytes, tokens_est: $tokens_est}'
      done | jq -s '.'
    )"
  fi
  probes_json="$(printf '%s\n' "${EAGER_REP_PATHS[@]}" | jq -R . | jq -s '.')"
  jq -n \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson sources "$sources_json" \
    --argjson probes "$probes_json" \
    --argjson parent_chain_total "$PARENT_CHAIN_TOTAL" \
    --argjson claudemd_total "$CLAUDEMD_TOTAL" \
    --argjson at_import_total "$AT_IMPORT_TOTAL" \
    --argjson rules_total "$RULES_TOTAL" \
    --argjson total_bytes "$GRAND_TOTAL" \
    --argjson total_tokens_est "$GRAND_TOKENS" \
    --argjson volatile_hits "$VOLATILE_HITS" \
    '{
      timestamp: $timestamp,
      representative_paths: $probes,
      sources: $sources,
      subtotals: {
        parent_chain: $parent_chain_total,
        claudemd: $claudemd_total,
        at_import: $at_import_total,
        rules: $rules_total
      },
      total_bytes: $total_bytes,
      total_tokens_est: $total_tokens_est,
      volatile_hits: $volatile_hits
    }' > "$out"
}

if [[ "$MODE" == "write" ]]; then
  write_json "$SNAPSHOT_PATH"
  echo
  echo "Snapshot written to: $SNAPSHOT_PATH"
fi

if [[ "$VOLATILE_HITS" -gt 0 ]]; then
  echo
  echo "CHECK FAILED: $VOLATILE_HITS volatile-file hit(s) -- see FLAG: lines above"
  exit 1
fi

echo
echo "CHECK PASSED: no volatile-file hits"
exit 0
