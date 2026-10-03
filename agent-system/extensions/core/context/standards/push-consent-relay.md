# Push-Consent Relay

## Overview

A dispatched agent cannot call `AskUserQuestion` — verified empirically (a `ToolSearch` for it
from inside a dispatch returns no matching deferred tool). So when a dispatched agent's
sanctioned endpoint genuinely is a push (not a routine "it would be nice to push" impulse — see
"When This Does NOT Apply" below), it cannot ask the human directly and cannot mint a grant
itself (only a literal human prompt submission can — see `hooks/please-grant.sh`). This document
specifies the one channel that exists for this case: the agent emits a `user_decision` (per
`context/standards/user-decision-contract.md`), and the orchestrator relays it, unchanged, at the
next natural batching point. **The relay never mints anything.** A YES answer tells the human the
exact `/please` line to type; the human's own prompt submission is the only mint path, now as
always.

This closes the `.decisions.json` replay hazard by construction, not by special-casing: nothing
replayable is ever recorded, because authorization never lives in `.decisions.json` to begin
with — it lives only in a single-use, SHA-bound grant token that is consumed or expires within
600 seconds. See "The `.decisions.json` Replay Hazard" below for why this had to be verified, not
assumed.

## The Request: a `user_decision` Naming the Exact Push

The qualifying shape is `context/standards/user-decision-contract.md`'s enumerated shape 2,
verbatim: "An external cost or risk the user must accept — spending money, granting a
credential, deleting data, or taking an action outside this repository that the agent cannot
verify is already sanctioned." A push to a remote is squarely an action outside this repository.

`options[]` entries are flat strings with no `description` field (confirmed during research —
`user_decision`'s schema has no such field), so each option string must be self-describing. The
target must be legible from the option text alone:

```json
{
  "user_decision": {
    "question": "This task's sanctioned endpoint is pushing feature-x to origin (a1b2c3d, 3 commits ahead, no force). May I request authorization?",
    "options": [
      "Grant via /please push origin feature-x (a1b2c3d, 3 commits ahead, no force)",
      "Do not authorize; the task stops at its current commit"
    ],
    "recommended": "Grant via /please push origin feature-x (a1b2c3d, 3 commits ahead, no force)",
    "blocking": true
  }
}
```

`question` names the exact target (remote, branch or tag, short SHA, commit count, force-or-not)
— a vague "may I push?" the guard would then have to interpret broadly defeats the entire design;
consent to an unspecified push is not consent. If the force form matters, say so explicitly in
both `question` and the affirmative `options[]` entry.

## `blocking` Is Always `true` For This Class

The non-blocking path (`blocking: false`) proceeds on the agent's own `recommended` pick as if
the user had already chosen it — for a push request, that would mean the agent authorizing its
own push, which is exactly the inversion this entire mechanism exists to prevent. **A push-class
`user_decision` with `blocking: false` is a contract violation**, not a looser variant. Enforce
this in the agent-facing text of any skill or agent doc that might emit this class of decision.

## The Return Leg: a YES Mints Nothing

There is no existing precedent for this leg — the relay channel, before this document, only ever
surfaced decisions for the user's *awareness*; it never needed to hand back an authorization
token a later subprocess could consume. The design choice here is to introduce no new token path
at all:

- A YES answer's relayed text tells the human the exact `/please` line to type (the `options[]`
  entry the user picked already IS that line, verbatim, by construction — see the example above).
- The human then types it themselves, in their own next turn. That literal prompt submission is
  what `hooks/please-grant.sh` mints from — exactly the same mint path as any other `/please`
  invocation, with no distinction for "came from a relay."
- A NO answer, or the run ending before any answer, both leave the task in exactly the same
  state: no grant exists, so `guard-git-push.sh`'s default-deny blocks any push outright. Neither
  case needs special-casing in the relay path — the guard's fail-closed default already
  guarantees the outcome.
- A grant minted this way is bound to the commit SHA, remote, branch/tag, and force-or-not at the
  moment the human typed `/please`, expires in 600 seconds, and is deleted (and ledgered — see
  `push-grant-lib.sh`'s consumed-HMAC ledger) on first use. It therefore never carries across a
  later orchestration cycle, consistent with Phase 2's one-push grant scope: a cycle boundary is
  not special here, the same 600-second expiry and delete-on-use apply whether or not a cycle
  happened to end in between.

## The `.decisions.json` Replay Hazard

`docs/architecture/handoff-schema.md` documents `.decisions.json` as additive, per-task, and read
back by `orchestrate-build-dispatch.sh` into a `## Prior Decisions` section injected into every
later dispatch for that task — a deliberate, desirable mechanism for ordinary design decisions
("don't re-ask a question already answered"). This is dangerous for a push authorization
specifically: a recorded `{question: "...", answer: "Grant via /please push origin
feature-x..."}` pair, replayed verbatim into cycle N+1's dispatch context, would read exactly
like standing prior approval — precisely the failure the task's requirement forbids ("permission
must never be inferred from a prior approval in another context").

**This is resolved by construction, not by a special case carved into
`orchestrate-build-dispatch.sh`.** The `## Prior Decisions` renderer is deliberately **not**
modified to exclude this decision class, and this is safe because of what actually gets
recorded: the answer text is informational ("the user was told to run `/please push origin
feature-x`"), never an authorization — authorization lives only in the single-use,
SHA-bound grant token, which `guard-git-push.sh`/`git-push-granted.sh` consult, and which
`orchestrate-build-dispatch.sh` never reads. A cycle N+1 dispatch that inherits the `## Prior
Decisions` text containing that exact line gains nothing actionable from it: no grant file
exists (it was deleted on first use, or it expired after 600 seconds, or — if the human never
typed `/please` at all — it was never minted), so the guard's default-deny fires exactly as it
would for a task with no decision history at all. See the two-cycle test in
`scripts/tests/test-orchestrate-build-dispatch.sh` (Phase 12 of the implementing plan) for the
executable proof: cycle N's decision is recorded and rendered into cycle N+1's dispatch, and
cycle N+1 still cannot push without a fresh `/please`.

## When This Does NOT Apply

The orchestrator never asks on its own, and never decides on the user's behalf; agents decide
everything else themselves. A push-consent request is not a prompt agents raise reflexively —
most tasks never reach this shape at all. It qualifies only when:

- A push is genuinely the task's sanctioned, already-determined endpoint (not a speculative "it
  would be nice to also push this").
- The agent cannot itself verify the push is already sanctioned by an existing grant (if a grant
  already exists and matches, the agent should simply route the push through the sanctioned
  wrapper — no decision needed).
- Routine exploratory or mid-implementation git operations (commits, branch creation, local
  resets under their own grant path) never qualify — only the final, deliberate "this needs to
  leave the repository" moment does.

## References

- `context/standards/user-decision-contract.md` — the general `user_decision` field contract
  this document specializes for the push-consent case.
- `context/formats/return-metadata-file.md`'s `user_decision` subsection — field shape and
  mirroring onto `.orchestrator-handoff.json`.
- `docs/architecture/handoff-schema.md` — `decisions_made`/`.decisions.json` schema and the
  `## Prior Decisions` renderer this document explains is deliberately not special-cased.
- `hooks/please-grant.sh`, `hooks/guard-git-push.sh`, `scripts/lib/push-grant-lib.sh`,
  `scripts/git-push-granted.sh` — the mint/guard/wrapper mechanism this relay's YES answer
  ultimately leads to.
- `rules/pr-prohibition.md`'s "Scoped exception" subsection — the policy statement this
  mechanism implements.
