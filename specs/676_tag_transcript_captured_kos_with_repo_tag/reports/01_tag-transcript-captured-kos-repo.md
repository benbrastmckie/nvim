# Research Report: Task #676

**Task**: 676 - Tag transcript-captured KOs with the repo tag
**Started**: 2026-11-20T00:00:00Z
**Completed**: 2026-11-20T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/sapience/` (source store), `.claude/context/project/sapience/domain/per-repo-scoping.md`, `.claude/rules/sapience-write-path.md`
- Vendor client (read-only inspection, not edited): `~/.sapience/extract_local.py`, `~/.sapience/upload.py`, `~/.sapience/sapience_capture.py`, `~/.sapience/config.json`, `~/.sapience/pending_kos.jsonl`
**Artifacts**:
- This report: `specs/676_tag_transcript_captured_kos_with_repo_tag/reports/01_tag-transcript-captured-kos-repo.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The transcript-capture pipeline that actually runs on this machine today is
  `extract_local.py` (backend `anthropic` per `~/.sapience/config.json`), **not**
  `upload.py`'s own streaming path. `upload.py` is imported only as a session-reader library
  (`import upload as up`) by `extract_local.py`; its own `_chunk()`/`post_kos()` duplicates are
  dead code for this capture flow. The existing `per-repo-scoping.md` passage describing
  `upload.py`'s `_chunk()` sending `project` and the server dropping it refers to that
  unused path, not to the one that staged the 1260 pending KOs this task is about.
- **A client-supplied `provenance` field survives verbatim to the stored KO; the server only
  synthesizes one when the field is absent.** This is established by the vendor client's own
  code, not inferred: `tag_cowork_ko()`/`tag_devin_ko()`/`tag_memory_ko()` set
  `k['provenance']` directly before staging, and a code comment at the point ordinary
  session-capture KOs are built states "the tool that recorded the session; `/ingest-kos`
  names it in the provenance" for KOs that reach the server **without** one. An ordinary
  Claude-Code session-capture KO (the 1260-record population in `pending_kos.jsonl`) carries no
  `provenance` field at staging time at all — confirmed from the live file's schema
  (`subject, predicate, object_value, ko_type, confidence, reasoning, open_thread, sid, tool,
  at, project, _hash, _staged_at`).
- **Recommended injection point: a new, extension-owned script that rewrites
  `~/.sapience/pending_kos.jsonl` in place, setting a `provenance` field (carrying the literal
  `[repo:<slug>]` tag) on every still-pending record, run after `sapience sync` stages records
  and before `sapience review`/`sapience review --all` posts them.** `pending_kos.jsonl` is a
  `LEDGER_FILE`, explicitly preserved (not overwritten) by `sapience update`/auto-update — only
  the vendor *scripts* (`extract_local.py`, `upload.py`, …) are client files subject to
  overwrite. A script that only ever touches the ledger file, never a vendor script, is durable
  across every future auto-update, which satisfies this task's "owned by the sapience
  extension" framing without depending on vendor cooperation.
- `sapience review`'s posting path (`review_queue()` → `post_kos()`) sends `_strip_meta(r)` —
  every non-underscore field of the staged record, verbatim — with **no** re-redaction and no
  re-derivation of `provenance` at post time. A `provenance` value written into the ledger file
  between sync and review therefore reaches `POST /ingest-kos` unchanged.
- Already-uploaded, untagged KOs (the ones a `[repo:nvim]`-filtered search misses today) **cannot
  be backfilled**: no delete API exists (already established) and this research additionally
  confirms **no update/PATCH API for an existing KO exists either** anywhere in the vendor
  client's own HTTP call sites (`extract_local.py`, `upload.py`). The only forward path is
  tagging records that are still in `pending_kos.jsonl`, before their next `sapience review`.
- Slug resolution mirrors `sapience-remember.sh` exactly, with one necessary detour: a pending
  KO record carries `project` (e.g. `"nvim"`), which is `capture.projects[].name` — not
  necessarily the basename of a path, since a user can rename it. The correct lookup is
  `capture.projects[] | select(.name == <KO's project>) | .path_prefix`, then resolve that
  path's git toplevel with the same worktree-aware `resolve_checkout_toplevel()` logic
  `sapience-remember.sh`/`sapience-retrieve.sh` already carry, then `basename()` that toplevel.
  On this machine `path_prefix=/home/benjamin/.config/nvim` and `basename == "nvim"` coincide,
  but the lookup must go through `path_prefix`, never assume `project == slug` for a renamed
  entry or a future repo.
- Editing `provenance` while leaving `project` untouched is safe against two mechanisms this
  research specifically checked: (1) the dedupe hash `_ko_hash()` is computed only from
  `subject`/`predicate`/`object_value`, so changing `provenance` does not disturb a future
  `sapience sync`'s duplicate-detection against already-queued records; (2) `sapience review`'s
  interactive "by source/project" grouping (`_group_summary()`) reads `project` first and falls
  back to `provenance` only when `project` is empty, so the grouping view a human sees at review
  time is unaffected by the added tag.

## Context & Scope

This task researches where a literal `[repo:<slug>]` substring can be injected into the
`provenance` of a Sapience knowledge object (KO) that originates from **transcript capture**
(the background `extract_local.py` extraction that stages findings into
`~/.sapience/pending_kos.jsonl` for later human review and upload), so that this extension's own
`source=[repo:<slug>]`-filtered retrieval (`scripts/sapience-retrieve.sh`) can find them. This is
distinct from, and does not change, the already-shipped tagged-write path for **explicit**
agent-authored notes (`scripts/sapience-remember.sh`'s direct `POST /ingest-kos`, documented in
`context/project/sapience/domain/per-repo-scoping.md`).

Explicitly in scope, per the dispatch:
- Where the tag can be injected, given the capture/extract/upload path is vendor-owned under
  `~/.sapience/` and overwritten by auto-update.
- Keeping the slug resolution identical to `sapience-remember.sh`'s.
- Whether already-uploaded, untagged KOs can be backfilled.

Out of scope: implementing the fix (this is a research dispatch); changing anything under
`~/.sapience/` or `~/.dotfiles/` directly (edit target is this repository's sapience extension
source store, `agent-system/extensions/sapience/`, per `.claude/rules/source-store-deploy-
boundary.md`).

## Findings

### Codebase Patterns

**The two existing Sapience write/read scripts, and why they do not already cover this
population.**

- `scripts/sapience-remember.sh` (`agent-system/extensions/sapience/scripts/sapience-remember.sh`)
  posts a single, explicitly-authored KO per call directly to `POST /ingest-kos`, with a
  client-built `provenance = "[repo:<slug>] via sapience-remember.sh (Claude Code dispatch)"`
  string. This is the ONLY current source of tagged KOs on the vault. It is called
  exclusively from the task-boundary postflight wrapup (`scripts/postflight-sapience-notes.sh`),
  never from a transcript-capture path, and is bounded to 3-8 notes per completed task — by
  design, it was never meant to (and cannot) cover the much larger, continuously-running
  transcript-capture population.
- `scripts/sapience-retrieve.sh` is read-only; it has no bearing on what gets tagged.

**The transcript-capture pipeline that is actually live on this machine.**

`~/.sapience/config.json` sets `"backend": "anthropic"`, which selects `extract_local.py`'s own
extraction+staging+review pipeline (`sapience sync` / `sapience review` / `sapience pending` /
`sapience backfill`, each `exec`ing `extract_local.py --<verb>` — already established in
`per-repo-scoping.md`'s "Capture Scheduling" section). `extract_local.py` imports `upload.py`
only as a session-reader library (`import upload as up`, used for `up.parse_claude`,
`up.delta_chunks`, `up.capture_meta`, `up.session_id_of`, etc.) — `upload.py`'s own top-level
`_chunk()`/`post_kos()`/`main()` functions are a separate, independent "default uploader"
pipeline (its own module docstring: "unlike the default uploader (upload.py), which streams
transcript chunks to the hosted extractor") that is not invoked by this machine's configuration.

This matters because the EXISTING `per-repo-scoping.md` passage —

> "Untagged and vendor-owned. Transcript extraction via `~/.sapience/upload.py`. Its `_chunk()`
> sends `'project': m['project']` per chunk, so the repo identity does reach the server, but the
> server-authored provenance drops it before the KO is stored… cannot be fixed from this
> repository."

— describes `upload.py`'s dead-for-this-machine code path, not the live `extract_local.py`
pipeline that actually staged the 1260 pending nvim-tagged (by `project`, not by `provenance`)
records this task is about. The "cannot be fixed from this repository" conclusion in that
passage is accurate for the `upload.py` path it describes, but this research finds a materially
different, and fixable, situation in the path that is actually live.

**How an ordinary session-capture KO is built (the fixable path), traced in
`extract_local.py`:**

Around the main extraction loop (`extract_local.py`, session-chunk branch, ~line 2255-2280):

```python
for k in kos:
    redacted += redact_ko(k)
    k['sid'] = sid
    if tool: k['tool'] = tool      # v177.10: named in the provenance by /ingest-kos
    if tool and _day_of:
        day = _day_of(f, end)
        if day: k['at'] = day
    if proj: k['project'] = proj   # workstream tag (drives sync-channel scoping)
    if is_mem: up.tag_memory_ko(k, prov)
    elif is_cw: tag_cowork_ko(k)
    elif is_dv: tag_devin_ko(k)
```

For an ordinary Claude Code session (not memory, not Cowork, not Devin — the common case, and
the one behind the 1260-record nvim population), **no `provenance` field is set at all** on the
client side. `tag_cowork_ko`/`tag_devin_ko` are the only two functions in this file that set
`k['provenance']` directly (`k['provenance'] = COWORK_PROV` / `DEVIN_PROV`), and they do so
*before* staging, proving the field is both settable client-side and (by the server's own
documented behavior at the capture point) honored once set. The inline comment "the tool that
recorded the session; `/ingest-kos` names it in the provenance" at the `k['tool'] = tool` line
confirms the server builds the provenance string itself *only when the KO arrives without one*
— `tool`/`sid`/`at` are what the server's auto-generated provenance is built from in that case.

**Where the fields land in `pending_kos.jsonl`, and how they reach `POST /ingest-kos`
unmodified.**

`_queue_add()` writes each staged KO's dict plus `_hash` and `_staged_at` to
`~/.sapience/pending_kos.jsonl` (one JSON object per line). Live inspection of this file
confirms the schema for the nvim-project population: `{subject, predicate, object_value,
ko_type, confidence, reasoning, open_thread, sid, tool, at, project, _hash, _staged_at}` — no
`provenance` key present on any sampled record.

`sapience review`'s posting path (`review_queue()`, both the interactive and `--all`
non-interactive branches) does:

```python
stripped = [_strip_meta(r) for r in recs]        # strips only underscore-prefixed fields
written = post_kos(stripped, source='local:review')
```

`_strip_meta` only removes keys starting with `_` (i.e. `_hash`, `_staged_at`); it performs **no
re-redaction** and **no field re-derivation**. `post_kos()` then POSTs the list of dicts
verbatim (plus a top-level `token`/`source`/`batch_id`/`backend`) to `/ingest-kos`. There is no
code path between `_queue_load()` and `post_kos()` that touches `provenance`. A `provenance`
value present on the staged record at review time is therefore exactly what reaches the server.

**Dedupe safety of editing `provenance` post-staging.**

```python
def _ko_hash(k):
    """Content hash for dedupe: subject + predicate + object_value (post-redaction)."""
    s = '\x1f'.join((k.get('subject') or '', k.get('predicate') or '', k.get('object_value') or ''))
    return hashlib.sha256(s.encode('utf-8', 'ignore')).hexdigest()[:16]
```

`_queue_add()` (invoked by the next `sapience sync`) computes this hash fresh from each newly
extracted KO and compares it against the *existing* `_hash` values already in the queue. Since
the hash never incorporates `provenance`, rewriting `provenance` on an already-queued record
(without touching `_hash`) leaves future dedupe comparisons exactly as they would have been —
no record is silently duplicated or silently dropped by the edit.

**Display safety of editing `provenance` post-staging.**

```python
def _group_summary(recs):
    """Staged recs grouped by project (fallback provenance/source) ..."""
    label = (str(r.get('project') or '').strip()
             or str(r.get('provenance') or '').strip()
             or str(r.get('source') or '').strip()
             or 'ungrouped')
```

The interactive `sapience review` summary groups by `project` first, falling back to
`provenance` only when `project` is empty. Since the tagging edit leaves `project` untouched,
the human-facing review grouping is unaffected.

**Slug resolution — matching `sapience-remember.sh`, with the needed detour through
`capture.projects`.**

A pending KO's `project` field is the matching `capture.projects[].name` entry, **not**
necessarily `basename(path_prefix)` — `sapience_capture.py`'s `project_entry()` defaults `name`
to `basename(path_prefix)` but accepts an explicit override, and `match_project()`/`for_cwd()`
resolve by longest-matching `path_prefix`, independent of `name`. The correct slug-resolution
procedure for a pending record therefore is:

1. Look up the record's `project` value against `~/.sapience/config.json`'s
   `.capture.projects[]` array by `.name == project`, to get that entry's `path_prefix`.
2. Resolve `path_prefix` to its git toplevel using the *same* `resolve_checkout_toplevel()`
   function `sapience-remember.sh`/`sapience-retrieve.sh` already carry verbatim (the
   worktree-aware helper that follows a linked worktree to its parent checkout, delimited by the
   `sapience-worktree-checkout-resolution` marker comment both scripts share).
3. `repo_slug = basename(<toplevel>)`.

On this machine, `path_prefix=/home/benjamin/.config/nvim`, whose toplevel's basename is
`"nvim"` — identical to the `name` field, so the simpler `project`-as-slug shortcut happens to
agree here, but a correct implementation must not assume that coincidence holds for a renamed
`capture.projects` entry or a future repository, and must honor the worktree detour exactly as
the two existing scripts do (otherwise a worktree-originated capture would stage a
throwaway-worktree-named tag no checkout-rooted query could ever retrieve — the exact hazard
`sapience-remember.sh`'s own header comment calls out for the write side).

A pending record whose `project` has no matching, resolvable `capture.projects[].path_prefix`
entry (e.g. its `name` was since removed from the config, or the directory no longer resolves to
a git repo) should be left untagged by the rewrite rather than aborting the whole pass — this
mirrors `sapience-remember.sh`'s own single-record failure mode, scaled to a batch.

**No backfill API exists for already-uploaded KOs.**

`per-repo-scoping.md` already establishes `DELETE /v1/ko/<hash>`, `DELETE /v1/kos/<hash>`, and
`POST /v1/ko/<hash>/delete` all 404. This research additionally confirms, by exhaustive grep of
every HTTP call site in `extract_local.py` and `upload.py` (`urllib.request.urlopen(...)` call
sites: `/ingest-kos`, `/extract-relay`, `/extract-prompt`, `/ingest-status`, `/company/join`,
`/company/leave`, `/company/me`, `KO_LOCAL_URL + '/v1/ko/subjects'` — the last one a *local*
read-only lookup server, not the hosted vault), that **no update/PATCH endpoint for an existing
KO exists anywhere in the vendor client either.** The vault's only two operations on a KO are
create (`/ingest-kos`) and read (`/v1/search`, `/v1/ko/subjects`); there is no mutate-in-place
surface. The ~39-vs-4 gap cited in the task description (an untagged nvim-topic search returning
39 session-capture KOs against 4 tagged) is therefore **permanent** for every KO that has already
left `pending_kos.jsonl` via a prior `sapience review`. The only remedy named anywhere in this
vendor surface is manual removal in the web app at app.spnc.ai (already noted in
`per-repo-scoping.md`'s Hazards section), which deletes rather than retags, and is outside this
repository's write surface regardless.

**The launcher boundary — why the fix must be a standalone script, not a wrapped command.**

`EXTENSION.md` notes "`review/sync/coverage/pending/stats` stay the GNOME launchers" — these
`sapience <verb>` invocations happen from desktop launcher icons entirely outside any Claude Code
session, and the `sapience` binary itself resolves to a Nix-profile-managed path
(`/home/benjamin/.nix-profile/bin/sapience`), built from `~/.dotfiles`, which is out of this
repository's write surface per `.claude/rules/source-store-deploy-boundary.md`'s task-siting
rule. A "wrapper at review/upload time" that intercepts the `sapience review` command itself
would therefore have to be built in `~/.dotfiles`, not here. What *can* be built here, entirely
within `agent-system/extensions/sapience`, is a standalone idempotent script that mutates only
`~/.sapience/pending_kos.jsonl` (a ledger file, not a vendor script, and therefore not subject to
being overwritten by `sapience update`) — run any time between a `sapience sync` staging pass and
the next `sapience review`/`review --all` posting pass. `/sapience`'s own skill
(`skills/skill-sapience/SKILL.md`) is a natural place to invoke this script as a courtesy
pre-step, since it already reads/writes local state before presenting its draft-update approval
picker; this is a design choice left to the implementation phase, not settled here.

### External Resources

None consulted — this question is answered entirely by the vendor client's own shipped source
(`~/.sapience/*.py`) and this repository's existing sapience-extension scripts/docs; no external
API documentation exists for `app.spnc.ai` beyond what the client code itself encodes.

## Recommendations

1. Add a new script to the sapience extension source store, e.g.
   `agent-system/extensions/sapience/scripts/sapience-tag-pending.sh` (name illustrative; the
   implementation phase should pick the final name/placement and register it in
   `manifest.json`'s `provides.scripts`), that:
   - Reads `~/.sapience/pending_kos.jsonl` and `~/.sapience/config.json`'s
     `.capture.projects[]`.
   - For each pending record with a non-empty `project` whose `name` resolves to a
     `path_prefix` under `.capture.projects[]`, resolves that path's git toplevel via the
     `resolve_checkout_toplevel()` block already shared verbatim by `sapience-remember.sh` and
     `sapience-retrieve.sh`, and sets/overwrites that record's `provenance` field to a string
     carrying the literal `[repo:<slug>]` tag (mirroring `sapience-remember.sh`'s own shape,
     e.g. `"[repo:<slug>] session capture via sapience-tag-pending.sh"`).
   - Leaves every other field untouched — in particular `_hash` (dedupe-load-bearing) and
     `project` (review-display-load-bearing) — and leaves a record with no resolvable
     `capture.projects` match untagged rather than failing the whole pass.
   - Writes the file back atomically (tmp + `os.replace`-equivalent, matching
     `extract_local.py`'s own `_write_atomic()` convention) and ideally takes the same
     `fcntl`-based ledger lock `extract_local.py`'s `_ledger_lock` class uses, since a
     concurrent `sapience sync`/`review` run touches the same file.
   - Is idempotent: re-running it on an already-tagged record is a safe no-op (skip a record
     whose `provenance` already contains a `[repo:` substring, or always recompute/overwrite —
     either is safe given the dedupe/display analysis above; the implementation phase should
     pick one explicitly rather than leaving it implicit).
2. Document, at the implementation phase, the operational sequencing this script requires
   (`sapience sync` → `sapience-tag-pending.sh` → `sapience review`/`review --all`) — most
   naturally as a short addition to `per-repo-scoping.md`'s population census (the "Untagged and
   vendor-owned" population becomes "now closable going forward for any repo path this script
   can resolve, via a pre-review tagging pass" rather than "cannot be fixed from this
   repository").
3. Do not pursue a wrapper around the `sapience` command itself (option "a wrapper at review/
   upload time" read as intercepting the launcher) — that command's launcher and binary are
   `~/.dotfiles`/Nix-profile-owned, outside this repository's write surface. The standalone-script
   recommendation above already achieves the same practical effect (the tag lands before the
   next review/post) without needing to touch anything outside
   `agent-system/extensions/sapience`.
4. Do not pursue a vendor ask as the primary remedy. It is not ruled out as a secondary,
   independent avenue (the server-side "stamp only when absent" behavior this report relies on
   is observed from the client's own code and comments, not from vendor API documentation, so an
   explicit confirmation from the vendor would still be useful corroboration before this is
   built) — but a workable, fully self-owned fix exists without waiting on it, which is the
   stronger property for a repository that cannot edit `~/.sapience/` at all.
5. Treat the already-uploaded, untagged population as permanently untagged. Do not design any
   backfill mechanism for it — none of the vendor's HTTP surfaces support mutating a landed KO,
   and the only non-API remedy (manual edit in the web app) is both manual and outside this
   repository's write surface regardless of a design choice made here.

## Decisions

- **Injection point selected for a future implementation phase**: a standalone,
  extension-owned script rewriting `~/.sapience/pending_kos.jsonl`'s `provenance` field between
  `sapience sync` and `sapience review`, not a vendor-file patch and not a wrapper around the
  `sapience` launcher command.
- **Slug resolution rule carried forward unchanged from `sapience-remember.sh`**: basename of the
  parent checkout's git toplevel, resolved via the shared `resolve_checkout_toplevel()` block —
  but reached, for a pending-queue record, via `capture.projects[].name == project →
  path_prefix`, not via any cwd this script itself runs from (the script runs once over the
  whole queue, covering every project in the capture map in one pass, not scoped to a single
  repo's own session).
- **Backfill of already-uploaded untagged KOs is out of scope for implementation** — confirmed
  impossible given the vendor API surface (create + read only; no update, no delete).

## Risks & Mitigations

- **Risk**: a future vendor client update adds a `provenance` field to ordinary session-capture
  KOs at staging time (not just Cowork/Devin/memory), which would make an unconditional
  "set/overwrite provenance" pass silently discard a vendor-authored provenance string in favor
  of this extension's own.
  **Mitigation**: the tagging script should compose its tag onto an *existing* `provenance`
  value when present (e.g. append `" [repo:<slug>]"` rather than clobber), rather than assuming
  the field is always absent — this costs nothing for the current (absent) case and is safe
  against the field appearing later.
- **Risk**: running the tagging pass concurrently with a live `sapience sync`/`review` risks the
  same lost-write race `extract_local.py`'s own `_ledger_lock` class was built to prevent (Ari
  Sklar's 2026-09-19 fix, cited in that file).
  **Mitigation**: the new script should take the same `fcntl` exclusive lock on
  `~/.sapience/.ledger.lock` before its own load-mutate-rewrite cycle, matching the existing
  convention exactly.
- **Risk**: a `capture.projects[]` entry's `path_prefix` no longer resolves to a git repository
  (directory moved/deleted, or never was a git repo — several disabled personal entries in this
  machine's config, e.g. `Wedding`, `Applications`, are plain directories).
  **Mitigation**: treat `resolve_checkout_toplevel()` failure as "leave this record untagged,
  continue the pass" rather than a fatal error, mirroring `sapience-remember.sh`'s own
  single-record failure mode scaled to a batch.
- **Risk**: this report's central finding (server preserves a client-supplied `provenance`
  verbatim, synthesizes one only when absent) is derived from the vendor client's own code
  comments and from the demonstrated Cowork/Devin/memory tagging pattern, not from a live,
  task-scoped empirical POST-and-read-back test against the hosted vault (no such test was run
  during this research dispatch, to avoid an unreviewed, permanent write outside the sanctioned
  postflight-wrapup call site).
  **Mitigation**: the implementation phase's own verification step should include exactly this
  empirical check — tag one real pending record, run `sapience review` (or a scoped equivalent),
  and confirm via `sapience-retrieve.sh`/`/v1/search?source=[repo:<slug>]` that the tagged KO is
  now retrievable — before declaring the mechanism trustworthy at scale.

## Context Extension Recommendations

- **Topic**: `per-repo-scoping.md`'s four-population census (Hazards section).
- **Gap**: Population 3 ("Untagged and vendor-owned... cannot be fixed from this repository") is
  written against `upload.py`'s dead-for-this-machine `_chunk()` path, and does not reflect that
  the actually-live `extract_local.py` pipeline exposes a fixable, pre-review injection point for
  the `provenance` field.
- **Recommendation**: once an implementation lands the tagging script this report recommends,
  revise Population 3's text to describe the corrected mechanism and the new script, rather than
  leaving the "cannot be fixed" conclusion standing against a path this research shows is not the
  live one.

## Appendix

- Search/exploration performed: `Read`/`Bash` inspection of
  `agent-system/extensions/sapience/scripts/{sapience-remember.sh,sapience-retrieve.sh,lib/
  sapience-api-lib.sh}`, `.../context/project/sapience/domain/{per-repo-scoping.md,
  review-gate-boundary.md}`, `.claude/rules/sapience-write-path.md`,
  `agent-system/extensions/sapience/manifest.json`, `agent-system/extensions/sapience/EXTENSION.md`;
  live inspection (read-only) of `~/.sapience/{config.json,pending_kos.jsonl,extract_local.py,
  upload.py,sapience_capture.py}` via `grep`/`sed`/`python3 -c` — no vendor file was modified.
- Key grep anchors used: `_ko_hash`, `_queue_add`, `_queue_load`, `_strip_meta`, `review_queue`,
  `post_kos`, `tag_cowork_ko`, `tag_devin_ko`, `tag_memory_ko`, `capture_meta`, `project_entry`,
  `match_project`, `resolve_checkout_toplevel`.
- No web research was performed; the question is answered entirely from the vendor client's own
  shipped source and this repository's existing sapience-extension artifacts.
