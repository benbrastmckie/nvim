# Sub-Mode: dream

This file is the COMPLETE and ONLY specification for skill-telemetry's `--dream` sub-mode execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Sub-Mode: dream` section of `skill-telemetry/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `--dream` is dispatched.

Speculative direction-finding over the user's own prompt history. Follows the Shared Sub-Mode
Skeleton in `skill-telemetry/SKILL.md`, with one sanctioned exemption stated below (the same
exemption `--review` states).

**Charter**: surface recurring themes and interests in the user's own prompt history
(`history.jsonl`) that have no corresponding memory or task yet. This is brainstorming, not
event-correlated memory revision or system-improvement proposal generation -- `dream` carries no
event-correlation machinery and no task-creation machinery of its own. Event-and-OTel-correlated
memory revision is `/distill --revise`'s charter; cross-repo agent-system improvement proposals
are `--meta`'s charter.

## MANDATORY STOP Exemption (Stated, Not Omitted)

No `AskUserQuestion` mutation gate is needed at the surfacing step, because nothing mutates at
that step. Like `--review`, this exemption is stated explicitly rather than left as a silent
omission. Any resulting action funnels to `--meta` (a system-improvement proposal) or `/learn` (a
new memory), never applied directly by `dream` itself.

## Edge Case Checks

```
1. Locate history.jsonl (global, not per-repo).
2. Slice to this repo's own prompts via each line's `project` field (see History.jsonl Access
   below) -- no transformation needed, since `project` is already an absolute cwd.
3. If zero prompts found for this repo:
   Display: "No prompt history found for this repo in history.jsonl. Nothing to dream over yet."
   Return early.
```

## Candidate Identification: `history.jsonl` Access

Line shape (one JSON object per line):

```json
{
  "display": "the literal prompt text the user typed",
  "pastedContents": "optional pasted content accompanying the prompt",
  "timestamp": 1736700000000,
  "project": "/home/user/.config/nvim",
  "sessionId": "3f9c2a10-8b4e-4c3d-9a1f-6e2d5c7b8a90"
}
```

- **Per-repo slicing**: filter lines where `project` matches the invoking repo's absolute path
  (or `$GLOBAL_ROOT` when `--meta`-style cross-repo scope is explicitly requested -- dream itself
  defaults to the invoking repo, unlike `--meta`'s cross-repo default).
- **Session-scoping**: `sessionId` groups prompts into the same Claude Code session when needed
  (e.g. to avoid treating a single multi-turn conversation as several independent "recurring"
  mentions of the same theme).
- **Recurring-theme surfacing logic**: cluster prompts by keyword/topic overlap, scoring overlap
  between a prompt cluster and candidate memories as:

  ```
  overlap_score = |segment_terms intersect memory_terms| / |segment_terms|

  Where:
  - segment_terms = segment.key_terms
  - memory_terms = keywords extracted from memory content (same algorithm)
  ```

  then apply the same three-strikes recurrence threshold defined in
  `context/contracts/convergence.md`'s `## Three-Strikes Rule` (`target_churn_count[target]`
  reaching 3) to decide which clusters are "recurring" rather than one-off. For each recurring
  cluster, check whether an existing memory or open task already covers the theme: scan
  `specs/TODO.md` unconditionally, and additionally scan `.memory/memory-index.json` for
  keyword/topic overlap when that file is present (the memory vault is optional infrastructure;
  its absence must not block the always-available `specs/TODO.md` coverage check). Only themes
  with **no** existing coverage surface as dream candidates.

## Dry-Run

```
[DRY RUN] Dream: {count} recurring themes with no existing memory or task coverage:
  - "{theme_summary}" -- seen {N} times across {session_count} session(s), most recent {date}
  - ...

No changes made.
```

## Execution: Surfacing Output

Terminal-only narrative, never written to disk:

```
{theme_summary} -- recurring interest, no existing memory or task found.
  Sample prompts: "{display excerpt 1}", "{display excerpt 2}"
  Suggested next step: /telemetry --meta to propose a task, or /learn to capture as a memory.
```

`dream` does **not** write a dated run-report file to any vault index directory: a vault's own
index directory holds regenerated vault indexes, not dated run reports, and adding one would
invent a new artifact type for no gain. A user who wants the narrative persisted can redirect the
command's output themselves.

## Batch Index Regeneration

Not applicable -- `dream` performs no mutation of any kind (no UPDATE/TOMBSTONE/CREATE), so there
is no batch to regenerate an index over. Any memory write a surfaced theme leads to happens
through `/learn`, which owns its own index regeneration.

## Dream Log Schema

Operations are logged to `specs/telemetry/dream-log.json`. This log is the sole `--since` cursor
for `dream` -- there is no separate state-file coupling; `since` and `summary.last_operation`
below are the only place the cursor lives:

```json
{
  "version": "1.0.0",
  "operations": [
    {
      "id": "dream_{timestamp}",
      "timestamp": "ISO8601",
      "type": "dream",
      "session_id": "sess_...",
      "since": "ISO8601 or null (first run)",
      "prompts_scanned": 0,
      "themes_surfaced": 0,
      "themes_with_existing_coverage_skipped": 0,
      "notes": ""
    }
  ],
  "summary": {
    "total_dreamed": 0,
    "total_themes_surfaced": 0,
    "last_operation": null
  }
}
```

This schema carries no `classification`, `affected_memories`, or `proposals` fields: `dream`
does not classify memories or create tasks itself -- those belong to `/distill --revise`'s and
`--meta`'s own logs respectively.
