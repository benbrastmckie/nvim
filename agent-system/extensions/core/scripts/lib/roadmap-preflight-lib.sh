#!/usr/bin/env bash
# roadmap-preflight-lib.sh - Single source of truth for specs/ROADMAP.md's layout-classification
# vocabulary (CLASSIC_HEADERS, the fenced-/orchestrate-block predicate, and detect_layout), plus
# the preflight gate that sits strictly IN FRONT of roadmap-integration.sh's write modes: a
# four-way classify entry point (absent/unknown/classic/stage) and (added in a later revision of
# this file) a mechanical skeleton scaffolder for the two verdicts the generator itself refuses
# on.
#
# Modeled on scripts/lib/status-vocabulary.sh's "one sourced shared library, many consumers"
# shape. roadmap-integration.sh sources this file and keeps zero copies of its own; the same
# consumer-discovery mechanism applies here, found live via
# `grep -rl 'roadmap-preflight-lib.sh' agent-system/extensions`.
#
# WHY classification moved out of roadmap-integration.sh: that script parses $@ and calls `exit`
# at top level with no `BASH_SOURCE` run-as-script guard, so sourcing it directly (to reuse
# detect_layout) would run its argument parser against the sourcing shell's own $@ and could exit
# that shell. CLASSIC_HEADERS, the two fence helpers, and detect_layout are side-effect-free and
# move cleanly.
#
# Usage (sourced, e.g. from another script):
#   source "${SCRIPT_DIR}/lib/roadmap-preflight-lib.sh"
#   verdict="$(roadmap_preflight_classify "$ROADMAP_PATH")"   # absent|unknown|classic|stage

# ─── Layout-classification vocabulary (moved verbatim from roadmap-integration.sh) ────────────

# CLASSIC_HEADERS -- the eight literal headers roadmap-format.md's classic layout requires, in
# order. Anchors detect_layout's classic predicate and the refusal message's header listing.
CLASSIC_HEADERS=(
  "## Goal"
  "## Gate state"
  "## Next"
  "## Open work"
  "## Checks before and after every call"
  "## Settled decisions (do not re-litigate)"
  "## Standing rules"
  "## Unfiled observations (none worth a task yet)"
)

# body_has_orchestrate_fence BODY -> status 0 iff some fenced code block (a line that is exactly
# ``` optionally followed by a language tag, e.g. ```bash) within BODY contains at least one line
# matching ^/orchestrate ; status 1 otherwise. Used both by roadmap_has_orchestrate_fence (whole
# file, for detect_layout) and directly by mode_regenerate_stage (one already-split section body,
# to locate which retained section is the run-order section).
body_has_orchestrate_fence() {
  local body="$1"
  awk '
    /^```/ { in_fence = !in_fence; next }
    in_fence && /^\/orchestrate / { found = 1 }
    END { exit (found ? 0 : 1) }
  ' <<<"$body"
}

# roadmap_has_orchestrate_fence FILE -> body_has_orchestrate_fence applied to the whole file's
# content. Helper for detect_layout's stage predicate (checked before any section splitting).
roadmap_has_orchestrate_fence() {
  body_has_orchestrate_fence "$(cat "$1")"
}

# detect_layout FILE -> "classic" | "stage" | "unknown"
#
# This is the permanent destructive-overwrite-refusal gate (sub-fault 3): both write modes call
# this before touching the file, and refuse loudly rather than guess on anything this script
# cannot round-trip. Detection is structural, never exact-header matching, for "stage" -- the
# stage layout's own headers have already been observed to drift by hand-rename (Decision 1).
#
#   classic: every literal header in CLASSIC_HEADERS is present (exact match IS correct here --
#            the classic vocabulary is defined as exactly those eight headers, matched the same
#            way load_existing_sections' extract_section calls match them).
#   stage:   a header matching ^## Stage [0-9]+ exists, AND some section's body holds a fenced
#            /orchestrate block (roadmap_has_orchestrate_fence above) -- survives a cosmetic
#            rename of "## Run order at a glance" or "## Stage N -- ..." text.
#   unknown: neither predicate matches.
detect_layout() {
  local file="$1" h is_classic=1
  for h in "${CLASSIC_HEADERS[@]}"; do
    grep -qxF "$h" "$file" || { is_classic=0; break; }
  done
  if [[ "$is_classic" -eq 1 ]]; then
    echo "classic"
    return 0
  fi

  if grep -qE '^## Stage [0-9]+' "$file" && roadmap_has_orchestrate_fence "$file"; then
    echo "stage"
    return 0
  fi

  echo "unknown"
}

# ─── Preflight classify (new) ──────────────────────────────────────────────────────────────

# roadmap_preflight_classify PATH -> "absent" | "unknown" | "classic" | "stage"; always exits 0
# (classification never fails). The verdict space is four-way; detect_layout above only produces
# three -- "absent" is checked here, before detect_layout is reached, so neither gated caller
# has to re-derive file existence on its own.
roadmap_preflight_classify() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "absent"
    return 0
  fi
  detect_layout "$path"
  return 0
}
