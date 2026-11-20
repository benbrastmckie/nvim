#!/usr/bin/env bash
# roadmap-entries-lib.sh - The one accessor for "the ordered batch list" and "the roadmap output
# path" held in specs/state.json. Every consumer that needs either answer sources this file and
# keeps zero jq of its own for the question; find consumers live via
# `grep -rl 'roadmap-entries-lib.sh' agent-system/extensions`.
#
# TWO STORE SHAPES, ONE ANSWER
# ----------------------------
#   milestone shape  .roadmap_milestones[].batches[]   -- batches nested under ordered milestones
#   flat shape       .roadmap_batches[]                -- a store that has not run
#                                                         scripts/migrate-roadmap-to-milestones.sh
# The milestone shape wins whenever the `roadmap_milestones` key is present at all (an empty
# array included). The flat shape is read only as a fallback when that key is absent, so a
# dispatch-selection surface keeps suggesting from a store's authored batches before the store
# migrates, instead of silently dropping to a mechanical fallback.
#
# This file is SOURCED. It sets no shell options, defines functions only, and never calls `exit`
# (a failed jq read yields empty output and a non-zero return, never a terminated caller).
#
# Functions:
#   roadmap_entries_shape STATE_FILE
#       Prints `milestones`, `flat` or `none`.
#   roadmap_entries_batches STATE_FILE
#       Prints one compact JSON object per line, in milestone-then-batch order, for every batch
#       of every milestone whose progress.status is not "closed":
#         {"milestone": ID|null, "ordinal": N, "index": K,
#          "task_ids": [...], "description": "...", "rationale": "...", "flags": "..."}
#       `ordinal` is the batch's 1-based position inside its own milestone (counting every batch
#       of that milestone); `index` is its 1-based position in the emitted stream. In the flat
#       shape `milestone` is null and `ordinal` equals `index`.
#   roadmap_entries_output_path STATE_FILE
#       Prints the repository-relative path the roadmap renders to:
#       `.roadmap_context.output_path` when it is a non-empty string, else `specs/ROADMAP.md`.

# ROADMAP_ENTRIES_JQ_DEFS -- the jq definitions behind the functions above, exported as a string
# so a consumer that already runs one large jq program can prepend them instead of shelling out
# a second time. `roadmap_entries_batches` is the stream described above, as an array.
# shellcheck disable=SC2016  # $-prefixed names below are jq variables, not shell expansions
ROADMAP_ENTRIES_JQ_DEFS='
def roadmap_entries_shape:
  if has("roadmap_milestones") then "milestones"
  elif ((.roadmap_batches // []) | length) > 0 then "flat"
  else "none" end;
def roadmap_entries_batches:
  ( if has("roadmap_milestones") then
      [ (.roadmap_milestones // [])[]
        | select((.progress.status // "") != "closed")
        | .id as $mid
        | (.batches // []) | to_entries[]
        | (.value + {milestone: $mid, ordinal: (.key + 1)}) ]
    else
      [ (.roadmap_batches // []) | to_entries[]
        | (.value + {milestone: null, ordinal: (.key + 1)}) ]
    end )
  | to_entries | map(.value + {index: (.key + 1)});
def roadmap_entries_output_path:
  (.roadmap_context.output_path // "") as $p
  | if ($p | type) == "string" and ($p | length) > 0 then $p else "specs/ROADMAP.md" end;
'

roadmap_entries_shape() {
  jq -r "${ROADMAP_ENTRIES_JQ_DEFS} roadmap_entries_shape" "$1" 2>/dev/null
}

roadmap_entries_batches() {
  jq -c "${ROADMAP_ENTRIES_JQ_DEFS} roadmap_entries_batches[]" "$1" 2>/dev/null
}

roadmap_entries_output_path() {
  local p
  p="$(jq -r "${ROADMAP_ENTRIES_JQ_DEFS} roadmap_entries_output_path" "$1" 2>/dev/null)"
  printf '%s\n' "${p:-specs/ROADMAP.md}"
}
