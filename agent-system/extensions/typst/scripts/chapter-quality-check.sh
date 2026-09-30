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
#   - Bibliography resolution (Rule 1.3) tries three branches in order: (a) the filename argument
#     of a `#bibliography("...")` call in the checked file itself, if present; else (b) a
#     nearest-ancestor `#bibliography("...")` declaration, walked upward one directory level at a
#     time from the checked file's own directory to the repo root (inclusive), read from a sibling
#     `*.typ` file at each level with a permissive extractor so a multi-argument declaration (e.g.
#     `#bibliography("x.bib", title: [...], style: "ieee")`) still matches -- this is the layout a
#     multi-file manual uses, where chapters are `#include`d into a root document that alone
#     carries the declaration; else (c) the single `*.bib` file found under the repo root once
#     vendored/build directories (`.lake`, `.git`, `node_modules`, `target`, `build`) are pruned
#     from the search, so a vendored dependency's own `.bib` no longer defeats the single-candidate
#     test. No resolution across all three branches is reported as a named `[INFO]`/`[WARN]`
#     environment note (see the NOT-EVALUATED SURFACING bullet below) and evaluates Rule 1.3 as
#     NOT EVALUATED for that file -- never as a blocking failure, and excluded from the MECHANICAL
#     score denominator for that file. Branch (b) assumes one unambiguous declaring `.typ` file
#     per ancestor level; two siblings at the same level with conflicting or unresolvable
#     declarations fall through to branch (c) rather than erroring, the same under-firing bias
#     Rule 1.2 documents below.
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

# Rule 2.1 threshold: warn when a section's words-per-claim ratio exceeds this (a "claim" is a
# `@key` citation or a semantic-element invocation within the section). UNREVIEWED -- no corpus
# observation behind this number yet; see chapter-quality.md's Rule 2.1 disclosure.
CLAIM_RATIO_THRESHOLD=150

# Rule 3.3 threshold: warn when a blank-line-delimited paragraph exceeds this many words.
# UNREVIEWED -- no corpus observation behind this number yet; see chapter-quality.md's Rule 3.3
# disclosure.
PARAGRAPH_WORD_THRESHOLD=150

# Rule 2.3 seed phrase list: UNREVIEWED and extensible (chapter-quality.md's own disclosure).
# Drawn from standards/textbook-standards.md's Professional Tone "Avoid" column (obviously,
# clearly, trivial, easy) plus chapter-quality.md Rule 2.3's own stated examples (it seems,
# arguably, it is worth noting that, needless to say). Add phrases here as false positives and
# misses are observed; bump HEDGING_LIST_VERSION when the list changes.
HEDGING_LIST_VERSION="v1"
HEDGING_SEED_LIST=(
  "obviously"
  "clearly"
  "trivial"
  "easy"
  "it seems"
  "arguably"
  "it is worth noting that"
  "needless to say"
)

# JUDGED_RULES table -- rule id | dimension | severity | decision question, one entry per JUDGED
# rule. Transcribed verbatim from chapter-quality.md's JUDGED rule statements and axis tags;
# update BOTH in the same commit if either changes (see RULE INVENTORY above). Every rule here is
# emitted as a structured reviewer prompt, never silently skipped.
JUDGED_RULES=(
  "1.1|SOURCE GROUNDING|BLOCKING|Does every substantive claim in this file trace to a cited source (a repo path, a paper, or an explicitly verified fact)?"
  "1.4|SOURCE GROUNDING|BLOCKING|Is every hand-typed count, version, or hash in this file derived from a cited, checkable source at the time it was written, rather than typed from memory or guessed?"
  "2.2|ANTI-FLUFF DENSITY|ADVISORY|Does this section's opening prose state a reader need (why the section exists, what it lets the reader do afterward)?"
  "3.1|PRESENTATION CLARITY|BLOCKING|Is every notation symbol and every glossary term defined before its first use?"
  "3.4|PRESENTATION CLARITY|ADVISORY|Does every non-obvious concept introduced in this file have an accompanying example or figure?"
  "4.1|OPEN-QUESTION HONESTY|BLOCKING|Is every speculative claim in this file explicitly marked with a Speculative: tag, distinct from a CONFIRM marker?"
  "4.2|OPEN-QUESTION HONESTY|BLOCKING|Are open questions listed in a dedicated, discoverable location (for example an == Open Questions section) rather than buried inline in ordinary prose?"
  "4.3|OPEN-QUESTION HONESTY|BLOCKING|Does any future-tense claim in this file get stated as settled fact, rather than honestly marked as unsettled?"
)

usage() {
  cat <<'EOF'
Usage: chapter-quality-check.sh [--verbose] [--help] PATH...

Mechanical backstop for context/project/typst/standards/chapter-quality.md. PATH is a .typ file
or a directory scanned recursively for *.typ files.

Emits BLOCKING and ADVISORY findings for every MECHANICAL rule the standard defines, and a
structured reviewer prompt for every JUDGED rule (never silently skipped). Placement is
delegated to the sibling typst-element-lint.sh, never re-implemented here.

Options:
  --verbose, -v   Print additional [INFO] detail (e.g. which .bib file a chapter's citations
                  were resolved against) beyond what is required for a finding.
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

# emit_judged RULE DIMENSION SEVERITY LOCATION QUESTION -- structured reviewer prompt for a
# JUDGED rule. SEVERITY is the rule's own BLOCKING/ADVISORY axis-1 tag (informational only here --
# it tells the reviewer what the rule counts as once adjudicated). Never counted toward
# TOTAL_BLOCKING or TOTAL_ADVISORY; counted only in its own JUDGED total.
emit_judged() {
  local rule="$1" dim="$2" sev="$3" loc="$4" question="$5"
  echo -e "${BLUE}[JUDGED]${NC} ${loc}: [${rule} / ${dim} / ${sev} once resolved] REVIEWER PROMPT: ${question}"
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

# resolve_repo_root FILE -- Decision 2: git rev-parse --show-toplevel from the checked file's
# own directory, falling back to that directory when the file is not inside a git work tree.
resolve_repo_root() {
  local f="$1" dir root
  dir="$(cd "$(dirname "$f")" && pwd)"
  root="$(cd "$dir" && git rev-parse --show-toplevel 2>/dev/null)" || root="$dir"
  printf '%s\n' "$root"
}

# resolve_bibliography FILE ROOT -- Decision 2, three-branch order: (a) the filename argument of
# a #bibliography("...") call in FILE if present; else (b) a nearest-ancestor #bibliography("...")
# declaration, walked upward from FILE's own directory to ROOT (inclusive), read from a sibling
# *.typ file at each level using a permissive extractor so a multi-argument declaration (e.g.
# #bibliography("x.bib", title: [...], style: "ieee")) still matches; else (c) the single *.bib
# file found under ROOT once vendored/build directories (.lake, .git, node_modules, target,
# build) are excluded from the search. Prints the resolved path and returns 0 on success; returns
# 1 (no output) when unresolvable.
# KNOWN LIMITATION: branch (b)'s ancestor walk assumes one unambiguous declaring .typ file per
# level; two siblings at the same level with conflicting (or unresolvable) declarations fall
# through to branch (c), matching this script's existing "under-firing is the safer bias" posture
# for BLOCKING rules (see the header's Known Limitations list).
resolve_bibliography() {
  local f="$1" root="$2" decl filedir
  filedir="$(cd "$(dirname "$f")" && pwd)"
  decl=$(grep -m1 -oE '#bibliography\("[^"]*"\)' "$f" 2>/dev/null | sed -E 's/#bibliography\("([^"]*)"\)/\1/')
  if [[ -n "$decl" ]]; then
    if [[ -f "${root}/${decl}" ]]; then
      printf '%s\n' "${root}/${decl}"
      return 0
    elif [[ -f "${filedir}/${decl}" ]]; then
      printf '%s\n' "${filedir}/${decl}"
      return 0
    fi
    return 1
  fi

  # Branch (b) -- BUG 2a/2c fix: nearest-ancestor declared path, permissive extractor.
  local ancestor="$filedir" anc_file anc_decl
  while true; do
    while IFS= read -r -d '' anc_file; do
      anc_decl=$(grep -m1 -oE '#bibliography\("[^"]*"' "$anc_file" 2>/dev/null | sed -E 's/#bibliography\("([^"]*)"/\1/')
      if [[ -n "$anc_decl" ]]; then
        if [[ -f "${ancestor}/${anc_decl}" ]]; then
          printf '%s\n' "${ancestor}/${anc_decl}"
          return 0
        elif [[ -f "${root}/${anc_decl}" ]]; then
          printf '%s\n' "${root}/${anc_decl}"
          return 0
        fi
      fi
    done < <(find "$ancestor" -maxdepth 1 -type f -name '*.typ' -print0 2>/dev/null | sort -z)
    if [[ "$ancestor" == "$root" ]]; then
      break
    fi
    ancestor="$(dirname "$ancestor")"
  done

  # Branch (c) -- BUG 2b fix: single *.bib candidate under ROOT, vendored/build dirs excluded.
  local -a candidates=()
  while IFS= read -r -d '' bibf; do
    candidates+=("$bibf")
  done < <(find "$root" \
    \( -path '*/.lake' -o -path '*/.git' -o -path '*/node_modules' -o -path '*/target' -o -path '*/build' \) -prune -o \
    -type f -name '*.bib' -print0 2>/dev/null)
  if [[ ${#candidates[@]} -eq 1 ]]; then
    printf '%s\n' "${candidates[0]}"
    return 0
  fi
  return 1
}

# check_heading_depth FILE CLEANFILE -- Rule 3.2 [BLOCKING / MECHANICAL].
check_heading_depth() {
  local f="$1" cleanf="$2" rawline lnum content
  while IFS= read -r rawline; do
    lnum="${rawline%%:*}"
    content="${rawline#*:}"
    emit_blocking "PRESENTATION CLARITY" "3.2" "${f}:${lnum}" \
      "heading depth exceeds level 3 (===): \"${content}\". A level-4+ heading is prohibited; restructure into level-1/2/3 sections (standards/document-structure.md)."
  done < <(grep -nE '^={4,}[[:space:]]' "$cleanf" 2>/dev/null || true)
}

# check_confirm_comment FILE -- Rule 1.5 [BLOCKING / MECHANICAL]. Operates on the RAW file (not
# the comment-stripped clean copy) because the CONFIRM marker IS the comment text being checked.
check_confirm_comment() {
  local f="$1" rawline lnum content payload
  while IFS= read -r rawline; do
    lnum="${rawline%%:*}"
    content="${rawline#*:}"
    payload="${content#*CONFIRM:}"
    payload="${payload#"${payload%%[![:space:]]*}"}"
    payload="${payload%"${payload##*[![:space:]]}"}"
    if [[ -z "$payload" ]]; then
      emit_blocking "SOURCE GROUNDING" "1.5" "${f}:${lnum}" \
        "CONFIRM comment has an empty payload after the 'CONFIRM:' prefix. Add the specific claim that needs a source, e.g. \`// CONFIRM: <claim>\`."
    fi
  done < <(grep -nE '//[[:space:]]*CONFIRM:' "$f" 2>/dev/null || true)
}

# check_backtick_paths FILE CLEANFILE ROOT -- Rule 1.2 [BLOCKING / MECHANICAL]. Decision 3:
# path-shaped tokens only (contains '/' or ends in a recognized extension), biased to under-fire.
check_backtick_paths() {
  local f="$1" cleanf="$2" root="$3" filedir rawline lnum content token
  filedir="$(cd "$(dirname "$f")" && pwd)"
  while IFS= read -r rawline; do
    lnum="${rawline%%:*}"
    content="${rawline#*:}"
    while IFS= read -r token; do
      [[ -z "$token" ]] && continue
      if [[ "$token" == */* ]] || [[ "$token" =~ \.(sh|md|typ|json|lua|py|lean|bib|ya?ml|toml|txt|jsonl)$ ]]; then
        if [[ ! -e "${root}/${token}" && ! -e "${filedir}/${token}" ]]; then
          emit_blocking "SOURCE GROUNDING" "1.2" "${f}:${lnum}" \
            "backticked path \`${token}\` does not resolve against the live tree (checked relative to repo root ${root} and to ${filedir})."
        fi
      fi
    done < <(grep -oE '`[^`]+`' <<<"$content" | sed -E 's/^`(.*)`$/\1/')
  done < <(grep -n '`' "$cleanf" 2>/dev/null || true)
}

# check_bib_keys FILE CLEANFILE BIBFILE -- Rule 1.3 [BLOCKING / MECHANICAL]. Citation syntax per
# patterns/bibliography.md: @key, optionally followed by [...] page-ref, not part of a longer
# identifier.
check_bib_keys() {
  local f="$1" cleanf="$2" bibfile="$3" rawline lnum content key
  while IFS= read -r rawline; do
    lnum="${rawline%%:*}"
    content="${rawline#*:}"
    while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      if ! grep -qE "^@[A-Za-z]+\{[[:space:]]*${key}[[:space:]]*," "$bibfile" 2>/dev/null; then
        emit_blocking "SOURCE GROUNDING" "1.3" "${f}:${lnum}" \
          "citation key @${key} does not resolve in ${bibfile}."
      fi
    done < <(grep -oE '(^|[^A-Za-z0-9_@])@[A-Za-z][A-Za-z0-9_:.-]*' <<<"$content" | sed -E 's/^.*@//')
  done < <(grep -n '@' "$cleanf" 2>/dev/null || true)
}

# check_claim_ratio FILE CLEANFILE -- Rule 2.1 [ADVISORY / MECHANICAL]. Per `==`/`===` section, a
# "claim" is a `@key` citation occurrence within that section (a claim traceable to a cited
# source, per this standard's SOURCE GROUNDING dimension); warns when the section's
# words-per-claim ratio exceeds CLAIM_RATIO_THRESHOLD (or has zero claims and more than
# CLAIM_RATIO_THRESHOLD words). Deliberately does NOT pattern-match on the semantic-element
# inventory (definition/theorem/.../rule-list) -- that inventory belongs to
# semantic-element-usage.md and to the delegated placement check only; reusing it here as a second
# "claim" signal would blur the boundary this script's SCOPE BOUNDARY draws. Never increments
# TOTAL_BLOCKING -- see emit_advisory.
check_claim_ratio() {
  local f="$1" cleanf="$2" lnum content ratio
  while IFS= read -r rawline; do
    [[ -z "$rawline" ]] && continue
    lnum="${rawline%%$'\t'*}"
    content="${rawline#*$'\t'}"
    emit_advisory "ANTI-FLUFF DENSITY" "2.1" "${f}:${lnum}" \
      "section \"${content}\" has a low claim-to-word ratio (threshold ${CLAIM_RATIO_THRESHOLD} words/claim, unreviewed). This rule never blocks."
  done < <(awk -v threshold="$CLAIM_RATIO_THRESHOLD" '
    function flush() {
      if (started) {
        if (claim_count == 0) {
          if (words > threshold) printf "%d\t%s\n", start_line, heading_text
        } else if ((words / claim_count) > threshold) {
          printf "%d\t%s\n", start_line, heading_text
        }
      }
    }
    BEGIN { started = 0; words = 0; claim_count = 0; start_line = 0; heading_text = "" }
    {
      line = $0
      clean = line
      gsub(/"[^"]*"/, "", clean)
      sub(/\/\/.*/, "", clean)
      trimmed = clean
      sub(/^[ \t]+/, "", trimmed)
      sub(/[ \t]+$/, "", trimmed)
      if (trimmed ~ /^=+[ \t]/) {
        flush()
        started = 1
        words = 0
        claim_count = 0
        start_line = FNR
        heading_text = trimmed
        next
      }
      if (!started) next
      if (trimmed == "") next
      n = split(trimmed, warr, /[ \t]+/)
      words += n
      tmp = trimmed
      c = gsub(/@[A-Za-z][A-Za-z0-9_:.-]*/, "&", tmp)
      claim_count += c
    }
    END { flush() }
  ' "$cleanf" 2>/dev/null || true)
}

# check_hedging_filler FILE CLEANFILE -- Rule 2.3 [ADVISORY / MECHANICAL]. Never increments
# TOTAL_BLOCKING -- see emit_advisory.
check_hedging_filler() {
  local f="$1" cleanf="$2" phrase rawline lnum content
  for phrase in "${HEDGING_SEED_LIST[@]}"; do
    while IFS= read -r rawline; do
      lnum="${rawline%%:*}"
      content="${rawline#*:}"
      emit_advisory "ANTI-FLUFF DENSITY" "2.3" "${f}:${lnum}" \
        "hedging/filler phrase \"${phrase}\" (seed list ${HEDGING_LIST_VERSION}) in: \"${content}\". This rule never blocks."
    done < <(grep -inF -- "$phrase" "$cleanf" 2>/dev/null || true)
  done
}

# check_paragraph_length FILE CLEANFILE -- Rule 3.3 [ADVISORY / MECHANICAL]. A "paragraph" is a
# blank-line-delimited block of the comment/quote-stripped file (KNOWN LIMITATION: not prose-aware
# -- a heading or a run of declarations counts as a paragraph too). Never increments
# TOTAL_BLOCKING -- see emit_advisory.
check_paragraph_length() {
  local f="$1" cleanf="$2" lnum words
  while IFS= read -r rawline; do
    [[ -z "$rawline" ]] && continue
    lnum="${rawline%%$'\t'*}"
    words="${rawline#*$'\t'}"
    emit_advisory "PRESENTATION CLARITY" "3.3" "${f}:${lnum}" \
      "paragraph spans ${words} words (threshold ${PARAGRAPH_WORD_THRESHOLD}, unreviewed). This rule never blocks."
  done < <(awk -v threshold="$PARAGRAPH_WORD_THRESHOLD" '
    function flush() {
      if (words > threshold) printf "%d\t%d\n", start_line, words
      words = 0
      start_line = 0
    }
    {
      line = $0
      clean = line
      gsub(/"[^"]*"/, "", clean)
      sub(/\/\/.*/, "", clean)
      trimmed = clean
      sub(/^[ \t]+/, "", trimmed)
      sub(/[ \t]+$/, "", trimmed)
      if (trimmed == "") { flush(); next }
      if (start_line == 0) start_line = FNR
      n = split(trimmed, warr, /[ \t]+/)
      words += n
    }
    END { flush() }
  ' "$cleanf" 2>/dev/null || true)
}

# emit_judged_prompts FILE CLEANFILE -- emits one structured reviewer prompt per JUDGED_RULES
# entry per checked file (never silently skipped). A green (0 BLOCKING) mechanical result asserts
# mechanical coverage only -- these prompts still require a reviewing agent's adjudication.
# Location-bearing rules get a concrete anchor where one is derivable without judging (2.2 anchors
# each ==/=== heading line; 4.2 anchors an "== Open Questions" heading when one is found);
# otherwise a rule is anchored at the file.
emit_judged_prompts() {
  local f="$1" cleanf="$2" entry rule dim sev question
  for entry in "${JUDGED_RULES[@]}"; do
    IFS='|' read -r rule dim sev question <<< "$entry"
    case "$rule" in
      2.2)
        local found_heading=0 rawline lnum content
        while IFS= read -r rawline; do
          found_heading=1
          lnum="${rawline%%:*}"
          content="${rawline#*:}"
          emit_judged "$rule" "$dim" "$sev" "${f}:${lnum}" "${question} (section: \"${content}\")"
        done < <(grep -nE '^(==|===)[[:space:]]' "$cleanf" 2>/dev/null || true)
        if [[ "$found_heading" -eq 0 ]]; then
          emit_judged "$rule" "$dim" "$sev" "$f" "$question"
        fi
        ;;
      4.2)
        local oq_line
        oq_line=$(grep -niE '^==+[[:space:]]+open[[:space:]]+questions[[:space:]]*$' "$cleanf" 2>/dev/null | head -1 | cut -d: -f1)
        if [[ -n "$oq_line" ]]; then
          emit_judged "$rule" "$dim" "$sev" "${f}:${oq_line}" "$question"
        else
          emit_judged "$rule" "$dim" "$sev" "$f" \
            "${question} (no '== Open Questions' heading found in this file -- confirm open questions are not scattered inline elsewhere)"
        fi
        ;;
      *)
        emit_judged "$rule" "$dim" "$sev" "$f" "$question"
        ;;
    esac
  done
}

# check_placement FILE -- Placement (BLOCKING, delegated). Decision 5: locates the sibling as
# $(dirname "$0")/typst-element-lint.sh and invokes it per file with --verbose, mapping its
# [FAIL] to a BLOCKING placement finding and [WARN] to an ADVISORY finding. A missing sibling is
# an environment error (exit 2), never a silent pass -- this is the ONLY placement implementation
# in this script; the Universal Placement Rule itself is never re-implemented here (see SCOPE
# BOUNDARY in the header).
check_placement() {
  local f="$1" sibling out line clean
  sibling="${SCRIPT_DIR}/typst-element-lint.sh"
  if [[ ! -x "$sibling" ]]; then
    echo "Error: sibling typst-element-lint.sh not found or not executable at ${sibling}" >&2
    exit 2
  fi
  out=$(bash "$sibling" --verbose "$f" 2>&1)
  while IFS= read -r line; do
    clean=$(printf '%s' "$line" | sed -E 's/\x1b\[[0-9;]*m//g')
    if [[ "$clean" == '[FAIL]'* ]]; then
      emit_blocking "PLACEMENT (delegated)" "element-lint:placement" "$f" \
        "delegated from typst-element-lint.sh: ${clean#'[FAIL] '}"
    elif [[ "$clean" == '[WARN]'* ]]; then
      emit_advisory "PLACEMENT (delegated)" "element-lint:advisory" "$f" \
        "delegated from typst-element-lint.sh: ${clean#'[WARN] '}"
    fi
  done <<< "$out"
}

# process_file FILE -- runs every implemented check against FILE and prints its score line.
# Rule-check bodies are added phase by phase (see the plan this script was implemented from).
process_file() {
  local f="$1"
  file_blocking=0
  file_advisory=0
  file_judged=0
  FILE_RULE_FIRED=()
  FILE_RULE_NOTEVAL=()

  local clean_tmp root bibfile
  clean_tmp="$(mktemp)"
  awk '{ gsub(/"[^"]*"/,""); sub(/\/\/.*/,""); gsub(/^[ \t]+/,""); gsub(/[ \t]+$/,""); print }' "$f" > "$clean_tmp"
  root="$(resolve_repo_root "$f")"

  check_placement "$f"
  check_heading_depth "$f" "$clean_tmp"
  check_confirm_comment "$f"
  check_backtick_paths "$f" "$clean_tmp" "$root"
  check_claim_ratio "$f" "$clean_tmp"
  check_hedging_filler "$f" "$clean_tmp"
  check_paragraph_length "$f" "$clean_tmp"
  emit_judged_prompts "$f" "$clean_tmp"

  if bibfile="$(resolve_bibliography "$f" "$root")"; then
    $VERBOSE && emit_info "$f" "Rule 1.3 evaluated against ${bibfile}"
    check_bib_keys "$f" "$clean_tmp" "$bibfile"
  else
    emit_not_evaluated "1.3" "${f}" \
      "no resolvable .bib file (no #bibliography(...) declaration and zero or multiple *.bib candidates under ${root})"
  fi

  rm -f "$clean_tmp"

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
