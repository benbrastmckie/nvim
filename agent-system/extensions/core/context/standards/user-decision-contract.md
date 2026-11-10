# User-Decision Contract

## Overview

`/orchestrate` runs without confirmation gates between phases. This contract governs the one
narrow channel through which a human's judgment can still reach the loop: an agent-authored
`user_decision` field, relayed by postflight, never invented or requested by the orchestrator
itself.

**The orchestrator never asks the user on its own, and never decides on the user's behalf.**
Agents decide. Every decision an agent makes — including ones a human might have made
differently — is recorded with its reasoning in the agent's own artifact (report, plan, or
summary), exactly like any other design decision. This is the default path and covers the
overwhelming majority of choices an agent makes during research, planning, or implementation.

## When an Agent Sets `user_decision`

Only when a choice genuinely requires the user's judgment — never as a substitute for the agent
making its own call. Three shapes qualify:

1. **A preference the artifacts cannot infer** — two (or more) reasonable designs exist, and
   nothing in the task description, prior artifacts, or codebase conventions favors one over the
   other for reasons other than taste.
2. **An external cost or risk the user must accept** — spending money, granting a credential,
   deleting data, or taking an action outside this repository that the agent cannot verify is
   already sanctioned. A git push is the canonical instance of this shape — see
   `context/standards/push-consent-relay.md` for the full specialized contract (always
   `blocking: true`, self-describing `options[]`, and why a YES never mints anything itself).
3. **An ambiguity research cannot resolve** — the task description is genuinely underspecified in
   a way no amount of further codebase exploration would settle.

A choice that research, convention, or the existing codebase already answers is NOT a
`user_decision` — the agent decides and records it. See "When NOT to Raise One" below for the
common false positives.

## Field Shape

Set on `.return-meta.json` (always) and, when the same dispatch also writes
`.orchestrator-handoff.json`, mirrored there under the same key:

```json
{
  "user_decision": {
    "question": "One or two sentences naming the exact choice.",
    "options": ["Option A — one line", "Option B — one line"],
    "recommended": "Option A — one line",
    "blocking": false,
    "obligation": "The specific obligation the recommended route is claimed to discharge."
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|--------------|
| `question` | string | Yes | The exact choice, stated once, not restated per option |
| `options` | array of strings | Yes | Every option genuinely on the table (2+) |
| `recommended` | string | Yes | The agent's own best-judgment pick, one of `options` verbatim |
| `blocking` | boolean | Yes | Whether the loop must stop and wait, or may proceed on `recommended` |
| `obligation` | string | **Required for a ROUTE decision**, omitted for a pure-preference decision | The specific obligation the recommended route is claimed to discharge, named concretely enough that the receiving agent can check it against the phase's own artifacts |

A decision is a **ROUTE decision** when the question is "which way do we go to get past this
obstruction" — the options are candidate ways around a concrete blocker, and one of them is about
to be acted on as if it resolves that blocker. A decision is a **pure-preference decision** when
the question is "which of these equally-workable things do you want" — nothing is being resolved,
only chosen. `obligation` is required for the former and omitted for the latter.

**Downstream path**: `orchestrate-cycle-postflight.sh` relays the whole `user_decision` object
verbatim into the `ask_user` verdict (it neither validates nor strips unknown keys), the loop's
batched relay (`skill-orchestrate/SKILL.md`'s Move 4) passes the recorded `obligation` value to
`orchestrate-record-decision.sh`'s `--obligation` argument when present, and the dispatch
composer (`orchestrate-build-dispatch.sh`) renders the stored value into the next dispatch's
`## Prior Decisions` section for the receiving agent to verify.

## Blocking vs. Non-Blocking

- **Non-blocking** (`blocking: false`): the agent proceeds on `recommended` as if the user had
  chosen it, completes its dispatch normally, and the decision is surfaced for the user's review
  at the next natural stopping point. Use this for reversible choices where proceeding on the
  agent's best judgment costs nothing if the user later disagrees.
- **Blocking** (`blocking: true`): the agent stops cleanly at a resumable point (per this
  extension's existing wrap-up/handoff conventions — see `context/contracts/wrap-up.md`) rather
  than guessing. Use this only for irreversible or costly choices (external cost/risk, the second
  qualifying shape above).

## How the Field Is Relayed

The postflight script reads `user_decision` off `.return-meta.json` (or the handoff, when
present) and relays it as an `ask_user` verdict for the invoking command/skill to surface. The
orchestrator's own lead prompt logic puts the question to the user exactly once, batched at the
end of the current cycle — never mid-dispatch, and never by re-deriving or rephrasing the
agent's `question`/`options`/`recommended` text.

## Producer Ownership

`user_decision` is producer-owned by the agent that sets it, in the same sense
`context/formats/return-metadata-file.md`'s "Multiple Sequential Writers" section already defines
for `modified_files`, `completion_data`, `memory_candidates`, and `proposed_file_scope`: any later
writer in the same invocation (e.g. `skill-orchestrate`'s own postflight stage) MUST merge onto
the existing file and leave `user_decision` untouched rather than overwrite it.

## Distinction from `decisions_made`

`docs/architecture/handoff-schema.md`'s existing `decisions_made` field is **informational and
historical** — a list of settled questions so a downstream agent doesn't re-investigate them.
`user_decision` is the opposite in kind: a single, **live, forward-looking request** for the
user's judgment on a choice that is not yet settled. Do not populate `decisions_made` with a
pending question, and do not treat an entry in `decisions_made` as satisfying this contract.

## When NOT to Raise One

- The choice is a matter of code style, naming, or internal structure the codebase's own
  conventions already answer.
- The agent could resolve the ambiguity with a bit more reading, grepping, or reasoning — do
  that first.
- The "risk" is fully reversible within this repository (a file edit, a plan revision) — record
  the decision and its reasoning instead.
- The question is really "did I do this right" self-doubt, not a genuine fork in the road.
- A prior artifact in this task already answered the same question — cite it, don't re-ask.
- **The mirror-polarity self-check — an option set presented as open when it is not.** Before
  listing `options`, confirm that each one is not already structurally excluded by facts already
  present in the task's own artifacts (a prior report's or plan's findings). An option set
  asserted to have several live members when it actually has one is the same defect, in mirror
  image, as a route asserted to discharge an obligation it does not: both reach a dispatch
  carrying authority and no checkability. Worked shape: a plan proposes routing a proof through
  an intermediate lemma as an "implementer's call" alternative to a direct proof, when the
  intermediate lemma's own module already imports (directly or transitively) the module the
  direct proof would need — an import cycle the plan's own findings already record. There is only
  one live option, not two, and it should never have been offered as a choice.

This proposal-time self-check, and the `obligation` requirement above, are never a license to
re-litigate a question a prior cycle already recorded an answer to — see "Distinction from
`decisions_made`" above and the "## Prior Decisions" rendering's own "do not re-ask" instruction.
Both are checks the agent performs **before** raising a NEW question, not an invitation to
re-open a settled one. Relatedly: an agent's informed adjudication that a route recorded in an
earlier cycle does not actually discharge its stated obligation is the intended **working case**
for this contract, not a false refusal — the fail-open posture that governs *mechanical*
validation (no such validator exists in this pipeline) does not apply to an agent's own judgment
call.
