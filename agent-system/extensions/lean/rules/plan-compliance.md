---
paths: "**/*.lean"
---

# Plan Compliance Rules

## Path Pattern

Applies to: **/*.lean

## Core Principle

When an implementation plan exists for a `.lean` file, the plan is the contract. The agent's
job is to execute the plan's task sequence, not to re-derive its own decomposition. A plan
already reflects deliberate choices about lemma structure, proof order, and scope; discarding
that work mid-implementation to substitute a different approach destroys the planning investment
and produces divergent, hard-to-review proofs.

Motivation: repeated observed failures in formal-proof implementation, where an agent produced
many successive plan revisions because each implementation dispatch re-derived its own
decomposition instead of executing the existing plan's task sequence — discarding prior planning
effort every cycle.

## Forbidden Patterns

The following rationalizations are explicitly banned when a plan exists for the file being
edited:

- **Assessing what's "truly minimal"** — the plan already made this judgment; re-assessing it
  mid-implementation is scope renegotiation, not execution
- **Inventing an alternative approach** — do not substitute your own proof strategy for the
  plan's specified one, even if you believe yours is better
- **Skipping intermediate theorems** the plan specifies, to jump directly to a final result
- **Inlining proofs** instead of following the plan's decomposition into named lemmas
- **Routing through different helper lemmas** than the plan specifies
- **"Cleaner approach" rationalizations** — a cleaner-seeming shortcut discovered mid-proof is
  not license to abandon the plan's decomposition
- **Weakening a recorded Challenge statement** — adding a hypothesis, specialising a quantifier,
  or restating a strictly weaker claim under the same name. See "Statement Fidelity" below.

## Statement Fidelity

Everything above governs *decomposition* fidelity — following the plan's chosen lemma structure
and proof order. It says nothing about whether a declaration's *signature* is part of the
contract, which leaves a gap: a same-named, strictly weaker restatement of a theorem violates
nothing in the rule as written above, yet is a more serious defect than any decomposition
deviation, because it passes a name-existence check while proving less than what was intended.

**When a plan carries a `## Lean Challenge Statements` section** (see
`context/formats/plan-format.md`), the named declarations' **signatures** — not only their
identifiers — are part of the contract this rule enforces. The section fixes the exact intended
statement of each theorem before implementation begins; an implementation that proves a
same-named but different (typically weaker) statement has not executed the plan, regardless of
whether the declaration name matches.

**Mechanical check**: `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh --check`
compares each named theorem's pinned signature (recorded at snapshot time, before
implementation) against the current working tree's same-named declaration, independently of
whether Comparator is ever wired in — see
`context/project/lean4/domain/challenge-snapshot.md` for the full design. **Its verdict is
ADVISORY ONLY**: a drift finding from `--check` MUST NOT be treated as grounds to fail a task,
set `verification_passed` false, or downgrade a status on its own. Treat a `--check` drift
finding the same way any other plan-compliance concern is treated under this rule: as a signal
to investigate, not an automatic verdict.

**If a drift finding turns out to reflect a genuinely wrong recorded statement** (the plan
itself specified something that should not have been specified), the sanctioned route is the
same escalate-rather-than-substitute behavior this rule already mandates above: mark the phase
`[BLOCKED]` and raise it. Do not quietly change the implementation to match a different, more
convenient statement, and do not quietly edit the recorded Challenge to match what was
implemented — either move silently launders the exact defect this section exists to catch.

## Required Behavior

- Follow the plan's exact task sequence, step-by-step, in the order given
- Implement each specified lemma/theorem as its own step, even if a later step could subsume it
- If a step genuinely cannot be completed as written, stop and escalate (see below) rather than
  silently substituting a different step

## Relationship to Plan Deviations

`general-implementation-agent.md` and `cslib-implementation-agent.md` document a sanctioned
"Plan Deviations" mechanism: an implementation agent may skip, alter, or defer a plan step with
only a post-hoc inline annotation, no pre-approval gate. **For files matching this rule's glob,
that mechanism is not a substitute for compliance.** A would-be deviation on a `.lean` file must
first be raised as a blocker to the user — mark the phase `[BLOCKED]` and explain what was tried
and why the plan step cannot be executed as written. Do not silently annotate and proceed past
it. This narrows the general policy for formal-proof files only; the general policy remains
unchanged for all other file types.

## Related Context

- **Literature Fidelity** (`lean4.md`): governs following a *literature source* (paper,
  textbook). This rule governs following the *plan*. Both matter and neither substitutes for
  the other — a task can have a literature source, a plan, both, or neither.
- **H2 anti-analysis** (`anti-analysis.md`): governs pace and analysis-output ratio, gated
  behind `--hard`. This rule applies unconditionally, in every mode, whenever a plan exists.
