# Anti-Analysis Contract (H2) — Lean4 Override

This file overrides the core `anti-analysis.md` contract for Lean4 tasks.
It adds a formal proof line bar, lean-specific forbidden conclusions, and
sub-sorry policy enforcement for leaf-only sorries.

Base contract: `@.claude/context/contracts/anti-analysis.md`

## Formal Proof Line Bar (Lean4 H2 Enforcement)

The H2 read budget applies with a lean4-specific milestone requirement:

**The first sorry-free lemma MUST be proved within the first 30% of tool calls.**

This replaces the base contract's generic "first file creation within 20% of tool calls"
bar. For lean4 implementation dispatches, a file write that contains only `sorry`-stubs
does NOT satisfy the bar. A file write satisfies the bar only when at least one lemma
has a complete, sorry-free proof body.

**Enforcement**: If you have used 30% of your estimated tool call budget and every lemma
written so far contains `sorry`, you are in violation. Prove at least one complete leaf
lemma immediately before continuing with more complex goals.

## Lean4 Forbidden Conclusions

The following outputs are NOT acceptable as final deliverables from a lean4 implementation
dispatch (in addition to the base contract's forbidden conclusions):

1. "This theorem needs a different approach" — without stating the concrete type-mismatch
   (exact goal state, exact type of the proposed term, exact unification failure)
2. "The tactic failed but the approach is correct" — without a `lean_goal` state showing
   what remains and at least one alternative tactic attempt via `lean_multi_attempt`
3. "Mathlib likely has a lemma for this" — without having called `lean_leansearch` or
   `lean_loogle` to find it
4. "This is a known issue with lean's elaboration" — without a minimal reproducer in
   `lean_run_code` demonstrating the issue

These are lean4-specific analysis-paralysis signatures. Dispatches that produce them
without accompanying proof progress have failed.

## Settled-Design Preamble for Lean4

At the start of each lean4 implementation dispatch, restate:

1. The proof strategy for this phase (direct, induction, contradiction, construction)
2. The tactic pipeline decided for the main goal (simp / omega / aesop / etc.)
3. Which sorries are inherited from the previous dispatch (cite the sorry_inventory)
4. What has been built and verified in prior phases (do not regress)

Example preamble:
```
Settled design for this phase:
- Strategy: structural induction on the list argument
- Tactic pipeline: intro + induction + simp [List.length_cons]
- Inherited sorries: none (prior phase had zero sorry at exit)
- Preserved: Ns.base_case (proved, committed in phase 1)
- Phase scope: Ns.inductive_step and Ns.main_theorem in Theories/Ns.lean
```

## Sub-Sorry Policy for Leaf Sorries

Leaf sub-sorries are permitted as progress markers under STRICT conditions:

**A sorry is a leaf sorry if and only if ALL of the following hold**:
1. It appears inside a `have` step or auxiliary `lemma` that is itself the argument
   to a larger theorem, NOT as the body of a top-level theorem
2. It has a comment: `-- sorry: assumes X; deferred because Y; next dispatch: Z`
3. It does NOT appear in the sorry_inventory of the final handoff as "main target"
   (it may appear as a leaf entry with `why_deferred` populated)

### Strategic main-target sorries (Lean4 skeleton division points)

A main-target-level `sorry` (i.e., a non-leaf sorry — the body of a top-level theorem,
lemma, or definition) is acceptable as a **strategic sorry** — a deliberate division point in
a skeleton, not an abandoned or stuck proof — ONLY when ALL five conditions hold:

1. **Deliberate division boundary**: The sorry marks a division point planned as part of a
   skeleton (e.g., from a hard-mode plan's phase/part breakdown), not a proof the agent got
   stuck on and gave up. An abandoned or stuck attempt is never strategic.
2. **Tightly scoped**: The placeholder is scoped to exactly one theorem, lemma, or definition
   — not an entire module, file, or multi-part goal.
3. **Documented**: The sorry's accompanying comment states (a) the assumption it stands in for,
   (b) why it was deferred rather than completed in this dispatch, and (c) the owning follow-up
   task or sub-phase that will discharge it (e.g.,
   `-- sorry: assumes X; deferred because Y; follow-up: task NNN`).
4. **Tracked**: The sorry is recorded in the handoff `sorry_inventory` with `strategic: true` and
   a non-null `follow_up_task`. An undocumented or untracked sorry is never strategic — it forces
   `status: "partial"` or `status: "blocked"`, not `"implemented"`.
5. **Build-green**: `sorry` is Lean4's canonical build-green placeholder — `lake build` (or a
   scoped module build) must still succeed with the sorry present. Track via `#print axioms
   <decl>` (showing `sorryAx` in the axiom list) and/or the `declaration uses 'sorry'` compiler
   warning to confirm the sorry is real and located exactly where documented.

A dispatch meeting all five conditions for every main-target sorry it introduces reports
`status: "implemented"` with `skeleton: true` (see core `wrap-up.md` for the field and the full
`sorry_inventory` schema), rather than being forced toward `partial`/`blocked` or into
analysis-paralysis. **Non-strategic main-target sorries — i.e. any that fail one or more of the
five conditions — remain forbidden.** If the main theorem body is `by sorry` and the five-condition
test is not met, the dispatch has failed to make progress and the Escalation Protocol (from
lean-implementation-agent) applies.

## Interaction with H9 Sorry Inventory

Lean4 hard dispatches use the sorry_inventory field in `.orchestrator-handoff.json`
to track leaf and strategic sorries across dispatch boundaries. At the end of each dispatch:

1. All remaining sorries (leaf or strategic) MUST be enumerated in `sorry_inventory`
2. Each entry requires: `{file, line, statement, strategic, assumption, why_deferred,
   follow_up_task}`
3. The orchestrator uses sorry_inventory to dispatch targeted follow-ups
4. A dispatch with sorries but an empty sorry_inventory is NON-CONFORMING

**Echo `dispatch_seq` alongside `sorry_inventory`.** The same handoff write that carries
`sorry_inventory` MUST also echo `dispatch_seq` unchanged from the delegation context, when
present — copy the value verbatim (never invent, increment, or recompute one); omit it when the
delegation context omits it. This is the orchestrator-minted per-dispatch identity Stage 5 of
both orchestrate engines compares against the value it minted for the current cycle — see
`context/patterns/dispatch-report-not-termination.md`.
