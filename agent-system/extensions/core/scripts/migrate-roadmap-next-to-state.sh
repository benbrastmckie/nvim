#!/usr/bin/env bash
# migrate-roadmap-next-to-state.sh - One-time migration: seed specs/state.json's
# roadmap_batches/roadmap_notes entries from the EXISTING specs/ROADMAP.md ## Next body, with a
# hard losslessness accounting gate.
#
# WHY THIS EXISTS: once ## Next renders wholly from roadmap_batches/roadmap_notes
# (roadmap-integration.sh's render_next()), the authored judgment currently living only in
# ## Next's hand-written prose -- which batch each task belongs to, the "Why this order:"
# rationale, the preamble/postamble framing -- has nowhere to live unless it is migrated into
# state first. This script performs that migration exactly once, proving the read was lossless
# rather than merely reporting success.
#
# Usage:
#   migrate-roadmap-next-to-state.sh [--dry-run] [--force] [--roadmap PATH] [--state PATH]
#                                     --session-id SID
#   migrate-roadmap-next-to-state.sh --help
#
# Options:
#   --roadmap PATH     Path to ROADMAP.md (default: specs/ROADMAP.md under the repo root)
#   --state PATH       Path to state.json (default: specs/state.json under the repo root)
#   --session-id SID   Required for a real (non-dry-run) write; passed through to state-write.sh
#   --dry-run          Print the proposed entries and the accounting result; write nothing
#   --force            Overwrite even if roadmap_batches is already non-empty
#   --help             Show this usage and exit 0
#
# Parsing model (see context/formats/roadmap-format.md's Next Grammar and this task's own plan
# for the full account): the ## Next body (minus its generated coverage appendix) splits into
# three regions in file order -- a PREAMBLE (everything before the first fenced code block), a
# FENCE (one /orchestrate line per batch), and an AFTER-FENCE region (the "Why this order:"
# bullets and any trailing free-standing prose). Both the preamble and the after-fence region
# are split into PARAGRAPH BLOCKS (maximal runs of non-blank lines, bounded by blank lines) --
# this one rule covers both a plain prose paragraph and a bullet (including one that itself
# line-wraps across several physical lines with no blank line between them). Every preamble
# block becomes one roadmap_notes.next_preamble entry, in order. Every after-fence block that
# names a batch's own task_ids member (its first bare integer token) is appended to that batch's
# rationale, after the batch's own verbatim trailing comment; every other after-fence block
# (a prose paragraph, or a bullet naming no live batch) becomes one roadmap_notes.next_postamble
# entry, in the same file order. This is lossless BY CONSTRUCTION -- every block lands in
# exactly one of these two places -- but the accounting gate below re-verifies it against the
# original text directly, as a safety net against a parsing bug rather than a structural proof.
#
# Losslessness accounting (the HARD GATE): every non-blank line of the body OUTSIDE the fence
# (i.e. every preamble/after-fence line, excluding the single structural "Why this order:"
# marker line) must appear, trimmed, among the lines of the captured preamble/postamble/
# rationale blocks. Any original line that does not is named explicitly and the script exits
# non-zero -- BEFORE any write. Separately, each batch's full original trailing comment must
# appear verbatim inside that batch's own rationale (the condensed-description exception).
# Fence lines are accounted for structurally: every non-blank fence line must match
# ^/orchestrate -- a stray line there also fails the gate, naming it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1

ROADMAP_PATH="${PROJECT_ROOT}/specs/ROADMAP.md"
STATE_PATH="${PROJECT_ROOT}/specs/state.json"
DRY_RUN=0
FORCE=0
SESSION_ID=""

usage() {
  sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --roadmap) ROADMAP_PATH="$2"; shift 2 ;;
    --state) STATE_PATH="$2"; shift 2 ;;
    --session-id) SESSION_ID="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ! -f "$ROADMAP_PATH" ]]; then
  echo "ERROR: --roadmap path does not exist: $ROADMAP_PATH" >&2
  exit 1
fi
if [[ ! -f "$STATE_PATH" ]]; then
  echo "ERROR: --state path does not exist: $STATE_PATH" >&2
  exit 1
fi
if [[ "$DRY_RUN" -eq 0 && -z "$SESSION_ID" ]]; then
  echo "ERROR: --session-id is required for a real (non-dry-run) write" >&2
  exit 1
fi

existing_count="$(jq -r '(.roadmap_batches // []) | length' "$STATE_PATH")"
if [[ "$existing_count" -gt 0 && "$FORCE" -ne 1 ]]; then
  echo "ERROR: roadmap_batches already has $existing_count entries; refusing to overwrite without --force." >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ─── Step 1: extract the ## Next body, minus its generated coverage appendix ──────────────────
awk '
  $0 == "## Next" { printing = 1; next }
  printing && /^## / { exit }
  printing { print }
' "$ROADMAP_PATH" > "$WORKDIR/next_raw.txt"

awk '
  /^\*\*Coverage appendix \(uncovered tasks\)\*\*:$/ { exit }
  { print }
' "$WORKDIR/next_raw.txt" > "$WORKDIR/next_body.txt"

# ─── Step 2: split into preamble / fence / after-fence regions ───────────────────────────────
awk -v pre="$WORKDIR/preamble.txt" -v fence="$WORKDIR/fence.txt" -v after="$WORKDIR/after.txt" '
  BEGIN { state = 0 }
  /^```/ {
    if (state == 0) { state = 1; next }
    else if (state == 1) { state = 2; next }
  }
  {
    if (state == 0) print > pre
    else if (state == 1) print > fence
    else print > after
  }
' "$WORKDIR/next_body.txt"
[[ -f "$WORKDIR/preamble.txt" ]] || : > "$WORKDIR/preamble.txt"
[[ -f "$WORKDIR/fence.txt" ]] || : > "$WORKDIR/fence.txt"
[[ -f "$WORKDIR/after.txt" ]] || : > "$WORKDIR/after.txt"

fence_count="$(grep -c '^```' "$WORKDIR/next_body.txt" || true)"
if [[ "$fence_count" -ne 2 ]]; then
  echo "ERROR: expected exactly 2 fence markers in the ## Next body, found $fence_count. Cannot migrate; the body's shape does not match this script's expected grammar." >&2
  exit 1
fi

# ─── Step 3: fence lines -> batches (task_ids, flags, description, rationale[0]=comment) ─────
# Every non-blank fence line MUST match ^/orchestrate -- a stray line fails the gate (named).
batch_count=0
STRAY_FENCE_LINES=()
while IFS= read -r line; do
  [[ -n "${line// /}" ]] || continue
  if [[ "$line" != /orchestrate\ * ]]; then
    STRAY_FENCE_LINES+=("$line")
    continue
  fi
  rest="${line#/orchestrate }"
  comment=""
  core="$rest"
  if [[ "$rest" == *"   # "* ]]; then
    comment="${rest#*"   # "}"
    core="${rest%%"   # "*}"
  fi
  # Trim trailing whitespace from core.
  core="${core%"${core##*[![:space:]]}"}"
  # Flags: the first whitespace-preceded "-" token onward (never the first run of whitespace,
  # which would mis-split a grammar-legal intra-list space like "716, 714 --hard").
  flags=""
  tasklist="$core"
  if [[ "$core" =~ [[:space:]]-[^[:space:]] ]]; then
    prefix="${core%%"${BASH_REMATCH[0]}"*}"
    tasklist="$prefix"
    flags="${core#"$prefix"}"
    flags="${flags# }"
  fi
  tasklist="${tasklist//[[:space:]]/}"
  IFS=',' read -ra ids <<<"$tasklist"
  ids_json="$(printf '%s\n' "${ids[@]}" | jq -R 'tonumber' | jq -s -c '.')"

  desc="$comment"
  if [[ "${#desc}" -gt 100 ]]; then
    desc="${desc:0:97}..."
  fi
  if [[ -z "$desc" ]]; then
    desc="(untitled batch: ${tasklist})"
  fi

  bnum="$(printf '%03d' "$batch_count")"
  printf '%s' "$ids_json" > "$WORKDIR/batch_${bnum}_ids.json"
  printf '%s' "$desc" > "$WORKDIR/batch_${bnum}_desc.txt"
  printf '%s' "$flags" > "$WORKDIR/batch_${bnum}_flags.txt"
  printf '%s' "$comment" > "$WORKDIR/batch_${bnum}_comment.txt"
  printf '%s' "$comment" > "$WORKDIR/batch_${bnum}_rationale.txt"
  printf '%s\n' "${ids[@]}" > "$WORKDIR/batch_${bnum}_idlist.txt"
  batch_count=$((batch_count + 1))
done < "$WORKDIR/fence.txt"

if [[ "${#STRAY_FENCE_LINES[@]}" -gt 0 ]]; then
  echo "ERROR: the fence block contains ${#STRAY_FENCE_LINES[@]} line(s) not matching ^/orchestrate -- cannot migrate:" >&2
  for l in "${STRAY_FENCE_LINES[@]}"; do
    echo "  UNACCOUNTED (fence): $l" >&2
  done
  exit 1
fi

if [[ "$batch_count" -eq 0 ]]; then
  echo "ERROR: no /orchestrate lines found in the ## Next fence -- nothing to migrate." >&2
  exit 1
fi

# ─── Step 4: paragraph-block splitter ─────────────────────────────────────────────────────────
# split_blocks SRC_FILE OUT_DIR -> writes one file per block (0000, 0001, ...) to OUT_DIR,
# echoes the block count. A block boundary occurs at a blank line (as usual), OR at the START
# of a fresh top-level "- " bullet line when the buffer already holds content -- GFM "tight"
# lists (the live ROADMAP.md's own style) pack consecutive bullets with NO blank line between
# them, so a blank-line-only splitter would merge an entire bullet list into one giant block. A
# bullet's own wrapped continuation lines (which never start with "- ") still accumulate into
# the same block as usual.
split_blocks() {
  local src="$1" outdir="$2"
  mkdir -p "$outdir"
  awk -v outdir="$outdir" '
    BEGIN { blk = 0; buf = "" }
    function flush() {
      if (buf != "") {
        file = outdir "/" sprintf("%04d", blk)
        printf "%s", buf > file
        close(file)
        blk++
        buf = ""
      }
    }
    /^[[:space:]]*$/ { flush(); next }
    /^- / { if (buf != "") flush() }
    {
      if (buf == "") buf = $0
      else buf = buf "\n" $0
    }
    END { flush() }
  ' "$src"
  find "$outdir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' '
}

preamble_block_count="$(split_blocks "$WORKDIR/preamble.txt" "$WORKDIR/preamble_blocks")"

# After-fence: drop a leading "Why this order:" marker line (and the blank line that follows it)
# before block-splitting the remainder -- it is a structural marker re-emitted unconditionally
# by render_next() whenever at least one batch carries a rationale, never content to migrate.
awk '
  BEGIN { skipped = 0 }
  !skipped && $0 == "Why this order:" { skipped = 1; next }
  { print }
' "$WORKDIR/after.txt" > "$WORKDIR/after_stripped.txt"
after_block_count="$(split_blocks "$WORKDIR/after_stripped.txt" "$WORKDIR/after_blocks")"

# ─── Step 5: attribute each after-fence BULLET block (one starting with "- ") to a batch (the
# first integer token in the block that actually NAMES a live batch's own task_ids member --
# not merely the first digit run in the text, which would false-match an incidental number
# like a date "2026-11-11" or a suite count before ever reaching the real task id); every other
# block -- a plain prose paragraph, or a bullet naming no live batch -- becomes a
# next_postamble entry, in file order. Attribution applies ONLY to bullet blocks: a free-
# standing prose paragraph always goes to next_postamble, even if it happens to mention a
# batch's task id in passing (e.g. "the claimant roster is five: 431, 459, 505, ..."), since it
# was never one of the "Why this order:" bullets the plan's own migration rule scopes
# attribution to. ──────────────────────────────────────────────────────────────────────────────
postamble_count=0
for ((i = 0; i < after_block_count; i++)); do
  bf="$WORKDIR/after_blocks/$(printf '%04d' "$i")"
  block_text="$(cat "$bf")"
  attributed=0
  if [[ "$block_text" == "- "* ]]; then
    while IFS= read -r candidate_id; do
      [[ -n "$candidate_id" ]] || continue
      for ((b = 0; b < batch_count; b++)); do
        bnum="$(printf '%03d' "$b")"
        if grep -qxF "$candidate_id" "$WORKDIR/batch_${bnum}_idlist.txt"; then
          # Append this block to batch b's rationale, as a new paragraph.
          {
            printf '%s' "$(cat "$WORKDIR/batch_${bnum}_rationale.txt")"
            printf '\n\n%s' "$block_text"
          } > "$WORKDIR/batch_${bnum}_rationale.txt.new"
          mv "$WORKDIR/batch_${bnum}_rationale.txt.new" "$WORKDIR/batch_${bnum}_rationale.txt"
          attributed=1
          break
        fi
      done
      [[ "$attributed" -eq 1 ]] && break
    done < <(grep -oE '[0-9]+' "$bf" || true)
  fi
  if [[ "$attributed" -eq 0 ]]; then
    pnum="$(printf '%04d' "$postamble_count")"
    cp "$bf" "$WORKDIR/postamble_${pnum}.txt"
    postamble_count=$((postamble_count + 1))
  fi
done

# ─── Step 6: losslessness accounting (the hard gate) ─────────────────────────────────────────
# Every non-blank line of preamble.txt and after_stripped.txt must appear, trimmed, among the
# lines of the captured preamble blocks / postamble blocks / batch rationales.
: > "$WORKDIR/covered_lines.txt"
for f in "$WORKDIR"/preamble_blocks/*; do
  [[ -f "$f" ]] || continue
  cat "$f" >> "$WORKDIR/covered_lines.txt"
  echo >> "$WORKDIR/covered_lines.txt"
done
for ((p = 0; p < postamble_count; p++)); do
  pnum="$(printf '%04d' "$p")"
  cat "$WORKDIR/postamble_${pnum}.txt" >> "$WORKDIR/covered_lines.txt"
  echo >> "$WORKDIR/covered_lines.txt"
done
for ((b = 0; b < batch_count; b++)); do
  bnum="$(printf '%03d' "$b")"
  cat "$WORKDIR/batch_${bnum}_rationale.txt" >> "$WORKDIR/covered_lines.txt"
  echo >> "$WORKDIR/covered_lines.txt"
done

# Normalize: trim trailing whitespace from every line, drop blanks, sort for lookup.
sed -E 's/[[:space:]]+$//' "$WORKDIR/covered_lines.txt" | sed '/^$/d' | sort -u > "$WORKDIR/covered_lines.sorted.txt"

cat "$WORKDIR/preamble.txt" "$WORKDIR/after_stripped.txt" \
  | sed -E 's/[[:space:]]+$//' | sed '/^$/d' > "$WORKDIR/original_lines.txt"

UNACCOUNTED=()
while IFS= read -r oline; do
  if ! grep -qxF -- "$oline" "$WORKDIR/covered_lines.sorted.txt"; then
    UNACCOUNTED+=("$oline")
  fi
done < "$WORKDIR/original_lines.txt"

if [[ "${#UNACCOUNTED[@]}" -gt 0 ]]; then
  echo "ERROR: losslessness accounting FAILED -- ${#UNACCOUNTED[@]} original line(s) are not accounted for in any roadmap_notes slot or batch rationale:" >&2
  for l in "${UNACCOUNTED[@]}"; do
    echo "  UNACCOUNTED: $l" >&2
  done
  exit 1
fi

# Condensed-description exception: each batch's full original (untruncated) comment must
# appear verbatim inside that same batch's own rationale -- a real search, not merely trusting
# the construction order, so a future edit to Step 3/5 that broke this is still caught here.
DESC_MISMATCHES=()
for ((b = 0; b < batch_count; b++)); do
  bnum="$(printf '%03d' "$b")"
  if [[ ! -s "$WORKDIR/batch_${bnum}_comment.txt" ]]; then
    continue  # an empty original comment has nothing to preserve
  fi
  if ! grep -qF -f "$WORKDIR/batch_${bnum}_comment.txt" "$WORKDIR/batch_${bnum}_rationale.txt"; then
    DESC_MISMATCHES+=("batch $b")
  fi
done
if [[ "${#DESC_MISMATCHES[@]}" -gt 0 ]]; then
  echo "ERROR: losslessness accounting FAILED -- the original trailing comment is not verbatim-present in its own batch's rationale for: ${DESC_MISMATCHES[*]}" >&2
  exit 1
fi

echo "Losslessness accounting PASSED: every non-blank line outside the fence is accounted for"
echo "  (preamble blocks: $preamble_block_count, batches: $batch_count, postamble blocks: $postamble_count)."

# ─── Step 7: build the JSON payload ───────────────────────────────────────────────────────────
roadmap_batches_json="[]"
for ((b = 0; b < batch_count; b++)); do
  bnum="$(printf '%03d' "$b")"
  entry="$(jq -n \
    --argjson task_ids "$(cat "$WORKDIR/batch_${bnum}_ids.json")" \
    --rawfile description "$WORKDIR/batch_${bnum}_desc.txt" \
    --rawfile rationale "$WORKDIR/batch_${bnum}_rationale.txt" \
    --rawfile flags "$WORKDIR/batch_${bnum}_flags.txt" \
    '($description | rtrimstr("\n")) as $desc_trimmed
     | ($rationale | rtrimstr("\n")) as $rationale_trimmed
     | ($flags | rtrimstr("\n")) as $flags_trimmed
     | {task_ids: $task_ids, description: $desc_trimmed}
       + (if ($rationale_trimmed | length) > 0 then {rationale: $rationale_trimmed} else {} end)
       + (if ($flags_trimmed | length) > 0 then {flags: $flags_trimmed} else {} end)')"
  roadmap_batches_json="$(jq -cn --argjson acc "$roadmap_batches_json" --argjson e "$entry" '$acc + [$e]' )"
done

next_preamble_json="[]"
for ((i = 0; i < preamble_block_count; i++)); do
  f="$WORKDIR/preamble_blocks/$(printf '%04d' "$i")"
  next_preamble_json="$(jq -cn --argjson acc "$next_preamble_json" --rawfile p "$f" '$acc + [$p]' )"
done

next_postamble_json="[]"
for ((p = 0; p < postamble_count; p++)); do
  pnum="$(printf '%04d' "$p")"
  f="$WORKDIR/postamble_${pnum}.txt"
  next_postamble_json="$(jq -cn --argjson acc "$next_postamble_json" --rawfile p "$f" '$acc + [$p]' )"
done

# open_work_trailer: free-standing prose after the last ## Open work fence (measured empty on
# the live file at plan time; the code path still exists and is exercised by the test fixture).
open_work_body="$(awk '
  $0 == "## Open work" { printing = 1; next }
  printing && /^## / { exit }
  printing { print }
' "$ROADMAP_PATH")"
open_work_trailer_text="$(awk '
  { lines[++n] = $0; if ($0 == "```") last_fence = n }
  END {
    if (last_fence == 0 || last_fence >= n) { exit }
    for (i = last_fence + 1; i <= n; i++) print lines[i]
  }
' <<<"$open_work_body")"
open_work_trailer_json="[]"
if [[ -n "${open_work_trailer_text// /}" ]]; then
  mkdir -p "$WORKDIR/ow_trailer_blocks"
  printf '%s\n' "$open_work_trailer_text" > "$WORKDIR/ow_trailer.txt"
  ow_count="$(split_blocks "$WORKDIR/ow_trailer.txt" "$WORKDIR/ow_trailer_blocks")"
  for ((i = 0; i < ow_count; i++)); do
    f="$WORKDIR/ow_trailer_blocks/$(printf '%04d' "$i")"
    open_work_trailer_json="$(jq -cn --argjson acc "$open_work_trailer_json" --rawfile p "$f" '$acc + [$p]' )"
  done
fi

roadmap_notes_json="$(jq -n --argjson pre "$next_preamble_json" --argjson post "$next_postamble_json" --argjson owt "$open_work_trailer_json" \
  '{next_preamble: $pre, next_postamble: $post, open_work_trailer: $owt}')"

echo
echo "=== Proposed roadmap_batches ($batch_count entries) ==="
jq '.' <<<"$roadmap_batches_json"
echo
echo "=== Proposed roadmap_notes ==="
jq '.' <<<"$roadmap_notes_json"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo
  echo "--dry-run: writing nothing."
  exit 0
fi

bash "${SCRIPT_DIR}/state-write.sh" \
  '.roadmap_batches = $batches | .roadmap_notes = $notes' \
  --session-id "$SESSION_ID" \
  --argjson batches "$roadmap_batches_json" \
  --argjson notes "$roadmap_notes_json" \
  --state-file "$STATE_PATH"

echo "Wrote $batch_count roadmap_batches entries and roadmap_notes to $STATE_PATH."
