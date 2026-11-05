#!/usr/bin/env bash
# test-literature-search.sh - Characterization suite for literature-search.sh, covering every
# documented CLI mode against a fixture local+global literature corpus.
#
# WHY THIS EXISTS: literature-search.sh is script-inventory.sh's highest-ranked self-internal
# duplication target (172 duplicate blocks, peers=0 -- see the plan phase that added this file).
# No paired test existed before this commit (has_test=false). This suite is the characterization
# test that MUST be green on the unmodified script before any extraction, and is also the
# before/after byte-identical output oracle for that extraction: every mode's raw JSON output is
# written under $CAPTURE_DIR (default: a fresh mktemp dir, printed at the end) so two runs -- one
# against the pre-refactor script, one against the post-refactor script -- can be `diff -r`'d.
#
# No absolute temp paths leak into any captured JSON (verified by construction: every mode
# tested here pops or never emits _db_path/_source_path, and the one "chunk not found" error
# path exercised reports only the chunk_id, never a filesystem path), so two independent mktemp
# fixture trees produce byte-identical captures when the script's behavior is unchanged.
#
# All I/O is confined to a mktemp workdir. This suite MUST NOT read from or write to
# ~/Projects/Literature/ (the real global corpus) or specs/literature/ in this repo.
#
# Usage:
#   bash test-literature-search.sh                       # fresh scratch CAPTURE_DIR
#   CAPTURE_DIR=/tmp/before bash test-literature-search.sh  # pin the capture directory
#
# Exit codes: 0 - all required assertions passed; 1 - a required assertion failed.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
SEARCH_SH="$SCRIPT_DIR/literature-search.sh"
SCHEMA_SQL="$SCRIPT_DIR/literature-schema.sql"

PASS=0
FAIL=0

t_log() { echo "[test-literature-search] $*" >&2; }
t_pass() { PASS=$((PASS + 1)); t_log "PASS: $*"; }
t_fail() { FAIL=$((FAIL + 1)); t_log "FAIL: $*"; }

if [ ! -f "$SEARCH_SH" ]; then
  t_log "literature-search.sh not found at $SEARCH_SH"
  exit 1
fi
if [ ! -f "$SCHEMA_SQL" ]; then
  t_log "literature-schema.sql not found at $SCHEMA_SQL"
  exit 1
fi
if ! command -v sqlite3 >/dev/null 2>&1; then
  t_log "sqlite3 not available; cannot run this suite"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  t_log "python3 not available; cannot run this suite"
  exit 1
fi

WORKDIR=$(mktemp -d)
CAPTURE_DIR="${CAPTURE_DIR:-$(mktemp -d)}"
mkdir -p "$CAPTURE_DIR"
trap 'rm -rf "$WORKDIR"' EXIT

LOCAL_REPO="$WORKDIR/localrepo"
GLOBAL_DIR="$WORKDIR/globaldir"
mkdir -p "$LOCAL_REPO/specs/literature" "$GLOBAL_DIR"

( cd "$LOCAL_REPO" && git init -q )

LOCAL_DB="$LOCAL_REPO/specs/literature/.literature.db"
GLOBAL_DB="$GLOBAL_DIR/.literature.db"

# ============================================================
# Fixture corpus
# ============================================================
# doc_alpha  (LOCAL, verified_conversion,   project_tags=[proj-a]) -- 2 chunks, "zephyrindex"
# doc_beta   (LOCAL, verified_conversion,   project_tags=[proj-b]) -- 1 chunk, "wombatcluster"
# doc_gamma  (LOCAL, unverified_summary,    no project_tags)       -- 1 chunk, "zephyrindex"
# doc_delta  (GLOBAL, verified_conversion,  no project_tags)       -- 1 chunk, "pelicanvortex"
# doc_alpha  (GLOBAL duplicate, different chunk) -- must be fully shadowed by the LOCAL doc_alpha
#            because merge drops ANY global row whose doc_id already appears locally.

build_db() {
  local db_path="$1"
  sqlite3 "$db_path" < "$SCHEMA_SQL"
  python3 - "$db_path" "$2" <<'PYEOF'
import sqlite3, sys, json

db_path, which = sys.argv[1], sys.argv[2]
conn = sqlite3.connect(db_path)

def insert_chunk(chunk_id, doc_id, level, section_path, title, keywords, summary,
                  token_count, source_path, prev_chunk_id, next_chunk_id, cross_refs, content):
    conn.execute(
        """INSERT INTO chunks_data
           (chunk_id, doc_id, level, section_path, title, keywords, summary, token_count,
            source_path, prev_chunk_id, next_chunk_id, cross_refs, content)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        (chunk_id, doc_id, level, section_path, title, keywords, summary, token_count,
         source_path, prev_chunk_id, next_chunk_id, json.dumps(cross_refs), content),
    )

if which == "local":
    insert_chunk("alpha_c1", "doc_alpha", 0, "Ch1", "Alpha Chapter 1", "zephyrindex",
                 "alpha summary one", 10, "sources/doc_alpha/alpha_c1.md", None, "alpha_c2",
                 ["Definition 1.1"],
                 "The zephyrindex pattern appears here in chapter one of the alpha document.")
    insert_chunk("alpha_c2", "doc_alpha", 1, "Ch1 > S1", "Alpha Section 1", "zephyrindex",
                 "alpha summary two", 12, "sources/doc_alpha/alpha_c2.md", "alpha_c1", None,
                 [], "Second alpha chunk about zephyrindex again, in more depth.")
    insert_chunk("beta_c1", "doc_beta", 0, "Ch1", "Beta Chapter 1", "wombatcluster",
                 "beta summary", 9, "sources/doc_beta/beta_c1.md", None, None,
                 [], "The wombatcluster emerges in this beta section of the corpus.")
    insert_chunk("gamma_c1", "doc_gamma", 0, "Ch1", "Gamma Chapter 1", "zephyrindex",
                 "gamma summary", 11, "sources/doc_gamma/gamma_c1.md", None, None,
                 [], "This gamma chunk also discusses zephyrindex in an unverified draft.")
    conn.execute(
        "INSERT INTO chunk_relations (from_chunk_id, to_chunk_id, relation_type, weight) "
        "VALUES ('alpha_c1','alpha_c2','child',1.0)"
    )
else:
    insert_chunk("delta_c1", "doc_delta", 0, "Ch1", "Delta Chapter 1", "pelicanvortex",
                 "delta summary", 8, "sources/doc_delta/delta_c1.md", None, None,
                 [], "A pelicanvortex phenomenon described in the delta document.")
    insert_chunk("alpha_c1_global", "doc_alpha", 0, "Ch1 (global dup)", "Alpha (global)",
                 "zephyrindex", "global dup summary", 10, "sources/doc_alpha/alpha_c1.md",
                 None, None, [],
                 "GLOBAL duplicate alpha content mentioning zephyrindex; must be shadowed "
                 "by the LOCAL doc_alpha chunks because the two share a doc_id.")

conn.commit()
conn.execute("INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild')")
conn.commit()
conn.close()
PYEOF
}

build_db "$LOCAL_DB" "local"
build_db "$GLOBAL_DB" "global"

# index.json: single source of truth for provenance_fidelity AND project_tags, always read
# from $LITERATURE_DIR regardless of which db (local/global) a doc_id's chunks live in.
cat > "$GLOBAL_DIR/index.json" <<'JSONEOF'
{
  "entries": [
    {"id": "doc_alpha", "path": "sources/doc_alpha/", "provenance_fidelity": "verified_conversion", "project_tags": ["proj-a"]},
    {"id": "doc_beta", "path": "sources/doc_beta/", "provenance_fidelity": "verified_conversion", "project_tags": ["proj-b"]},
    {"id": "doc_gamma", "path": "sources/doc_gamma/", "provenance_fidelity": "unverified_summary", "project_tags": []},
    {"id": "doc_delta", "path": "sources/doc_delta/", "provenance_fidelity": "verified_conversion", "project_tags": []}
  ]
}
JSONEOF

# On-disk chunk files for --read (content deliberately differs from the DB `content` column
# so a passing --read assertion proves the file, not the DB column, was read).
mkdir -p "$LOCAL_REPO/specs/literature/sources/doc_alpha" \
         "$LOCAL_REPO/specs/literature/sources/doc_beta" \
         "$LOCAL_REPO/specs/literature/sources/doc_gamma" \
         "$GLOBAL_DIR/sources/doc_delta"
echo "ON-DISK alpha_c1 full chunk text." > "$LOCAL_REPO/specs/literature/sources/doc_alpha/alpha_c1.md"
echo "ON-DISK alpha_c2 full chunk text." > "$LOCAL_REPO/specs/literature/sources/doc_alpha/alpha_c2.md"
echo "ON-DISK beta_c1 full chunk text." > "$LOCAL_REPO/specs/literature/sources/doc_beta/beta_c1.md"
echo "ON-DISK gamma_c1 full chunk text." > "$LOCAL_REPO/specs/literature/sources/doc_gamma/gamma_c1.md"
echo "ON-DISK delta_c1 full chunk text." > "$GLOBAL_DIR/sources/doc_delta/delta_c1.md"

export LITERATURE_DIR="$GLOBAL_DIR"

run_search() {
  # $1 = capture filename, remaining args = passed to literature-search.sh
  local name="$1"
  shift
  local out rc
  out=$(cd "$LOCAL_REPO" && "$SEARCH_SH" "$@" 2>/dev/null)
  rc=$?
  printf '%s' "$out" > "$CAPTURE_DIR/$name.stdout"
  echo "$rc" > "$CAPTURE_DIR/$name.exit"
  printf '%s\n%s' "$rc" "$out"
}

run_search_stdin() {
  # $1 = capture filename, $2 = stdin payload, remaining args = passed to literature-search.sh
  local name="$1" stdin_payload="$2"
  shift 2
  local out rc
  out=$(cd "$LOCAL_REPO" && printf '%s' "$stdin_payload" | "$SEARCH_SH" "$@" 2>/dev/null)
  rc=$?
  printf '%s' "$out" > "$CAPTURE_DIR/$name.stdout"
  echo "$rc" > "$CAPTURE_DIR/$name.exit"
  printf '%s\n%s' "$rc" "$out"
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    t_pass "$desc"
  else
    t_fail "$desc (expected to find: $needle)"
  fi
}

assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    t_pass "$desc"
  else
    t_fail "$desc (did not expect to find: $needle)"
  fi
}

assert_exit() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    t_pass "$desc"
  else
    t_fail "$desc (expected exit $expected, got $actual)"
  fi
}

count_occurrences() {
  # $1 = haystack, $2 = needle (plain substring)
  local haystack="$1" needle="$2" count=0
  local rest="$haystack"
  while [[ "$rest" == *"$needle"* ]]; do
    count=$((count + 1))
    rest="${rest#*"$needle"}"
  done
  echo "$count"
}

# ============================================================
# Mode A: default search -- quarantine + local-over-global precedence
# ============================================================
out=$(run_search "default-search-zephyrindex" "zephyrindex")
rc="${out%%$'\n'*}"
body="${out#*$'\n'}"
assert_exit "default search: exit 0" "$rc" "0"
assert_contains "default search: finds local alpha_c1" "$body" '"chunk_id": "alpha_c1"'
assert_contains "default search: finds local alpha_c2" "$body" '"chunk_id": "alpha_c2"'
assert_not_contains "default search: quarantines unverified gamma_c1" "$body" '"chunk_id": "gamma_c1"'
assert_not_contains "default search: global alpha dup never surfaces (shadowed by local doc_id)" "$body" '"chunk_id": "alpha_c1_global"'

# ============================================================
# Mode B: --include-unverified opts gamma back in
# ============================================================
out=$(run_search "include-unverified-zephyrindex" --include-unverified "zephyrindex")
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "include-unverified: exit 0" "$rc" "0"
assert_contains "include-unverified: gamma_c1 now present" "$body" '"chunk_id": "gamma_c1"'
assert_contains "include-unverified: gamma_c1 flagged unverified_summary" "$body" '"provenance_fidelity": "unverified_summary"'

# ============================================================
# Mode C: --project filter narrows correctly when the filtered set has a match
# ============================================================
out=$(run_search "project-filter-match" --project proj-a "zephyrindex")
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "project filter match: exit 0" "$rc" "0"
assert_contains "project filter match: alpha_c1 present" "$body" '"chunk_id": "alpha_c1"'

# ============================================================
# Mode D: --project filter yields zero scoped rows -> in-process unscoped retry
# (this is the ~230-line duplicate fallback heredoc the refactor collapses)
# ============================================================
out=$(run_search "project-filter-fallback-retry" --project proj-a "wombatcluster")
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "project filter fallback: exit 0" "$rc" "0"
assert_contains "project filter fallback: retry surfaces beta_c1 despite proj-a scope" "$body" '"chunk_id": "beta_c1"'

# ============================================================
# Mode E: --multi -- corroboration across two terms
# ============================================================
out=$(run_search_stdin "multi-search" $'zephyrindex\nwombatcluster' --multi)
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "multi search: exit 0" "$rc" "0"
assert_contains "multi search: alpha_c1 present" "$body" '"chunk_id": "alpha_c1"'
assert_contains "multi search: beta_c1 present" "$body" '"chunk_id": "beta_c1"'
assert_not_contains "multi search: gamma_c1 quarantined by default" "$body" '"chunk_id": "gamma_c1"'
assert_contains "multi search: total_matched field present" "$body" '"total_matched"'
assert_contains "multi search: corroborated_count field present" "$body" '"corroborated_count"'

# ============================================================
# Mode F: --read verified chunk (no banner) vs unverified chunk (banner present)
# ============================================================
out=$(run_search "read-verified" --read alpha_c1)
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "read verified: exit 0" "$rc" "0"
assert_contains "read verified: reads on-disk content" "$body" "ON-DISK alpha_c1 full chunk text."
assert_not_contains "read verified: no unverified banner" "$body" "UNVERIFIED CONTENT"

out=$(run_search "read-unverified" --read gamma_c1)
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "read unverified: exit 0" "$rc" "0"
assert_contains "read unverified: banner present" "$body" "UNVERIFIED CONTENT - provenance_fidelity: unverified_summary"
assert_contains "read unverified: still reads on-disk content" "$body" "ON-DISK gamma_c1 full chunk text."

out=$(run_search "read-missing" --read nonexistent_chunk_id)
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "read missing chunk: exit 1" "$rc" "1"
assert_contains "read missing chunk: 404 error body" "$body" '"code": 404'

# ============================================================
# Mode G: --toc (all, and doc_id-scoped) and --doc alias identity
# ============================================================
out=$(run_search "toc-all" --toc)
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "toc all: exit 0" "$rc" "0"
toc_all_count=$(count_occurrences "$body" '"chunk_id"')
if [ "$toc_all_count" = "5" ]; then
  t_pass "toc all: 5 rows (2 alpha + 1 beta + 1 gamma + 1 delta; global alpha dup shadowed)"
else
  t_fail "toc all: expected 5 chunk rows, counted $toc_all_count"
fi

out=$(run_search "toc-doc-beta" --toc doc_beta)
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "toc doc_beta: exit 0" "$rc" "0"
assert_contains "toc doc_beta: beta_c1 present" "$body" '"chunk_id": "beta_c1"'
assert_not_contains "toc doc_beta: alpha chunks absent" "$body" '"chunk_id": "alpha_c1"'

out=$(run_search "doc-alias-beta" --doc doc_beta)
rc2="${out%%$'\n'*}"; body2="${out#*$'\n'}"
if [ "$body2" = "$body" ] && [ "$rc2" = "$rc" ]; then
  t_pass "doc alias: --doc doc_beta byte-identical to --toc doc_beta"
else
  t_fail "doc alias: --doc doc_beta diverged from --toc doc_beta"
fi

# ============================================================
# Mode H: --refs
# ============================================================
out=$(run_search "refs-alpha-c1" --refs alpha_c1)
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "refs: exit 0" "$rc" "0"
assert_contains "refs: alpha_c2 linked as child" "$body" '"relation_type": "child"'

# ============================================================
# Mode I: --next / --prev navigation
# ============================================================
out=$(run_search "next-alpha-c1" --next alpha_c1)
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "next: exit 0" "$rc" "0"
assert_contains "next: alpha_c1 -> alpha_c2" "$body" '"chunk_id": "alpha_c2"'

out=$(run_search "prev-alpha-c2" --prev alpha_c2)
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "prev: exit 0" "$rc" "0"
assert_contains "prev: alpha_c2 -> alpha_c1" "$body" '"chunk_id": "alpha_c1"'

out=$(run_search "next-missing" --next beta_c1)
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "next with no next_chunk_id: exit 1" "$rc" "1"
assert_contains "next with no next_chunk_id: 404 body" "$body" '"code": 404'

# ============================================================
# Mode J: error paths (exit codes/messages captured for the before/after diff too)
# ============================================================
out=$(run_search "err-no-args")
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "no args: exit 1" "$rc" "1"
assert_contains "no args: usage error" "$body" '"error"'

out=$(run_search "err-unknown-flag" --bogus-flag)
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "unknown flag: exit 1" "$rc" "1"
assert_contains "unknown flag: error body" "$body" "Unknown flag"

out=$(run_search "err-empty-after-sanitize" "AND")
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "query sanitizes to empty: exit 1" "$rc" "1"
assert_contains "query sanitizes to empty: error body" "$body" "empty after sanitization"

out=$(run_search "err-read-missing-arg" --read)
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "--read with no id: exit 1" "$rc" "1"

out=$(run_search_stdin "err-multi-empty-stdin" "" --multi)
rc="${out%%$'\n'*}"; body="${out#*$'\n'}"
assert_exit "--multi with empty stdin: exit 1" "$rc" "1"
assert_contains "--multi with empty stdin: error body" "$body" "Multi-query list is empty"

t_log "CAPTURE_DIR=$CAPTURE_DIR"
t_log "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
