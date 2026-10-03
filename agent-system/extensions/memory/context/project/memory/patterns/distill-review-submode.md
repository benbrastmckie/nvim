# Sub-Mode: review

This file is the COMPLETE and ONLY specification for skill-distill's `--review` sub-mode execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Sub-Mode: review` section of `skill-distill/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `--review` is dispatched.

Read-only ad hoc inquiry over the vault and all four telemetry source tiers -- the one sub-mode
that legitimately spans every tier live, driven by the user's question rather than a fixed query.
Follows the Shared Sub-Mode Skeleton in `skill-distill/SKILL.md`, with one sanctioned exemption
stated explicitly below.

**Strictly read-only.** `--review` never proposes and never writes. This is what distinguishes it
from `report` (fixed structured output over the vault only) and from `--revise` / `--meta` (which
do propose writes). Any action arising from a review funnels to `--meta` (a system-improvement
proposal), `--revise` (a memory change), or `/learn` (a new memory) -- `--review` never acts
directly.

## MANDATORY STOP Exemption (Stated, Not Omitted)

Because `--review` does not mutate anything, it needs no `AskUserQuestion` mutation gate. This is
the one sanctioned deviation from the Shared Sub-Mode Skeleton's Interactive Selection
(MANDATORY STOP) step, alongside `report` and `auto`. It is stated here explicitly rather than
left as a silent omission: the absence of a mutation gate is a considered design decision (there
is nothing to confirm before writing, because nothing is written), not an oversight.

## Edge Case Checks

```
1. Parse the user's question (free-text, passed as the sub-mode's argument).
2. If no question is provided:
   Display: "Usage: /distill --review \"<question>\""
   Return early.
```

## Candidate Identification: Per-Tier Access

`--review` answers the user's specific question by querying whichever of the four tiers are
relevant to it -- there is no fixed candidate set, unlike every other sub-mode above. Each tier
has a named access path and a named degraded behavior when unavailable:

| Tier | Access Path | Degraded Behavior When Unavailable |
|------|-------------|-------------------------------------|
| 1. Claude Code OTel | Whatever OTel query surface is available in the deployment (this sub-mode does not stand up a collector or query language) | "OTel not enabled for this session/repo -- outcome evidence unavailable for this question." |
| 2. `events.jsonl` | `events-query.sh` exclusively -- hand-rolled `jq` against `specs/events.jsonl` is prohibited, per the script's own header contract | "No events captured yet in specs/events.jsonl for this query." (the existing "No Events Yet" pattern, generalized) |
| 3. `history.jsonl` | Read directly (global, cwd-scoped via each line's `project` field, session-scoped via `sessionId`) | "history.jsonl not found or empty for this repo/session." |
| 4. Transcripts + `.meta.json` sidecars | Read within the 30-day replay window only; the sidecar itself carries no session id and no outcome field, so replay value is in the paired `.jsonl` | "No transcript available within the 30-day window for this task/session; falling back to history.jsonl's prompt-level record and the task's own archived specs/ artifacts." |

Any script call this sub-mode makes uses the mandatory chained relative form -- see
`telemetry-guardrails.md`'s cross-repo invocation discipline; not restated here.

## Dry-Run

`--dry-run` is a no-op for `--review`: since the sub-mode never writes, there is nothing a
dry run would additionally suppress. `--dry-run` is accepted (for CLI consistency with every
other sub-mode) and silently has no effect beyond the normal read-only answer.

## Execution: Output Shape

An open-ended answer with evidence citations naming the tier and record each claim came from --
never an unsourced assertion:

```
{answer, in prose, addressing the user's question}

Evidence:
- [Tier 2 / events.jsonl] {event_id}: {message}
- [Tier 1 / OTel] session {cc_session_id}: {tool_result.error_type or similar}
- [Tier 3 / history.jsonl] {timestamp}: "{display excerpt}"
- [Tier 4 / transcript] {transcript_path}#{line or turn reference}

If this points at something actionable:
  - Memory correction -> run `/distill --revise` to review and apply.
  - System-improvement proposal -> run `/distill --meta` to propose a task.
  - New memory worth capturing -> run `/learn` to create it.
```

**Funnel rule, stated explicitly**: `--review` performs none of the three actions above itself.
It only names which follow-on sub-mode or command applies.

## Batch Index Regeneration

Not applicable -- `--review` performs no mutation of any kind, so there is no batch to
regenerate an index over.

## Log Entry

Optional and lightweight: `--review` MAY log a `review` operation to `.memory/distill-log.json`
(matching the general Distill Log Schema in `skill-distill/SKILL.md`, with `pre_metrics` and
`post_metrics` identical,
mirroring the existing `report` convention for read-only operations) recording the question asked
and which tiers were consulted, for audit purposes only. This is not required for the sub-mode to
function.

