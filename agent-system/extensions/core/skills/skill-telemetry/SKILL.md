---
name: skill-telemetry
description: Cross-repo agent-system improvement proposals (--meta), read-only ad hoc telemetry inquiry (--review), and speculative prompt-history direction-finding (--dream). Invoke for /telemetry command operations.
allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion, Agent
---

# Telemetry Skill (Direct Execution)

Direct execution skill for the `/telemetry` command's three sub-modes: `--meta`, `--review`, and
`--dream`. None of the three touches the memory vault or any other knowledge store; each reads
`specs/events.jsonl`, `~/.claude/history.jsonl`, session transcripts and Claude Code OTel (when
enabled), and either reports or proposes.

**This is a direct-execution skill, invoked by the session that ran `/telemetry`, never
dispatched as a subagent.** `AskUserQuestion` is categorically withheld from dispatched subagents
(see `docs/reference/standards/agent-frontmatter-standard.md`'s "Tool Withholding from Dispatched
Subagents"), and `--meta`'s MANDATORY STOP depends on calling it directly. Running this skill as
a dispatched subagent would silently disable that stop -- never do it.

## Context References

Reference (do not load eagerly):
- Path: `@.claude/context/standards/telemetry-guardrails.md` - Binding design constraints (four-tier source model, evaluator-outside-the-loop rule, six failure modes, `gen_ai.*` borrowing rule, cross-repo invocation discipline)
- Path: `@.claude/scripts/events-query.sh` - the mandated, exclusive access path to `specs/events.jsonl` (Tier 2); hand-rolled `jq` against the file is prohibited per the script's own header contract
- Path: `@.claude/context/contracts/convergence.md` - the canonical `## Three-Strikes Rule` definition (`target_churn_count[target]` reaching 3) that `--meta` and `--dream` both cite by name

---

## Shared Sub-Mode Skeleton

All three `/telemetry` sub-modes follow the same six-step shape. This section states that shape
once, with named, generic placeholders; each sub-mode's own specification -- in its extracted
`telemetry-<submode>-submode.md` file, reached via the stub pointer at that sub-mode's heading
below -- states only its deltas from this skeleton: its specific candidate logic, prompts,
execution steps, and log payload, rather than restating the shape itself.

1. **Edge Case Checks** -- Validate preconditions before identifying candidates. If a
   precondition fails, display a specific message and return early without further action.
2. **Candidate Identification** -- Compute the sub-mode's specific candidate set from the
   relevant telemetry source tier(s). If a shared dependency (e.g. the three-strikes threshold)
   is used, cite it by name rather than re-deriving it.
3. **Dry-Run** -- When `--dry-run` is active, display what the sub-mode would do (the specific
   candidate list, with sub-mode-relevant fields) and return early. No file is modified.
4. **Interactive Selection (MANDATORY STOP)** -- Present candidates via `AskUserQuestion`
   (`multiSelect: true` for `--meta`, which selects among multiple candidates). **This step is
   non-negotiable for `--meta`: no task creation may proceed without an explicit, user-confirmed
   selection at this step.**
5. **Execution** -- Apply the confirmed operation (for `--meta`, delegation to
   `meta-builder-agent`). This step's actual content is the most sub-mode-specific of the six and
   is stated in full in each sub-mode's own section.
6. **Log Entry** -- Log the operation to the sub-mode's own file under `specs/telemetry/` per the
   Telemetry Log Schemas below, and update the relevant `summary` counter.

There is no vault-index-regeneration step in this skeleton: all three sub-modes mutate no
knowledge-store index (each relocated specification states "Not applicable" for Batch Index
Regeneration in its own body), so that step from the seven-step shape used by store-maintenance
sub-modes elsewhere in this system does not apply here.

**Two sanctioned exemptions, stated explicitly rather than left as a silent omission**:
`--review` and `--dream` carry no step-4 mutation gate, because neither mutates anything -- there
is nothing to confirm before writing, because nothing is written. `--meta` does carry the
mutation gate: it is the only one of the three whose Execution step creates a task.

### Sub-Mode: meta

READ .claude/context/patterns/telemetry-meta-submode.md now and follow it exactly.

### Sub-Mode: review

READ .claude/context/patterns/telemetry-review-submode.md now and follow it exactly.

### Sub-Mode: dream

READ .claude/context/patterns/telemetry-dream-submode.md now and follow it exactly.

### Sub-Mode Dispatch

| Sub-Mode | Description | Mutation Gate |
|----------|-------------|----------------|
| `meta` | Cross-repo agent-system improvement proposals, delegated to `meta-builder-agent` | Yes (MANDATORY STOP) |
| `review` | Read-only ad hoc inquiry over all four telemetry source tiers | No (stated exemption) |
| `dream` | Speculative direction-finding over `history.jsonl`'s recurring themes | No (stated exemption) |

---

## Telemetry Log Schemas

### Meta Log Schema

Operations are logged to `specs/telemetry/meta-log.json`:

```json
{
  "version": "1.0.0",
  "operations": [
    {
      "id": "meta_{timestamp}",
      "timestamp": "ISO8601",
      "type": "meta",
      "session_id": "sess_...",
      "target_root": "/home/user/.config/nvim",
      "proposals": {
        "surfaced": 0,
        "created_as_task": 0,
        "noted_only": 0,
        "skipped": 0,
        "task_numbers_created": []
      },
      "notes": ""
    }
  ],
  "summary": {
    "total_meta_runs": 0,
    "total_proposals_created": 0,
    "last_operation": null
  }
}
```

### Dream Log Schema

Operations are logged to `specs/telemetry/dream-log.json`. This log is the sole `--since` cursor
for `dream`:

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

### Review Log (Optional)

`--review` MAY log a `review` operation to `specs/telemetry/review-log.json`, with `pre_metrics`
and `post_metrics` identical (mirroring the general convention for read-only operations),
recording the question asked and which tiers were consulted, for audit purposes only. This is not
required for the sub-mode to function.

### Degraded-Path Outcomes Are Normal Results, Not Errors

Both of the following are expected, loggable outcomes, never failures:
- **"No events yet"**: `events-query.sh` reports zero matching events in `specs/events.jsonl`.
- **"OTel not enabled"**: `--review`'s Tier 1 access is unavailable because
  `CLAUDE_CODE_ENABLE_TELEMETRY` is unset. State this explicitly in the output rather than
  omitting Tier 1's evidence silently.
