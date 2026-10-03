# Sub-Mode: learn

This file is the COMPLETE and ONLY specification for skill-distill's `--learn` sub-mode execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Sub-Mode: learn` section of `skill-distill/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `--learn` is dispatched.

Retroactive, batch harvest across already-completed tasks whose `memory_candidates` were never
harvested -- declined, skipped, or predating the harvest mechanism entirely. Follows the Shared
Sub-Mode Skeleton in `skill-distill/SKILL.md`; deltas below.

**Two distinctions, stated up front because the flag name collides with the `/learn` command and
a reader will otherwise conflate the three mechanisms**:

1. **vs. `/learn --task N`**: that path is single-task, any-time, artifact-driven (the user picks
   one task and reviews its `specs/` artifacts interactively). `/distill --learn` is batch, scans
   *every* already-archived task for unharvested candidates, and runs on a schedule/maintenance
   cadence rather than a single explicit task pick.
2. **vs. `/todo`'s archive-time harvest**: that harvest is automatic, fires only at the moment of
   archival, and reads only `memory_candidates` already present on the task at that instant.
   `/distill --learn` runs independently of archival timing, against tasks that already went
   through archival (possibly long ago) and whose candidates were declined, skipped, or simply
   predate the harvest mechanism's existence -- it is a second chance, not a duplicate of the
   first.

## Edge Case Checks

```
1. Scan specs/archive/ (or specs/vault/{NN-vault}/ for vaulted tasks) for task directories whose
   state.json entry has memory_candidates present but no corresponding harvest recorded.
2. If no such tasks exist:
   Display: "No archived tasks with unharvested memory candidates found."
   Return early.
```

## Candidate Identification

For each archived task with unharvested `memory_candidates`:

- If the task's completion falls within the **30-day transcript replay window**: primary source
  is Tier 4 (the task's transcript + `.meta.json` sidecar). Reuse existing transcript parsers
  (e.g. `ccusage` / `claude-code-log` parsing approaches) rather than writing one from scratch --
  per `telemetry-guardrails.md`'s OSS-tooling position. Note explicitly: these parsers extract no
  success/failure signal, so outcome evidence (if wanted at all) must come from the OTel tier, not
  from the transcript parse.
- If the task's completion falls **outside** the 30-day window: fall back to Tier 3
  (`history.jsonl`), which is the durable global prompt spine and outlives transcripts, plus the
  task's own archived `specs/` artifacts (reports/plans/summaries) which remain on disk
  regardless of transcript retention.
- The `.meta.json` sidecar's limits apply here as everywhere: it carries only `agentType`,
  `description`, `toolUseId`, `spawnDepth` -- no session id and no outcome field -- so it is
  bootstrap-only, and the replay value lives in the paired `.jsonl`.

**Announcement when a task's transcript is no longer available** (the 30-day boundary crossed):

```
Task {N}'s transcript has rolled past the 30-day replay window -- falling back to
history.jsonl's prompt-level record and the task's own archived specs/ artifacts for candidate
extraction.
```

## Dry-Run

```
[DRY RUN] Unharvested memory candidates found across {task_count} archived task(s):
  - Task {N}: {candidate_count} candidate(s), source: transcript|history.jsonl+specs artifacts
  - ...

No memories created.
```

## Interactive Selection (MANDATORY STOP)

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step). Do NOT create any
memory without explicit user selection.** Present candidates via `AskUserQuestion` `multiSelect`,
grouped by task, using the same TECHNIQUE/PATTERN/CONFIG/WORKFLOW/INSIGHT/SKIP classification
`/learn --task N` already uses -- this sub-mode proposes through the shared skeleton exactly like
every mutating sub-mode above; it never auto-creates memories.

```json
{
  "question": "Task {N} has {count} unharvested memory candidate(s). Classify each:",
  "header": "Unharvested Candidates: Task {N}",
  "multiSelect": true,
  "options": [
    {
      "label": "{candidate.content_summary}",
      "description": "[TECHNIQUE] / [PATTERN] / [CONFIG] / [WORKFLOW] / [INSIGHT] / [SKIP] -- source: {source_tier}"
    }
  ]
}
```

## Execution

For each confirmed candidate, apply the same UPDATE/EXTEND/CREATE operations `/learn` uses
(`skill-learn/SKILL.md`) -- this sub-mode does not invent a new memory-write mechanism, only a
new discovery path over already-archived tasks.

## Batch Index Regeneration

After all confirmed candidates across all selected tasks are written (not after each task
individually): regenerate `memory-index.json`, `index.md`, and `.memory/10-Memories/README.md`
per the Shared Sub-Mode Skeleton's Batch Index Regeneration step.

## Learn-Harvest Log Schema

Rather than overloading the general Distill Log Schema's closed `type` enum (`report|purge|
merge|compress|refine|gc|dream`, which this sub-mode leaves untouched), operations are logged to
their own file, `.memory/learn-harvest-log.json`, mirroring the shape of `.memory/distill-log.json`:

```json
{
  "version": "1.0.0",
  "operations": [
    {
      "id": "learn_harvest_{timestamp}",
      "timestamp": "ISO8601",
      "type": "learn_harvest",
      "session_id": "sess_...",
      "tasks_scanned": 0,
      "tasks_with_candidates": 0,
      "candidates_by_source": {"transcript": 0, "history_jsonl": 0},
      "affected_memories": [
        {"task": 259, "memory_id": "MEM-...", "classification": "PATTERN", "source": "transcript"}
      ],
      "notes": ""
    }
  ],
  "summary": {
    "total_learn_harvest_runs": 0,
    "total_memories_created": 0,
    "last_operation": null
  }
}
```

Mark each processed task's `memory_candidates` as harvested in its `state.json`/archived record
so a subsequent `--learn` run does not re-surface the same candidates.

