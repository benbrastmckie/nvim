# Sub-Mode: revise

This file is the COMPLETE and ONLY specification for skill-distill's `--revise` sub-mode execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Sub-Mode: revise` section of `skill-distill/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `--revise` is dispatched.

Event-and-OTel-correlated review of hosted knowledge objects in the Sapience vault. `--revise`
correlates evidence to the hosted store rather than enumerating a local population: it clusters
recurring `events.jsonl` evidence first, applies the three-strikes recurrence threshold, and
queries the hosted store once per surviving cluster via `sapience-retrieve.sh`. This is the
evidence-to-store direction (not store-to-evidence): there is no hosted enumeration endpoint, only
a capped keyword query, so the correlation direction inverts relative to a local-vault design.
Tier 1 (OTel) supplies outcome evidence, joined on `cc_session_id`, alongside Tier 2
(`events.jsonl`) correlation. Follows the Shared Sub-Mode Skeleton in `skill-distill/SKILL.md`;
deltas below. See `context/standards/telemetry-guardrails.md` for the miss-rate expectation and
the never-auto-apply rule -- not restated here. Distinct from `--meta`'s own
(`context/patterns/telemetry-meta-submode.md`) system-improvement-proposal charter.

## Edge Case Checks

**Reachability probe (mandatory, before any classification).** `sapience-retrieve.sh` now splits
its failure exit code: 1 for a BENIGN no-match (no token, no keywords, a zero-hit result), 2 for
a GENUINE transport/HTTP failure (see the script's own header). Both are still non-zero, so the
probe-failure branch below treats them identically and this submode's behavior is unchanged; a
caller that wants to distinguish the two explicitly may check for exit code 2 rather than
treating every non-zero exit as a single undifferentiated case. Before classifying any cluster,
run one probe query whose keywords are known to match at least one existing `[repo:nvim]`-tagged
knowledge object:

```
1. probe=$(bash .claude/scripts/sapience-retrieve.sh "sapience per-repo scoping" meta 2>/dev/null)
2. If the probe call fails (non-zero exit, empty stdout):
   Display: "Hosted knowledge store unreachable -- revise proceeds using events.jsonl evidence
   only, with zero hosted-store correlations this run. No cluster is classified as a gap."
   Classify every surviving cluster's store-correlation as skipped (not gap, not corroborated,
   not contradicted) and continue to the Interactive Selection step with only prior, already-known
   corroborated/contradicted buckets, if any.
3. If the probe succeeds: proceed to classification normally.
```

## Candidate Identification: Event Ingestion (Tier 2)

`--revise` reads the unified event store exclusively through `events-query.sh` -- **hand-rolled
`jq` against `specs/events.jsonl` is prohibited**, per the script's own header contract. Every
call below additionally takes `--since {last_revise}` once `memory_health.last_revise` is set
(mirroring the existing `last_dream`/`dream_count` pattern in State Integration, with its own
`last_revise`/`revise_count` fields), so every run after the first is bounded to events captured
since the previous revise. Invoke via the mandatory chained relative form -- see
`telemetry-guardrails.md`'s cross-repo invocation discipline:

```bash
GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"
cd "$GLOBAL_ROOT" && bash .claude/scripts/events-query.sh --format summary-counts [--since {last_revise}]
```

In order:

1. **Cheap gate** -- an aggregate count before pulling full event bodies:
   ```bash
   events-query.sh --format summary-counts [--since {last_revise}]
   ```
2. **Deviation/blocker pull** -- the primary signal for memory contradiction/gap detection:
   ```bash
   events-query.sh --category deviation --format json-array [--since {last_revise}]
   events-query.sh --category blocker --format json-array [--since {last_revise}]
   ```
3. **Reflection pull** -- completion-time structured reflections:
   ```bash
   events-query.sh --event-type reflection --format json-array [--since {last_revise}]
   ```

**Why the event store, not `state.json`'s `reflection` field**: `state.json`'s per-task
`reflection` field is overwrite-only / most-recent-only. The event store's `reflection`-typed
events are append-only across a task's entire history, so `--revise` sees every reflection ever
captured for a task, not just whichever one happens to currently sit in `state.json`.

**Producer-status note**: the `state.json` `reflection` field has since been retired entirely
(zero live writers), and the `reflection`-typed event above has no live producer either — see
`context/formats/events-format.md`'s producer-status note. This pull now surfaces only
historical rows written before that retirement; do not expect new ones.

## Candidate Identification: OTel Outcome Join (Tier 1, New)

For each event pulled above that carries a non-null `cc_session_id`, query OTel for outcome
records from that same session (via whatever OTel query surface is available in the deployment
-- this sub-mode does not itself stand up a collector or query language; it consumes an existing
one). The join is exact and requires no time-window heuristic:

```
cc_session_id (events.jsonl) == session.id (OTel event/span/metric)
```

A memory can be classified `contradicted` by citing an OTel `tool_result.error_type` alongside a
`deviation` event from the same session -- outcome evidence corroborating or sharpening the
`events.jsonl`-derived signal, never replacing it. OTel-derived evidence is cited inside `detail`
using the borrowed `gen_ai.*` / `error.type` keys, per `telemetry-guardrails.md`'s `gen_ai.*`
borrowing rule -- e.g.:

```json
{
  "detail": {
    "events_jsonl_event_id": "evt_1736700010789_g7h8i9",
    "gen_ai.usage.input_tokens": 1200,
    "error.type": "ENOENT"
  }
}
```

**Degraded path -- OTel not enabled**: when `CLAUDE_CODE_ENABLE_TELEMETRY=1` is unset, this join
contributes nothing. This is an explicitly-announced, first-class outcome, generalizing the
existing "No Events Yet" pattern below:

```
OTel not enabled for this session -- outcome evidence unavailable. Correlation proceeds using
events.jsonl alone (Tier 2), with zero OTel-sourced corroboration this run.
```

## No Events Yet (Degraded Path)

**This is a normal, first-class outcome -- not an error.** Verified live: when
`specs/events.jsonl` does not exist yet, `events-query.sh --format summary-counts` returns
`{"total_events":0,"by_category":{},"by_event_type":{}}` and `--format json-array` returns `[]`,
both exiting 0. This is the expected day-one experience.

When the summary-counts gate reports `total_events: 0`, display:

```
No events captured yet in specs/events.jsonl -- revise has no recurring pattern to cluster and
nothing to correlate against the hosted store, with zero correlations this run.
```

Continuation rule: `--revise` does NOT stop or treat this as an error. It proceeds, running
Stage 4b's bookkeeping and the run-record write below, and reports zero
corroborated/contradicted/gap correlations. (Local vault scoring, where it still applies, is
`auto`'s own concern -- see `skill-distill/SKILL.md`'s Scoring Engine -- and is untouched by
`--revise`'s degraded path, since `--revise` never reads or writes `.memory/`.)

## Event Clustering

Two-tier clustering, reusing existing formulas rather than inventing a new one, groups the pulled
events into recurring pattern clusters at checkpoint/event_type granularity:

- **Tier (a) -- task-number substring match**: for each pulled event with a non-null `task`
  field, group by that task number. This is the high-confidence tier.
- **Tier (b) -- keyword/topic overlap fallback**: for events with no task-number match (or no
  `task` field), fall back to the existing overlap formula from `### Overlap Scoring` above,
  grouping events whose `message`/`detail` text overlaps on keywords. Reference that section by
  name -- do not restate or fork the formula here.

**Recurrence threshold**: a cluster must contain **three or more** occurrences at the same
checkpoint/event_type combination to proceed to hosted-store correlation below (rather than being
discarded as a one-off). This three-strikes threshold is the same one the Convergence Policing
Contract's Divergence Audit precedent (`context/contracts/convergence.md`) uses for churn
detection -- reused here by name, not reinvented.

Clusters that never cross the threshold are discarded; nothing is queried or written for them.

## Hosted-Store Correlation

For each cluster that crosses the three-strikes threshold (and only after the reachability probe
in Edge Case Checks has succeeded), query the hosted store once via `sapience-retrieve.sh`, using
the cluster's representative task number or overlap keywords as the query description:

```bash
bash .claude/scripts/sapience-retrieve.sh "{cluster keywords/task description}" meta
```

Classify the result into exactly one bucket:

| Classification | Meaning |
|-----------------|---------|
| Corroborated | The hosted store returned a note whose guidance is consistent with the cluster's evidence -- no contradiction found. |
| Contradicted | The hosted store returned a note whose guidance the cluster's evidence (deviation/blocker event, optionally sharpened by an OTel error outcome from the same `cc_session_id`) shows no longer holds, or is stale relative to captured evidence. |
| Gap | The query returned no note (after the reachability probe confirmed the store itself is reachable), so the cluster's recurring pattern has no existing hosted coverage. |

This preserves every classification outcome a local-vault design would have produced, and is
strictly cheaper: only clusters that already crossed the threshold are queried, rather than
enumerating a whole local population.

## Dry-Run

When `--dry-run` is active, print the full three-bucket classification (corroborated /
contradicted / gap) with per-cluster counts and the specific correlated event IDs/messages (and
any OTel-sourced `detail` citations) cited as evidence, and perform **zero writes**:

```
[DRY RUN] Revise classification:
  Corroborated: {count} clusters (no action)
  Contradicted: {count} clusters -- would prompt SUPERSEDE/skip
  Gap: {count} clusters -- would prompt CREATE

No changes made.
```

Exit after displaying the dry-run summary.

## Interactive Selection (MANDATORY STOP)

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step). YOU MUST call
`AskUserQuestion` for the contradicted and gap buckets before writing anything. Do NOT infer what
the user wants. Do NOT apply any SUPERSEDE/CREATE without explicit user selection.** This is the
evaluator-outside-the-loop rule from `telemetry-guardrails.md`: no sub-mode may treat its own
prior output as primary evidence, and mutation never proceeds without this stop. Every SUPERSEDE
and CREATE write is permanent and unreviewed -- there is no delete API on the hosted store -- so
this stop is load-bearing, not advisory.

**`--revise` may never run under `/distill --auto`.** The interactive selection gate above is a
hard constraint, not a default that `--auto` could override: `auto` dispatches only its own local
vault scoring/refine fixes and never reaches this sub-mode.

### Corroborated Handling

No write. The cluster and its corroborating evidence (event IDs, and OTel citations if present)
are recorded in the run record only (see Revise Run Record below) -- corroboration is
informational, not actionable.

### Contradicted / Stale Handling

Present each contradicted cluster via `AskUserQuestion`, with two options -- SUPERSEDE and SKIP.
Neither of the hosted store's write primitives supports the other branches a local vault would
offer: there is no delete API, so a contradicted note cannot be tombstoned, and `/ingest-kos`
appends rather than rewrites, so an in-place update has no mechanism either. Both branches a
local design would have offered therefore collapse into one write. Each option's `description`
MUST cite the specific correlated evidence, and SUPERSEDE MUST show the **proposed superseding
body** for review -- never a bare yes/no confirmation:

```json
{
  "question": "The cluster at checkpoint '{checkpoint}' ({N} occurrences) appears contradicted by hosted note '{ko_id}'. How should it be handled?",
  "header": "Contradicted: {cluster_label}",
  "multiSelect": false,
  "options": [
    {
      "label": "SUPERSEDE",
      "description": "Evidence: {event_id_1} ({message_1}), {event_id_2} ({message_2})[, OTel: {error.type}]. Proposed superseding note:\n\n{proposed_superseding_body}"
    },
    {
      "label": "SKIP",
      "description": "Take no action this run"
    }
  ]
}
```

- **SUPERSEDE**: write exactly one new knowledge object via
  `bash .claude/scripts/sapience-remember.sh`, whose body states the corrected guidance first and
  then a clearly marked section quoting the superseded guidance it corrects, citing the evidence
  that contradicted it. The superseded note is left in place in the hosted store -- that is the
  store's own designed behavior (it performs its own conflict surfacing and stale-position
  re-confirmation server-side), not a leak this sub-mode must clean up.
- **SKIP**: no write.

### Gap Handling

Present each gap cluster via `AskUserQuestion`, evidence-cited the same way. Before offering
CREATE, apply the escalation discriminator:

- If the gap represents durable domain/technique knowledge that fits the existing
  TECHNIQUE/PATTERN/CONFIG/WORKFLOW/INSIGHT taxonomy, offer **CREATE**: one
  `bash .claude/scripts/sapience-remember.sh` write sourced from the cluster's representative
  event `detail`/`message` content.
- If the gap instead represents a *system change* (a skill, hook, rule, or doc that should
  differ), it escalates to an **Improvement Proposal** (`--meta`,
  `context/patterns/telemetry-meta-submode.md`) instead of a knowledge-object write -- `--revise`
  never creates a knowledge object to paper over a system defect.

## Revise Run Record

Hosted writes need no local index regeneration -- `sapience-remember.sh` and
`sapience-retrieve.sh` are both self-contained round trips to the hosted store. This run touches
no file under `.memory/`: no index read, no index regeneration, and no local log file.

Instead of a local `.memory/revise-log.json`, each run appends one event to the existing
`specs/events.jsonl` store via `events-append.sh`, so the run record lives beside the same event
data `--revise` already reads rather than introducing a second, `.memory/`-scoped log:

```bash
bash .claude/scripts/events-append.sh --event-type distill-revise --category milestone \
  --session "$session_id" \
  --message "revise: {corroborated} corroborated, {contradicted} contradicted, {gap} gap" \
  --detail-json '{
    "since": "ISO8601 or null (first run)",
    "events_ingested": {"total_events": 0, "deviation": 0, "blocker": 0, "reflection": 0},
    "otel_joins": {"sessions_with_cc_session_id": 0, "otel_enabled": true, "outcome_records_matched": 0},
    "reachability_probe": "ok|unreachable",
    "classification": {"corroborated": 0, "contradicted": 0, "gap": 0},
    "affected_clusters": [
      {"cluster_label": "...", "classification": "contradicted", "action": "superseded|skipped", "evidence_event_ids": ["evt_..."], "otel_evidence": {"error.type": "ENOENT"}}
    ]
  }'
```

`otel_joins.otel_enabled: false` records the degraded path explicitly rather than leaving the
absence of OTel-sourced evidence ambiguous with "OTel was checked and found nothing", and
`reachability_probe: "unreachable"` records the degraded path from the Edge Case Checks probe
explicitly in the same way.

