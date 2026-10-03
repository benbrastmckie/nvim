#!/usr/bin/env bash
# typst-element-lint.sh - Mechanical element-placement and density lint for Typst chapters.
#
# PURPOSE. Backstops standards/semantic-element-usage.md's prose rules with a mechanical gate.
# The prose-alone hypothesis was already tested and falsified in this extension:
# templates/chapter-template.md already required an "Opening paragraph" and a 25-item #remark
# checklist still landed as the first body content after a chapter heading in a real chapter.
# `typst compile` exit 0 is blind to this class of defect -- it is a rhetorical/structural
# misuse, not a syntax error. This script is that missing mechanical backstop.
#
# CHECKS.
#   1. Placement (BLOCKING). A semantic element standing as the first body content after a
#      heading (`=`, `==`, `===`), with no intervening prose. This is the Universal Placement
#      Rule from semantic-element-usage.md, applied uniformly to every element in the standard's
#      inventory, not remark-only. The check is POSITION-SPECIFIC BY CONSTRUCTION: it never
#      inspects any line before the first heading it encounters, so a legitimate pre-heading
#      #import/#let macro-and-comment block is out of scope structurally, not by exemption, and
#      it only evaluates the single line immediately following a heading (after skipping blank,
#      comment, declaration, and bare-label lines) -- a remark following a substantial result
#      elsewhere in the document is never reachable by this check, because prose/results
#      necessarily intervene between the heading and the remark.
#   2. Remark item count (ADVISORY). Warns when a #remark block's body contains more enumerated
#      items (Typst `+`, `-`, or `N.` markers) than a threshold. This threshold has NO textual
#      anchor in semantic-element-usage.md (which is qualitative: "sparing", "never a long
#      enumerated status or tracking list") and is therefore an initial, UNREVIEWED value.
#   3. Remark density (ADVISORY). Warns per file when #remark occurrences exceed the
#      theorem-family occurrence count (definition+theorem+lemma+corollary+example), citing
#      semantic-element-usage.md's own stated signal ("if a chapter has more remarks than
#      theorems, that is a signal the remarks are doing work that belongs elsewhere"). Guarded
#      by an absolute floor so a file with few remarks and zero theorem-family elements does not
#      warn merely because the ratio is undefined/trivial.
#   4. Element presence (ADVISORY). Warns when a non-exempt chapter file contains zero
#      theorem-family elements (definition+theorem+lemma+corollary+example) at all -- placement
#      (check 1) can only police elements that are PRESENT; a chapter using none of the
#      vocabulary is invisible to checks 1-3, which is exactly the drift this check exists to
#      surface. EXEMPTION CLASS (basename-matched, kept short and documented here, not scattered
#      across a config file): a basename containing "introduction" (pure-narrative front matter,
#      by convention never carries numbered results), starting with "appendix-" (index/ledger/
#      export back matter, generally a thin wrapper around generated content), or containing
#      "glossary" (assembled automatically from other chapters' term-def sites, carries no
#      elements of its own by construction). A file outside this class and still legitimately
#      narrative or not-yet-written is expected to WARN here -- that is the check doing its job,
#      not a false positive to special-case away. Advisory only, for the same reason checks 2-3
#      are: see SEVERITY SPLIT below.
#
# SEVERITY SPLIT (do not change without a documented review pass against real chapters).
# Checks 2, 3 and 4 are ADVISORY-ONLY: they are reported and counted but NEVER affect the exit
# code. Promoting any of them to blocking requires first observing their behavior against a real
# corpus of chapters (Phase 5 of the plan that introduced checks 1-3 ran that observation once
# against typst/manual/chapters/ -- see that plan's implementation summary for the recorded
# evidence; check 4 was introduced later, against the same corpus, by the plan that raised the
# manual's chapters to the BimodalReference textbook standard -- see that task's own record
# report for the observed presence/exemption counts). An unreviewed hard threshold that fires on
# correct documents is exactly the failure mode this split exists to prevent (a gate that fires
# on correct documents gets switched off, and this repository has already watched exactly that
# drift happen once, silently, before check 4 existed).
#
# ELEMENT INVENTORY. Sourced verbatim from
# context/project/typst/standards/semantic-element-usage.md's Per-Element Semantics section:
# definition, theorem, lemma, corollary, example, proof, remark, rule-block, rule-list. Do not
# invent a second, divergent element list here -- if the standard's inventory changes, update
# ELEMENTS_LIST below to match, in the same commit that updates the standard.
#
# KNOWN LIMITATIONS (documented rather than solved with a full Typst parser).
#   - Bracket-depth counting for check 2 strips `//` comment tails and double-quoted string
#     contents per line before counting `[`/`]`, but does not parse Typst math mode (`$...$`)
#     or raw/code blocks; a `[`/`]` inside math or a raw block can misalign the depth count.
#   - Check 1's "intervening prose" skip list is: blank lines, `//` comment lines, and
#     `#import`/`#let`/`#set`/`#show` declaration lines, and bare `<label>` lines. Declarations
#     are SKIPPED (treated as chapter-local setup, not prose) rather than counted as prose --
#     the Constraint-1-consistent reading: a heading followed immediately by `#let` declarations
#     and THEN a semantic element still violates the rule, because no prose was ever supplied.
#   - Element/remark detection matches only at the start of a (comment/quote-stripped) line.
#     An element invoked mid-line (unusual Typst style) is not detected.
#
# CLI. typst-element-lint.sh [--verbose] [--help] PATH...
#   PATH is a `.typ` file, or a directory scanned recursively for `*.typ` files.
#   No PATH given, or a PATH that does not exist, exits 2 with usage guidance.
#
# EXIT CODES.
#   0 - all files pass (advisory warnings, if any, do not affect this)
#   1 - one or more check-1 (placement) failures found
#   2 - usage or environment error (no PATH, nonexistent PATH, no .typ files found)
#
# Class B strict mode (deliberate `set -uo pipefail`, no `-e`): this script accumulates
# FAIL/WARN/PASS counters across every file and every check and must keep scanning after the
# first finding to produce an accurate, complete summary -- see
# context/standards/shell-strict-mode.md's Class B admission test.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERBOSE=false

# Element inventory -- verbatim from semantic-element-usage.md. Keep in sync with that file.
ELEMENTS_LIST="definition,theorem,lemma,corollary,example,proof,remark,rule-block,rule-list"

# Check 2 threshold: warn when a remark's enumerated-item count exceeds this. UNREVIEWED -- see
# header comment above.
ITEM_THRESHOLD=3

# Check 3 absolute floor: a file needs at least this many #remark occurrences before the
# remark-vs-theorem-family ratio is treated as meaningful.
DENSITY_FLOOR=3

usage() {
  cat <<'EOF'
Usage: typst-element-lint.sh [--verbose] [--help] PATH...

Mechanical element-placement and density lint for Typst chapters. PATH is a .typ file or a
directory scanned recursively for *.typ files.

Checks:
  1. Placement (BLOCKING)  - semantic element as first body content after a heading, no
                             intervening prose.
  2. Item count (ADVISORY) - a #remark block whose body has more than 3 enumerated items.
  3. Density (ADVISORY)    - a file with more #remark occurrences than theorem-family elements
                             (definition+theorem+lemma+corollary+example), floor 3.
  4. Presence (ADVISORY)   - a non-exempt file (basename not matching introduction/appendix-/
                             glossary) with zero theorem-family elements.

Options:
  --verbose, -v   Print per-file counts even when nothing is flagged.
  --help, -h      Show this help and exit 0.

Exit codes: 0 = pass (warnings allowed), 1 = placement failures found, 2 = usage/environment error.
EOF
}

PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        PATHS+=("$1")
        shift
      done
      ;;
    -*)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      PATHS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#PATHS[@]} -eq 0 ]]; then
  echo "Error: no PATH given" >&2
  usage >&2
  exit 2
fi

TYP_FILES=()
for p in "${PATHS[@]}"; do
  if [[ -f "$p" ]]; then
    TYP_FILES+=("$p")
  elif [[ -d "$p" ]]; then
    while IFS= read -r -d '' f; do
      TYP_FILES+=("$f")
    done < <(find "$p" -type f -name '*.typ' -print0 | sort -z)
  else
    echo "Error: path does not exist: $p" >&2
    exit 2
  fi
done

if [[ ${#TYP_FILES[@]} -eq 0 ]]; then
  echo "Error: no .typ files found under the given path(s)" >&2
  exit 2
fi

TOTAL_FAILURES=0
TOTAL_WARNINGS=0
FILES_CHECKED=0

# The AWK program implements all three checks in a single per-file pass, and emits a
# machine-readable RESULT protocol on stdout that the bash loop below parses into colored
# PASS/FAIL/WARN output. See the header comment for the algorithm each check uses.
read -r -d '' AWK_PROGRAM <<'AWKEOF' || true
function detect_element(s,    i, pat) {
  for (i = 1; i <= n_elements; i++) {
    pat = "^#" ELEMENTS[i] "[ \t]*(\\(|\\[)"
    if (s ~ pat) return ELEMENTS[i]
  }
  return ""
}

BEGIN {
  n_elements = split(ELEMENTS_LIST, ELEMENTS, ",")
  awaiting = 0
  heading_line = 0
  heading_text = ""
  inside_remark = 0
  remark_depth = 0
  remark_body_opened = 0
  remark_start = 0
  remark_items = 0
}

{
  raw = $0
  clean = raw
  gsub(/"[^"]*"/, "", clean)
  sub(/\/\/.*/, "", clean)
  trimmed = clean
  sub(/^[ \t]+/, "", trimmed)
  sub(/[ \t]+$/, "", trimmed)

  # ---- Check 1: heading / placement state machine ----
  if (trimmed ~ /^=+[ \t]+/) {
    awaiting = 1
    heading_line = FNR
    heading_text = trimmed
  } else if (awaiting == 1) {
    if (trimmed == "") {
      # blank (or comment-only, already stripped to empty) -- still awaiting
    } else if (trimmed ~ /^#(import|let|set|show)([ \t(]|$)/) {
      # chapter-local declaration -- skipped, not counted as prose
    } else if (trimmed ~ /^<[A-Za-z0-9_:.-]+>[ \t]*$/) {
      # bare label -- skipped
    } else {
      awaiting = 0
      elem = detect_element(trimmed)
      if (elem != "") {
        printf "FAIL\tplacement\t%s\t%d\t%d\t%s\t%s\n", FILENAME, heading_line, FNR, elem, heading_text
      }
    }
  }

  # ---- Check 2: remark item-count via bracket-depth matching ----
  if (inside_remark == 0) {
    if (trimmed ~ /^#remark[ \t]*(\(|\[)/) {
      inside_remark = 1
      remark_start = FNR
      remark_items = 0
      remark_depth = 0
      remark_body_opened = 0
    }
  }
  if (inside_remark == 1) {
    tmp = clean
    o = gsub(/\[/, "[", tmp)
    tmp = clean
    c = gsub(/\]/, "]", tmp)
    remark_depth += (o - c)
    if (remark_depth > 0) remark_body_opened = 1
    if (trimmed ~ /^\+[ \t]/ || trimmed ~ /^-[ \t]/ || trimmed ~ /^[0-9]+\.[ \t]/) {
      remark_items++
    }
    if (remark_body_opened == 1 && remark_depth <= 0) {
      if (remark_items > ITEM_THRESHOLD) {
        printf "WARN\titems\t%s\t%d\t%d\t%d\t-\n", FILENAME, remark_start, FNR, remark_items
      }
      inside_remark = 0
      remark_body_opened = 0
    }
  }

  # ---- Check 3: per-file element counts (density) ----
  elem3 = detect_element(trimmed)
  if (elem3 != "") {
    count[elem3]++
  }
}

END {
  remarks = count["remark"] + 0
  family = count["definition"] + count["theorem"] + count["lemma"] + count["corollary"] + count["example"]
  if (VERBOSE == 1) {
    printf "INFO\tcounts\t%s\t%d\t%d\t-\t-\n", FILENAME, remarks, family
  }
  if (remarks >= DENSITY_FLOOR && remarks > family) {
    printf "WARN\tdensity\t%s\t%d\t%d\t-\t-\n", FILENAME, remarks, family
  }
  # ---- Check 4: element presence, exemption class basename-matched (see header comment) ----
  if (family == 0) {
    base = FILENAME
    sub(/^.*\//, "", base)
    if (base !~ /introduction/ && base !~ /^appendix-/ && base !~ /glossary/) {
      printf "WARN\tpresence\t%s\t-\t-\t-\t-\n", FILENAME
    }
  }
}
AWKEOF

verbose_flag=0
$VERBOSE && verbose_flag=1

for f in "${TYP_FILES[@]}"; do
  FILES_CHECKED=$((FILES_CHECKED + 1))
  file_failures=0
  file_warnings=0

  while IFS=$'\t' read -r severity check rfile f1 f2 f3 f4; do
    case "$severity" in
      FAIL)
        if [[ "$check" == "placement" ]]; then
          # f1=heading_line f2=elem_line f3=elem f4=heading_text
          echo -e "${RED}[FAIL]${NC} ${rfile}:${f2}: element '#${f3}' opens as the first body content after heading at line ${f1} (\"${f4}\"), with no intervening prose. Add opening prose stating what this section covers before the element; if this is tracking/status content, it belongs in specs/**, an appendix, or a dedicated status section -- never as chapter-opening body content (see standards/semantic-element-usage.md's \"Where Tracking Content Belongs\")."
          TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
          file_failures=$((file_failures + 1))
        fi
        ;;
      WARN)
        if [[ "$check" == "items" ]]; then
          # f1=start_line f2=end_line f3=item_count
          echo -e "${YELLOW}[WARN]${NC} ${rfile}:${f1}: remark spans lines ${f1}-${f2} with ${f3} enumerated items (advisory, threshold ${ITEM_THRESHOLD}). A remark is never a long enumerated status or tracking list -- if this is tracking content, it belongs in specs/**, an appendix, or a dedicated status section (see standards/semantic-element-usage.md's \"Where Tracking Content Belongs\")."
          TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
          file_warnings=$((file_warnings + 1))
        elif [[ "$check" == "density" ]]; then
          # f1=remark_count f2=family_count
          echo -e "${YELLOW}[WARN]${NC} ${rfile}: ${f1} #remark occurrences vs ${f2} theorem-family elements -- \"if a chapter has more remarks than theorems, that is a signal the remarks are doing work that belongs elsewhere\" (standards/semantic-element-usage.md, Remark: Expected density). Advisory only."
          TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
          file_warnings=$((file_warnings + 1))
        elif [[ "$check" == "presence" ]]; then
          echo -e "${YELLOW}[WARN]${NC} ${rfile}: zero theorem-family elements (definition/theorem/lemma/corollary/example) in a file outside the introduction/appendix-/glossary exemption class. Placement (check 1) only polices elements that are present -- a chapter using none of the vocabulary is invisible to it. Advisory only; not necessarily wrong (a genuinely narrative file may legitimately have none), but confirm before leaving it this way."
          TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
          file_warnings=$((file_warnings + 1))
        fi
        ;;
      INFO)
        if [[ "$check" == "counts" ]]; then
          echo -e "${BLUE}[INFO]${NC} ${rfile}: ${f1} remarks, ${f2} theorem-family elements"
        fi
        ;;
    esac
  done < <(awk -v ELEMENTS_LIST="$ELEMENTS_LIST" -v ITEM_THRESHOLD="$ITEM_THRESHOLD" \
                -v DENSITY_FLOOR="$DENSITY_FLOOR" -v VERBOSE="$verbose_flag" \
                "$AWK_PROGRAM" "$f")

  if [[ $file_failures -eq 0 && $file_warnings -eq 0 ]]; then
    echo -e "${GREEN}[PASS]${NC} ${f}"
  fi
done

echo ""
echo "Summary"
echo "-------"
echo "Files checked: ${FILES_CHECKED}"
echo -e "Failures:      ${RED}${TOTAL_FAILURES}${NC}"
echo -e "Warnings:      ${YELLOW}${TOTAL_WARNINGS}${NC}"
echo ""

if [[ "$TOTAL_FAILURES" -gt 0 ]]; then
  echo -e "${RED}TYPST ELEMENT LINT FAILED (${TOTAL_FAILURES} placement failures)${NC}"
  exit 1
elif [[ "$TOTAL_WARNINGS" -gt 0 ]]; then
  echo -e "${YELLOW}TYPST ELEMENT LINT PASSED WITH WARNINGS (${TOTAL_WARNINGS} advisory findings)${NC}"
  exit 0
else
  echo -e "${GREEN}TYPST ELEMENT LINT PASSED${NC}"
  exit 0
fi
