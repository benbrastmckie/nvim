# Decision Record: A Review Slice Is a Declared Task, Not an Inferred Range

This record rules how landed work becomes a stack of pull requests. It amends
`specs/decisions/isolation-off-landing-verification-and-review-time-squash.md` (the "landing
record") in the places listed under "Assertions amended". It does not disturb the landing
record's verification predicate V1 to V5, its landing proof, or its retirement order, all of
which stand as written.

Decided 2026-11-23 by operator direction, in session `sess_1795472390_63c292`, after the
restack element of `stack_pr_submission_from_integration_branch` landed and its remaining
elements were reviewed for cost against value.

This record rules. It builds nothing.

## The contradiction

The landing record rules that phase commits stay on the integration branch as made (L1), that
the reviewable unit of a task is its attributed commit set rather than one commit (L3), and that
one commit per task is produced **at review time, on a review ref, by plumbing** (L4). Its
"Interface to review submission" states the consequence plainly: what the review step receives
is "not a range per task" but "one proof per task", and to the question "Whether it is one
commit per task" it answers "No."

A review step bound by that interface must reconstruct review units from history it did not
shape. `review-stack-prepare.sh` does so: it groups tasks into connected components over
dependency edges and landing-proof path overlap, orders each component topologically with
ancestry tie-breaks, refuses when the edges contradict the landed order, overlays each unit on
`merge-base(review_base, integration_branch)`, and moves commits onto a moved base with a
three-way `merge-tree`. That machinery is the direct and correct consequence of L4. It is not
accidental complexity.

The reconstruction has a floor the landing record states and measures:

> A task whose proof has a non-empty `shared_paths` cannot be separated exactly by path: its
> overlay carries the other writer's lines in those files. Four of fourteen measured tasks had
> one.

For those tasks the review step must choose between shipping another writer's lines, naming them
as contamination in the pull-request description, or merging the units. No refinement of the
inference removes the choice, because the information that would decide it was destroyed when
the work landed interleaved. Roughly three tasks in ten arrive irreducibly entangled.

## Ruling

**S1. The reviewable unit is declared before the work, never inferred after it.** A review
slice is a task record. Its boundary is fixed at slice-creation time by a proposal a human
approves. No slice boundary is derived from path overlap, dependency-edge topology, or commit
ancestry.

**S2. A slice is not the task that did the work.** One slice may carry one task, several tasks,
or part of one task. Decoupling the review unit from the development unit is the point: a slice
drawn to contain both writers of a shared path is clean by construction, so the `shared_paths`
floor above does not arise. The entanglement is priced once, when the slice is proposed, by
someone who can see it.

**S3. The two branch roles are already declared and do not change.** `integration_branch` is
the branch orchestrated work is built on, with phase commits, bookkeeping commits and other
sessions' commits interleaved, exactly as the landing record describes. `review_base` is the
branch slices target. Both are top-level keys in `.claude-extensions.json`, documented in
`context/standards/repo-level-declarations.md`. A repository whose `review_base` equals its
`integration_branch` is refused and gets no slices. This is the existing declaration schema,
affirmed rather than altered.

**S4. A slice lands by an ordinary scoped commit from a working tree.** This is the one
mechanism the landing record measured as working: "The only landing that worked was an ordinary
scoped commit of the task's paths from the working tree." A slice task commits its slice onto
its own review branch. Nothing is overlaid blob by blob, nothing is picked into a tree that
produced the commits, and no plumbing reconstructs a tree the operator never saw.

**S5. Stacking is by construction, not by recomputation.** Slice `N+1` branches from slice `N`
at creation. Order comes from the declared slice sequence, carried as `dependencies[]` edges
between the slice tasks, so the ordinary dependency-aware wave dispatch already serializes them
correctly and no separate topological sort exists. When slice `N`'s pull request merges, slice
`N+1`'s base changes on the forge by a base edit, not by rewriting local refs.

**S6. Proposal is a command; execution is ordinary orchestration.** A command reads the landing
proofs and the open task records, proposes slice boundaries with their contents and order, and
shows one approval prompt. On approval it creates one task per slice through the ordinary task
creation path, chained by `dependencies[]`. From that point the slices are ordinary tasks: they
are researched, planned, implemented and verified by the machinery that already exists. No
bespoke lifecycle is built for them.

**S7. The consent boundary is unchanged.** Every push stays behind a typed `/please`, every
forge call stays inside the user-invoked `/merge`, and no agent-reachable path pushes or opens a
pull request. `rules/pr-prohibition.md` binds unamended.

## What is retained from the inference route, and what is not

Working code is not deleted to make a point. Retained and still wired:

- The `review_base`, remote and platform resolvers in `review-stack-prepare.sh`, with their
  refusals. A slice needs a resolved base and a supported platform exactly as an inferred unit
  did.
- The manifest at `specs/.orchestration/reviews/<stack id>/manifest.json`, its body files, and
  `show`. Something must record what is in flight; a slice stack has the same need and the same
  shape.
- `record-request`.
- `restack`, including its compare-and-swap ref moves and its divergence refusals, demoted from
  the primary path to the recovery path for a stack cut by the inference route. S5 means a
  slice stack does not need it; a stack already cut by `cut` does.

Not built further:

- Unit inference by union-find over dependency edges and landing-proof path overlap.
- Topological reordering with ancestry tie-breaks, and the refusal when edges contradict the
  landed order.
- The overlay onto `merge-base(review_base, integration_branch)` and the moved-base three-way
  `merge-tree` recompute, as the route by which a review unit is first produced.
- A second-repository demonstration of the above, whose purpose was to show that the inference
  generalizes beyond the repository that developed it.

## Why not keep the inference route as the primary path

It works, it is tested, and three of its seven elements are landed. Three reasons it is still
not the primary path:

1. **The floor is structural.** Four of fourteen measured tasks cannot be separated by path.
   The inference cannot do better than present a contaminated commit and say so.
2. **It pays twice for the same judgment.** A human must adjudicate every entangled unit at
   review time anyway. Declaring the slice first moves that judgment earlier, where it is
   cheaper and where the person making it still remembers the work.
3. **Its remaining cost is concentrated in proving generality.** The unbuilt elements are the
   inference's own correctness argument, not capability the operator gains.

## Why not abandon the inference route entirely

A stack already cut by `cut` exists and its manifest is on disk. A repository that has not
adopted slices still has the inference route as its only path. Retaining the resolvers, the
manifest, `show` and `restack` costs nothing further and keeps both routes serviceable.

## Obligations on the implementing plan

- **Redeploy declaration.** Every plan authored in this territory so far declares the
  `__WHOLE_TREE__` sentinel for a redeploy phase, and the whole-tree admission gate serializes
  any batch whose members declare it. If each slice task declares a redeploy, an N-slice stack
  serializes into N cycles for no benefit. The plan must site the redeploy once per batch at the
  close rather than once per slice. `redeploy_phase_declaration_and_gate_criterion` (509) is the
  open record that owns the gate criterion.
- **Grant count.** An N-slice stack costs N typed `/please push` grants, each bound to `HEAD`
  when typed, inside a 600-second window, dying when any session commits in between. The landing
  record's own risk table already names this. The plan states the count in the printed output
  and does not design around it; a batch grant is worth more than any reduction in the plumbing
  and is not in this record's scope.
- **Slice proposal quality.** S6's proposal step is the whole value of this ruling, because a
  badly drawn slice reintroduces the entanglement S2 exists to prevent. The plan states what
  evidence the proposal shows the approver: at minimum each slice's contents, its order, and the
  paths it shares with any other proposed slice.

## Assertions amended

Each assertion below is amended for repositories that adopt declared slices. For a repository
still cutting by inference, the landing record stands as written.

| Landing record | Assertion | Now |
|---|---|---|
| L3 | The reviewable unit of a task is its attributed commit set | The reviewable unit is a slice, declared before the work. A task's attributed commit set remains the unit of *landing verification*, which is unchanged |
| L4 | One commit per task is produced at review time, on a review ref, by plumbing | One commit per slice is produced by a slice task, by an ordinary scoped commit (S4). The review ref is built forward, not reconstructed |
| Interface to review submission, "Whether it is one commit per task" | "No. It is one proof per task." | Still no, and still one proof per task. The proof is now an input to drawing a slice, not the thing a slice is reconstructed from |
| Interface to review submission, "How one commit per task is built" | The blob-overlay recipe, with tree equality as the check | Not the route by which a slice is first produced. Retained for a stack cut by inference |
| Interface to review submission, "The stated limit" | The review step must decide per entangled task between accepting co-landed lines, naming them, or merging the units | The decision moves to slice-proposal time, where a slice containing both writers is clean by construction (S2) |
| Stack-PR design record, PD3 | One task, built from its landing proof as one commit; two tasks become one unit when their proofs share a path | A slice is declared; its relationship to tasks is many-to-many (S2) |
| Stack-PR design record, PD5 | Tasks are grouped into connected components and ordered topologically, with a refusal on contradiction | Order is the declared slice sequence, carried as `dependencies[]` edges (S5) |
| Stack-PR design record, PD6 | Overlay each unit on the merge base; move onto the tip by three-way `merge-tree` | Not the primary route (S4) |
| Stack-PR design record, PD7 | Restack by local detection, descendant recompute and compare-and-swap | Retained as the recovery path for an inference-cut stack; a slice stack restacks by a forge base edit (S5) |

L1 and L2 are not amended: phase commits stay on the integration branch as made, and landing
remains a verification run before the completion status write. PD1, PD4, PD9, PD10, PD11 and
PD12 are not amended.

## What this does not deliver

The integration branch's history stays one commit per phase. A slice stack is a parallel history
built for one review, as the landing record already accepted for the review ref.

This record does not name the proposal command's own surface beyond S6, does not rule how a
slice task's working tree is arranged, and does not reinstate worktree isolation. Isolation
stays deferred; whether declared slices make it attractive again is open work, and the five held
two-root and worktree records are the place it is judged.
