"""literature_search_pylib.py - Shared Python helpers for literature-search.sh.

File-local to literature-search.sh: imported by that one script's own embedded python3
heredocs (do_search, do_multi_search, do_read, do_toc), never by another script in this or
any other extension. Not promoted to a cross-extension shared lib, because literature-search.sh
has peers=0 in script-inventory.sh's duplicate-block report -- there is no second consumer, so
a cross-script import surface would add coupling for no deduplication gain. The deduplication
gain this module captures is SELF-internal: literature-search.sh's own do_search()/
do_multi_search()/do_read()/do_toc() each spawned a separate python3 process via a heredoc, and
every one of those heredocs re-defined the same handful of helpers (load_fidelity_map,
get_fidelity, the fallback-ladder tier vocabulary, ensure_trigram, the chunks_fts/chunks_trigram
SQL builder) because a heredoc cannot `import` a sibling function defined in another heredoc in
the same shell script. This module exists so each heredoc instead does
`sys.path.insert(0, ...); from literature_search_pylib import ...` once, and the single
BIGGEST duplicate block -- do_search()'s ~230-line "re-run the whole search a second time
without the project filter" fallback -- collapses into an in-process retry inside
run_single_search() instead of a second, separately-interpolated python3 heredoc.

Every function below is a VERBATIM move of code that previously lived inline in
literature-search.sh (comments included where they carried load-bearing rationale) -- no
behavior change, by construction, which is what makes the before/after byte-identical output
diff in tests/test-literature-search.sh a meaningful verification of this extraction rather
than of an independent reimplementation.
"""

import json
import os
import re
import sqlite3
import sys


def load_fidelity_map(lit_dir):
    """directory-name -> provenance_fidelity. Fail-open: callers must
    default a missing map entry to an unverified value, never to verified_conversion.

    KEYED BY DIRECTORY NAME, NOT index.json's id/parent_doc fields -- those are a
    separate namespace from chunks_data.doc_id (e.g. index.json's top-level id for
    the blackburn_2002 directory is "blackburn_2002_book", but every chunks.json /
    chunks_data row for that same directory carries doc_id="blackburn_2002", the bare
    directory name). literature-fidelity-audit.sh stamps provenance_fidelity onto
    index.json entries (root or, for phantom-parent docs, child entries -- see that
    script's header), but every stamped entry's path field still starts with
    "sources/<dir>/" regardless of which id/parent_doc scheme it uses. Deriving the
    key from that path prefix (the same directory-name key chunks_data.doc_id
    actually uses) is what makes this lookup correct for both naming schemes at once,
    including the phantom-parent-fallback and multi-root cases."""
    index_file = os.path.join(lit_dir, "index.json")
    fmap = {}
    if not os.path.isfile(index_file):
        return fmap
    try:
        with open(index_file, encoding="utf-8") as f:
            idx = json.load(f)
    except Exception:
        return fmap
    prefix = "sources/"
    for e in idx.get("entries", []) or []:
        pf = e.get("provenance_fidelity")
        if pf is None:
            continue
        path = e.get("path")
        if not isinstance(path, str) or not path.startswith(prefix):
            continue
        dirname = path[len(prefix):].split("/", 1)[0]
        if dirname:
            fmap.setdefault(dirname, pf)
    return fmap


def get_fidelity(fmap, doc_id):
    # Fail-open: absent field or absent entry -> unverified_summary, never
    # verified_conversion.
    return fmap.get(doc_id) or "unverified_summary"


# --- Fallback ladder tiers ---
# Internal tier names match the envelope's "fallback_tier" vocabulary exactly
# ("bm25" | "phrase_retry" | "trigram" | "none"); row-level "match_tier" uses
# "trigram_fallback" instead of "trigram" -- ROW_TIER_LABEL maps between them.
TIER_RANK = {'bm25': 0, 'phrase_retry': 1, 'trigram': 2, 'none': 3}
ROW_TIER_LABEL = {'bm25': 'bm25', 'phrase_retry': 'phrase_retry', 'trigram': 'trigram_fallback'}


def ensure_trigram(conn):
    """Idempotently ensure chunks_trigram exists and is populated. This is the
    ONLY place chunks_trigram is populated -- literature-build-index.sh rebuilds chunks_fts
    only, so the trigram table starts (or goes back to) empty after any full reindex until a
    search next needs this rung. Returns True if the table is usable for a query, False if
    creation/rebuild failed (e.g. a read-only DB) -- callers must skip the trigram rung and
    report fallback_tier "none" with query_error populated, rather than raise."""
    try:
        conn.execute(
            "CREATE VIRTUAL TABLE IF NOT EXISTS chunks_trigram USING fts5("
            "content, content='chunks_data', content_rowid='id', tokenize='trigram')"
        )
        # count(*) on an external-content FTS5 table is satisfied directly from the content
        # table's rowid range and is NOT a reliable "is the index populated" check -- it
        # reports the full chunks_data row count immediately after CREATE, before 'rebuild'
        # has ever run (verified empirically against the real corpus DB: a freshly (re)created
        # table reports the full row count via count(*) while an actual MATCH query still
        # returns zero rows until 'rebuild' runs). Probe with a real MATCH against a
        # known-present substring from chunks_data instead of trusting count(*).
        sample = conn.execute(
            "SELECT id, content FROM chunks_data WHERE content IS NOT NULL"
            " AND length(content) >= 8 LIMIT 1"
        ).fetchone()
        if sample is not None:
            sample_id, sample_content = sample
            m = re.search(r'[A-Za-z]{6,}', sample_content or '')
            if m:
                probe_term = '"' + m.group(0)[:6] + '"'
                hit = conn.execute(
                    "SELECT count(*) FROM chunks_trigram WHERE chunks_trigram MATCH ? AND rowid = ?",
                    (probe_term, sample_id),
                ).fetchone()[0]
                if hit == 0:
                    conn.execute("INSERT INTO chunks_trigram(chunks_trigram) VALUES('rebuild')")
                    # Without an explicit commit, this write lives only in the connection's
                    # implicit transaction and is silently rolled back the moment conn.close()
                    # runs below (do_search()'s connections were read-only historically, so
                    # this was never an issue until ensure_trigram() added the first write path)
                    # -- verified empirically: the rebuild was visible within the same
                    # connection but vanished from the on-disk shadow tables after close()
                    # without this commit.
                    conn.commit()
        return True
    except sqlite3.OperationalError:
        return False


def build_sql(table, rank_expr, allowed_doc_ids):
    """Shared SQL builder for both the single-query (do_search) and multi-query
    (do_multi_search) ladders. allowed_doc_ids, when truthy, adds the project-filter
    IN-clause; the parameter list for this SQL is [query_or_phrase, *allowed_doc_ids, limit]."""
    if allowed_doc_ids:
        placeholders = ','.join('?' * len(allowed_doc_ids))
        sql = f"""
            SELECT d.chunk_id, d.doc_id, d.section_path, d.title, d.summary,
                   d.token_count, d.cross_refs, d.source_path,
                   d.prev_chunk_id, d.next_chunk_id,
                   {rank_expr} AS rank,
                   substr(d.content, 1, 200) AS snippet
            FROM {table}
            JOIN chunks_data d ON d.id = {table}.rowid
            WHERE {table} MATCH ?
            AND d.doc_id IN ({placeholders})
            ORDER BY rank
            LIMIT ?
        """
    else:
        sql = f"""
            SELECT d.chunk_id, d.doc_id, d.section_path, d.title, d.summary,
                   d.token_count, d.cross_refs, d.source_path,
                   d.prev_chunk_id, d.next_chunk_id,
                   {rank_expr} AS rank,
                   substr(d.content, 1, 200) AS snippet
            FROM {table}
            JOIN chunks_data d ON d.id = {table}.rowid
            WHERE {table} MATCH ?
            ORDER BY rank
            LIMIT ?
        """
    return sql


def run_ladder(conn, query, limit, allowed_doc_ids, db_path):
    """Run the 3-rung fallback ladder (bm25 -> phrase_retry on syntax error ->
    trigram on zero rows) for ONE query against an already-open connection. Shared by
    do_search's single-query path and do_multi_search's per-term loop (which calls this
    once per filtered term without paying a new DB-open cost per term).
    Returns (rows, tier, query_error)."""
    query_error = None
    rows = []
    tier = 'none'
    params_tail = list(allowed_doc_ids) + [limit] if allowed_doc_ids else [limit]

    # Rung 0: primary BM25 MATCH on the sanitized query
    try:
        sql = build_sql("chunks_fts", "bm25(chunks_fts, 10, 5, 3, 1)", allowed_doc_ids)
        rows = conn.execute(sql, [query] + params_tail).fetchall()
        if rows:
            tier = 'bm25'
    except sqlite3.OperationalError as e:
        query_error = str(e)
        print(f"[search] Query error ({query!r}): {e}", file=sys.stderr)
        rows = []

    # Rung 1: phrase-quote retry -- only when Rung 0 raised a syntax error
    if query_error is not None:
        phrase_query = '"' + query.replace('"', '') + '"'
        try:
            sql = build_sql("chunks_fts", "bm25(chunks_fts, 10, 5, 3, 1)", allowed_doc_ids)
            rows = conn.execute(sql, [phrase_query] + params_tail).fetchall()
            if rows:
                tier = 'phrase_retry'
        except sqlite3.OperationalError as e:
            print(f"[search] Phrase-retry query error ({query!r}): {e}", file=sys.stderr)
            rows = []

    # Rung 2: trigram fallback -- on zero rows from whichever of Rungs 0/1 ran
    # (syntactically valid-but-empty is the common case; this is also the
    # best-effort path if Rung 1's phrase-retry itself failed to parse).
    if not rows:
        if ensure_trigram(conn):
            trigram_query = '"' + query.replace('"', '') + '"'
            try:
                sql = build_sql("chunks_trigram", "bm25(chunks_trigram)", allowed_doc_ids)
                rows = conn.execute(sql, [trigram_query] + params_tail).fetchall()
                if rows:
                    tier = 'trigram'
            except sqlite3.OperationalError as e:
                print(f"[search] Trigram query error ({query!r}): {e}", file=sys.stderr)
                rows = []
        elif query_error is None:
            # Trigram creation/rebuild failed (e.g. read-only DB) and there was no
            # earlier syntax error to report -- surface the degradation reason so the
            # envelope's query_error is never silently null on a real failure.
            query_error = f"trigram fallback unavailable for {db_path} (create/rebuild failed, e.g. read-only database)"

    return rows, tier, query_error


def search_db(db_path, query, limit, allowed_doc_ids, fidelity_map, quarantined_fidelity):
    """Single-query search of one database (do_search's per-database worker).
    Returns {'results': [...], 'tier': tier, 'query_error': str|None} where tier is the
    internal name (see TIER_RANK) of whichever rung actually produced the returned results
    ('none' if no rung produced any rows). Does not apply the quarantine filter itself --
    quarantined_fidelity is accepted only so get_fidelity's lookup stays local to this call;
    callers (run_single_search) apply the quarantine after the local/global merge, matching
    the original do_search behavior exactly."""
    if not os.path.isfile(db_path):
        return {'results': [], 'tier': 'none', 'query_error': None}

    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row

        rows, tier, query_error = run_ladder(conn, query, limit, allowed_doc_ids, db_path)

        results = []
        for row in rows:
            cross_refs = row['cross_refs'] or '[]'
            try:
                cross_refs = json.loads(cross_refs)
            except (json.JSONDecodeError, TypeError):
                cross_refs = []

            results.append({
                'chunk_id': row['chunk_id'],
                'doc_id': row['doc_id'],
                'section_path': row['section_path'],
                'title': row['title'],
                'summary': row['summary'],
                'token_count': row['token_count'],
                'cross_refs': cross_refs,
                'rank': row['rank'],
                'snippet': (row['snippet'] or '').strip()[:200],
                'provenance_fidelity': get_fidelity(fidelity_map, row['doc_id']),
                'match_tier': ROW_TIER_LABEL.get(tier, 'bm25'),
                '_source_path': row['source_path'],
                '_db_path': db_path,
            })

        conn.close()
        return {'results': results, 'tier': tier if results else 'none', 'query_error': query_error}
    except Exception as e:
        print(f"[search] Database error ({db_path}): {e}", file=sys.stderr)
        return {'results': [], 'tier': 'none', 'query_error': str(e)}


def run_single_search(local_db, global_db, query, limit, allowed_doc_ids, literature_dir,
                       include_unverified, quarantined_fidelity):
    """Full do_search() pipeline for one scope (allowed_doc_ids, which may be empty): search
    local then global, merge with local-over-global doc_id precedence, apply the quarantine
    filter, re-sort by rank, and build the envelope. literature-search.sh's do_search() calls
    this TWICE in-process when a project-scoped search returns zero rows (once scoped, once
    with allowed_doc_ids=[] as the unscoped retry) instead of re-running a second, separately
    interpolated python3 heredoc -- the single biggest duplicate block this module replaces."""
    fidelity_map = load_fidelity_map(literature_dir)

    local_out = search_db(local_db, query, limit, allowed_doc_ids or None, fidelity_map, quarantined_fidelity)
    global_out = search_db(global_db, query, limit, allowed_doc_ids or None, fidelity_map, quarantined_fidelity)
    local_results = local_out['results']
    global_results = global_out['results']

    # Merge: local takes precedence on duplicate doc_id
    local_doc_ids = {r['doc_id'] for r in local_results}
    merged = local_results + [r for r in global_results if r['doc_id'] not in local_doc_ids]

    # Quarantine: exclude unverified/no-baseline docs from default ranking.
    # Not a deletion -- always retrievable via --include-unverified, or directly via
    # --read/--toc/--doc regardless of this flag.
    if not include_unverified:
        merged = [r for r in merged if r['provenance_fidelity'] not in quarantined_fidelity]

    # Re-sort by rank (BM25 returns negative values; lower is better)
    merged.sort(key=lambda r: r['rank'])
    merged = merged[:limit]

    # --- Envelope construction ---
    # fallback_tier/degraded reflect the rows actually surviving quarantine (a tier whose rows
    # were all quarantined does not count as having "answered"). "degraded" is true whenever the
    # primary bm25 tier is not what answered -- this is the honest, never-silent signal that
    # distinguishes "retrieval degraded" from "genuine zero-result", which literature-briefing.sh
    # consumes downstream.
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
    query_error = next((o['query_error'] for o in (local_out, global_out) if o['query_error']), None)

    # Remove internal fields from output
    for r in merged:
        r.pop('_source_path', None)
        r.pop('_db_path', None)

    return {
        'results': merged,
        'degraded': degraded,
        'fallback_tier': fallback_tier,
        'query_error': query_error,
    }
