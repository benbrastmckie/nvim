# Approve Interaction Design

This is ONE ruling covering both the `AskUserQuestion` four-option cap and the step-through
walk with its two escapes. Scope item (3) (the option cap) and scope item (8) (the step-through
UX) are about the same interaction and are reconciled here, not left to contradict each other.

## Hard Rule: The Option Cap

`AskUserQuestion` takes at most four options per question. Items are **never** packed into
options. Item count changes the **number of questions** this flow asks, never the number of
options on any one of them. A nineteen-item cycle is nineteen (or fewer, see Stage A) per-item
questions, never one question with items as its options.

## Stage A: Bulk Triage Gate

One question, with the per-item walk always available and the bulk approve-all option
**offered only when safe**:

| Option | Meaning |
|--------|---------|
| `Approve all N mechanical-only items` | Only present when `N >= 1` — see "Option-Availability Gating" below |
| `Step through every item` | Always present |
| `Decline all` | Always present |

Three options when the bulk option is offered, two when it is not — never four, since no
fourth meaning is needed here.

### Option-Availability Gating

The bulk option is **offered only when** `approve-classify.sh` mechanically cleared at least
one item (class `mechanical`, confidence `MEASURED` or the narrow boilerplate `INFERENCE` bar —
see `confidence-vocabulary.md`). This is **option-availability gating**: an unsafe option does
not exist as a choice at all, rather than being offered and then filtered or double-checked
after the fact. Its correctness rests on each cleared item's own `MEASURED` or bounded
`INFERENCE` fact, individually, not on a sample. An item the classifier cannot mechanically
clear is excluded from the bulk count entirely and falls through to Stage B regardless of what
the owner picks in Stage A.

## Stage B: Per-Item Step-Through Walk

One question **per remaining item**, exactly four options every time:

| Option | Meaning |
|--------|---------|
| `Approve` | Record this item as approved |
| `Decline` | Record this item as declined |
| `Discuss this item` | Escape 1 — see below |
| `Decide later` | Leave undecided |

"Remaining item" means: every item not already approved via the Stage A bulk option (if chosen)
plus every item Stage A's bulk count excluded (declaration-level, needs-full-text, or any item
the owner chose to step through instead of bulk-approving).

`Decide later` leaves that item's `## Decisions` line at `no` and names it as undecided in the
final report — it is not a silent skip.

## Escape 1: Conversational (Discuss This Item)

Selecting `Discuss this item` in Stage B drops the skill out of the structured
`AskUserQuestion` prompt and into ordinary prose discussion, in the root session, of that
item's diff, classification, recommendation, and confidence — exactly the detail the summary
contract otherwise keeps out of the structured question. Once the owner signals they are ready,
the skill re-issues the **identical** Stage B question for that item. The item remains
undecided (its Decisions line stays `no`) until an actual `Approve` or `Decline` answer is
given — a discussion is never itself a decision. This escape works only because `skill-approve`
runs in the root session, per `README.md`'s "Why `/approve` Is Never Dispatched".

## Escape 2: Open the Files Directly

This escape **consumes no option on any question**. It is a property of the persisted,
predictable, tracked artifact path from `approval-artifact-convention.md`, not of any menu.
`skill-approve` prints the review path and both sidecar paths **before** Stage A ever runs, and
repeats the review path in every Stage B question's own text, so the owner can open and read
the files unmediated at any point in the walk — whether or not a question is currently pending.
Because the escape needs no option, it never competes with the option budget either stage
actually requires.

## Rejected Alternative: Batching by Module Family

Considered and rejected: grouping items into `AskUserQuestion` options by module family (e.g.
one option per subsystem) to stay under the four-option cap without a bulk/step-through split.

Rejected because a family batch re-introduces exactly the averaging the summary contract
(`confidence-vocabulary.md`) forbids — one decision standing in for several items whose
discrepancies may differ from each other — and it buys nothing: the option cap constrains
**options per question**, not **questions per run**, so a family batch does not actually save
any interaction budget over the bulk-gate-then-step-through design above. The number of
questions a nineteen-item cycle costs is bounded by the number of items, not by the number of
options per question either way.
