# Approvals Detection: Recognizing "a Person Needs to Approve Something"

A component gate's approvals stage can fail for many reasons. This document pins the one
narrow failure mode that means **a person needs to approve something** — distinguished from
every other way the same stage can go red — and records the ruling for where that recognition
lives, the options offered, their semantics, and the prohibitions that keep the offer honest.

## The ruling: detection lives in the books agent definitions, not postflight

**The seam is the books implementation agent definition** (`books-implementation-agent.md` — the
sole surviving books implementation agent; its retired `-hard`-suffixed counterpart carried the
identical detection logic before `--hard` moved to `hard_contracts` contract injection on this
same agent), never `orchestrate-cycle-postflight.sh`, and never both.

**Reason, which is the durable part**: postflight's verdict derivation is a flat lookup from the
agent's own reported `status` string (plus a small set of fixed artifact/git probes) and has no
access to a dispatch's raw gate command output — so "postflight classification" presupposes a
signal postflight structurally does not have. Separately, `context/standards/
user-decision-contract.md` makes `user_decision` **producer-owned**: the agent that sets it is
the one deciding, and every later writer in the same invocation must relay it untouched. A
postflight-side classifier that *originated* a `user_decision` from raw output it was never
designed to see would be the orchestrator deciding what counts as an approval need — the exact
inversion the contract's opening sentence rules out ("The orchestrator never asks the user on
its own, and never decides on the user's behalf"). "Both" collapses to "agent only" plus
redundant, never-exercised machinery in postflight.

The agent recognizes the condition at the point it runs the gate, and shapes its own return —
nothing more.

## The pinned signature

Read from `/home/benjamin/Projects/Logos/Verification/components/framed_channel/` on
**2026-10-17**: `check.sh` and `check-approvals.sh`. This is an external repository's source,
pinned here with its read date because this corpus has no other way to track its drift.

- `check.sh` runs the approvals stage **last**, under an `== approvals ==` header, and on
  failure prints the literal line
  `check.sh: FAIL at the final stage, approvals; every earlier stage passed`, then exits 1. That
  line is the **stage-attribution line** — corroboration that the failure that just happened was
  specifically the approvals stage.
- `check-approvals.sh` exits `0` current, `1` "a record is absent or stale", `2` usage error or
  missing prerequisite.
- **Exit 1 alone is not the signal.** It also covers a malformed approvals file, a
  `spec-check.sh` failure, record-consistency errors, and the `--require-person` policy refusal.
  The distinguishing marker is the **message text**, and all of it is on **stdout** — its
  `fail()` helper and the absent-file branch both `echo` without redirection; only usage errors
  go to stderr. A recognizer that reads stderr for this signal will see nothing.

### Recognized: the six absent-or-stale families — "a person needs to approve"

| # | Message family (the literal text to match) |
|---|---|
| 1 | `[FAIL] approvals: <file> does not exist. No selection or specification has been approved.` |
| 2 | `[FAIL] approvals: no selection record (the selection has not been approved)` |
| 3 | `[FAIL] approvals: the selection is stale: the Rust changed since it was approved (source_sha256 recorded …` |
| 4 | `[FAIL] approvals: the selection is stale: the candidate set changed since it was approved (candidates_sha256 recorded …` |
| 5 | `[FAIL] approvals: the specification <M> is stale: it changed since it was approved (spec_digest recorded …` |
| 6 | `[FAIL] approvals: no specification record for <M> (its current spec_digest is <D>): it has not been approved` |

### Excluded: same stage, same exit 1, but "something is broken" or a policy refusal

Deliberately **not** recognized as an approval need — a build/record/consistency problem, not a
missing human decision:

| Excluded family (the literal text, or its distinguishing substring) | Why excluded |
|---|---|
| malformed `by`/`approver`/`confirmed_via`/`assisted_by` records | the record is broken, not absent |
| `is both selected and declined` | a self-contradictory record, not a missing one |
| `is listed more than once` | a duplicate-record defect |
| `is neither selected nor declined` | a record-shape defect, not absence |
| `is selected or declined but is not an in-subset candidate` | a scope-consistency defect |
| `selected, but no registered statement is about it` | a cross-reference defect |
| `specified … but not selected` | a scope-consistency defect |
| `declined … has an empty reason` | a record-completeness defect |
| `names <M>, which is not a Challenge module` | a naming/scope defect |
| `SpecCheck reports no digest for it` | an upstream `spec-check.sh` failure |
| `the approvals file does not have the recorded shape` | a schema/parse defect |
| `spec-check.sh failed` | an upstream tool failure, not an approval gap |
| every exit-2 usage/prerequisite path | a usage error in the gate itself |

### `--require-person` is excluded, with its reason stated

`[FAIL] approvals: <what> was approved by an agent (<approver>), and --require-person is set`
genuinely does mean a person must approve — but the records are present and current. It is not
the **absent-or-stale** mode this task is scoped to ("that specific failure mode", per the
originating dispatch). Excluding it is a deliberate scoping decision, not an oversight. It is
recorded here as a **candidate follow-up**, not silently folded into the recognized set: a
future task could add a second recognized class for "approved, but by an agent, and a person is
required" — distinct wording, distinct semantics (the records are not absent-or-stale; nothing
needs re-approving, a person simply needs to countersign) — but this task does not build it.

### Mixed reds are honest, not suppressed

The classes above are not mutually exclusive. When a recognized absent-or-stale family matches
**and** an excluded family also matches in the same captured output, the offer is still made
(the approval need is real), and the recognizer's `question` text names plainly that other
approvals failures are present too — so the owner is never misled into thinking that review
alone will turn the leg green.

## The three options and their exact semantics

Three options, always offered together, never fewer:

1. **Enter review now** — relays the exact command line for the owner to type themselves in
   their own next turn (see "Hand-off design" below). This option is never a silent default:
   nothing acts on it without the owner's own keystroke.
2. **Defer** — the need survives the deferral. It is raised again on the next run that hits the
   same red. Deferring consumes nothing; it costs nothing; it is fully reversible.
3. **Decline** — leaves the approval records exactly as they are: absent-or-stale. The gate leg
   stays red. **This is the honest outcome, and it is the required one**: the owner chose not to
   approve right now, which is not the same as the approval not being needed.

**Declining MUST NEVER silently self-approve and MUST NEVER downgrade the approval requirement.**
Any implementation in which declining turns the leg green, suppresses the requirement, weakens
it to a warning, or marks it waived is wrong. The records stay absent-or-stale; the gate stays
fail-closed. Nothing today reads a recorded "decline" or "defer" answer as evidence the
requirement is satisfied — `.decisions.json` is purely informational and is read by no guard or
gate.

**MUST NOT (stated explicitly, not left implicit):** a recorded decline or defer is never read
by any check, guard, or gate as evidence that the approval requirement is satisfied, waived, or
downgraded. The real risk this guards against is a *future* implementer adding a
`.decisions.json`-reading shortcut that treats a recorded answer as a green light; this
prohibition exists so that a later editor who considers such a shortcut finds this sentence
first.

## `blocking: false`, `recommended` = the defer option

Per the `user_decision` schema (`context/standards/user-decision-contract.md`), this offer is
emitted with `blocking: false` and `recommended` set **verbatim** to the defer option's own
string.

**Reason**: "Enter review now" cannot be a silent default — nothing can act on it without the
owner's own keystroke, so recommending it non-blockingly would be procedurally meaningless (the
orchestrator cannot type `/approve` for the owner). "Decline" must never be chosen for the
owner — the honesty requirement here reads as "the owner must affirmatively decline," never as
"the system defaults to declining on the owner's behalf." "Defer" is the one option that is free
to take as a default: it is fully reversible, costs nothing, and matches
`user-decision-contract.md`'s own description of what `blocking: false` is for — proceeding on
the agent's best judgment when nothing is lost if the owner later disagrees.

## Hand-off design: a relayed command line, never an auto-invocation

The accepted ("enter review now") option **never auto-invokes `/approve`**. It relays the exact
`/approve <component> [--task N]` line (or, when the `/approve` surface is not deployed in this
repository, the component's own `approve.sh --review …` / `approve.sh --record …` lines) for the
owner to type in their own next turn — reusing `context/standards/push-consent-relay.md`'s
YES-mints-nothing design.

**Three independent reasons this is the only mechanism that works, not merely the most
convenient one:**

1. `/approve` is direct-execution only (see `skill-approve/SKILL.md`'s own Stage 2) — there is no
   programmatic entry point a dispatched agent could call even if it wanted to.
2. `AskUserQuestion` is withheld from every dispatched subagent (empirically verified by
   `push-consent-relay.md`'s own research) — a dispatched agent cannot prompt the owner directly
   regardless of what it wants to offer.
3. No review logic is duplicated: `/approve` owns diff classification, the summary contract, and
   the step-through approval UX in full (per the companion task's scope). This recognizer and
   the agent instruction that calls it emit a question and a command line; they do not run, nor
   re-implement any part of, the review itself.

## The no-human case: stop and report, never answer on the owner's behalf

An autonomous dispatch with **no human attached** must **stop and report**, never answer this
prompt on the owner's behalf. It does not pick a default, does not auto-defer silently, and does
not auto-decline as a convenience.

This mirrors `skill-approve/SKILL.md`'s own Stage 2 refusal exactly: on `orchestrator_mode:
true`, `/approve` itself stops immediately and reports plainly — *"`/approve` requires a human at
the keyboard; this dispatch is autonomous and cannot proceed"* — rather than weakening the
channel by guessing, defaulting, or silently skipping to a no-op success. The same condition
must produce the same behaviour on both surfaces, and it does **by construction** here: this
recognizer never auto-invokes `/approve` (see "Hand-off design" above), so there is no action to
take on the owner's behalf in the first place — it only emits a `user_decision` object that the
existing Move 3/Move 4 relay carries to the root session. If no human is ever there to answer it,
nothing happens beyond the honest-red outcome ("decline" produces) — the same outcome as if the
owner had explicitly declined. No default is picked, no silent auto-defer or auto-decline
occurs; the dispatch simply reports the gate red exactly as it is and the offer waits.

## Summary: what this document pins, for a future reader

- **D1**: the detection seam is the books agent definitions, not postflight, with the reason
  above.
- **D2**: the pinned six-family/excluded-family signature, read 2026-10-17, with its stage
  attribution line and the stdout-not-stderr detail.
- **D3**: detection is implemented as a read-only recognizer script
  (`scripts/books-approvals-signal.sh`), not prose alone — because the acceptance bar requires
  demonstrated-not-asserted and testable clauses prose cannot satisfy.
- **D4**: the recognizer lives in the books extension, consumed by the books implementation
  agents.
- **D5**: `user_decision` shape — `blocking: false`, `recommended` byte-equal to the defer
  option, for the reasons above.
- The never-suppress MUST NOT block, and the no-human stop-and-report ruling mirroring
  `skill-approve`'s own Stage 2 refusal.

## Related

- `domain/gate-tiers.md` — the `full-gate.sh` tier's Checks row now names the approvals stage;
  this document is its `Related` pointer's target.
- `context/standards/user-decision-contract.md` — the general `user_decision` field contract.
- `context/standards/push-consent-relay.md` — the YES-mints-nothing relay design this reuses.
- `agent-system/extensions/approvals/skills/skill-approve/SKILL.md` — Stage 2's own
  `orchestrator_mode: true` refusal, mirrored above.
