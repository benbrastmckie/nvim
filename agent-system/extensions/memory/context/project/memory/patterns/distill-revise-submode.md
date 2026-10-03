# Sub-Mode: revise

This file is the COMPLETE and ONLY specification for skill-distill's `--revise` sub-mode execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Sub-Mode: revise` section of `skill-distill/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `--revise` is dispatched.

Event-and-OTel-correlated review and revision of the memory vault. `--revise` inherits, in
substance unchanged, the current `dream` section's Event Ingestion, Event-to-Memory Correlation,
corroborated/contradicted/gap Classification (three-strikes threshold), the `AskUserQuestion`
UPDATE/TOMBSTONE/CREATE gate, and Batch Index Regeneration -- this content is relocated from
`dream` (Phase 10 removes the now-duplicated copy from `dream` once this section and `--meta`
(`distill-meta-submode.md`) fully contain it). **New in this sub-mode**: Tier 1 (OTel) supplies
outcome evidence, joined on `cc_session_id`, alongside the existing Tier 2 (`events.jsonl`)
correlation. Follows the Shared Sub-Mode Skeleton in `skill-distill/SKILL.md`; deltas below. See
`context/project/memory/telemetry-guardrails.md` for the miss-rate expectation and the
never-auto-apply rule -- not restated here.

## Edge Case Checks

```
1. Run validate-on-read to ensure memory-index.json is consistent with the filesystem
2. Count non-tombstoned memories (status != "tombstoned" or status absent)
3. If no non-tombstoned memories:
   Display: "No memories in vault to revise. Use /learn to add memories first."
   Return early.
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
No events captured yet in specs/events.jsonl -- revise proceeds using vault scoring alone
(staleness/duplicate/size), with zero event correlations this run.
```

Continuation rule: `--revise` does NOT stop or treat this as an error. It proceeds exactly as
`/distill --refine` would, using only the existing Scoring Engine, and reports zero
corroborated/contradicted/gap correlations.

## Event-to-Memory Correlation

Two-tier correlation, reusing existing formulas rather than inventing a new one:

- **Tier (a) -- task-number substring match**: for each pulled event with a non-null `task`
  field, substring-match the task number against each memory's free-text `source` frontmatter
  field (e.g. an event with `"task": 259` matches a memory whose `source` contains `"259"` in a
  task-directory-shaped context). This is the high-confidence tier.
- **Tier (b) -- keyword/topic overlap fallback**: for events with no task-number match (or no
  `task` field), fall back to the existing overlap formula from `### Overlap Scoring` above,
  scoring the event's `message`/`detail` text against each memory's `keywords`. Reference that
  section by name -- do not restate or fork the formula here.

## Classification

Each memory with at least one correlated event (Tier 2) or OTel outcome record (Tier 1) is
classified into exactly one bucket:

| Classification | Meaning |
|-----------------|---------|
| Corroborated | Correlated evidence is consistent with the memory's existing guidance -- no contradiction found. |
| Contradicted | Correlated evidence (deviation/blocker event, optionally sharpened by an OTel error outcome from the same `cc_session_id`) shows the memory's guidance no longer holds, or is stale relative to captured evidence. |
| Gap | Correlated evidence points at a recurring pattern with no existing memory covering it. |

**Recurrence threshold**: a pattern must occur **three or more times** at the same
checkpoint/event_type combination to be treated as `contradicted` (rather than a one-off) or
surfaced as a `gap` candidate. This three-strikes threshold is the same one the Convergence
Policing Contract's Divergence Audit precedent (`context/contracts/convergence.md`) uses for
churn detection -- reused here by name, not reinvented.

Memories with zero correlated evidence are left out of this classification entirely; they are
still covered by the ordinary Scoring Engine as usual.

## Dry-Run

When `--dry-run` is active, print the full three-bucket classification (corroborated /
contradicted / gap) with per-memory counts and the specific correlated event IDs/messages (and
any OTel-sourced `detail` citations) cited as evidence, and perform **zero writes**:

```
[DRY RUN] Revise classification:
  Corroborated: {count} memories (no action)
  Contradicted: {count} memories -- would prompt UPDATE/tombstone/skip
  Gap: {count} candidate memories -- would prompt CREATE

No changes made.
```

Exit after displaying the dry-run summary.

## Interactive Selection (MANDATORY STOP)

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step). YOU MUST call
`AskUserQuestion` for the contradicted and gap buckets before writing anything. Do NOT infer what
the user wants. Do NOT apply any UPDATE/CREATE/tombstone without explicit user selection.** This
is the evaluator-outside-the-loop rule from `telemetry-guardrails.md`: no sub-mode may treat its
own prior output as primary evidence, and mutation never proceeds without this stop.

### Corroborated Handling

No write. The memory and its corroborating evidence (event IDs, and OTel citations if present)
are recorded in the revise summary/log only (see Revise Log Schema below) -- corroboration is
informational, not actionable.

### Contradicted / Stale Handling

Present each contradicted memory via `AskUserQuestion`, with three options. Each option's
`description` MUST cite the specific correlated evidence, and the UPDATE option MUST show the
**proposed new memory body** for review -- never a bare yes/no confirmation:

```json
{
  "question": "Memory '{memory.id}' appears contradicted by {N} captured events. How should it be handled?",
  "header": "Contradicted: {memory.id}",
  "multiSelect": false,
  "options": [
    {
      "label": "UPDATE",
      "description": "Evidence: {event_id_1} ({message_1}), {event_id_2} ({message_2})[, OTel: {error.type}]. Proposed new body:\n\n{proposed_new_memory_body}"
    },
    {
      "label": "TOMBSTONE",
      "description": "Mark superseded by revise evidence: {event_id_1} ({message_1})"
    },
    {
      "label": "SKIP",
      "description": "Take no action this run"
    }
  ]
}
```

- **UPDATE**: apply via the existing `### UPDATE Operation` template -- old guidance moves to
  `## History`, the corrected guidance (sourced from event/OTel evidence) becomes the new main
  content.
- **TOMBSTONE**: apply via the existing tombstone frontmatter pattern (see the Purge Sub-Mode's
  `#### Tombstone Application` above) with `tombstone_reason: "revise_superseded"` -- a new
  *value* for the existing field, not a new schema.
- **SKIP**: no write.

### Gap Handling

Present each gap candidate via `AskUserQuestion`, evidence-cited the same way. Before offering
CREATE, apply the escalation discriminator:

- If the gap represents durable domain/technique knowledge that fits the existing
  TECHNIQUE/PATTERN/CONFIG/WORKFLOW/INSIGHT taxonomy, offer **CREATE** via the existing
  `### CREATE Operation` template, sourced from the event's `detail`/`message` content.
- If the gap instead represents a *system change* (a skill, hook, rule, or doc that should
  differ), it escalates to an **Improvement Proposal** (`--meta`, `distill-meta-submode.md`)
  instead of a memory
  CREATE -- `--revise` never creates a memory to paper over a system defect.

## Batch Index Regeneration

After all UPDATE/TOMBSTONE/CREATE writes for this revise run are complete (and only after --
never per-memory):

```
1. Regenerate memory-index.json using "JSON Index Maintenance" procedure
2. Regenerate index.md using "Index Regeneration Pattern"
3. Regenerate .memory/10-Memories/README.md
```

## Revise Log Schema

Operations are logged to `.memory/revise-log.json`, mirroring the shape of
`.memory/distill-log.json`:

```json
{
  "version": "1.0.0",
  "operations": [
    {
      "id": "revise_{timestamp}",
      "timestamp": "ISO8601",
      "type": "revise",
      "session_id": "sess_...",
      "since": "ISO8601 or null (first run)",
      "events_ingested": {
        "total_events": 0,
        "deviation": 0,
        "blocker": 0,
        "reflection": 0
      },
      "otel_joins": {
        "sessions_with_cc_session_id": 0,
        "otel_enabled": true,
        "outcome_records_matched": 0
      },
      "classification": {
        "corroborated": 0,
        "contradicted": 0,
        "gap": 0
      },
      "affected_memories": [
        {
          "id": "{memory.id}",
          "classification": "contradicted",
          "action": "updated|tombstoned|skipped",
          "evidence_event_ids": ["evt_..."],
          "otel_evidence": {"error.type": "ENOENT"}
        }
      ],
      "notes": ""
    }
  ],
  "summary": {
    "total_revised": 0,
    "total_corroborated": 0,
    "total_contradicted": 0,
    "total_gaps_created": 0,
    "last_operation": null
  }
}
```

`otel_joins.otel_enabled: false` records the degraded path explicitly rather than leaving the
absence of OTel-sourced evidence ambiguous with "OTel was checked and found nothing."

