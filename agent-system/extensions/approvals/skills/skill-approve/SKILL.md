---
name: skill-approve
description: Owner-labeled, agent-assisted component approval. Invoke for /approve <component>.
allowed-tools: AskUserQuestion, Bash, Edit, Read, Write
---

# Skill: skill-approve

**Direct execution only — no `Agent` tool, no `agent:` frontmatter field, by design.**
`AskUserQuestion` is categorically withheld from every `Agent`-tool dispatch of a named
`subagent_type` on this harness (settled by the in-repository investigation
`askuserquestion_unreachable_in_subagents` — see `../../README.md`'s "Why `/approve` Is Never
Dispatched"). If any part of this flow were delegated to a dispatched subagent, the prompt this
command exists to raise could not be raised at all. This skill therefore runs every stage below
— including the owner-facing prompting — in this session's own execution, the same
pre-delegation-interview pattern `skill-meta` already proves for its own interview stage, here
with **no delegation stage following it at all**.

**There is no fallback that records the agent as approver.** If `AskUserQuestion` cannot be
reached, Stage 2 below stops the run and reports. This is the command's entire reason for
existing — see `../../README.md`'s "Owner-Labeled, Never Self-Approved".

## Inputs

Parsed from `/approve <component> [component-flags...] [--task N] [--dry-run]`:

- `component` (required)
- `component_flags[]` — every trailing flag not recognized below, forwarded verbatim
- `task_number` (optional)
- `dry_run` (boolean, default false)

A caller-supplied `--out` is refused immediately (see `approve-paths.sh`'s own refusal) and
never reaches any later stage.

## Stage 1: Resolve Paths

```bash
bash .claude/scripts/approve-paths.sh --component "$component" ${task_number:+--task "$task_number"} --emit-paths
```

Three lines come back: `review_path`, `classification_path`, `presented_path`. A non-zero exit
(missing component, missing `approve.sh`, or a rejected `--out`) stops here; report the named
refusal verbatim and do nothing further.

## Stage 2: Refuse an Autonomous Dispatch

Stop immediately, before anything else runs, when this invocation's own delegation context
carries `orchestrator_mode: true`. An autonomous `/orchestrate` cycle must never answer this
prompt on the owner's behalf — report the refusal plainly ("`/approve` requires a human at the
keyboard; this dispatch is autonomous and cannot proceed") rather than weakening the channel by
guessing, defaulting, or silently skipping to a no-op success.

## Stage 3: Run the Component's Review

```bash
bash "$(git rev-parse --show-toplevel)/components/$component/approve.sh" --review --out "$review_path" "${component_flags[@]}"
```

Propagate a non-zero exit from `approve.sh` verbatim — stop, report the component's own stderr,
and do nothing further. On success, `$review_path` now holds the generated review (its `##
Decisions` and `## Evidence: <item>` sections, per `approve-classify.sh`'s documented grammar).

## Stage 4: Classify

```bash
bash .claude/scripts/approve-classify.sh "$review_path" > "$classification_path"
```

A non-zero exit here means the review has a shape `approve-classify.sh` does not recognize
(malformed `## Decisions`, `## Notes`, or `## Evidence:`) — stop and report the named heading
verbatim; never guess or treat an unparsed item as mechanical.

## Stage 5: Build the Essentials-Only Summary

Read `$classification_path` (`{component_head, items: [...]}`). Per
`../../context/project/approvals/standards/confidence-vocabulary.md`'s summary contract, build,
for presentation only (nothing is written yet):

- A **Discrepancies block** naming, by id, every item whose `class` is `declaration-level`, or
  whose `decl_added`/`decl_removed`/`decl_restated` is non-empty, or whose `evidence_kind` is
  `never-approved`/`uncommitted-approval`.
- Per item: `id`, `class`, the declaration delta **by name** (not a count), `recommendation`,
  `confidence`.
- The three artifact paths (`review_path`, `classification_path`, `presented_path`).

The full classified diff is never shown inline — point at `review_path` for that.

## Stage 6: Print the Artifact Paths (Escape 2 Is Live From Here On)

Print `review_path`, `classification_path`, and `presented_path` to the owner **before** any
question is asked. Per
`../../context/project/approvals/patterns/approve-interaction-design.md`'s Escape 2, the owner
may open and read these files directly, unmediated, at any point in the walk from this moment
on — this escape consumes no `AskUserQuestion` option and needs no further action from this
skill to stay available.

## Stage 7: Dry Run

If `dry_run`: print the Stage 5 summary and the exact `--record` command that would run
(Stage 11's command line, with the actual resolved owner/agent strings), then **stop**. Call no
`AskUserQuestion`, write no presented sidecar, flip no Decisions line, record nothing.

## Stage 8: Ask the Owner

Only reached when `dry_run` is false and Stage 2 did not refuse. Implements
`approve-interaction-design.md` exactly:

**Stage A — bulk triage gate** (one `AskUserQuestion` call): let `N` = the count of items whose
`class == "mechanical"`. If `N >= 1`, ask one question with three options:
`Approve all N mechanical-only items` / `Step through every item` / `Decline all`. If `N == 0`,
ask the same question with only the two always-present options (no bulk option exists as a
choice at all).

- `Approve all N mechanical-only items`: mark every `mechanical` item approved; every
  non-`mechanical` item still falls through to Stage B below.
- `Decline all`: mark every item declined; still surface the Discrepancies block, then proceed
  directly to the refusal/record stages (an all-decline run records nothing to approve, but the
  presented sidecar and Notes are still written honestly).
- `Step through every item`: no items are pre-decided; every item goes to Stage B.

**Stage B — per-item step-through walk**: for every item not already decided by a Stage A bulk
approval, ask one question per item, always exactly four options:
`Approve` / `Decline` / `Discuss this item` / `Decide later`.

- `Discuss this item` (**Escape 1**): drop out of the structured prompt into ordinary
  conversational discussion of that item's diff, classification, recommendation, and
  confidence (drawn from `$classification_path` and `$review_path` — never fabricated). When
  the owner signals readiness, re-issue the **identical** Stage B question for that item. The
  item's decision stays `no decision yet` until an actual `Approve`/`Decline` answer lands.
- `Decide later`: leave the item undecided; it stays `no` in the Decisions block and is named
  as undecided in the final report.

As each question is answered, append its literal question text and the owner's literal answer
to an in-memory transcript (this becomes the `Question:`/`Answer:` Notes lines at Stage 10 and
the answer-file contents at Stage 9) and record the per-item decision.

Write `$presented_path` once the walk concludes, carrying at minimum:
```json
{
  "discrepancies": ["<every id from Stage 5's Discrepancies block>"],
  "items": [{"id": "...", "class": "...", "recommendation": "...", "confidence": "...", "decision": "approve|decline|undecided"}],
  "transcript": [{"question": "...", "answer": "..."}]
}
```

## Stage 9: Run the Four Guards

Write the accumulated transcript to a scratch answer file (`Question: ...` / `Answer: ...`
lines, one pair per transcript entry — or, for a Stage-A-only bulk run, the bulk question and
answer) **before** touching the review file itself, so the human-attachment check runs against
real, already-collected evidence rather than evidence this stage invents to pass itself:

```bash
bash .claude/scripts/approve-guard.sh --check-surfaced --classification "$classification_path" --presented "$presented_path"
bash .claude/scripts/approve-guard.sh --check-freshness --classification "$classification_path"
bash .claude/scripts/approve-guard.sh --check-human --answer-file "$answer_scratch_file"
bash .claude/scripts/approve-guard.sh --check-labels --approver "$owner_label" --assisted-by "$assisted_by_label"
```

Any non-zero exit stops the run here: report the named refusal verbatim, leave the review file
untouched, and record nothing. `$owner_label` is resolved from the repository's own git identity
(`git config user.name`/`user.email`, formatted `"Name <email>"`) and is **never** suffixed
`(agent)`. `$assisted_by_label` names this skill/agent, formatted `"<agent name> (agent)
<email>"`, and **always** carries the `(agent)` suffix.

## Stage 10: Edit the Review File

For every item decided `approve` in Stage 8, flip its `## Decisions` line's leading `no` to
`yes` — editing nothing else on that line. Under `## Notes`, write the transcript collected in
Stage 8 as `Question:` / `Answer:` line pairs, verbatim, per `approve.sh`'s own `--via-prompt`
grammar (it greps `^Question:`/`^Answer:` out of `## Notes` and refuses when either is absent —
this is the external, independent backstop behind this skill's own Stage 9 `--check-human`).

## Stage 11: Record

```bash
bash "$(git rev-parse --show-toplevel)/components/$component/approve.sh" \
  --record "$review_path" \
  --approver "$owner_label" \
  --via-prompt \
  --assisted-by "$assisted_by_label" \
  "${component_flags[@]}"
```

**Never pass `--agent`.** The approver is always the owner; this command is always only
`assisted_by`. Propagate a non-zero exit verbatim and never retry through another channel — a
failed record here is reported exactly as `approve.sh` reported it, not silently re-attempted.

## Stage 12: Report

Tell the owner: what was recorded (by id), what was declined (by id), what was left undecided
(by id, from `Decide later` or an all-decline run), and the three artifact paths from Stage 6.

## No Self-Approval, Stated Plainly

There is no code path in this skill that records the agent as approver. `--agent` is never
passed to `approve.sh --record`; the approver string is always the owner's own git identity,
never `(agent)`-suffixed; the assisted-by string always is. If Stage 2 or Stage 9 refuses,
nothing is recorded — the run stops and reports, it does not fall back to a weaker channel.
