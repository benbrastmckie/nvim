# Sub-Mode: dream

This file is the COMPLETE and ONLY specification for skill-distill's `--dream` sub-mode execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Sub-Mode: dream` section of `skill-distill/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `--dream` is dispatched.

Speculative direction-finding over the user's own prompt history. **Redefined by overlap
resolution, not deletion**: dream's prior two responsibilities have been migrated verbatim in
substance to dedicated sub-modes -- event-and-OTel-correlated memory revision now lives in
`--revise` (`distill-revise-submode.md`), and cross-repo agent-system improvement proposals now
live in `--meta` (`distill-meta-submode.md`). Every element of the old `dream` section is
traceable to one of those two destinations or to this new charter; nothing was lost in the
migration (see the migration-verification note in this phase's own progress record). Follows the
Shared Sub-Mode Skeleton in `skill-distill/SKILL.md`, with one sanctioned exemption stated below
(the same exemption `--review` states).

**Charter**: surface recurring themes and interests in the user's own prompt history
(`history.jsonl`) that have no corresponding memory or task yet. This is brainstorming, not
event-correlated revision -- dream carries **no event-correlation machinery of its own**; that
all lives in `--revise` now.

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
- **Recurring-theme surfacing logic**: cluster prompts by keyword/topic overlap (reuse the
  existing `### Overlap Scoring` formula by name -- do not restate or fork it), then apply the
  same three-strikes recurrence threshold `--revise`'s Classification step uses (reused by name,
  not reinvented) to decide which clusters are "recurring" rather than one-off. For each
  recurring cluster, check whether an existing memory or open task already covers the theme
  (keyword/topic overlap against `.memory/memory-index.json` and a lightweight scan of
  `specs/TODO.md`); only themes with **no** existing coverage surface as dream candidates.

## Dry-Run

```
[DRY RUN] Dream: {count} recurring themes with no existing memory or task coverage:
  - "{theme_summary}" -- seen {N} times across {session_count} session(s), most recent {date}
  - ...

No changes made.
```

## Execution: Surfacing Output

Terminal-only narrative, exactly as the bare `/distill` health report already is (which is
likewise never written to disk):

```
{theme_summary} -- recurring interest, no existing memory or task found.
  Sample prompts: "{display excerpt 1}", "{display excerpt 2}"
  Suggested next step: /distill --meta to propose a task, or /learn to capture as a memory.
```

`dream` does **not** create a `.memory/20-Indices/dream-report-{date}.md` file: `20-Indices/`
holds regenerated vault indexes, not dated run reports, and adding one would invent a new
artifact type for no gain. A user who wants the narrative persisted can redirect the command's
output themselves.

## Batch Index Regeneration

Not applicable -- the redefined `dream` performs no mutation of any kind (no UPDATE/TOMBSTONE/
CREATE), so there is no batch to regenerate an index over. Any memory write a surfaced theme
leads to happens through `/learn`, which owns its own index regeneration.

## Dream Log Schema

Operations are logged to `.memory/dream-log.json`:

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

This schema is narrower than the prior `dream` section's log (no `classification`,
`affected_memories`, or `proposals` fields) because this sub-mode no longer classifies memories
or creates tasks itself -- those are `--revise`'s and `--meta`'s own logs respectively.

