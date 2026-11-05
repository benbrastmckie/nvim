#!/usr/bin/env bash
# literature-search.sh - Agent-callable FTS5 search tool for literature retrieval
#
# Usage:
#   literature-search.sh "query"             # FTS5 search, returns ranked metadata JSON
#   literature-search.sh --include-unverified "query"  # also include quarantined docs
#   literature-search.sh --read <chunk_id>   # Read full chunk content from disk
#   literature-search.sh --toc [doc_id]      # Browse TOC (metadata only, no content)
#   literature-search.sh --refs <chunk_id>   # Follow cross-references from chunk
#   literature-search.sh --next <chunk_id>   # Next chunk in sequence (metadata + first paragraph)
#   literature-search.sh --prev <chunk_id>   # Previous chunk in sequence (metadata + first paragraph)
#   literature-search.sh --doc <doc_id>      # List all chunks for a document
#   printf '%s\n' "term one" "term two" | literature-search.sh --multi [limit]
#                                             # Multi-query mode: run N short queries
#                                             # (one per stdin line) inside this ONE process
#                                             # (one DB open, one fidelity-map load) and
#                                             # return a single rank-merged, chunk_id-deduped
#                                             # envelope -- one process for per-term recall
#                                             # instead of N. Envelope adds `total_matched`
#                                             # (top-level: de-duplicated, post-quarantine,
#                                             # pre-limit-slice count), `corroborated_count`
#                                             # (top-level: same pre-limit-slice pool, but
#                                             # only rows with matched_terms >= 2 -- a
#                                             # sparse/rich signal total_matched alone
#                                             # cannot give once many short, individually-
#                                             # common words are OR-merged), and
#                                             # `matched_terms` (per row: how many distinct
#                                             # sub-queries surfaced it). Results sort by matched_terms
#                                             # descending, then rank ascending WITHIN a
#                                             # matched_terms tier -- bm25 scores from
#                                             # independent single-term sub-queries are not
#                                             # on a comparable scale, so cross-term
#                                             # corroboration leads (see do_multi_search's
#                                             # merge-sort comment for the empirical evidence).
#                                             # query_error is non-null only when every
#                                             # sub-query failed against every database that
#                                             # exists.
#
# Output: JSON to stdout. Errors as {"error": "...", "code": N} to stdout, exit non-zero.
#
# Two-tier search: queries local specs/literature/.literature.db first,
# then global ~/Projects/Literature/.literature.db. Local results take
# precedence on duplicate doc_id. Results merged and re-ranked by BM25.
#
# Query sanitization: strips FTS5 operators (AND/OR/NOT at word boundaries,
# unbalanced quotes/parens). Allows "quoted phrases". Escapes apostrophes.
#
# Provenance/fidelity flagging: every search/read/toc result carries a
# `provenance_fidelity` field looked up from $LITERATURE_DIR/index.json (fail-open —
# a doc missing the field is treated as unverified, never as verified_conversion; see
# .claude/scripts/literature-fidelity-audit.sh for how the field is computed and
# stamped). do_search excludes `unverified_summary`/`unverified_no_baseline` docs from
# its default ranked output; pass --include-unverified to opt back in. This is a
# retrieval-time quarantine only — --read/--toc/--doc always return the doc regardless
# of this flag, and --read prefixes the content of any non-verified_conversion chunk
# with a loud warning banner. No corpus file is ever hidden, deleted, or edited by
# this quarantine.
#
# Environment:
#   LITERATURE_DIR  — Global library path (default: ~/Projects/Literature)
#   LITERATURE_LIMIT — Default result limit (default: 20)

set -euo pipefail

LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
LITERATURE_LIMIT="${LITERATURE_LIMIT:-20}"
PROJECT_FILTER=""
INCLUDE_UNVERIFIED="false"

# File-local python helper module (see lib/literature_search_pylib.py's module
# docstring). Not a cross-extension shared lib -- this script has peers=0 in
# script-inventory.sh's duplicate-block report; the only "second consumer" each
# helper has is this script's OWN other heredocs.
LIT_SEARCH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"

# --- provenance_fidelity values excluded from default search ranking ---
# Docs whose fidelity is one of these are quarantined from default do_search output:
# still fully retrievable (via --include-unverified, or directly via --read/--toc/
# --doc), never deleted, never edited. See literature-fidelity-audit.sh for how the
# field is computed and stamped. "unadjudicated" covers low-ratio,
# undisclosed docs where the proof-completeness signal could not fire at all --
# fail closed, quarantine it like the other unverified values.
QUARANTINED_FIDELITY_VALUES="unverified_summary unverified_no_baseline unadjudicated unverified_scan_source"

# --- Build allowed doc_id set from index.json for a project ---
# Returns newline-separated doc_ids, or empty string if no index or no matches
#
# INVARIANT: the allow-list must live in the chunks_data.doc_id namespace, never the
# curated .id namespace alone. index.json's curated `.id` and .literature.db's
# chunks_data.doc_id are two independent id namespaces that have drifted apart (see
# literature-doc-key.sh's header for the full invariant and the corpus history that
# proved renaming to unify them breaks --toc). This function therefore emits the UNION
# of the path-derived key (the sources/<dir>/ directory-name component of .path, which
# IS the FTS doc_id) and the entry's own .id for every matching entry -- union, not
# replacement, because the result feeds a `WHERE d.doc_id IN (...)` filter downstream:
# an extra key with no FTS rows is inert, while dropping a key can silently hide a
# document that only resolves under one of the two names. Iterates .entries[]? (children
# included), which is what pulls in the directories whose only index coverage is at
# child level. Mirrors literature-doc-key.sh's own --list-keys derivation; not routed
# through that script's CLI here to avoid a second jq/process spawn per query, but the
# derivation logic is identical -- see that file if the two ever need to be reconciled.
get_project_doc_ids() {
  local project="$1"
  local index_file="$LITERATURE_DIR/index.json"

  if [ ! -f "$index_file" ]; then
    echo ""
    return
  fi

  jq -r --arg proj "$project" '
    .entries[]? |
    select(
      (.project_tags == null) or
      (.project_tags | length == 0) or
      (.project_tags | map(ascii_downcase) | index($proj | ascii_downcase)) != null
    ) |
    (
      (if (.path? // "" | tostring | startswith("sources/"))
        then (.path | ltrimstr("sources/") | split("/")[0])
        else empty
       end),
      (.id // empty)
    )
  ' "$index_file" 2>/dev/null | sort -u
}

# --- Error output ---
error_json() {
  local msg="$1"
  local code="${2:-1}"
  printf '{"error": %s, "code": %d}\n' "$(printf '%s' "$msg" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" "$code"
  exit "$code"
}

# --- Find databases ---
find_databases() {
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  local local_db="$git_root/specs/literature/.literature.db"
  local global_db="$LITERATURE_DIR/.literature.db"

  # Return: local_db (may be empty if not found), global_db (may be empty if not found)
  echo "${local_db}:${global_db}"
}

# --- Query sanitization ---
sanitize_query() {
  local query="$1"

  python3 << PYEOF
import re
import sys

query = "$query"

# Escape shell substitution issues - get query from variable
import os
query = os.environ.get('_SEARCH_QUERY', query)

# --- Ligature fold ---
# Mirrors literature-convert.sh's LIGATURE_MAP (U+FB00-FB06) verbatim. Applied
# FIRST, before any other transform, so a query containing a raw ligature
# glyph matches the corpus's already-folded text (#831 folds ligatures at
# conversion time; this is the query-time half of that same fold, deliberately
# NOT blanket NFKC -- NFKC corrupts math-italic/blackboard-bold Unicode).
LIGATURE_MAP = {
    "ﬀ": "ff", "ﬁ": "fi", "ﬂ": "fl",
    "ﬃ": "ffi", "ﬄ": "ffl", "ﬅ": "st", "ﬆ": "st",
}
_LIGATURE_RE = re.compile("[" + "".join(LIGATURE_MAP) + "]")
query = _LIGATURE_RE.sub(lambda m: LIGATURE_MAP[m.group(0)], query)

# Remove bare FTS5 operators at word boundaries (case-insensitive)
# Allow "quoted phrases" by preserving balanced double-quote pairs
query = re.sub(r'\bAND\b', ' ', query, flags=re.IGNORECASE)
query = re.sub(r'\bOR\b', ' ', query, flags=re.IGNORECASE)
query = re.sub(r'\bNOT\b', ' ', query, flags=re.IGNORECASE)

# Remove unanchored wildcards (keep * inside "..." quotes)
# Simple approach: strip * not inside double quotes
in_quote = False
chars = []
for c in query:
    if c == '"':
        in_quote = not in_quote
    if c == '*' and not in_quote:
        chars.append(' ')
    else:
        chars.append(c)
query = ''.join(chars)

# Balance double quotes: if odd number, strip all quotes
quote_count = query.count('"')
if quote_count % 2 != 0:
    query = query.replace('"', ' ')

# --- Punctuation normalization ---
# FTS5's query grammar treats mid-word hyphens (column-exclusion/NOT-prefix),
# colons (column-filter), slashes, parens (grouping -- even word-attached
# and balanced), and angle brackets (unrecognized syntax -- FTS5 raises a hard
# "fts5: syntax error near '<'" the moment one appears anywhere in a MATCH
# string, not just when balanced/word-attached) as syntax, not as word
# characters. This function owns the FTS5-hostile character set for its one
# caller (do_search/do_multi_search's sanitize_query() call, and any future
# caller): that caller passes one opaque free-text query string, never a
# hand-built FTS5 boolean expression, so none of this syntax is ever an
# intended feature here -- fold all of it to spaces rather than trying to
# preserve grouping/filter semantics.
query = re.sub(r'(?<=\w)-(?=\w)', ' ', query)  # mid-word hyphen only
query = query.replace(':', ' ')
query = query.replace('/', ' ')
query = query.replace('(', ' ').replace(')', ' ')
query = query.replace('<', ' ').replace('>', ' ')

# Balance parentheses: if unbalanced, strip all parens (no-op now that parens
# are unconditionally stripped above -- kept so this stays inert rather than
# silently wrong if the unconditional strip above is ever narrowed).
open_count = query.count('(')
close_count = query.count(')')
if open_count != close_count:
    query = query.replace('(', ' ').replace(')', ' ')

# Strip apostrophes/single quotes from FTS5 query
# FTS5 does not accept SQL-escaped '' in query strings
# The porter+unicode61 tokenizer strips apostrophes during indexing anyway
query = query.replace("'", '')

# Normalize whitespace
query = ' '.join(query.split())

print(query)
PYEOF
}

# --- Main search function ---
do_search() {
  local query="$1"
  local limit="${2:-$LITERATURE_LIMIT}"
  local project_filter="${3:-}"
  local include_unverified="${4:-false}"

  export _SEARCH_QUERY="$query"
  local sanitized
  sanitized=$(sanitize_query "$query")
  unset _SEARCH_QUERY

  if [ -z "$sanitized" ]; then
    error_json "Query is empty after sanitization" 1
  fi

  local db_paths
  db_paths=$(find_databases)
  local local_db="${db_paths%%:*}"
  local global_db="${db_paths##*:}"

  # Build allowed doc_id list when project filter is set
  local allowed_doc_ids=""
  if [ -n "$project_filter" ]; then
    allowed_doc_ids=$(get_project_doc_ids "$project_filter")
  fi

  local results
  results=$(python3 << PYEOF
import json
import sys

sys.path.insert(0, "$LIT_SEARCH_LIB_DIR")
from literature_search_pylib import run_single_search

local_db = "$local_db"
global_db = "$global_db"
query = "$sanitized"
limit = $limit
allowed_doc_ids_raw = """$allowed_doc_ids"""
literature_dir = "$LITERATURE_DIR"
include_unverified = "$include_unverified" == "true"
quarantined_fidelity = set("$QUARANTINED_FIDELITY_VALUES".split())

# Parse allowed doc_ids (newline-separated, may be empty)
allowed_doc_ids = [d.strip() for d in allowed_doc_ids_raw.strip().splitlines() if d.strip()]

envelope = run_single_search(local_db, global_db, query, limit, allowed_doc_ids,
                              literature_dir, include_unverified, quarantined_fidelity)

# Fallback: if a project filter was in effect and the scoped search yielded zero
# rows, retry unscoped IN THIS SAME PROCESS -- no second python3 heredoc, no
# duplicated search logic. See run_single_search()'s docstring in
# literature_search_pylib.py for why this collapsed what used to be literature-
# search.sh's single biggest duplicate block (an entire second ~230-line copy of
# the search pipeline below this one).
if allowed_doc_ids and not envelope['results']:
    envelope = run_single_search(local_db, global_db, query, limit, [],
                                  literature_dir, include_unverified, quarantined_fidelity)

print(json.dumps(envelope, indent=2, ensure_ascii=False))
PYEOF
)

  echo "$results"
}

# --- Multi-query search ---
# Runs N short queries inside ONE literature-search.sh process (one DB open per
# database, one fidelity-map load per database) and returns a single
# rank-merged, chunk_id-deduped envelope. This is the mechanism that lets a
# caller replace a single AND-all-terms query with per-term recall without
# re-creating the per-invocation process-spawn cost a multi-process fan-out
# would cost (see literature-briefing.sh's filtered-term --global call site,
# the sole caller today).
#
# Usage: printf '%s\n' "term one" "term two" | literature-search.sh --multi [limit]
# stdin: newline-separated RAW (unsanitized) queries, one per line.
do_multi_search() {
  local limit="${1:-$LITERATURE_LIMIT}"
  local project_filter="$PROJECT_FILTER"
  local include_unverified="$INCLUDE_UNVERIFIED"

  # Read raw queries from stdin.
  local raw_queries=()
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] && raw_queries+=("$line")
  done

  # sanitize_query() stays the single source of sanitization truth -- loop it
  # once per query here in the bash layer rather than porting/duplicating its
  # rules into the search heredoc below. Drop entries that sanitize to empty
  # and dedupe (a repeated term costs a wasted MATCH for no additional recall).
  local sanitized_queries=()
  declare -A _seen_sanitized=()
  local raw sanitized
  for raw in "${raw_queries[@]}"; do
    export _SEARCH_QUERY="$raw"
    sanitized=$(sanitize_query "$raw")
    unset _SEARCH_QUERY
    if [ -n "$sanitized" ] && [ -z "${_seen_sanitized[$sanitized]:-}" ]; then
      _seen_sanitized["$sanitized"]=1
      sanitized_queries+=("$sanitized")
    fi
  done

  if [ ${#sanitized_queries[@]} -eq 0 ]; then
    error_json "Multi-query list is empty (no queries on stdin, or all queries sanitized to empty)" 1
  fi

  local queries_json
  queries_json=$(printf '%s\n' "${sanitized_queries[@]}" | jq -R . | jq -s -c .)

  local db_paths
  db_paths=$(find_databases)
  local local_db="${db_paths%%:*}"
  local global_db="${db_paths##*:}"

  local allowed_doc_ids=""
  if [ -n "$project_filter" ]; then
    allowed_doc_ids=$(get_project_doc_ids "$project_filter")
  fi

  export _MULTI_QUERIES_JSON="$queries_json"
  local results
  results=$(python3 << PYEOF
import json
import os
import sqlite3
import sys

sys.path.insert(0, "$LIT_SEARCH_LIB_DIR")
from literature_search_pylib import load_fidelity_map, get_fidelity, run_ladder, ROW_TIER_LABEL

local_db = "$local_db"
global_db = "$global_db"
limit = $limit
allowed_doc_ids_raw = """$allowed_doc_ids"""
literature_dir = "$LITERATURE_DIR"
include_unverified = "$include_unverified" == "true"
quarantined_fidelity = set("$QUARANTINED_FIDELITY_VALUES".split())
queries = json.loads(os.environ["_MULTI_QUERIES_JSON"])

allowed_doc_ids = [d.strip() for d in allowed_doc_ids_raw.strip().splitlines() if d.strip()]

fidelity_map = load_fidelity_map(literature_dir)


def search_db_multi(db_path, queries, limit, allowed_doc_ids):
    """Run every query in 'queries' against db_path inside ONE connection,
    dedupe results by chunk_id (keeping the best/lowest rank occurrence and a
    per-chunk matched_terms corroboration count -- how many distinct
    sub-queries surfaced that chunk), and report how many of the N queries
    failed outright (zero rows AND a query_error) so the caller can apply the
    'query_error only when ALL sub-queries failed' aggregation rule."""
    if not os.path.isfile(db_path):
        return {'results': [], 'failed_terms': 0, 'attempted_terms': 0, 'errors': []}

    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
    except Exception as e:
        print(f"[search] Database error ({db_path}): {e}", file=sys.stderr)
        return {'results': [], 'failed_terms': len(queries), 'attempted_terms': len(queries), 'errors': [str(e)]}

    by_chunk = {}
    failed_terms = 0
    errors = []

    for q in queries:
        try:
            rows, tier, query_error = run_ladder(conn, q, limit, allowed_doc_ids, db_path)
        except Exception as e:
            rows, tier, query_error = [], 'none', str(e)

        if not rows and query_error is not None:
            failed_terms += 1
            errors.append(f"{q!r}: {query_error}")
            continue

        match_tier = ROW_TIER_LABEL.get(tier, 'bm25')
        for row in rows:
            cid = row['chunk_id']
            cross_refs = row['cross_refs'] or '[]'
            try:
                cross_refs = json.loads(cross_refs)
            except (json.JSONDecodeError, TypeError):
                cross_refs = []
            rank = row['rank']
            existing = by_chunk.get(cid)
            if existing is None:
                by_chunk[cid] = {
                    'chunk_id': cid,
                    'doc_id': row['doc_id'],
                    'section_path': row['section_path'],
                    'title': row['title'],
                    'summary': row['summary'],
                    'token_count': row['token_count'],
                    'cross_refs': cross_refs,
                    'rank': rank,
                    'snippet': (row['snippet'] or '').strip()[:200],
                    'provenance_fidelity': get_fidelity(fidelity_map, row['doc_id']),
                    'match_tier': match_tier,
                    'matched_terms': 1,
                }
            else:
                existing['matched_terms'] += 1
                if rank < existing['rank']:
                    existing['rank'] = rank
                    existing['match_tier'] = match_tier

    conn.close()
    return {
        'results': list(by_chunk.values()),
        'failed_terms': failed_terms,
        'attempted_terms': len(queries),
        'errors': errors,
    }


local_out = search_db_multi(local_db, queries, limit, allowed_doc_ids if allowed_doc_ids else None)
global_out = search_db_multi(global_db, queries, limit, allowed_doc_ids if allowed_doc_ids else None)
local_results = local_out['results']
global_results = global_out['results']

# Local-over-global doc_id precedence -- identical rule to do_search's
# single-query merge: any global row whose doc_id already has a local
# occurrence is dropped wholesale, never partially combined with it.
local_doc_ids = {r['doc_id'] for r in local_results}
merged = local_results + [r for r in global_results if r['doc_id'] not in local_doc_ids]

# Quarantine: exclude unverified/no-baseline docs from default ranking (same
# rule as do_search; always retrievable via --include-unverified/--read/--toc).
if not include_unverified:
    merged = [r for r in merged if r['provenance_fidelity'] not in quarantined_fidelity]

# total_matched: the de-duplicated, post-quarantine, PRE-limit-slice count --
# literature-briefing.sh's seg_count/coverage_count is pinned to this field so
# the sparse=true marker stays honest. Never a sum of per-term totals.
total_matched = len(merged)

# corroborated_count: the subset of the same pre-limit-slice merged set matched by
# 2+ DISTINCT filtered terms. Additive, alongside total_matched -- not a replacement
# for it. Exists because total_matched alone is NOT a reliable sparse-vs-rich signal
# once many short, individually-common English words are searched independently and
# merged by OR: verified empirically against the real global corpus that a
# genuinely off-topic query (no shared subject matter with the corpus at all) can
# still report a large total_matched purely from coincidental single-term hits
# across unrelated documents, silently defeating the sparse=true re-prompt this
# field exists to keep honest. literature-briefing.sh uses this field (never
# total_matched) for the sparse determination specifically when the filtered term
# count exceeds MULTI_TERM_MATCH_THRESHOLD -- mirroring the same >=2-distinct-hits
# asymmetry literature-coverage-delta.sh/literature-discover.sh already apply to
# their own long-query keyword passes. total_matched/seg_count keep reporting the
# full deduplicated count regardless; only the sparse boolean's INPUT changes.
corroborated_count = sum(1 for r in merged if r['matched_terms'] >= 2)

# Sort by matched_terms descending, THEN rank ascending (bm25 is more-negative-is-
# better) within each matched_terms tier. matched_terms leads, not rank, because
# bm25 scores from INDEPENDENT single-term sub-queries are not on a comparable
# scale: a generic word that happens to be the entirety of one short document's
# match can score more extreme than a genuinely on-topic multi-word hit, so
# sorting the merged pool by raw rank alone lets corpus-wide-common words flood
# the top with single-term-only noise. Corroboration by two or more distinct
# filtered terms is real signal that raw cross-query rank cannot see -- verified
# empirically against the real global corpus with a full-length (100+-word) task
# description: rank-primary sorting returned zero topically relevant chunks in the
# top 10 despite non-empty recall, while promoting matched_terms surfaced the
# corpus's actual modal-logic textbook among the top hits. Within a matched_terms
# tier, rank is still the ONLY signal used to order -- this never recomputes a new
# relevance score, it only changes which of the two existing signals leads.
merged.sort(key=lambda r: (-r['matched_terms'], r['rank']))
merged = merged[:limit]

if merged:
    tiers_present = {r.get('match_tier', 'bm25') for r in merged}
    if 'bm25' in tiers_present:
        fallback_tier = 'bm25'
    elif 'phrase_retry' in tiers_present:
        fallback_tier = 'phrase_retry'
    elif 'trigram_fallback' in tiers_present:
        fallback_tier = 'trigram'
    else:
        fallback_tier = 'none'
else:
    fallback_tier = 'none'
degraded = fallback_tier != 'bm25'

# Conservative query_error aggregation: a hard, non-null query_error surfaces
# ONLY when every sub-query attempted against every database that actually
# exists failed outright -- one hostile term among valid ones (or a term that
# fails against one database but succeeds against the other) must never
# poison the whole multi-query response. A database that does not exist
# contributes 0 attempted/0 failed (see search_db_multi's early return), so
# it never counts toward "all failed".
total_attempted = local_out['attempted_terms'] + global_out['attempted_terms']
total_failed = local_out['failed_terms'] + global_out['failed_terms']
if total_attempted > 0 and total_failed == total_attempted:
    all_errors = local_out['errors'] + global_out['errors']
    n = len(queries)
    query_error = f"all {n} sub-quer{'y' if n == 1 else 'ies'} failed: " + "; ".join(all_errors[:5])
else:
    query_error = None

envelope = {
    'results': merged,
    'degraded': degraded,
    'fallback_tier': fallback_tier,
    'query_error': query_error,
    'total_matched': total_matched,
    'corroborated_count': corroborated_count,
}

print(json.dumps(envelope, indent=2, ensure_ascii=False))
PYEOF
)
  unset _MULTI_QUERIES_JSON

  echo "$results"
}


# --- Read chunk ---
do_read() {
  local chunk_id="$1"

  local db_paths
  db_paths=$(find_databases)
  local local_db="${db_paths%%:*}"
  local global_db="${db_paths##*:}"

  python3 << PYEOF
import sqlite3
import json
import os
import sys

sys.path.insert(0, "$LIT_SEARCH_LIB_DIR")
from literature_search_pylib import load_fidelity_map, get_fidelity

local_db = "$local_db"
global_db = "$global_db"
chunk_id = "$chunk_id"
literature_dir = "$LITERATURE_DIR"

fidelity_map = load_fidelity_map(literature_dir)


def find_chunk(db_path, chunk_id):
    if not os.path.isfile(db_path):
        return None
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.execute(
            "SELECT * FROM chunks_data WHERE chunk_id=?", (chunk_id,)
        )
        row = cursor.fetchone()
        conn.close()
        if row:
            return dict(row), db_path
    except Exception:
        pass
    return None

# Try local first, then global
result = find_chunk(local_db, chunk_id) or find_chunk(global_db, chunk_id)

if not result:
    print(json.dumps({"error": f"Chunk not found: {chunk_id}", "code": 404}))
    sys.exit(1)

chunk_row, db_path = result
source_path = chunk_row.get('source_path', '')
db_dir = os.path.dirname(db_path)

# Resolve the chunk file path
chunk_file = os.path.join(db_dir, source_path)

# Also try checking if this is a nested path (chunks in subdirectory)
if not os.path.isfile(chunk_file):
    # Try finding the file under the db directory
    chunk_file_basename = os.path.basename(source_path)
    doc_id = chunk_row.get('doc_id', '')
    alt_path = os.path.join(db_dir, doc_id, chunk_file_basename)
    if os.path.isfile(alt_path):
        chunk_file = alt_path

# Converted chunk files actually live under sources/<doc_id>/, the same
# doc_id == directory-name-under-sources/ assumption load_fidelity_map() above
# already relies on (see its "sources/<dir>/" derivation). Try this candidate
# last, only after both existing candidates have missed.
if not os.path.isfile(chunk_file):
    chunk_file_basename = os.path.basename(source_path)
    doc_id = chunk_row.get('doc_id', '')
    sources_path = os.path.join(db_dir, "sources", doc_id, chunk_file_basename)
    if os.path.isfile(sources_path):
        chunk_file = sources_path

content = ''
if os.path.isfile(chunk_file):
    try:
        with open(chunk_file, encoding='utf-8', errors='replace') as f:
            content = f.read()
    except IOError as e:
        content = f"[Error reading file: {e}]"
else:
    content = f"[Chunk file not found: {chunk_file}]"

cross_refs = chunk_row.get('cross_refs', '[]')
try:
    cross_refs = json.loads(cross_refs)
except Exception:
    cross_refs = []

doc_id = chunk_row.get('doc_id', '')
provenance_fidelity = get_fidelity(fidelity_map, doc_id)

# Loud content banner: never silently hand an agent unverified text as
# if it were an authoritative conversion. verified_conversion docs are unchanged.
if provenance_fidelity != 'verified_conversion':
    banner = (
        f"[UNVERIFIED CONTENT - provenance_fidelity: {provenance_fidelity}]\n"
        f"This chunk has not been confirmed to faithfully reproduce its source PDF. "
        f"Do not cite claims, lemmas, or definitions from it as authoritative without "
        f"verifying against the primary source (doc_id: {doc_id}).\n"
        f"{'=' * 70}\n\n"
    )
    content = banner + content

output = {
    'chunk_id': chunk_id,
    'doc_id': doc_id,
    'title': chunk_row.get('title', ''),
    'section_path': chunk_row.get('section_path', ''),
    'token_count': chunk_row.get('token_count', 0),
    'cross_refs': cross_refs,
    'provenance_fidelity': provenance_fidelity,
    'content': content,
}

print(json.dumps(output, indent=2, ensure_ascii=False))
PYEOF
}

# --- TOC listing ---
do_toc() {
  local doc_id="${1:-}"

  local db_paths
  db_paths=$(find_databases)
  local local_db="${db_paths%%:*}"
  local global_db="${db_paths##*:}"

  python3 << PYEOF
import sqlite3
import json
import os
import sys

sys.path.insert(0, "$LIT_SEARCH_LIB_DIR")
from literature_search_pylib import load_fidelity_map, get_fidelity

local_db = "$local_db"
global_db = "$global_db"
doc_id_filter = "$doc_id"
literature_dir = "$LITERATURE_DIR"

fidelity_map = load_fidelity_map(literature_dir)


def get_toc(db_path, doc_id_filter):
    if not os.path.isfile(db_path):
        return []
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        if doc_id_filter:
            sql = """SELECT chunk_id, doc_id, section_path, title, summary, token_count, level
                     FROM chunks_data WHERE doc_id=?
                     ORDER BY id"""
            cursor = conn.execute(sql, (doc_id_filter,))
        else:
            sql = """SELECT chunk_id, doc_id, section_path, title, summary, token_count, level
                     FROM chunks_data
                     ORDER BY doc_id, id"""
            cursor = conn.execute(sql)
        rows = [dict(r) for r in cursor.fetchall()]
        for r in rows:
            r['provenance_fidelity'] = get_fidelity(fidelity_map, r['doc_id'])
        conn.close()
        return rows
    except Exception as e:
        print(f"[search] TOC error ({db_path}): {e}", file=sys.stderr)
        return []

# Get from local first, then global (local takes precedence)
local_results = get_toc(local_db, doc_id_filter)
global_results = get_toc(global_db, doc_id_filter)

# Merge (local wins on duplicate doc_id)
local_doc_ids = {r['doc_id'] for r in local_results}
merged = local_results + [r for r in global_results if r['doc_id'] not in local_doc_ids]

print(json.dumps(merged, indent=2, ensure_ascii=False))
PYEOF
}

# --- Cross-reference lookup ---
do_refs() {
  local chunk_id="$1"

  local db_paths
  db_paths=$(find_databases)
  local local_db="${db_paths%%:*}"
  local global_db="${db_paths##*:}"

  python3 << PYEOF
import sqlite3
import json
import os
import re
import sys

local_db = "$local_db"
global_db = "$global_db"
chunk_id = "$chunk_id"

def get_refs(db_path, chunk_id):
    if not os.path.isfile(db_path):
        return []
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        # Get all chunks linked from this chunk via chunk_relations
        sql = """
            SELECT d.chunk_id, d.doc_id, d.section_path, d.title, d.summary,
                   d.token_count, r.relation_type, r.weight
            FROM chunk_relations r
            JOIN chunks_data d ON d.chunk_id = r.to_chunk_id
            WHERE r.from_chunk_id = ?
            ORDER BY r.relation_type, d.id
        """
        cursor = conn.execute(sql, (chunk_id,))
        rows = [dict(r) for r in cursor.fetchall()]
        conn.close()
        return rows
    except Exception as e:
        print(f"[search] Refs error ({db_path}): {e}", file=sys.stderr)
        return []

local_results = get_refs(local_db, chunk_id)
global_results = get_refs(global_db, chunk_id)

# Merge (local wins)
seen = {r['chunk_id'] for r in local_results}
merged = local_results + [r for r in global_results if r['chunk_id'] not in seen]

print(json.dumps(merged, indent=2, ensure_ascii=False))
PYEOF
}

# --- Next/Prev navigation ---
do_navigate() {
  local direction="$1"  # 'next' or 'prev'
  local chunk_id="$2"

  local db_paths
  db_paths=$(find_databases)
  local local_db="${db_paths%%:*}"
  local global_db="${db_paths##*:}"

  python3 << PYEOF
import sqlite3
import json
import os
import re
import sys

local_db = "$local_db"
global_db = "$global_db"
chunk_id = "$chunk_id"
direction = "$direction"

def get_adjacent(db_path, chunk_id, direction):
    if not os.path.isfile(db_path):
        return None
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row

        # Get the adjacent chunk_id
        field = 'next_chunk_id' if direction == 'next' else 'prev_chunk_id'
        cursor = conn.execute(f"SELECT {field} FROM chunks_data WHERE chunk_id=?", (chunk_id,))
        row = cursor.fetchone()
        if not row or not row[0]:
            conn.close()
            return None

        adj_id = row[0]
        cursor = conn.execute(
            "SELECT chunk_id, doc_id, section_path, title, summary, token_count, content FROM chunks_data WHERE chunk_id=?",
            (adj_id,)
        )
        adj_row = cursor.fetchone()
        conn.close()

        if adj_row:
            # First paragraph of content
            content = adj_row['content'] or ''
            paragraphs = [p.strip() for p in content.split('\n\n') if p.strip()]
            first_para = paragraphs[0] if paragraphs else content[:200]

            return {
                'chunk_id': adj_row['chunk_id'],
                'doc_id': adj_row['doc_id'],
                'section_path': adj_row['section_path'],
                'title': adj_row['title'],
                'summary': adj_row['summary'],
                'token_count': adj_row['token_count'],
                'first_paragraph': first_para[:500],
            }
    except Exception as e:
        print(f"[search] Navigate error ({db_path}): {e}", file=sys.stderr)
    return None

result = get_adjacent(local_db, chunk_id, direction) or get_adjacent(global_db, chunk_id, direction)

if result:
    print(json.dumps(result, indent=2, ensure_ascii=False))
else:
    print(json.dumps({"error": f"No {direction} chunk for: {chunk_id}", "code": 404}))
    sys.exit(1)
PYEOF
}

# --- Main dispatch ---
if [ $# -eq 0 ]; then
  error_json "No arguments provided. Usage: literature-search.sh [--project <name>] [--include-unverified] \"query\" | --multi [limit] (queries on stdin) | --read <id> | --toc [doc_id] | --refs <id> | --next <id> | --prev <id> | --doc <doc_id>" 1
fi

# Pre-scan for --project / --include-unverified flags (may appear before any subcommand)
args=("$@")
remaining_args=()
for ((i = 0; i < ${#args[@]}; i++)); do
  if [ "${args[$i]}" = "--project" ]; then
    if [ -z "${args[$((i+1))]:-}" ]; then
      error_json "Missing project name for --project" 1
    fi
    PROJECT_FILTER="${args[$((i+1))]}"
    i=$((i+1))
  elif [ "${args[$i]}" = "--include-unverified" ]; then
    # Opt back into unverified_summary/unverified_no_baseline results in
    # do_search's default ranking (they remain always retrievable via --read/--toc
    # regardless of this flag; this only affects do_search's exclusion filter).
    INCLUDE_UNVERIFIED="true"
  else
    remaining_args+=("${args[$i]}")
  fi
done

if [ ${#remaining_args[@]} -eq 0 ]; then
  error_json "No command provided after --project. Usage: literature-search.sh [--project <name>] \"query\" | --read <id> | --toc [doc_id] | ..." 1
fi

case "${remaining_args[0]}" in
  --read)
    if [ -z "${remaining_args[1]:-}" ]; then
      error_json "Missing chunk_id for --read" 1
    fi
    do_read "${remaining_args[1]}"
    ;;
  --toc)
    do_toc "${remaining_args[1]:-}"
    ;;
  --refs)
    if [ -z "${remaining_args[1]:-}" ]; then
      error_json "Missing chunk_id for --refs" 1
    fi
    do_refs "${remaining_args[1]}"
    ;;
  --next)
    if [ -z "${remaining_args[1]:-}" ]; then
      error_json "Missing chunk_id for --next" 1
    fi
    do_navigate "next" "${remaining_args[1]}"
    ;;
  --prev)
    if [ -z "${remaining_args[1]:-}" ]; then
      error_json "Missing chunk_id for --prev" 1
    fi
    do_navigate "prev" "${remaining_args[1]}"
    ;;
  --doc)
    if [ -z "${remaining_args[1]:-}" ]; then
      error_json "Missing doc_id for --doc" 1
    fi
    do_toc "${remaining_args[1]}"
    ;;
  --multi)
    # Composable with the pre-scanned --project / --include-unverified flags
    # above (PROJECT_FILTER/INCLUDE_UNVERIFIED are read directly inside
    # do_multi_search). Queries come from stdin, one per line; the optional
    # positional argument is a result limit, not a query.
    do_multi_search "${remaining_args[1]:-$LITERATURE_LIMIT}"
    ;;
  -*)
    error_json "Unknown flag: ${remaining_args[0]}. Use --project, --read, --toc, --refs, --next, --prev, --doc, --multi, or a search query string." 1
    ;;
  *)
    # Default: full-text search
    do_search "${remaining_args[0]}" "${remaining_args[1]:-$LITERATURE_LIMIT}" "$PROJECT_FILTER" "$INCLUDE_UNVERIFIED"
    ;;
esac
