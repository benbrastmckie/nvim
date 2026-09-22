#!/usr/bin/env bash
# task-type-detect.sh - Single source of truth for /task step 4's task_type detection sequence.
#
# Sourced (never executed) by commands/task.md's Create Mode step 4 and referenced by
# commands/fix-it.md's research-task language detection. Implements the strong-anchor +
# weak-signal-threshold resolution ladder documented in
# specs/210_fix_task_create_topic_assignment_order/plans/01_topic-order-and-keyword-routing.md's
# Decision D6 (see that plan's "D6 detail: the detection rule" section for the full rationale and
# the worked acceptance-case table).
#
# Resolution order (preserves the shape of the original step-4 4a-4e sequence; only 4a and 4d
# change behavior -- 4b, 4c, and 4e port across unchanged):
#   1. Strong anchors (new, replaces 4a) -- a single high-confidence phrase/pattern match
#      resolves immediately to "meta" or "lean4".
#   2. Extension keyword_overrides scan (4b, unchanged in mechanism) -- first match across
#      .claude/extensions/*/manifest.json in alphabetical directory-name order, is FINAL (not
#      subject to alias remapping by step 5).
#   3. Project default (4c, unchanged) -- state.json's .default_task_type, if set.
#   4. Weak-signal scoring (new, replaces 4d's first-match-wins table) -- each candidate type
#      accumulates a count of DISTINCT matched keywords over the whole description; a type
#      resolves only at >= DTD_WEAK_THRESHOLD distinct matches; highest count wins; ties break by
#      table order (meta, lean4, then the remaining rows in their original 4d order); zero types
#      reaching the threshold resolves to "general".
#   5. Alias remapping (4e, unchanged) -- applied ONLY to a result from step 3 or step 4, never
#      to a strong-anchor (step 1) or keyword_overrides (step 2) result.
#
# CONTRACT (mirrors manifest-routing-lib.sh's sourcing contract):
#   - Never calls `exit` -- a faulty resolution at worst returns "general".
#   - Sets no shell options (no `set -e`, no `set -u`, no `set -o pipefail`) on the calling
#     shell -- sourcing this file must never change the caller's error-handling behavior.
#   - Every internal variable/function is prefixed `_dtd_` or `DTD_` and function-local
#     variables are explicitly `local`, so sourcing this file does not leak working state beyond
#     its two intentionally-caller-visible pieces: the detect_task_type function itself and the
#     DTD_WEAK_THRESHOLD constant (retunable without restructuring, per D6's risk mitigation).
#   - Matching is case-insensitive throughout. Weak-signal keywords and multi-word/hyphenated
#     strong-anchor keywords use whole-word boundaries (`\b<keyword>\b`); the meta strong-anchor
#     literal strings (".claude/", "specs/", "manifest.json", etc.) are fixed-string substring
#     matches via `grep -F`, matching how those tokens actually appear in prose.
#   - Uses the `select(... | not)` jq idiom rather than `!=` throughout (Claude Code Issue #1132).
#
# Usage:
#   source .claude/scripts/lib/task-type-detect.sh
#   task_type=$(detect_task_type "$description" "specs/state.json" ".claude/extensions")
#
# Arguments:
#   $1 - description (required): the task description text to classify.
#   $2 - state_file (optional, default "specs/state.json"): read for .default_task_type (step 3).
#        A missing file is treated as "no project default" (falls through to step 4).
#   $3 - extensions_dir (optional, default ".claude/extensions"): scanned for
#        <extensions_dir>/*/manifest.json (steps 2 and 5). A missing directory or empty glob is
#        treated as "no manifests" (both steps become no-ops).
#
# Output: echoes the resolved task_type on stdout, always non-empty (worst case "general").

# ─── Weak-signal table (step 4) ────────────────────────────────────────────────────────────────
# Ordered "type|kw1,kw2,..." entries. Order is the tie-break order when two or more types reach
# the threshold with an equal distinct-match count: meta, then lean4, then the remaining rows in
# their original 4d table order (unchanged from before this task). A keyword entry may itself
# contain a literal space or hyphen (e.g. "pitch deck", "home-manager", "case-control") -- only
# the comma is a field separator.
DTD_WEAK_SIGNAL_TABLE=(
  "meta|meta,agent,command,skill,hook,rule,dispatch,orchestrate"
  "lean4|lean,theorem,proof,lemma,axiom,proposition,corollary,derivation,formalize,formalization"
  "general|textbook,chapter,thesis,dissertation"
  "formal|formal,logic,math,physics,modal,kripke"
  "latex|latex,tex,typeset"
  "typst|typst"
  "python|python,pytest,pip"
  "z3|z3,smt,solver,constraint"
  "nix|nix,nixos,home-manager,flake"
  "web|web,astro,tailwind,cloudflare"
  "epi:study|epidemiology,epi,cohort,case-control,strobe"
  "founder:deck|deck,slide,presentation,pitch deck"
  "founder:sheet|spreadsheet,sheet,excel"
  "founder:finance|finance,financial,revenue,burn rate"
  "founder:market|market size,tam,sam,som"
  "founder:analyze|competitive,competitor"
  "founder:strategy|strategy,strategic,roadmap"
  "founder:legal|legal,contract,agreement"
  "founder:project|project plan,timeline,milestone"
  "founder|founder,go-to-market,gtm"
)

# A type resolves via weak-signal scoring only when its distinct matched-keyword count reaches
# this value. One named constant, so the threshold is retunable without restructuring the
# scoring function itself (see the plan's Risk table: "Weak-signal threshold of 2 misroutes a
# genuine short description" is a named, retunable risk, not a hardcoded magic number).
DTD_WEAK_THRESHOLD=2

# ─── Step 1: strong anchors ────────────────────────────────────────────────────────────────────

# _dtd_strong_anchor_meta <desc_lower> <desc_original> -- echoes "hit" if a meta strong anchor
# is present, otherwise echoes nothing. Fixed-string literals matched via grep -F (no regex
# escaping needed); the two hyphenated-compound patterns and the leading-slash command token
# use grep -E with explicit word boundaries.
_dtd_strong_anchor_meta() {
  local _dtd_desc_lower="$1" _dtd_desc="$2"
  local _dtd_lit
  for _dtd_lit in ".claude/" "agent-system" "agent system" "skill.md" "claude.md" \
                  "manifest.json" "state.json" "slash command" "subagent" "task_type" \
                  "keyword_overrides" "specs/"; do
    if printf '%s' "$_dtd_desc_lower" | grep -Fq -- "$_dtd_lit"; then
      printf 'hit\n'
      return 0
    fi
  done
  # skill-<word> or <word>-agent hyphenated compound (e.g. "skill-orchestrate", "planner-agent")
  if printf '%s' "$_dtd_desc_lower" | grep -Eq '\bskill-[a-z0-9_]+\b|\b[a-z0-9_]+-agent\b'; then
    printf 'hit\n'
    return 0
  fi
  # A leading-slash command token (/task, /orchestrate, /implement, ...): a "/" preceded by
  # start-of-string or whitespace, followed by a word.
  if printf '%s' "$_dtd_desc_lower" | grep -Eq '(^|[[:space:]])/[a-z][a-z-]*'; then
    printf 'hit\n'
    return 0
  fi
  unset _dtd_desc_lower _dtd_desc _dtd_lit
  return 0
}

# _dtd_strong_anchor_lean4 <desc_lower> -- echoes "hit" if a lean4 strong anchor is present.
_dtd_strong_anchor_lean4() {
  local _dtd_desc_lower="$1"
  local _dtd_lit
  if printf '%s' "$_dtd_desc_lower" | grep -Eq '\.lean\b'; then
    printf 'hit\n'
    return 0
  fi
  for _dtd_lit in "mathlib" "lean4" "mathlib4"; do
    if printf '%s' "$_dtd_desc_lower" | grep -Fq -- "$_dtd_lit"; then
      printf 'hit\n'
      return 0
    fi
  done
  unset _dtd_desc_lower _dtd_lit
  return 0
}

# ─── Step 2: extension keyword_overrides scan (4b, unchanged in mechanism) ────────────────────
# _dtd_scan_keyword_overrides <desc_lower> <extensions_dir> -- echoes the first matched
# task_type, or nothing on a miss. Iterates <extensions_dir>/*/manifest.json in alphabetical
# directory-name order (glob expansion is already alphabetical) and, within a manifest, in the
# JSON's own key declaration order (jq to_entries preserves it) -- first match wins, exactly as
# the original reference jq pattern in commands/task.md did.
_dtd_scan_keyword_overrides() {
  local _dtd_desc_lower="$1" _dtd_ext_dir="$2"
  local _dtd_manifest _dtd_matched
  for _dtd_manifest in "$_dtd_ext_dir"/*/manifest.json; do
    [ -f "$_dtd_manifest" ] || continue
    _dtd_matched=$(jq -r --arg desc "$_dtd_desc_lower" '
      .keyword_overrides // {} | to_entries[] |
      select(.value.keywords[]? as $kw |
        ($desc | test("\\b" + ($kw | ascii_downcase) + "\\b"))) |
      .key' "$_dtd_manifest" 2>/dev/null | head -1)
    if [ -n "$_dtd_matched" ]; then
      printf '%s\n' "$_dtd_matched"
      unset _dtd_desc_lower _dtd_ext_dir _dtd_manifest _dtd_matched
      return 0
    fi
  done
  unset _dtd_desc_lower _dtd_ext_dir _dtd_manifest _dtd_matched
  return 0
}

# ─── Step 5: extension alias remapping (4e, unchanged) ────────────────────────────────────────
# _dtd_alias_remap <task_type> <extensions_dir> -- echoes the remapped task_type if any manifest
# lists <task_type> in a keyword_overrides entry's aliases array, otherwise echoes nothing.
_dtd_alias_remap() {
  local _dtd_tt="$1" _dtd_ext_dir="$2"
  local _dtd_manifest _dtd_aliased
  [ -z "$_dtd_tt" ] && return 0
  for _dtd_manifest in "$_dtd_ext_dir"/*/manifest.json; do
    [ -f "$_dtd_manifest" ] || continue
    _dtd_aliased=$(jq -r --arg tt "$_dtd_tt" '
      .keyword_overrides // {} | to_entries[] |
      select(.value.aliases[]? == $tt) |
      .key' "$_dtd_manifest" 2>/dev/null | head -1)
    if [ -n "$_dtd_aliased" ]; then
      printf '%s\n' "$_dtd_aliased"
      unset _dtd_tt _dtd_ext_dir _dtd_manifest _dtd_aliased
      return 0
    fi
  done
  unset _dtd_tt _dtd_ext_dir _dtd_manifest _dtd_aliased
  return 0
}

# ─── Step 4: weak-signal scoring (replaces 4d's first-match-wins table) ───────────────────────
# _dtd_weak_signal_score <desc_lower> -- echoes the winning type, or "general" if no type reaches
# DTD_WEAK_THRESHOLD distinct matches.
_dtd_weak_signal_score() {
  local _dtd_desc_lower="$1"
  local _dtd_best_type="" _dtd_best_count=0
  local _dtd_entry _dtd_type _dtd_kws _dtd_kw _dtd_count
  for _dtd_entry in "${DTD_WEAK_SIGNAL_TABLE[@]}"; do
    _dtd_type="${_dtd_entry%%|*}"
    _dtd_kws="${_dtd_entry#*|}"
    _dtd_count=0
    local _dtd_kw_arr=()
    IFS=',' read -ra _dtd_kw_arr <<< "$_dtd_kws"
    for _dtd_kw in "${_dtd_kw_arr[@]}"; do
      if printf '%s' "$_dtd_desc_lower" | grep -Eq "\\b${_dtd_kw}\\b"; then
        _dtd_count=$((_dtd_count + 1))
      fi
    done
    if [[ "$_dtd_count" -ge "$DTD_WEAK_THRESHOLD" && "$_dtd_count" -gt "$_dtd_best_count" ]]; then
      _dtd_best_type="$_dtd_type"
      _dtd_best_count="$_dtd_count"
    fi
  done
  if [[ -n "$_dtd_best_type" ]]; then
    printf '%s\n' "$_dtd_best_type"
  else
    printf 'general\n'
  fi
  unset _dtd_desc_lower _dtd_best_type _dtd_best_count _dtd_entry _dtd_type _dtd_kws _dtd_kw \
    _dtd_count _dtd_kw_arr
  return 0
}

# ─── Public entry point ────────────────────────────────────────────────────────────────────────
detect_task_type() {
  local _dtd_desc="${1:-}"
  local _dtd_state_file="${2:-specs/state.json}"
  local _dtd_ext_dir="${3:-.claude/extensions}"
  local _dtd_desc_lower
  _dtd_desc_lower="$(printf '%s' "$_dtd_desc" | tr '[:upper:]' '[:lower:]')"

  # Step 1: strong anchors -- a single match resolves immediately.
  if [ -n "$(_dtd_strong_anchor_meta "$_dtd_desc_lower" "$_dtd_desc")" ]; then
    printf 'meta\n'
    unset _dtd_desc _dtd_state_file _dtd_ext_dir _dtd_desc_lower
    return 0
  fi
  if [ -n "$(_dtd_strong_anchor_lean4 "$_dtd_desc_lower")" ]; then
    printf 'lean4\n'
    unset _dtd_desc _dtd_state_file _dtd_ext_dir _dtd_desc_lower
    return 0
  fi

  # Step 2: extension keyword_overrides -- final, not subject to step 5 alias remapping.
  local _dtd_override
  _dtd_override="$(_dtd_scan_keyword_overrides "$_dtd_desc_lower" "$_dtd_ext_dir")"
  if [ -n "$_dtd_override" ]; then
    printf '%s\n' "$_dtd_override"
    unset _dtd_desc _dtd_state_file _dtd_ext_dir _dtd_desc_lower _dtd_override
    return 0
  fi

  # Step 3: project default, else Step 4: weak-signal scoring.
  local _dtd_default="" _dtd_resolved
  if [ -f "$_dtd_state_file" ]; then
    _dtd_default="$(jq -r '.default_task_type // empty' "$_dtd_state_file" 2>/dev/null)"
  fi
  if [ -n "$_dtd_default" ]; then
    _dtd_resolved="$_dtd_default"
  else
    _dtd_resolved="$(_dtd_weak_signal_score "$_dtd_desc_lower")"
  fi

  # Step 5: alias remapping, applied only to the step 3/4 result above.
  local _dtd_aliased
  _dtd_aliased="$(_dtd_alias_remap "$_dtd_resolved" "$_dtd_ext_dir")"
  if [ -n "$_dtd_aliased" ]; then
    _dtd_resolved="$_dtd_aliased"
  fi

  printf '%s\n' "$_dtd_resolved"
  unset _dtd_desc _dtd_state_file _dtd_ext_dir _dtd_desc_lower _dtd_override _dtd_default \
    _dtd_resolved _dtd_aliased
  return 0
}
