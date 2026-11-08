# Shared Stage 4a Literature Flow (`--lit`)

**Placed in core context** (not the literature extension) so the `@`-import below resolves for
`skill-orchestrate` and every domain research/implementation skill regardless of whether the
literature extension is in the selected extension set. If the literature scripts referenced here
(`literature-lit-flag-resolve.sh`, `literature-briefing-invoke.sh`, `literature-discover.sh`,
`literature-ingest-online.sh`, `literature-create-setup-task.sh`) are not deployed, the resolver
call below will fail with a "command not found" error — treat that failure the same as
`GLOBAL_MISSING` (emit a visible notice, continue with `lit_context=""`) rather than aborting the
skill.

This file is the SINGLE canonical Stage 4a literature block. `skill-orchestrate` and every domain
research/implementation skill reference this file instead of maintaining near-duplicate copies —
this is the fix for the drift class where each skill's own Stage 4a block diverged (some never
called the resolver at all, some still used a raw `literature-briefing.sh 2>/dev/null` call site,
none offered the online-ingest option). Every instruction below is DIRECT and EXECUTABLE — none
of it is commented-out pseudocode inside a bash fence. `AskUserQuestion` calls are prose
instructions to the agent executing the skill, not shell code (the tool cannot be invoked from
inside a script).

## Preconditions (variables the importing skill already has in scope)

- `lit_flag` — value of the `--lit` command flag ("true"/"false"), already read by the skill's
  own command-flag parsing.
- `description` — the task description text (already extracted from `state.json` earlier in the
  skill, e.g. `description=$(echo "$task_data" | jq -r '.description // ""')`).
- `orchestrator_mode` — value of the `orchestrator_mode` field from the delegation context this
  skill instance received (present when dispatched by `/orchestrate` or `/orchestrate --hard`;
  absent/unset for a research, plan, or implement dispatch invoked outside `/orchestrate`). Default to
  `"false"` when unset: `"${orchestrator_mode:-false}"`. See
  `.claude/docs/architecture/handoff-schema.md`'s Dual-Consumer Note — this field also gates the
  `.orchestrator-handoff.json` write, a SEPARATE consumer; do not conflate the two meanings.

## Step 1: Resolve the directive

```bash
lit_context=""
directive=$(bash .claude/scripts/literature-lit-flag-resolve.sh \
  --lit-flag "$lit_flag" \
  --orchestrator-mode "${orchestrator_mode:-false}" \
  --query "$description" 2>/tmp/lit-resolve-rationale.$$) || directive="GLOBAL_MISSING"
rationale="$(cat /tmp/lit-resolve-rationale.$$ 2>/dev/null || true)"
rm -f /tmp/lit-resolve-rationale.$$
```

`directive` is now exactly one of: `LIT_DISABLED`, `SUBINDEX_PRESENT`, `GLOBAL_MISSING`,
`PROMPT_NEEDED`, `AUTONOMOUS_GLOBAL`, `SPARSE_PROMPT_NEEDED`. Branch on it below.

## Step 2: Branch on the directive

### `LIT_DISABLED`

No action. `lit_context` stays `""`. (`--lit` was not passed for this invocation.)

### `GLOBAL_MISSING`

Emit a visible notice and continue with no literature context:

```
echo "[lit] No literature available this run: no per-repo sub-index and no global Literature index found. ($rationale)" >&2
```

`lit_context` stays `""`. This is the one acceptable empty branch, and it is explicitly
announced, never silent.

### `SUBINDEX_PRESENT`

The per-repo sub-index exists and resolves to `>=` the sparsity threshold. Run the per-repo
briefing via the failure-surfacing wrapper (never the raw script with `2>/dev/null` — that
collapses a real crash into the same empty value as a legitimately-empty briefing). Pass
`--query "$description"` so `literature-briefing.sh`'s repo mode can run the topic-scoped
coverage-delta guard (see "Coverage-Delta Marker Fields" below) — without `--query` the guard
never runs and the marker's `delta_checked` field stays `false`:

```bash
lit_context=$(bash .claude/scripts/literature-briefing-invoke.sh --query "$description") || lit_context=""
```

### `AUTONOMOUS_GLOBAL`

Sub-index absent, global index present, autonomous context (`orchestrator_mode == "true"`).
**MUST NOT call `AskUserQuestion`** — no human is available to prompt. Take the deterministic
default "Use global corpus now":

```bash
lit_context=$(bash .claude/scripts/literature-briefing-invoke.sh --global "$description") || lit_context=""
echo "[lit:auto] No per-repo sub-index found; autonomous context (orchestrator_mode=true) — running a global-corpus search instead of prompting. ($rationale)" >&2
```

If `lit_context` itself contains a `sparse=true` coverage marker (see the "Two-Checkpoint Sparse
Detection" section below), do NOT re-prompt or trigger online ingest here — autonomous runs
never perform online ingest (an explicit interactive-only action; see Non-Goals). Simply proceed
with the (sparse but honestly-labeled) briefing as-is; the `[SPARSE COVERAGE ...]` banner already
inside `lit_context` makes the limitation visible to the consuming agent.

### `SPARSE_PROMPT_NEEDED`

The per-repo sub-index exists but EITHER (a) resolved to `<` the sparsity threshold (including
zero resolving entries), OR (b) resolved to `>=` the sparsity threshold but the topic-scoped
coverage-delta guard found global top-level documents matching this task's search terms that are
absent from the sub-index (see `literature-lit-flag-resolve.sh`'s stderr rationale for which
cause applies — the directive token, option set, and autonomy contract are identical for both).

**If `"${orchestrator_mode:-false}" = "true"` (autonomous)**: treat this the same way as
`AUTONOMOUS_GLOBAL`'s "no human available" rule, but reuse the EXISTING sub-index rather than
launching a new global search (the sub-index is curated and sparse-but-real; a fresh global
search would not use it). **MUST NOT call `AskUserQuestion`.** Pass `--query "$description"` so
any topic-scoped coverage delta is surfaced in-band inside `lit_context` (the `[COVERAGE DELTA
...]` banner, see "Coverage-Delta Marker Fields" below) — this is the channel that actually
reaches this autonomous run, since `AskUserQuestion` is forbidden here and stderr never enters
the agent's prompt:

```bash
lit_context=$(bash .claude/scripts/literature-briefing-invoke.sh --query "$description") || lit_context=""
echo "[lit:auto] Per-repo sub-index is sparse or has a topic-scoped coverage delta (below the configured threshold, or topic-relevant global documents are absent from it); autonomous context (orchestrator_mode=true) — proceeding with the existing sub-index rather than prompting. A topic-scoped coverage delta, if any, is surfaced in-band inside lit_context via the [COVERAGE DELTA ...] banner. Online ingest is interactive-only and was not triggered. ($rationale)" >&2
```

**If interactive** (`orchestrator_mode` is not `"true"`): issue the SAME four-option
`AskUserQuestion` as `PROMPT_NEEDED` below, with prompt wording that covers both causes (e.g.
"The per-repo literature sub-index is sparse, or topic-relevant global documents are absent from
it. How would you like to proceed?"). See "The Four Options" below for the shared option
definitions — they are identical for `PROMPT_NEEDED` and `SPARSE_PROMPT_NEEDED`.

### `PROMPT_NEEDED`

Sub-index absent, global index present, interactive context. Call `AskUserQuestion` with the
prompt: "The `--lit` flag was used but `specs/literature-index.json` does not exist for this
repo. A global Literature index was found. How would you like to proceed?" and the four options
below.

## The Four Options (shared by `PROMPT_NEEDED` and `SPARSE_PROMPT_NEEDED`)

Present in this order (recommended default listed first):

1. **"Use global corpus now"** (recommended default) — Run a live relevance search against the
   global Literature corpus and inject the result for this run only. No setup, no file writes.

   ```bash
   lit_context=$(bash .claude/scripts/literature-briefing-invoke.sh --global "$description") || lit_context=""
   ```

   Then apply the "Two-Checkpoint Sparse Detection" rule below.

2. **"Create curation task"** — Create a task to populate the sub-index, then attempt to
   fork-populate it inline so this run also benefits:

   ```bash
   new_task_num=$(bash .claude/scripts/literature-create-setup-task.sh)
   echo "Created task $new_task_num to populate specs/literature-index.json."
   ```

   Then invoke the Agent tool with `subagent_type: "fork"` per the existing Stage 4a-fork inline
   population procedure (read `$LITERATURE_DIR/index.json` and `specs/state.json`, match
   keywords/topics against this repo's task descriptions, write matched entries to
   `specs/literature-index.json`, mark the new task `completed` in `specs/state.json`, call
   `bash .claude/scripts/generate-todo.sh`). After the fork returns, if the sub-index now exists:

   ```bash
   lit_context=$(bash .claude/scripts/literature-briefing-invoke.sh --query "$description") || lit_context=""
   ```

   If the fork failed or timed out: log a warning, report the task number, suggest
   `/orchestrate $new_task_num`, and leave `lit_context=""`.

3. **"Search online to ingest"** (new) — Discover and ingest sources online via the
   `literature-ingest-online.sh` bridge (STABLE CONTRACT — see that script's header for the full
   input schema, directive tokens, and exit codes; this flow does not change that contract):

   ```bash
   records_json=$(bash .claude/scripts/literature-discover.sh "$description") || records_json="[]"
   # Filter to statuses the bridge actually handles (available/in_zotero records already have a
   # local file or attached PDF and do not need this bridge).
   candidate_records=$(echo "$records_json" | jq -c '[.[] | select(.status == "open_access" or .status == "paywall" or .status == "in_zotero_no_pdf")]')
   candidate_count=$(echo "$candidate_records" | jq 'length')

   if [ "$candidate_count" -eq 0 ]; then
     echo "[lit] No online-ingestible records found for this query (0 open_access/paywall/in_zotero_no_pdf candidates)." >&2
   else
     echo "$candidate_records" | jq -c '.[]' | while IFS= read -r record; do
       bash .claude/scripts/literature-ingest-online.sh --record "$record"
       # Directive token appears on stdout; ONLINE_INGEST_INGESTED / ONLINE_INGEST_ATTACHED are
       # the two success tokens (exit 0). Any other token (exit 1-6) is an honest, visible stop
       # for that ONE record -- log it and continue to the next candidate record, never abort
       # the whole loop on a single record's failure.
     done
   fi

   # The bridge self-registers successfully-ingested records into specs/literature-index.json,
   # so re-run the per-repo briefing (not --global) to pick up whatever was just ingested.
   lit_context=$(bash .claude/scripts/literature-briefing-invoke.sh --query "$description") || lit_context=""
   ```

   This option performs live network calls (discovery + PDF download). It is gated strictly as
   an explicit interactive user choice — never triggered from `AUTONOMOUS_GLOBAL` or the
   autonomous branch of `SPARSE_PROMPT_NEEDED` above.

4. **"Skip this run"** — An explicit, user-chosen decision to continue without literature
   context:

   ```bash
   echo "[lit] Skipped by user choice" >&2
   lit_context=""
   ```

   Non-silent because it is an explicit, logged choice, not a default.

## Two-Checkpoint Sparse Detection (after "Use global corpus now")

After running the global-corpus search (option 1 above), inspect `lit_context` for the
machine-readable marker `literature-briefing.sh` emits: `<!-- lit-coverage mode=global
seg_count=N sparse=true|false threshold=T -->`.

```bash
if echo "$lit_context" | grep -q 'lit-coverage mode=global .*sparse=true'; then
  global_search_sparse=true
else
  global_search_sparse=false
fi
```

If `global_search_sparse=true` AND this is an interactive context (`orchestrator_mode` not
`"true"`) AND the user's choice that led here was **"Use global corpus now"** (never after
"Skip this run" or "Create curation task" — this is not reachable from those branches since they
do not run a global search): re-prompt with `AskUserQuestion` using the SAME four-option list
above (prompt wording: "The global-corpus search also returned only a few relevant segments.
Would you like to try something else?"). The user's second answer replaces `lit_context`
according to whichever of the four options they choose this time (including choosing "Use global
corpus now" again with a different query, "Search online to ingest", "Create curation task", or
"Skip this run" — which now discards the sparse global result and sets `lit_context=""`).

If `global_search_sparse=true` and the context is autonomous (reached via `AUTONOMOUS_GLOBAL`
above, not this interactive path), do NOT re-prompt — see `AUTONOMOUS_GLOBAL`'s own rule.

## Coverage-Delta Marker Fields

`literature-briefing.sh` repo mode, when called with `--query` (as every repo-mode call site
above now does), appends three fields to its `<!-- lit-coverage ... -->` marker, strictly AFTER
the pre-existing `mode=`/`seg_count=`/`sparse=`/`threshold=`/`requested=`/`resolved=`/`skipped=`/
`skip_rate=` fields (which stay byte-for-byte adjacent and in order — the "Two-Checkpoint Sparse
Detection" grep above is unaffected):

```
delta_checked=true|false delta_gap=N delta_candidates=M
```

- `delta_checked=false` means the topic-scoped coverage-delta guard never ran at all (no `--query`
  was passed, or the guard failed open) — it is NOT the same as "ran and found zero". Never treat
  `delta_checked=false` as a verified absence of a gap.
- `delta_gap` is the raw `global_docs - subindex_docs` count (top-level documents only); it only
  gates whether the more expensive keyword pass ran and is not itself the firing condition.
- `delta_candidates` is the count of global top-level documents matching this task's own filtered
  search terms that are absent from the sub-index — the actionable, topic-scoped signal.

When the guard fires (`delta_checked=true` and `delta_candidates` at or above
`LITERATURE_COVERAGE_DELTA_THRESHOLD`), `lit_context` also contains a `[COVERAGE DELTA - ...]`
banner (same family as `[SPARSE COVERAGE ...]` / `[SKIPPED SOURCES ...]`) listing up to
`--top-n` candidate titles and doc_ids, with the untruncated total stated separately. This banner
is the mandatory, unconditional channel that reaches `orchestrator_mode=true` runs — the delta
guard deliberately does **not** set `sparse=true` (so the two-checkpoint `grep -q 'lit-coverage
mode=global .*sparse=true'` logic above is unaffected by it), since "this briefing resolved
almost nothing" and "more relevant material exists elsewhere in the global corpus" are different
operator actions. See `context/project/literature/domain/sparse-coverage.md`'s "Coverage-Delta
Detection" section for the full mechanism.

## Injection Rule

Do NOT inject an empty `<literature-briefing>` block when `lit_context` is empty. When non-empty,
place it in the subagent prompt AFTER the memory context block (if any) and BEFORE task-specific
instructions — the same placement rule used throughout this pattern.

## Non-Silence Invariant

Every branch above either produces a `<literature-briefing>` block or explicitly and visibly
announces why none was produced (a logged `[lit]`/`[lit:auto]` notice, or an explicit user
choice). No branch silently injects nothing and no branch silently auto-searches.
