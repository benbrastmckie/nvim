#!/usr/bin/env bash
# chapter-quality-check.sh - Mechanical backstop for context/project/typst/standards/chapter-quality.md.
#
# PURPOSE. chapter-quality.md sets a measurable bar for hand-built Typst manual chapters across
# four dimensions (SOURCE GROUNDING, ANTI-FLUFF DENSITY, PRESENTATION CLARITY, OPEN-QUESTION
# HONESTY). Prose alone leaves that bar unenforced -- a reviewer has to remember, per chapter, to
# check every backticked path, every citation key, every heading depth, every CONFIRM marker, by
# hand. This script is the mechanical backstop: it evaluates every rule the standard tags
# MECHANICAL automatically, and surfaces every rule it tags JUDGED as a structured prompt for a
# reviewing agent, so no rule is ever silently skipped.
#
# CHECKS. One check per rule the standard defines, tagged exactly as chapter-quality.md tags it
# (do not re-tag here -- see RULE INVENTORY below):
#   Rule 1.2 (BLOCKING / MECHANICAL)  - backticked path resolves against the live tree.
#   Rule 1.3 (BLOCKING / MECHANICAL)  - `@key` citation resolves in the project .bib.
#   Rule 1.5 (BLOCKING / MECHANICAL)  - `// CONFIRM:` marker is well-formed (non-empty payload).
#   Rule 3.2 (BLOCKING / MECHANICAL)  - heading depth bounded at `===`; `====`+ is prohibited.
#   Rule 2.1 (ADVISORY / MECHANICAL)  - claim-to-word ratio per section, unreviewed threshold.
#   Rule 2.3 (ADVISORY / MECHANICAL)  - hedging/filler seed-phrase list, unreviewed and extensible.
#   Rule 3.3 (ADVISORY / MECHANICAL)  - paragraph length bounded, unreviewed threshold.
#   Rules 1.1, 1.4, 2.2, 3.1, 3.4, 4.1, 4.2, 4.3 (JUDGED) - emitted as structured reviewer
#     prompts, never evaluated mechanically (see RULE INVENTORY below for each rule's tags).
#   Placement (BLOCKING, delegated) - the Universal Placement Rule is enforced by invoking the
#     sibling `typst-element-lint.sh`, never re-implemented here (see SCOPE BOUNDARY).
#
# SEVERITY SPLIT (do not change without a documented review pass against real chapters). A
# BLOCKING finding drives this script's exit code; an ADVISORY finding is reported and counted
# but NEVER affects exit status, however severe it looks in the report. In particular, every
# ANTI-FLUFF DENSITY rule (2.1, 2.3) is ADVISORY throughout the standard, so no ANTI-FLUFF
# finding may ever change the exit code -- this is asserted explicitly in this script's test
# suite, not just claimed here. Promoting any rule from ADVISORY to BLOCKING requires first
# observing its behavior against a real corpus of chapters, exactly as
# `typst-element-lint.sh`'s own header already requires for its own advisory checks.
#
# PER-CHAPTER SCORE (a reporting convention, not a rule -- introduces no new rule, re-tags
# nothing). Computed solely from the standard's own inventory and printed once per checked file:
#   MECHANICAL <passed>/<evaluated> | BLOCKING <n> | ADVISORY <n> | JUDGED <n> prompts pending
# <evaluated> counts the standard's 7 MECHANICAL rules (1.2, 1.3, 1.5, 3.2, 2.1, 2.3, 3.3) minus
# any rule marked NOT EVALUATED for that file (currently only Rule 1.3 when no `.bib` resolves,
# per KNOWN LIMITATIONS below); <passed> is <evaluated> minus the MECHANICAL rules that produced
# at least one finding. The JUDGED count is always printed alongside the mechanical ratio
# precisely so a green (0 BLOCKING) score can never be misread as full coverage -- judged rules
# still require a reviewing agent's adjudication regardless of the mechanical ratio.
#
# RULE INVENTORY. Sourced VERBATIM from context/project/typst/standards/chapter-quality.md's
# rule statements and axis tags. If a rule here diverges from that file, the file is stale --
# update BOTH in the same commit; never re-tag, rename, or invent a rule in this script alone.
#   1.1 - Every substantive claim traces to a cited source (a repo path, a paper, or an
#         explicitly verified fact). [BLOCKING / JUDGED]
#   1.2 - Every backticked path in the chapter resolves against the live tree.
#         [BLOCKING / MECHANICAL]
#   1.3 - Every citation key resolves in bibliography.bib. [BLOCKING / MECHANICAL]
#   1.4 - No hand-typed count, version, or hash. Any such value appearing in the chapter must be
#         derived from a cited, checkable source at the time it was written, never typed from
#         memory or guessed. [BLOCKING / JUDGED]
#   1.5 - Every CONFIRM comment is well-formed. [BLOCKING / MECHANICAL]
#   2.1 - The chapter's claim-to-word ratio meets a stated per-section threshold.
#         [ADVISORY / MECHANICAL]
#   2.2 - No `==` or `===` section lacks a stated reader need in its opening prose (why the
#         section exists, what it lets the reader do afterward). [ADVISORY / JUDGED]
#   2.3 - Hedging and filler connective prose is flagged against a seed phrase list (for example:
#         "it seems", "arguably", "it is worth noting that", "needless to say").
#         [ADVISORY / MECHANICAL]
#   3.1 - Every notation symbol and every glossary term is defined before its first use.
#         [BLOCKING / JUDGED]
#   3.2 - Heading depth is bounded at level 3 (`===`); a level-4 heading or deeper is prohibited.
#         [BLOCKING / MECHANICAL]
#   3.3 - Paragraph length is bounded (a word or line count per paragraph).
#         [ADVISORY / MECHANICAL]
#   3.4 - Every non-obvious concept introduced has an accompanying example or figure.
#         [ADVISORY / JUDGED]
#   4.1 - Every speculative claim is explicitly marked. [BLOCKING / JUDGED]
#   4.2 - Open questions are listed in a dedicated, discoverable location (for example an
#         `== Open Questions` section) rather than buried inline in ordinary prose.
#         [BLOCKING / JUDGED]
#   4.3 - No future-tense claim is stated as settled fact. [BLOCKING / JUDGED]
#
# SCOPE BOUNDARY. This script implements Rules 1.2 and 1.3 (backticked-path and citation-key
# resolution) itself. It does NOT implement chapter-quality.md's "Interface Contract for
# Repo-Local Checks" -- the `local:name-resolution` and `local:chapter-source-coverage` checks --
# those belong to a consuming repository's own `typst/scripts/` by that standard's own contract,
# and are never implemented or duplicated here. Placement (the Universal Placement Rule) is owned
# by `standards/semantic-element-usage.md` and already mechanically enforced by the sibling
# `typst-element-lint.sh`; this script composes with that lint rather than re-implementing
# placement a second time (two independent implementations of one rule would diverge, and the
# divergence would surface as a contradictory pair of findings on a real chapter).
#
# KNOWN LIMITATIONS (documented rather than solved with a full Typst parser).
#   - No Typst math-mode parsing (carried over from typst-element-lint.sh): a backtick, `@key`,
#     or phrase occurring inside `$...$` math mode is scanned the same as prose.
#   - No raw-block parsing (carried over from typst-element-lint.sh): a `#raw[...]` or fenced
#     code block's contents are scanned the same as prose.
#   - Rule/element/phrase detection matches only at the start of a (comment/quote-stripped) line,
#     or via a fixed-pattern extraction pass over that stripped line; text embedded unusually
#     mid-line in ways the extraction pass does not anticipate can be missed.
#   - Repo-root resolution (Rules 1.2/1.3) is `git rev-parse --show-toplevel` run from the
#     checked file's own directory, falling back to that directory when the checked file is not
#     inside a git work tree.
#   - Bibliography resolution (Rule 1.3) is: (a) the filename argument of a `#bibliography("...")`
#     call in the checked file if present, else (b) the single `*.bib` file found under the repo
#     root. Zero or multiple candidates with no explicit `#bibliography(...)` declaration is
#     reported as a named `[INFO]` environment note and evaluates Rule 1.3 as NOT EVALUATED for
#     that file -- never as a blocking failure, and excluded from the MECHANICAL score
#     denominator for that file.
#   - Rule 1.2's path-shape heuristic is deliberately biased toward under-firing: a backtick
#     token is treated as path-shaped only when it contains `/` or ends in a recognized file
#     extension. Since Rules 1.2/1.3 are BLOCKING, a false positive on a correct chapter is the
#     failure mode that gets a gate switched off; under-firing is the safer bias, at the cost of
#     missing some genuine unresolved bare-word paths.
#   - Rules 2.1 (claim-to-word ratio) and 3.3 (paragraph length) use UNREVIEWED numeric
#     thresholds with no corpus observation behind them yet, exactly as chapter-quality.md
#     itself discloses for these two rules; both are ADVISORY for this reason and each finding
#     reports the threshold it used.
#   - Rule 2.3's seed phrase list is UNREVIEWED and extensible, exactly as chapter-quality.md
#     discloses; each finding reports the list version it used.
#
# CLI. chapter-quality-check.sh [--verbose] [--help] PATH...
#   PATH is a `.typ` file, or a directory scanned recursively for `*.typ` files.
#   No PATH given, or a PATH that does not exist, exits 2 with usage guidance.
#
# EXIT CODES.
#   0 - no BLOCKING findings (ADVISORY findings and JUDGED prompts, if any, do not affect this).
#   1 - one or more BLOCKING findings found (any MECHANICAL BLOCKING rule, or a delegated
#       BLOCKING placement finding).
#   2 - usage or environment error (no PATH, nonexistent PATH, no .typ files found, or the
#       sibling typst-element-lint.sh is missing).
#
# Class B strict mode (deliberate `set -uo pipefail`, no `-e`): this script accumulates
# BLOCKING/ADVISORY/JUDGED counters across every file and every rule and must keep scanning after
# the first finding to produce an accurate, complete per-chapter score -- see
# context/standards/shell-strict-mode.md's Class B admission test.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERBOSE=false

# The standard's own 7 MECHANICAL rules (excludes the delegated, non-numbered placement check).
MECH_RULES=(1.2 1.3 1.5 3.2 2.1 2.3 3.3)

usage() {
  cat <<'EOF'
Usage: chapter-quality-check.sh [--verbose] [--help] PATH...

Mechanical backstop for context/project/typst/standards/chapter-quality.md. PATH is a .typ file
or a directory scanned recursively for *.typ files.

Emits BLOCKING and ADVISORY findings for every MECHANICAL rule the standard defines, and a
structured reviewer prompt for every JUDGED rule (never silently skipped). Placement is
delegated to the sibling typst-element-lint.sh, never re-implemented here.

Options:
  --verbose, -v   Print per-file NOT EVALUATED/environment notes even when nothing else fires.
  --help, -h      Show this help and exit 0.

Exit codes: 0 = no BLOCKING findings, 1 = BLOCKING findings found, 2 = usage/environment error.
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

TOTAL_BLOCKING=0
TOTAL_ADVISORY=0
TOTAL_JUDGED=0
FILES_CHECKED=0

# Per-file state, reset at the top of each file's processing.
file_blocking=0
file_advisory=0
file_judged=0
declare -A FILE_RULE_FIRED=()
declare -A FILE_RULE_NOTEVAL=()

# emit_blocking DIMENSION RULE LOCATION MESSAGE
emit_blocking() {
  local dim="$1" rule="$2" loc="$3" msg="$4"
  echo -e "${RED}[FAIL]${NC} ${loc}: [${rule} / ${dim}] ${msg}"
  TOTAL_BLOCKING=$((TOTAL_BLOCKING + 1))
  file_blocking=$((file_blocking + 1))
  FILE_RULE_FIRED["$rule"]=1
}

# emit_advisory DIMENSION RULE LOCATION MESSAGE
emit_advisory() {
  local dim="$1" rule="$2" loc="$3" msg="$4"
  echo -e "${YELLOW}[WARN]${NC} ${loc}: [${rule} / ${dim}] ${msg}"
  TOTAL_ADVISORY=$((TOTAL_ADVISORY + 1))
  file_advisory=$((file_advisory + 1))
  FILE_RULE_FIRED["$rule"]=1
}

# emit_info LOCATION MESSAGE
emit_info() {
  local loc="$1" msg="$2"
  echo -e "${BLUE}[INFO]${NC} ${loc}: ${msg}"
}

# emit_not_evaluated RULE LOCATION MESSAGE -- marks a rule NOT EVALUATED for this file (excluded
# from the MECHANICAL score denominator), and prints the reason as an [INFO] note.
emit_not_evaluated() {
  local rule="$1" loc="$2" msg="$3"
  FILE_RULE_NOTEVAL["$rule"]=1
  emit_info "$loc" "Rule ${rule} NOT EVALUATED: ${msg}"
}

# emit_judged RULE DIMENSION LOCATION QUESTION -- structured reviewer prompt for a JUDGED rule.
# Never counted toward BLOCKING or ADVISORY; counted only in its own JUDGED total.
emit_judged() {
  local rule="$1" dim="$2" loc="$3" question="$4"
  echo -e "${BLUE}[JUDGED]${NC} ${loc}: [${rule} / ${dim}] REVIEWER PROMPT: ${question}"
  TOTAL_JUDGED=$((TOTAL_JUDGED + 1))
  file_judged=$((file_judged + 1))
}

# print_score FILE -- the Per-Chapter Score reporting convention (see header).
print_score() {
  local f="$1"
  local evaluated=0 passed=0 r
  for r in "${MECH_RULES[@]}"; do
    if [[ -n "${FILE_RULE_NOTEVAL[$r]:-}" ]]; then
      continue
    fi
    evaluated=$((evaluated + 1))
    if [[ -z "${FILE_RULE_FIRED[$r]:-}" ]]; then
      passed=$((passed + 1))
    fi
  done
  echo "SCORE ${f}: MECHANICAL ${passed}/${evaluated} | BLOCKING ${file_blocking} | ADVISORY ${file_advisory} | JUDGED ${file_judged} prompts pending"
}

# process_file FILE -- runs every implemented check against FILE and prints its score line.
# Rule-check bodies are added phase by phase (see the plan this script was implemented from);
# this framework phase wires the per-file reset/dispatch/score/summary machinery only.
process_file() {
  local f="$1"
  file_blocking=0
  file_advisory=0
  file_judged=0
  FILE_RULE_FIRED=()
  FILE_RULE_NOTEVAL=()

  if [[ "$file_blocking" -eq 0 && "$file_advisory" -eq 0 ]]; then
    echo -e "${GREEN}[PASS]${NC} ${f}"
  fi
  print_score "$f"
}

for f in "${TYP_FILES[@]}"; do
  FILES_CHECKED=$((FILES_CHECKED + 1))
  process_file "$f"
done

echo ""
echo "Summary"
echo "-------"
echo "Files checked: ${FILES_CHECKED}"
echo -e "Blocking:      ${RED}${TOTAL_BLOCKING}${NC}"
echo -e "Advisory:      ${YELLOW}${TOTAL_ADVISORY}${NC}"
echo -e "Judged:        ${BLUE}${TOTAL_JUDGED}${NC} reviewer prompts pending"
echo ""

if [[ "$TOTAL_BLOCKING" -gt 0 ]]; then
  echo -e "${RED}CHAPTER QUALITY CHECK FAILED (${TOTAL_BLOCKING} blocking findings)${NC}"
  exit 1
else
  echo -e "${GREEN}CHAPTER QUALITY CHECK PASSED${NC} (mechanical coverage only -- judged rules still pending adjudication)"
  exit 0
fi
